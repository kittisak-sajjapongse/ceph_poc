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
sudo ./cephadm bootstrap --cleanup-on-failure --cluster-network 10.10.0.0/16 --mon-ip $PRIVATE_IP | tee bootstrap.log

##################
# Important Note:
# Ceph cluster seems to be IO (network) intensive. Network performance is critical to communication between OSDs and master
# We use the --cluster-network option to make sure that they communicate through internal network. However, we still observe
# intermittent down / slowness / long response / Pool unhealthiness with the internal network on DigitalOcean.
##################

