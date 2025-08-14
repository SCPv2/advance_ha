#!/bin/bash
set -euxo pipefail
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y epel-release
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat
