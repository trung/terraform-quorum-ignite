resource "docker_container" "tessera" {
  count    = local.number_of_nodes
  name     = format("%s-tm%d", var.network_name, count.index)
  image    = docker_image.tessera.name
  hostname = format("tm%d", count.index)
  restart  = "no"
  publish_all_ports = false
  must_run = true
  ports {
    internal = var.tessera.container.port.p2p
  }
  ports {
    internal = var.tessera.container.port.thirdparty
    external = var.tessera.host.port.thirdparty_start + count.index
  }
  volumes {
    container_path = "/data/tm"
    host_path      = var.tessera_datadirs[count.index]
  }
  networks_advanced {
    name         = docker_network.quorum.name
    ipv4_address = var.tm_networking[count.index].ip.private
    aliases      = [format("tm%d", count.index)]
  }
  healthcheck {
    test         = ["CMD-SHELL", "[ -S /data/tm/tm.ipc ] || exit 1"]
    interval     = "3s"
    retries      = 20
    timeout      = "3s"
    start_period = "5s"
  }
  entrypoint = [
    "/bin/sh",
    "-c",
    <<EOF
rm -f /data/tm/*.ipc
java -Xms128M -Xmx128M \
  -jar /tessera/tessera-app.jar \
  --override jdbc.url="jdbc:h2:/data/tm/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0" \
  --override serverConfigs[1].serverAddress="unix:/data/tm/tm.ipc" \
  --override serverConfigs[2].sslConfig.serverKeyStore="/data/tm/serverKeyStore" \
  --override serverConfigs[2].sslConfig.serverTrustStore="/data/tm/serverTrustStore" \
  --override serverConfigs[2].sslConfig.knownClientsFile="/data/tm/knownClientsFile" \
  --override serverConfigs[2].sslConfig.clientKeyStore="/data/tm/clientKeyStore" \
  --override serverConfigs[2].sslConfig.clientTrustStore="/data/tm/clientTrustStore" \
  --override serverConfigs[2].sslConfig.knownServersFile="/data/tm/knownServersFile" \
  --configfile /data/tm/config.json
EOF
  ]
}