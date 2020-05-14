#!/usr/bin/env bash

#!/bin/bash

echo -e "\e[30;48;5;82mEDBPool E-Z Setup\e[0m"

if [[ $(id -u) -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo -e "\e[40;38;5;82mBeginning RPC/Reverse Shell Pipeline:"
sudo -u edbpool -H bash -c "cd /home/edbpool/edbpool; bash docker-mock-scripts/setup.sh"
