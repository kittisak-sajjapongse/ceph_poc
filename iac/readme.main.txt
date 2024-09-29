# main.tf

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {
  type = string
}

provider "digitalocean" {
  token = var.do_token
}

variable "region" {
  default = "sgp1"  # You can change this to your preferred region
}

# Create a VPC for the private network
resource "digitalocean_vpc" "private_network" {
  name   = "ceph-cluster"
  region = var.region
  ip_range = "10.10.0.0/16"
}

# Create an Internet Gateway (DigitalOcean droplets have Internet access by default, so this is implied)
# In DigitalOcean, creating a public IP automatically provides internet access

# Droplet #1
resource "digitalocean_droplet" "host1" {
  name   = "host1"
  region = var.region
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  vpc_uuid = digitalocean_vpc.private_network.id
  
  # Assign public IP for internet access
  ipv6 = false
}

# Droplet #2
resource "digitalocean_droplet" "host2" {
  name   = "host2"
  region = var.region
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  vpc_uuid = digitalocean_vpc.private_network.id
  
  ipv6 = false
}

# Droplet #3
resource "digitalocean_droplet" "host3" {
  name   = "host3"
  region = var.region
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
  
  vpc_uuid = digitalocean_vpc.private_network.id
  
  ipv6 = false
}

output "droplet_ips" {
  value = [
    digitalocean_droplet.host1.ipv4_address,
    digitalocean_droplet.host2.ipv4_address,
    digitalocean_droplet.host3.ipv4_address,
  ]
}

