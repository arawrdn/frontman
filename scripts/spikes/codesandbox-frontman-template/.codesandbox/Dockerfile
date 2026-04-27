FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    autoconf \
    bash \
    build-essential \
    ca-certificates \
    curl \
    fop \
    git \
    inotify-tools \
    jq \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libncurses5-dev \
    libnss3-tools \
    libpng-dev \
    libssh-dev \
    libssl-dev \
    libwxgtk-webview3.2-dev \
    libwxgtk3.2-dev \
    libxml2-utils \
    locales \
    postgresql-client \
    sudo \
    unixodbc-dev \
    unzip \
    wget \
    xsltproc \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /project/workspace

RUN curl https://mise.run | sh

ENV PATH="/root/.local/bin:$PATH"

RUN echo 'eval "$(/root/.local/bin/mise activate bash)"' >> /root/.bashrc
