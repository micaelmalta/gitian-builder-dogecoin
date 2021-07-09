#!/bin/bash

sudo apt update
sudo apt install -y ruby git build-essential apt-transport-https ca-certificates \
     curl gnupg-agent software-properties-common

os=`lsb_release -is| awk '{print tolower($0)}'`
release=`lsb_release -cs| awk '{print tolower($0)}'`

curl -fsSL https://download.docker.com/linux/$os/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$os $release"

sudo apt update

sudo apt install -y docker-ce
sudo apt upgrade -y

sudo usermod -aG docker `whoami`
#newgrp docker
sudo systemctl enable docker
sudo systemctl start docker