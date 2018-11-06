# linux-helper
Some useful helping linux scripts.

## Ubuntu (16,17,18)

### Docker

#### Install or update

Install or update a docker installation:

    ./ubuntu/docker/install-update.sh
    
Or the remote one liner ;)

    wget https://raw.githubusercontent.com/ManuelReschke/linux-helper/master/ubuntu/docker/install-update.sh; chmod +x install-update.sh; sudo ./install-update.sh
    
#### Cleanup and remove

Remove all containers, images, networks and volumes

    ./ubuntu/docker/cleanup.sh
    
Or the remote one liner ;)

    wget https://raw.githubusercontent.com/ManuelReschke/linux-helper/master/ubuntu/docker/cleanup.sh; chmod +x cleanup.sh; sudo ./cleanup.sh
    