# Project Mimir - Bare-Metal Edge Deployment Blueprint
# Terraform configuration for deploying the Mimir fabric on Hetzner and OVH.

terraform {
  required_providers {
    hetzner = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.35"
    }
    # OVH provider would go here
  }
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

provider "hetzner" {
  token = var.hcloud_token
}

# --- Edge Nodes (Zig Proxy + WASM Execution) ---

resource "hcloud_server" "mimir_edge_eu" {
  count       = 3
  name        = "mimir-edge-eu-\${count.index}"
  image       = "ubuntu-24.04"
  server_type = "cpx31" # Compute-optimized
  location    = "fsn1"  # Falkenstein, Germany

  # Initialize the Mimir environment
  user_data = <<-EOF
              #!/bin/bash
              echo "Bootstrapping Mimir Edge Node..."
              # Install dependencies
              apt-get update && apt-get install -y curl wget git
              
              # Pull the Mimir Runtime container (GraalVM + Wasmtime)
              # Set up Zig Proxy as systemd service
              # Join the libp2p DHT network
              EOF
}

# --- Control Plane Nodes (Pony + Erlang BEAM) ---

resource "hcloud_server" "mimir_control_eu" {
  count       = 2
  name        = "mimir-control-eu-\${count.index}"
  image       = "ubuntu-24.04"
  server_type = "cax21" # ARM64 for efficiency
  location    = "nbg1"  # Nuremberg

  user_data = <<-EOF
              #!/bin/bash
              echo "Bootstrapping Mimir Control Plane Node..."
              # Start Erlang OTP cluster
              # Initialize Pony Actor Mesh
              EOF
}

# --- Private Network (Tailscale/WireGuard underlay) ---

resource "hcloud_network" "mimir_fabric" {
  name     = "mimir-global-fabric"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "mimir_eu_subnet" {
  network_id   = hcloud_network.mimir_fabric.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

output "edge_node_ips" {
  value = hcloud_server.mimir_edge_eu[*].ipv4_address
}
