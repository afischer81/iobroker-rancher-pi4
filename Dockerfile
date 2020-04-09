FROM balenalib/aarch64-debian:stretch

ARG IOBROKER_UID=1000
ARG IOBROKER_GID=1000

LABEL maintainer="Alexander Fischer"

ENV DEBIAN_FRONTEND noninteractive

# Install prerequisites (as listed in iobroker installer.sh)
RUN apt-get update && apt-get install -y \
    acl \
    apt-utils \
    build-essential \
    curl \
    git \
    gnupg2 \
    gosu \
    libavahi-compat-libdnssd-dev \
    libcap2-bin \
    libpam0g-dev \
    libudev-dev \
    locales \
    pkg-config \
    procps \
    python \
    python-dev \
    sudo \
    udev \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install node10
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Generating locales
RUN sed -i 's/^# *\(de_DE.UTF-8\)/\1/' /etc/locale.gen \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen

# Create scripts directory and copy scripts
RUN mkdir -p /opt/scripts/ \
    && chmod 777 /opt/scripts/
WORKDIR /opt/scripts/
COPY scripts/iobroker_startup.sh iobroker_startup.sh
COPY scripts/setup_avahi.sh setup_avahi.sh
COPY scripts/setup_packages.sh setup_packages.sh
COPY scripts/setup_zwave.sh setup_zwave.sh
RUN chmod +x iobroker_startup.sh \
    && chmod +x setup_avahi.sh \
    && chmod +x setup_packages.sh

# Install ioBroker
WORKDIR /
RUN apt-get update \
    && curl -sL https://raw.githubusercontent.com/ioBroker/ioBroker/stable-installer/installer.sh | bash - \
    && echo $(hostname) > /opt/iobroker/.install_host \
    && echo $(hostname) > /opt/.firstrun \
    && rm -rf /var/lib/apt/lists/*

# Install node-gyp
WORKDIR /opt/iobroker/
RUN npm install -g node-gyp

# Backup initial ioBroker-folder
RUN tar -czf /opt/initial_iobroker.tar.gz /opt/iobroker

# Setting up iobroker-user (shell and home directory)
RUN chsh -s /bin/bash iobroker \
    && groupmod -g ${IOBROKER_GID} iobroker && usermod -g ${IOBROKER_GID} -u ${IOBROKER_UID} --home /opt/iobroker iobroker

# Setting up ENVs
ENV ADMINPORT=8081 \
    AVAHI="false" \
    DEBIAN_FRONTEND="teletype" \
    LANG="de_DE.UTF-8" \
    LANGUAGE="de_DE:de" \
    LC_ALL="de_DE.UTF-8" \
    PACKAGES="vi" \
    REDIS="false" \
    SETGID=${IOBROKER_UID} \
    SETUID=${IOBROKER_UID} \
    TZ="Europe/Berlin" \
    USBDEVICES="none" \
    ZWAVE="false"
	
# Run startup-script
ENTRYPOINT ["/opt/scripts/iobroker_startup.sh"]
