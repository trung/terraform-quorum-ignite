resource "docker_container" "geth" {
  count    = local.number_of_nodes
  name     = format("%s-node%d", var.network_name, count.index)
  image    = docker_image.geth.name
  hostname = format("node%d", count.index)
  restart  = "no"
  ports {
    internal = var.geth.container.port.p2p
  }
  ports {
    internal = var.geth.container.port.raft
  }
  dynamic "ports" {
    for_each = var.geth.container.port.ws == -1 ? [{ internal = var.geth.container.port.http, external = var.geth.host.port.http_start + count.index }] : [{ internal = var.geth.container.port.http, external = var.geth.host.port.http_start + count.index }, { internal = var.geth.container.port.ws, external = var.geth.host.port.ws_start + count.index }]
    content {
      internal = ports.value["internal"]
      external = ports.value["external"]
    }
  }
  volumes {
    container_path = "/data"
    volume_name    = docker_volume.shared_volume[count.index].name
  }
  volumes {
    container_path = "/data/qdata"
    host_path      = var.geth_datadirs[count.index]
  }
  volumes {
    container_path = "/data/tm"
    host_path      = var.tessera_datadirs[count.index]
  }
  depends_on = [docker_container.ethstats]
  networks_advanced {
    name         = docker_network.quorum.name
    ipv4_address = var.geth_networking[count.index].ip.private
    aliases      = [format("node%d", count.index)]
  }
  env = ["PRIVATE_CONFIG=/data/tm/tm.ipc"]
  healthcheck {
    test         = ["CMD", "nc", "-vz", "localhost", var.geth_networking[count.index].port.http.internal]
    interval     = "3s"
    retries      = 10
    timeout      = "3s"
    start_period = "5s"
  }
  entrypoint = [
    "/bin/sh",
    "-c",
    <<RUN
    /data/qdata/wait-for-tessera.sh
    /data/qdata/start-geth.sh
RUN
  ]
  upload {
    file       = "/data/qdata/wait-for-tessera.sh"
    executable = true
    content    = <<EOF
URL="${var.tm_networking[count.index].ip.private}:${var.tessera.container.port.p2p}/upcheck"

UDS_WAIT=10
for i in $(seq 1 100)
do
  result=$(wget --timeout $UDS_WAIT -qO- --proxy off $URL)
  echo "$result"
  if [ -S $PRIVATE_CONFIG ] && [ "I'm up!" = "$result" ]; then
    break
  else
    echo "Sleep $UDS_WAIT seconds. Waiting for TxManager."
    sleep $UDS_WAIT
  fi
done
EOF
  }

  upload {
    file       = "/data/qdata/start-geth.sh"
    executable = true
    content    = <<EOF
geth \
  --identity Node${count.index + 1} \
  --datadir /data/qdata \
  --nodiscover \
  --verbosity 5 \
  --networkid ${var.network_id} \
  --nodekeyhex ${var.node_keys_hex[count.index]} \
  --rpc \
  --rpcaddr 0.0.0.0 \
  --rpcport ${var.geth_networking[count.index].port.http.internal} \
  --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus} \
%{ if var.geth.container.port.ws != -1 ~}
  --ws \
  --wsaddr 0.0.0.0 \
  --wsport ${var.geth.container.port.ws} \
  --wsapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus} \
%{ endif ~}
  --port ${var.geth_networking[count.index].port.p2p} \
  --permissioned \
  --ethstats "Node${count.index + 1}:${var.ethstats_secret}@${var.ethstats_ip}:${var.ethstats.container.port}" \
  --unlock 0 \
  --password /data/qdata/${var.password_file_name} ${var.additional_geth_args} \
  ${var.consensus == "istanbul" ? "--istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1" : format("--raft --raftport %d", var.geth_networking[count.index].port.raft)}
EOF
  }
}