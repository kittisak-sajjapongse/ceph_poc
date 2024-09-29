#!/usr/bin/env bash

# Requirements:
# 1. Operating System: Ubuntu 22.04 (jammy)
# 2. One or more raw (unformatted) block storage

set -e
sudo apt-get update
sudo apt-get install -y net-tools

# Fetch cephadm and configure the version to install
CEPH_RELEASE=18.2.4
curl --silent --remote-name --location https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm
chmod +x cephadm
sudo ./cephadm add-repo --release reef

# Install packeges including container runtime
sudo ./cephadm install

# Look for private IP address on eth1. This might only works on DigitalOcean
PRIVATE_IP=$(ip addr show eth1 | grep -oP '(?<=inet\s)10\.\d+\.\d+\.\d+')
echo "Use the following IP (eth1) for API server: $PRIVATE_IP"

# Run bootstrap
sudo ./cephadm bootstrap --cleanup-on-failure --mon-ip $PRIVATE_IP | tee bootstrap.log

