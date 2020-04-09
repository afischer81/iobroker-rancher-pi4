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
        sudo -u iobroker mkdir /mnt/opt/iobroker/backups /mnt/opt/iobroker/iobroker-data
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

function do_backup {
    do_stop
    docker exec iobroker iobroker backup
    do_start
}

function do_restore {
    do_stop
    docker exec iobroker iobroker restore 0
    docker exec iobroker iobroker upload all
    do_start
}

function do_extract_data {
    docker exec iobroker cp -avx iobroker-data /mnt/tmp
    sudo -u iobroker cp -a tmp/iobroker-data/* /mnt/opt/iobroker/iobroker-data
    sudo rm -fr tmp
}

function do_run {
    if [ "$1" = "first" ]
    then
        mkdir -p $PWD/tmp
        # 1) start with a temporary mount on iobroker-data
        docker run -d -p 8081-8082:8081-8082 -v /mnt/opt/iobroker/backups:/opt/iobroker/backups -v $PWD/tmp:/mnt/tmp --cap-add=NET_ADMIN --restart unless-stopped --name iobroker ${IMAGE}
        # 2) wait until system is fully up
        echo "WAIT until iobroker is fully initialized, until docker logs iobroker shows"
        echo "------------------------------------------------------------"
        echo "-----          Step 5 of 5: ioBroker startup           -----"
        echo "------------------------------------------------------------"
        echo 
        echo "Starting ioBroker..."
        echo 
        echo "THEN run ./install.sh extract_data"
        # 3) extract iobroker-data and store in local filesystem, upon next start use that as mount
    else
        docker run -d -p 8081-8082:8081-8082 -v /mnt/opt/iobroker/backups:/opt/iobroker/backups -v /mnt/opt/iobroker/iobroker-data:/opt/iobroker/iobroker-data --cap-add=NET_ADMIN --restart unless-stopped --name iobroker ${IMAGE} noinit
    fi
}

do_$1 $2
