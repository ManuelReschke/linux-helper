#!/bin/bash

# stop all running containers
sudo docker stop $(sudo docker ps -a -q)