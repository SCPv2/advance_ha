#!/bin/bash
set -euxo pipefail
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/db-server/vm_db
sudo bash install_postgresql_vm.sh