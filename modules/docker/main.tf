locals {
  number_of_nodes = 4
}

resource "docker_network" "quorum" {
  name = format("%s-net", var.network_name)
  ipam_config {
    subnet = var.network_cidr
  }
}

resource "docker_volume" "shared_volume" {
  count = local.number_of_nodes
  name  = format("vol%d", count.index)
}