#!/bin/bash
#
# Install dependencies required for the Playground Tester to run in a clean environment.
#
# This script will install NVM, Node.js and npm.
# After that it will install the dependencies for the Playground Tester.
#
# Usage:
#   ./scripts/install-dependencies.sh

source "./scripts/pre-script-run.sh"

NVM_DIR="$PLAYGROUND_TESTER_PATH/.nvm"

if [ -d "$NVM_DIR" ]; then
    source "$NVM_DIR/nvm.sh"
fi

# Install nvm if not installed
if [ ! -d "$NVM_DIR" ]; then
    mkdir -p "$NVM_DIR"
fi
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    source "$NVM_DIR/nvm.sh"
fi


# Install Node
nvm install $(cat .nvmrc)

# Install dependencies
npm install
