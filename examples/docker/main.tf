variable "consensus" {
  default = "istanbul"
}

variable "network_name" {
  default = "my-network"
}

variable "number_of_nodes" {
  default = 4
}

module "helper" {
  source          = "../../modules/docker-helper"
  consensus       = var.consensus
  number_of_nodes = var.number_of_nodes
}

module "network" {
  source          = "../../"
  concensus       = module.helper.consensus
  network_name    = var.network_name
  geth_networking = module.helper.geth_networking
  tm_networking   = module.helper.tm_networking
}

module "docker" {
  source = "../../modules/docker"

  consensus       = module.helper.consensus
  geth            = module.helper.geth_docker_config
  tessera         = module.helper.tessera_docker_config
  geth_networking = module.helper.geth_networking
  tm_networking   = module.helper.tm_networking
  network_cidr    = module.helper.network_cidr
  ethstats_ip     = module.helper.ethstat_ip
  ethstats_secret = module.helper.ethstats_secret

  network_name       = module.network.network_name
  network_id         = module.network.network_id
  node_keys_hex      = module.network.node_keys_hex
  password_file_name = module.network.password_file_name
  geth_datadirs      = module.network.data_dirs
  tessera_datadirs   = module.network.tm_dirs
}

output "location" {
  value = module.network.generated_dir
}