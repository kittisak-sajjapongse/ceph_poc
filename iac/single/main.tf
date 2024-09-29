terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Variables
variable "do_token" {
  type = string
}

variable "region" {
  default = "sgp1"
}

resource "digitalocean_project" "ceph_project" {
  name        = "ceph_project"
  description = "A project for learning Ceph storage"
  purpose     = "Learning Ceph Storage"
  environment = "Development"
  resources   = concat(
    [for volume in digitalocean_volume.storage_volumes : volume.urn],
    [digitalocean_droplet.master.urn]
  )
}

# Create a VPC for the private network
resource "digitalocean_vpc" "ceph_network" {
  name     = "ceph-network"
  region   = var.region
  ip_range = "10.10.0.0/16"
}

# Array of configurations for storage hosts
variable "hdds" {
  default = [
    {
      size = 10
    },
    {
      size = 10
    },
    {
      size = 10
    }
  ]
}

locals {
  cloud_init = <<-EOF
    #cloud-config
    users:
      - name: ceph
        gecos: Ceph User
        groups: sudo
        shell: /bin/bash
        sudo: ALL=(ALL:ALL) ALL
        lock_passwd: false
        passwd: $(echo 'cephpoc' | openssl passwd -1 -stdin)
    chpasswd:
      list: |
        root:changeme
      expire: False
    runcmd:
      - sed -i 's/^#ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
      - systemctl restart ssh
      - cd /root; git clone https://github.com/kittisak-sajjapongse/ceph_poc.git
  EOF
}

# Create 10GB volumes and attach them to the internal hosts
resource "digitalocean_volume" "storage_volumes" {
  count = length(var.hdds)

  name   = "volume${count.index}"
  region = var.region
  size   = var.hdds[count.index].size  # Size in GB
}

resource "digitalocean_volume_attachment" "volume_attachment" {
  count = length(var.hdds)

  droplet_id = digitalocean_droplet.master.id
  volume_id  = digitalocean_volume.storage_volumes[count.index].id
}

# master server: public + private network for SSH access
resource "digitalocean_droplet" "master" {
  name   = "master"
  region = var.region
  size   = "s-2vcpu-4gb"
  image  = "ubuntu-22-04-x64"

  # Connect to both public and private networks
  vpc_uuid = digitalocean_vpc.ceph_network.id
  ipv6 = false
  
  # Enable a public IP for external access
  # ssh_keys = ["your_ssh_key_id"]  # Add your SSH key ID here

  # Use cloud-init to change the root password on master server too
  user_data = local.cloud_init
}

# Output the public IP of the master server
output "master_public_ip" {
  value = digitalocean_droplet.master.ipv4_address
}

