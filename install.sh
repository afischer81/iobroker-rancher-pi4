#!/bin/bash

IMAGE=iobroker/aarch64
IOBROKER_UID=1102
IOBROKER_GID=1102

function do_build {
    docker build --build-arg IOBROKER_UID=${IOBROKER_UID} --build-arg IOBROKER_GID=${IOBROKER_GID} -t ${IMAGE} .
}

function do_init {
    if [ ! -d /mnt/opt/iobroker ]
    then
        sudo addgroup -g ${IOBROKER_GID} iobroker
        sudo adduser -G iobroker -u ${IOBROKER_UID} -h /mnt/opt/iobroker -s /bin/bash iobroker
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
    docker exec iobroker tar -c -f - . | sudo -u iobroker tar -x -f - -C /mnt/opt/iobroker
    sudo -u iobroker patch /mnt/opt/iobroker/node_modules/iobroker.js-controller/lib/setup/setupBackup.js setupBackup.js.diff
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
    docker run -d -p 1883:1883 -p 9011:9001 --restart unless-stopped --name mosquitto eclipse-mosquitto
}

function do_shell {
    docker exec -it iobroker /bin/bash
}

function do_run {
    if [ "$1" = "first" ]
    then
        mkdir -p $PWD/tmp
        # 1) start with a temporary mount
        docker run -d -p 8081-8082:8081-8082 --hostname iobroker --name iobroker ${IMAGE}
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
            -v /mnt/opt/iobroker:/opt/iobroker \
            -v /usr/local/bin:/usr/local/bin \
            --cap-add=NET_ADMIN \
            --hostname iobroker \
            --name iobroker \
            --network=host \
            --restart unless-stopped \
            ${IMAGE} noinit
        #    --device=/dev/bus/usb/001/003 \
        #    --device=/dev/ttyACM0 \
    fi
}

do_$1 $2
