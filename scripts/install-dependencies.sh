#!/bin/bash

if [ -z "$NVM_DIR" ]; then
    export NVM_DIR="$HOME/.nvm"
fi

if [ -d "$NVM_DIR" ]; then
    source "$NVM_DIR/nvm.sh"
fi

# Install nvm if not installed
if ! command -v nvm &> /dev/null
then
    if [ ! -d "$NVM_DIR" ]; then
        mkdir -p "$NVM_DIR"
    fi
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    source "$NVM_DIR/nvm.sh"
fi


# Install Node
nvm install $(cat .nvmrc)

# Install dependencies
npm install
