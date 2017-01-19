#!/bin/bash
# Automate EC2 Instance Setup for Ubuntu 14.04
set -e -x
sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install git apt-transport-https ca-certificates
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo touch /etc/apt/sources.list.d/docker.list && sudo chmod 777 /etc/apt/sources.list.d/docker.list
sudo echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install -y linux-image-extra-$(uname -r) docker-engine
sudo docker pull edensoftware/eden
