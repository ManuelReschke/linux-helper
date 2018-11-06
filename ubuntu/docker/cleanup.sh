#!/bin/bash

# stop all running containers
sudo docker stop $(sudo docker ps -a -q)

# delete all containers
sudo docker rm $(sudo docker ps -a -q)

# delete all images
sudo docker rmi -f $(sudo docker images -q)

# delete all networks
sudo docker network prune -f

# delete all volumes
sudo docker volume prune -f