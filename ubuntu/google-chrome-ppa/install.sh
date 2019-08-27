#!/usr/bin/env bash

# config
# channels: stable, beta, unstable
CHANNEL="stable"
# installed package name
PACKAGE="google-chrome-$CHANNEL"

# Setup key
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
# Setup repository
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
# install package
sudo apt-get update
sudo apt-get install $PACKAGE