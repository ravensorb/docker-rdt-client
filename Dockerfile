# Stage 1 - Build the frontend
FROM node:15.5-buster AS node-build-env
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ARG BUILDPLATFORM
ENV BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}

RUN mkdir /appclient
WORKDIR /appclient

RUN \
   git clone https://github.com/rogerfar/rdt-client.git . && \
   cd client && \
   npm ci && \
   npx ng build --prod --output-path=out

# Stage 2 - Build the backend
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS dotnet-build-env
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ARG BUILDPLATFORM
ENV BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}

RUN mkdir /appserver
WORKDIR /appserver

RUN \
   echo "**** Cloning Source Code ****" && \ 
   git clone https://github.com/rogerfar/rdt-client.git . && \
   echo "**** Building Source Code for $TARGETPLATFORM on $BUILDPLATFORM ****" && \ 
   cd server && \
   if [ "$TARGETPLATFORM" = "linux/arm/v7" -o "$TARGETPLATFORM" = "linux/arm64" ] ; then \
      echo "**** Building $TARGETPLATFORM version" && \
      dotnet restore -r linux-arm RdtClient.sln && dotnet publish -r linux-arm -c Release -o out ; \
   else \
      echo "**** Building standard version" && \
      dotnet restore RdtClient.sln && dotnet publish -c Release -o out ; \
   fi

# Stage 3 - Build runtime image
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ARG BUILDPLATFORM
ENV BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io extended version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="ravensorb"

# set environment variables
ARG DEBIAN_FRONTEND="noninteractive"
ENV XDG_CONFIG_HOME="/config/xdg"
ENV RDTCLIENT_BRANCH="main"

RUN \
    mkdir -p /data/downloads /data/db || true && \
    echo "**** Updating package information ****" && \ 
    apt-get update -y -qq

RUN \
    echo "**** Install pre-reqs ****" && \ 
    apt-get install -y -qq wget && \
    apt-get install -y libc6 libgcc1 libgssapi-krb5-2 libssl1.1 libstdc++6 zlib1g libicu66

RUN \
    echo "**** Installing dotnet ****" && \
    wget -q https://dot.net/v1/dotnet-install.sh && \
    chmod +x ./dotnet-install.sh && \
    bash ./dotnet-install.sh -c Current --runtime dotnet --install-dir /usr/share/dotnet && \
    bash ./dotnet-install.sh -c Current --runtime aspnetcore --install-dir /usr/share/dotnet 

RUN \
    echo "**** Cleaning image ****" && \
    apt-get -y -qq -o Dpkg::Use-Pty=0 clean && apt-get -y -qq -o Dpkg::Use-Pty=0 purge && \
    echo "**** Setting permissions ****" && \
    chown -R abc:abc /data && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/* || true

ENV PATH "$PATH:/usr/share/dotnet"

WORKDIR /app
COPY --from=dotnet-build-env /appserver/server/out .
COPY --from=node-build-env /appclient/client/out ./wwwroot

# add local files
COPY root/ /

# ports and volumes
EXPOSE 6500
VOLUME ["/config", "/data" ]
