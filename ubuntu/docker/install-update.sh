#!/usr/bin/env bash

#################
##### Config ####
#################

# possible stable, test, and nightly
DOCKER_CHANNEL="stable"

# docker-compose releases -> https://github.com/docker/compose/releases
DOCKER_COMPOSE_VERSION="v2.19.1"

#########################
## Remove old Versions ##
#########################

sudo apt-get purge -y docker-ce
sudo rm -rf /var/lib/docker
sudo rm /usr/local/bin/docker-compose

#########################
# Install/Update Docker #
#########################

sudo apt-get update

sudo apt-get install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) $DOCKER_CHANNEL"

sudo apt-get update

sudo apt-get install docker-ce

#################################
# Install/Update Docker Compose #
#################################

sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# show versions
sudo docker --version
sudo docker-compose --version

###############################
# create and add docker group #
###############################

sudo groupadd docker
sudo usermod -aG docker $USER
