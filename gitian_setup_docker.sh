#!/bin/bash
# Copyright (c) 2021 The Dogecoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

if ! command -v docker &> /dev/null
then
    if command -v lsb_release &> /dev/null
    then
      ./gitian_setup_linux_apt_docker.sh | exit 1
      # logout
    else
      echo "MACOS: Docker is not available..."
      echo "Please install Docker first: https://docs.docker.com/docker-for-mac/install/"
    fi
else
  echo "Docker already setup"
fi
