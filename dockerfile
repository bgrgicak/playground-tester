FROM alpine:latest

# Install essential packages using apk instead of apt-get
RUN apk update && apk add --no-cache \
    curl \
    git \
    bash \
    jq \
    unzip \
    nodejs \
    npm

# Set bash as the default shell
SHELL ["/bin/bash", "-c"]

# Set working directory
WORKDIR /app

# Add Git credentials
RUN git config --global user.email "bgrgicak@users.noreply.github.com"
RUN git config --global user.name "bgrgicak"



