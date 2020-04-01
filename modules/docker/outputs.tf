output "docker_network_name" {
  value = docker_network.quorum.name
}

output "container_geth_datadir" {
  value = local.container_geth_datadir
}

output "container_tm_datadir" {
  value = local.container_tm_datadir
}