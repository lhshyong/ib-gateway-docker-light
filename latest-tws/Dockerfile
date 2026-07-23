
#
# Setup Stage: install apps
#
# This is a dedicated stage so that donwload archives don't end up on 
# production image and consume unnecessary space.
#

ARG IB_GATEWAY_VERSION=10.37.1r
ARG IB_GATEWAY_RELEASE_CHANNEL=latest
ARG IBC_VERSION=3.23.0
ARG IBC_GATEWAY_VERSION_PATH=1037

FROM ubuntu:24.04 AS setup

ARG IB_GATEWAY_VERSION
ARG IB_GATEWAY_RELEASE_CHANNEL
ARG IBC_VERSION
ARG IBC_GATEWAY_VERSION_PATH
ENV IB_GATEWAY_VERSION=${IB_GATEWAY_VERSION}
ENV IB_GATEWAY_RELEASE_CHANNEL=${IB_GATEWAY_RELEASE_CHANNEL}
ENV IBC_VERSION=${IBC_VERSION}
ENV IBC_GATEWAY_VERSION_PATH=${IBC_GATEWAY_VERSION_PATH}

# Prepare system
RUN apt-get update -y \
 && apt-get install --no-install-recommends --yes \
      curl \
      ca-certificates \
      unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/setup

# Install IB TWS
# Use this instead of "RUN curl .." to install a local file:
#COPY ibgateway-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh .
RUN curl -sSL https://github.com/lhshyong/ib-gateway-docker-light/releases/download/ibgateway-${IB_GATEWAY_RELEASE_CHANNEL}%40${IB_GATEWAY_VERSION}/tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh \
  --output tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh
RUN curl -sSL https://github.com/lhshyong/ib-gateway-docker-light/releases/download/ibgateway-${IB_GATEWAY_RELEASE_CHANNEL}%40${IB_GATEWAY_VERSION}/tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256 \
  --output tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256
RUN sha256sum --check ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh.sha256

RUN chmod a+x ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh
RUN ./tws-${IB_GATEWAY_VERSION}-standalone-linux-x64.sh -q -dir /root/Jts/${IBC_GATEWAY_VERSION_PATH}
COPY ./config/ibgateway/jts.ini /root/Jts/jts.ini

# The installer hardcodes ParallelGCThreads=20/ConcGCThreads=5, sized for a desktop.
# Those are honoured verbatim inside a container, so on a 2-vCPU host the GC runs
# 10x oversubscribed. Pin them to a middle value that suits every environment this
# image is deployed to, and that also caps the runaway case where no CPU limit is set
# on a many-core host (ergonomics would otherwise scale to the whole node).
RUN sed -i \
  -e 's/^-Xmx.*/-Xmx2048m/' \
  -e 's/^-XX:ParallelGCThreads=.*/-XX:ParallelGCThreads=8/' \
  -e 's/^-XX:ConcGCThreads=.*/-XX:ConcGCThreads=2/' \
  /root/Jts/${IBC_GATEWAY_VERSION_PATH}/tws.vmoptions

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

FROM ubuntu:24.04

ARG IBC_GATEWAY_VERSION_PATH
ENV IBC_GATEWAY_VERSION=${IBC_GATEWAY_VERSION_PATH}
ENV TZ=Etc/UTC
ENV NO_AT_BRIDGE=1

WORKDIR /root

# Prepare system (+ JxBrowser deps for TWS UI)
# https://teamdev.com/jxbrowser/docs/guides/introduction/requirements/
#
# JxBrowser's published list targets a bare system; on top of libgtk-3-0t64 and libnss3
# most of it is already satisfied. Verified with apt: naming those extras made no
# difference to the installed set (190 packages either way), so only packages that
# actually pull something in are listed. fontconfig and libx{render1,tst6,i6} are kept
# explicit despite also being GTK3 dependencies - fonts and AWT are what the VNC login
# screen needs, and they must not silently vanish if GTK3 rearranges its dependencies.
# Dropped: libu2f-udev (USB security keys, also drags in udev) and xdg-utils (hands
# URLs to a desktop browser) - both meaningless in a headless container.
# wget is kept deliberately as an in-image debugging tool.
RUN apt-get update -y \
 && apt-get install --no-install-recommends --yes \
      gettext \
      xvfb \
      x11vnc \
      xfonts-base \
      blackbox \
      socat \
      tini \
      procps \
      ca-certificates \
      fontconfig \
      fonts-dejavu-core \
      fonts-liberation \
      libxrender1 \
      libxtst6 \
      libxi6 \
      libxslt1.1 \
      libgtk-3-0t64 \
      libasound2t64 \
      libcurl4t64 \
      libnss3 \
      wget \
 && rm -rf /var/lib/apt/lists/*

# Copy files
COPY --from=setup /root/ .
RUN chmod a+x /root/scripts/*.sh
COPY --from=setup /usr/local/i4j_jres/ /usr/local/i4j_jres

# IBC env vars
ENV TWS_MAJOR_VRSN=${IBC_GATEWAY_VERSION}
ENV TWS_PATH=/root/Jts
ENV IBC_PATH=/root/ibc
ENV IBC_INI=/root/ibc/config.ini
ENV TWOFA_TIMEOUT_ACTION=exit

ARG VERSION_TAG
LABEL version_tag=$VERSION_TAG

# Start run script under tini. As PID 1 a plain shell ignores SIGTERM entirely, so
# "docker stop" always ends in SIGKILL; tini gives the container a real signal handler
# and reaps orphans. Note: a clean TWS shutdown additionally needs run.sh to
# 'exec' ibcstart.sh, otherwise the signal stops at run.sh and never reaches Java.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/root/scripts/run.sh"]
