
#
# Setup Stage: install apps
#
# This is a dedicated stage so that donwload archives don't end up on 
# production image and consume unnecessary space.
#

FROM ubuntu:22.04 as setup

ENV IB_GATEWAY_VERSION=10.37.1l
ENV IB_GATEWAY_RELEASE_CHANNEL=stable
ENV IBC_VERSION=3.23.0
ENV IBC_GATEWAY_VERSION_PATH=1037

# Prepare system
RUN apt-get update -y
RUN apt-get install --no-install-recommends --yes \
  curl \
  ca-certificates \
  unzip

WORKDIR /tmp/setup

# Install IB TWS
# Use this instead of "RUN curl .." to install a local file:
#COPY ibgateway-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh .
RUN curl -sSL https://github.com/lhshyong/ib-gateway-docker-light/releases/download/ibgateway-${IB_GATEWAY_RELEASE_CHANNEL}%40${IB_GATEWAY_VERSION}/tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh \
  --output tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh
RUN curl -sSL https://github.com/lhshyong/ib-gateway-docker-light/releases/download/ibgateway-${IB_GATEWAY_RELEASE_CHANNEL}%40${IB_GATEWAY_VERSION}/tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256 \
  --output tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256
#RUN sha256sum --check ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256

RUN chmod a+x ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh
RUN ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh -q -dir /root/Jts/${IBC_GATEWAY_VERSION_PATH}
COPY ./config/ibgateway/jts.ini /root/Jts/jts.ini
RUN ls /root/Jts/

# Install IBC
RUN curl -sSL https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip --output IBCLinux-${IBC_VERSION}.zip
RUN mkdir /root/ibc
RUN unzip ./IBCLinux-${IBC_VERSION}.zip -d /root/ibc
RUN chmod -R u+x /root/ibc/*.sh 
RUN chmod -R u+x /root/ibc/scripts/*.sh
COPY ./config/ibc/config.ini.tmpl /root/ibc/config.ini.tmpl

# Copy scripts
COPY ./scripts /root/scripts

#
# Build Stage: build production image
#

FROM ubuntu:22.04

ENV IBC_GATEWAY_VERSION=1037

WORKDIR /root

# Prepare system
RUN apt-get update -y
RUN apt-get install --no-install-recommends --yes \
  gettext \
  xvfb \
  libxslt-dev \
  libxrender1 \
  libxtst6 \
  libxi6 \
  libgtk2.0-bin \
  socat \
  x11vnc

# TWS use JxBrowser, which having dependency below
# https://teamdev.com/jxbrowser/docs/guides/introduction/requirements/
RUN apt install -y ca-certificates fonts-liberation libasound2 \
    libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libc6 libcairo2 libcups2 \
    libcurl4 libdbus-1-3 libdrm2 libexpat1 libgbm1 libglib2.0-0 libgtk-3-0 \
    libnspr4 libnss3 libpango-1.0-0 libu2f-udev libvulkan1 libx11-6 libxcb1 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 \
    wget xdg-utils


# Copy files
COPY --from=setup /root/ .
RUN chmod a+x /root/scripts/*.sh
COPY --from=setup /usr/local/i4j_jres/ /usr/local/i4j_jres

# IBC env vars
ENV TWS_MAJOR_VRSN ${IBC_GATEWAY_VERSION}
ENV TWS_PATH /root/Jts
ENV IBC_PATH /root/ibc
ENV IBC_INI /root/ibc/config.ini
ENV TWOFA_TIMEOUT_ACTION exit


ARG VERSION_TAG
LABEL version_tag=$VERSION_TAG


# Start run script
CMD ["/root/scripts/run.sh"]
