#!/bin/bash

#Update OS
dnf update -y

# Install Git
dnf install git -y


dnf -y install dnf-utils
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

#Install Docker and its components:
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

#Start and enable the Docker service
systemctl start docker
systemctl enable docker

#Check Docker version
docker --version
docker compose version

