#!/bin/bash

HOST=$(hostname -s)
# aarch64 for RASPI4
ARCH=aarch64
IMAGE=iobroker/${ARCH}
IOBROKER_UID=1102
IOBROKER_GID=1102
IOBROKER_DIR=/mnt/opt/iobroker
BACKUP_DIR=/mnt/opt/backup/${HOST}

function do_build {
    docker build --build-arg ARCH=${ARCH} IOBROKER_UID=${IOBROKER_UID} --build-arg IOBROKER_GID=${IOBROKER_GID} -t ${IMAGE} .
}

function do_init {
    if [ ! -d ${IOBROKER_DIR} ]
    then
        sudo addgroup --gid ${IOBROKER_GID} iobroker
        sudo adduser --gid ${IOBROKER_GID} --uid ${IOBROKER_UID} --home ${IOBROKER_DIR} --shell /bin/bash iobroker
        sudo mkdir ${IOBROKER_DIR}
        sudo chown -R iobroker.iobroker ${IOBROKER_DIR}
    fi
}

function get_controller_pid {
    docker exec iobroker ps -aux | grep iobroker.js-controller | awk '{ print $2 }'
}

function do_stop {
    pid=$(get_controller_pid)
    if [ $pid -gt 0 ]
    then
        echo "controller running ($pid)"
        docker exec iobroker kill $pid
    fi
}

function do_start {
    docker exec -d iobroker gosu iobroker node node_modules/iobroker.js-controller/controller.js
}

function do_restart {
    do_stop
    sleep 5
    do_start
}

function do_backup {
    do_stop
    docker exec iobroker iobroker backup
    do_start
    sleep 10
    sudo rm -f ${IOBROKER_DIR}/core
    sudo mv ${IOBROKER_DIR}/backups/$(ls -t ${IOBROKER_DIR}/backups | head -1) ${BACKUP_DIR}
    sudo rm -f ${IOBROKER_DIR}/core
    sudo chmod 644 ${BACKUP_DIR}/*iobroker*
}

function do_host {
    do_stop
    docker exec iobroker iobroker host $*
    do_start
}

function do_restore {
    backup_id=$1
    echo "restoring backup ${backup_id:=0}"
    do_stop
    docker exec iobroker iobroker restore ${backup_id}
    #docker exec iobroker iobroker upload all
    #do_start
}

function do_extract_data {
    do_stop
    docker exec iobroker tar -c -f - . | sudo -u iobroker tar -x -f - -C ${IOBROKER_DIR}
    sudo -u iobroker patch ${IOBROKER_DIR}/node_modules/iobroker.js-controller/lib/setup/setupBackup.js setupBackup.js.diff
    docker exec iobroker npm install iobroker.pilight
    # 
    docker exec iobroker apt-get update
    docker exec iobroker sudo apt-get install libpcap-dev
    docker exec iobroker iobroker install amazon-dash
    docker exec iobroker mkdir -m 700 .ssh
    docker exec iobroker ssh-keygen -t rsa -N "" -f .ssh/id_rsa
    docker exec iobroker chown -R iobroker:iobroker .ssh
}

function do_mqtt {
    docker pull eclipse-mosquitto
    # port 9001 is also used by iobroker
    docker run -d -e TZ=Europe/Berlin -p 1883:1883 -p 9011:9001 --restart unless-stopped --name mosquitto eclipse-mosquitto
}

function do_shell {
    docker exec -it iobroker /bin/bash
}

function do_ssh {
    docker exec -it --user iobroker ssh-keygen
    docker exec -it --user iobroker chmod 600 .ssh/id_rsa
    cat ${IOBROKER_DIR}/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
}

function do_switch {
    switch=$1
    state=$2
    docker exec -it --user iobroker iobroker /usr/local/bin/switch.sh 192.168.137.83 none $switch $state
    gpio readall
}

function do_run {
    if [ "$1" = "first" ]
    then
        mkdir -p $PWD/tmp
        # 1) start with a temporary mount
        docker run -d -e TZ=Europe/Berlin -p 8081-8082:8081-8082 --hostname iobroker --name iobroker ${IMAGE}
        # 2) wait until system is fully up
        echo "WAIT until iobroker is fully initialized, until docker logs iobroker shows"
        echo "------------------------------------------------------------"
        echo "-----          Step 5 of 5: ioBroker startup           -----"
        echo "------------------------------------------------------------"
        echo 
        echo "Starting ioBroker..."
        echo 
        echo "THEN run ./install.sh extract_data"
        # 3) extract iobroker and store in local filesystem, upon next start use that as mount
    else
        docker run \
            -d \
            -e TZ=Europe/Berlin \
            -v /etc/resolv.conf:/etc/resolv.conf \
            -v ${IOBROKER_DIR}:/opt/iobroker \
            -v /usr/local/bin:/usr/local/bin \
            --cap-add=NET_ADMIN \
            --device=/dev/ttyACM0 \
            --hostname ${HOST} \
            --name iobroker \
            --network=host \
            --restart unless-stopped \
            ${IMAGE} noinit
        #    --device=/dev/bus/usb/001/003 \
    fi
}

function do_check_slave {
    slave=$1
    alive=$(curl -s "http://${HOST}:8082/getPlainValue/system.host.${slave}.alive")
    if [ x"${alive}" = x"true" ]
    then
        echo $(date --rfc-3339=seconds) slave ${slave} is ${alive}
    else
        echo $(date --rfc-3339=seconds) slave ${slave} is down
        ssh ${slave} projects/iobroker-rancher-pi4/install.sh restart
    fi
}

function do_check_zigbee {
    state=$(curl -s "http://${HOST}:8082/getPlainValue/zigbee.0.000b57fffedc3be7.available")
    echo $(date --rfc-3339=seconds) zigbee is ${state}
    if [ "${state}" = "false" ]
    then
        docker exec -it iobroker iobroker restart zigbee
    fi
}

function do_net_check {
    grep EHOSTUNREACH ${IOBROKER_DIR}/log/iobroker.current.log
}

task=$1
shift
do_$task $*
