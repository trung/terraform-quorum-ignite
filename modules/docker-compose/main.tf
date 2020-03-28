locals {
  node_indices        = range(length(var.geth_datadirs))
  container_tm_dir    = "/data/tm"
  container_qdata_dir = "/data/qdata"
  container_tm_ipc    = "${local.container_tm_dir}/tm.ipc"

  geth_consensus_args = [for idx in local.node_indices :
    (var.consensus == "istanbul" ? "--istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1" : "--raft --raftport ${var.geth_networking[idx].port.raft}")
  ]
}

resource "local_file" "docker-compose" {
  filename = format("%s/docker-compose.yml", var.output_directory)
  content  = <<-EOF
version: "3.6"
x-quorum-def:
  &quorum-def
  restart: "no"
  expose:
    - ${var.geth.container.port.p2p}
    - ${var.geth.container.port.raft}
  healthcheck:
    test: ["CMD", "nc", "-vz", "localhost", "${var.geth.container.port.http}"]
    interval: 3s
    timeout: 3s
    retries: 10
    start_period: 5s
  entrypoint:
    - /bin/sh
    - -c
    - |
      UDS_WAIT=10
      for i in $$(seq 1 100)
      do
        result=$$(wget --timeout $$UDS_WAIT -qO- --proxy off $$TXMANAGER_IP:${var.tessera.container.port.p2p}/upcheck)
        echo "$$result"
        if [ -S $$PRIVATE_CONFIG ] && [ "I'm up!" = "$$result" ]; then
          break
        else
          echo "Sleep $$UDS_WAIT seconds. Waiting for TxManager."
          sleep $$UDS_WAIT
        fi
      done
      geth \
        --identity Node$$NODE_ID \
        --datadir $$DDIR \
        --nodiscover \
        --verbosity 5 \
        --networkid ${var.network_id} \
        --nodekeyhex $$NODEKEY_HEX \
        --rpc \
        --rpcaddr 0.0.0.0 \
        --rpcport ${var.geth.container.port.http} \
        --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus} \
        --port ${var.geth.container.port.p2p} \
        --permissioned \
        --ethstats "Node$$NODE_ID:${var.ethstats_secret}@${var.ethstats_ip}:${var.ethstats.container.port}" \
        --unlock 0 \
        --password ${local.container_qdata_dir}/${var.password_file_name} \
        $$GETH_ARGS
x-tx-manager-def:
  &tx-manager-def
  expose:
    - ${var.tessera.container.port.p2p}
    - ${var.tessera.container.port.thirdparty}
  restart: "no"
  healthcheck:
    test: ["CMD-SHELL", "[ -S ${local.container_tm_dir}/tm.ipc ] || exit 1"]
    interval: 3s
    timeout: 3s
    retries: 20
    start_period: 5s
  entrypoint:
    - /bin/sh
    - -c
    - |
      rm -f ${local.container_tm_dir}/*.ipc
      java -Xms128M -Xmx128M \
        -jar /tessera/tessera-app.jar \
        --override jdbc.url="jdbc:h2:${local.container_tm_dir}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0" \
        --override serverConfigs[1].serverAddress="unix:${local.container_tm_ipc}" \
        --override serverConfigs[2].sslConfig.serverKeyStore="${local.container_tm_dir}/serverKeyStore" \
        --override serverConfigs[2].sslConfig.serverTrustStore="${local.container_tm_dir}/serverTrustStore" \
        --override serverConfigs[2].sslConfig.knownClientsFile="${local.container_tm_dir}/knownClientsFile" \
        --override serverConfigs[2].sslConfig.clientKeyStore="${local.container_tm_dir}/clientKeyStore" \
        --override serverConfigs[2].sslConfig.clientTrustStore="${local.container_tm_dir}/clientTrustStore" \
        --override serverConfigs[2].sslConfig.knownServersFile="${local.container_tm_dir}/knownServersFile" \
        --configfile ${local.container_tm_dir}/config.json
services:
%{for i in local.node_indices~}
  node${i}:
    << : *quorum-def
    image: ${var.geth.container.image}
    container_name: ${var.network_name}-node${i}
    hostname: node${i}
    ports:
      - ${format("%d:%d", var.geth.host.port.http_start + i, var.geth.container.port.http)}
    volumes:
      - vol${i}:/data
      - .${trimprefix(element(var.geth_datadirs, i), var.output_directory)}:${local.container_qdata_dir}
      - .${trimprefix(element(var.tessera_datadirs, i), var.output_directory)}:${local.container_tm_dir}
    depends_on:
      - tm${i}
      - ethstats
    networks:
      ${var.network_name}-net:
        ipv4_address: ${var.geth_networking[i].ip.private}
        aliases:
          - node${i}
    environment:
      - PRIVATE_CONFIG=${local.container_tm_ipc}
      - GETH_ARGS=${local.geth_consensus_args[i]}
      - TXMANAGER_IP=${var.tm_networking[i].ip.private}
      - NODE_ID=${format("%d", i + 1)}
      - DDIR=${local.container_qdata_dir}
      - NODEKEY_HEX=${element(var.node_keys_hex, i)}
  tm${i}:
    << : *tx-manager-def
    image: ${var.tessera.container.image}
    container_name: ${var.network_name}-tm${i}
    hostname: txmanager${i}
    ports:
      - ${format("%d:%d", var.tessera.host.port.thirdparty_start + i, var.tessera.container.port.thirdparty)}
    volumes:
      - vol${i}:/data
      - .${trimprefix(element(var.tessera_datadirs, i), var.output_directory)}:${local.container_tm_dir}
    networks:
      ${var.network_name}-net:
        ipv4_address: ${var.tm_networking[i].ip.private}
%{endfor~}
  ethstats:
    container_name: ${var.network_name}-ethstats
    hostname: ethstats
    image: "puppeth/ethstats:latest"
    expose:
      - ${var.ethstats.container.port}
    ports:
      - ${var.ethstats.host.port}:${var.ethstats.container.port}
    environment:
      - WS_SECRET=${var.ethstats_secret}
    healthcheck:
      test: ["CMD", "nc", "-vz", "localhost", "${var.ethstats.container.port}"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 3s
    networks:
      ${var.network_name}-net:
        ipv4_address: ${var.ethstats_ip}
networks:
  ${var.network_name}-net:
    name: ${var.network_name}-net
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: ${var.network_cidr}
volumes:
%{for i in local.node_indices~}
  "vol${i}":
%{endfor~}
EOF
}
