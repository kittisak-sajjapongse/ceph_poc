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

# Create a VPC for the private network
resource "digitalocean_vpc" "ceph_network" {
  name     = "ceph-network"
  region   = var.region
  ip_range = "10.10.0.0/16"
}

# Array of configurations for storage hosts
variable "hosts" {
  default = [
    {
      name = "storage01",
      size = "s-2vcpu-2gb",
    },
    {
      name = "storage02",
      size = "s-2vcpu-2gb",
    },
    {
      name = "storage03",
      size = "s-2vcpu-2gb",
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
  EOF
}


# Droplet resources for the storage hosts, connecting only to the private network
resource "digitalocean_droplet" "storage" {
  count = length(var.hosts)

  name   = var.hosts[count.index].name
  region = var.region
  size   = var.hosts[count.index].size
  image  = "ubuntu-22-04-x64"

  vpc_uuid = digitalocean_vpc.ceph_network.id
  ipv6 = false

  # Use cloud-init to change the root password
  user_data = local.cloud_init
}

# Create 10GB volumes and attach them to the internal hosts
resource "digitalocean_volume" "storage_volumes" {
  count = length(var.hosts)

  name   = "${var.hosts[count.index].name}-volume"
  region = var.region
  size   = 10  # Size in GB
}

resource "digitalocean_volume_attachment" "volume_attachment" {
  count = length(var.hosts)

  droplet_id = digitalocean_droplet.storage[count.index].id
  volume_id  = digitalocean_volume.storage_volumes[count.index].id
}

# master server: public + private network for SSH access
resource "digitalocean_droplet" "master" {
  name   = "master"
  region = var.region
  size   = "s-2vcpu-2gb"
  image  = "ubuntu-22-04-x64"

  # Connect to both public and private networks
  vpc_uuid = digitalocean_vpc.ceph_network.id
  ipv6 = false
  
  # Enable a public IP for external access
  # ssh_keys = ["your_ssh_key_id"]  # Add your SSH key ID here

  # Use cloud-init to change the root password on master server too
  user_data = local.cloud_init
}

# Create a firewall for internal hosts, allowing SSH only from bastion
resource "digitalocean_firewall" "internal_hosts_firewall" {
  name    = "internal-hosts-firewall"
  droplet_ids = [for droplet in digitalocean_droplet.storage : droplet.id]

  # Inbound rules: Allow SSH only from the bastion private IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [digitalocean_droplet.master.ipv4_address_private]
  }

  # Allow all outbound traffic from the internal hosts
  outbound_rule {
    protocol         = "tcp"
    port_range       = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Output the private IPs of the three hosts
output "storage_private_ips" {
  value = [for host in digitalocean_droplet.storage : host.ipv4_address_private]
}

# Output the public IP of the master server
output "master_public_ip" {
  value = digitalocean_droplet.master.ipv4_address
}

