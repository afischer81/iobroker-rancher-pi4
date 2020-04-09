# iobroker-rancher-pi4
iobroker on Rancher OS on a Raspberry Pi4

## Setup

install RancherOS, e.g. from https://github.com/btharper/os-rpi-kernel/releases/download/v4.19.80-rpi4-beta/rancheros-raspberry-pi64.zip on SD card. Create empty ssh file for remote login.

Make full SD card available to docker and reserve some space for an /opt file system.

```
sudo fdisk /dev/mmcblk0
# create new partition 3 with 8G (for /opt file system)
# create new partition 4 with rest of disk space (for /mnt/docker file system)
sudo reboot
sudo mkdir /mnt/docker
sudo ros config set rancher.docker.extra_args [-g,/mnt/docker]
sudo mkfs.ext4 /dev/mmcblk0p4
sudo mkdir /mnt/opt
sudo mkfs.ext4 /dev/mmcblk0p3
sudo ros config set mounts "[['/dev/mmcblk0p3','/mnt/opt','ext4',''], ['/dev/mmcblk0p4','/mnt/docker','ext4','']]"
sudo mount /dev/mmcblk0p3 /mnt/opt
sudo mount /dev/mmcblk0p4 /mnt/docker
sudo system-docker restart docker
```

## Installation

* Build docker image

```
./install.sh build
```

* create local iobroker group and user

```
./install.sh init
```

* first run with temporary mount

```
./install.sh run first
```

wait until system is fully up,
```
docker logs iobroker

...

------------------------------------------------------------
-----          Step 5 of 5: ioBroker startup           -----
------------------------------------------------------------

Starting ioBroker...

host.23f44d8a188d check instance "system.adapter.admin.0" for host "23f44d8a188d"
host.23f44d8a188d check instance "system.adapter.discovery.0" for host "23f44d8a188d"
host.23f44d8a188d check instance "system.adapter.info.0" for host "23f44d8a188d"
```

* extract initial content of iobroker-data folder
```
./install.sh extract_data
```
* stop the first run container

```
docker rm -f iobroker
```

* real (final) start

```
./install.sh run
```
iobroker web interface shall become available at http://<iobrokerIP>:8081/
startup will again take some time (as for first run)

## Migration from existing installation

* install backitup adapter on old and new system, if not already available
* perform backup on old system
* extract/download backup (from /opt/iobroker/backups)
* copy to /opt/iobroker/backups on new system
