resource "local_file" "docker-compose" {
  filename = format("%s/docker-compose.yml", local.out_dir)
  content  = <<-EOF
version: "3.6"
x-quorum-def:
  &quorum-def
  restart: "no"
  expose:
    - "${local.container_p2p_port}"
  healthcheck:
    test: ["CMD", "nc", "-vz", "localhost", "${local.container_rpc_port}"]
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
        result=$$(wget --timeout $$UDS_WAIT -qO- --proxy off $$TXMANAGER_IP:${local.container_tm_p2p_port}/upcheck)
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
        --networkid ${local.network_id} \
        --nodekeyhex $$NODEKEY_HEX \
        --rpc \
        --rpcaddr 0.0.0.0 \
        --rpcport ${local.container_rpc_port} \
        --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus} \
        --port ${local.container_p2p_port} \
        --permissioned \
        --ethstats "Node$$NODE_ID:${random_id.ethstat_secret.hex}@${local.ethstats_ip}:${local.container_ethstats_port}" \
        --unlock 0 \
        --password ${local.container_qdata_dir}/${local.password_file_name} \
        $$GETH_ARGS
x-tx-manager-def:
  &tx-manager-def
  expose:
    - ${local.container_tm_p2p_port}
    - ${local.container_tm_third_party_port}
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
    image: ${local.quorum_docker_image}
    container_name: ${local.network_name}-node${i}
    hostname: node${i}
    ports:
      - ${format("%d:%d", local.host_rpc_port_start + i, local.container_rpc_port)}
    volumes:
      - vol${i}:/data
      - .${trimprefix(element(module.quorum.data_dirs, i), local.out_dir)}:${local.container_qdata_dir}
      - .${trimprefix(element(module.quorum.tm_dirs, i), local.out_dir)}:${local.container_tm_dir}
    depends_on:
      - tm${i}
      - ethstats
    networks:
      ${local.network_name}-net:
        ipv4_address: ${local.geth_networking[i].ip.private}
        aliases:
          - node${i}
    environment:
      - PRIVATE_CONFIG=${local.container_tm_ipc}
      - GETH_ARGS=${local.geth_consensus_args[i]}
      - TXMANAGER_IP=${local.tm_networking[i].ip.private}
      - NODE_ID=${format("%d", i + 1)}
      - DDIR=${local.container_qdata_dir}
      - NODEKEY_HEX=${element(module.quorum.node_keys_hex, i)}
  tm${i}:
    << : *tx-manager-def
    image: ${local.tessera_docker_image}
    container_name: ${local.network_name}-tm${i}
    hostname: txmanager${i}
    ports:
      - ${format("%d:%d", local.host_tm_thirdparty_port_start + i, local.container_tm_third_party_port)}
    volumes:
      - vol${i}:/data
      - .${trimprefix(element(module.quorum.tm_dirs, i), local.out_dir)}:${local.container_tm_dir}
    networks:
      ${local.network_name}-net:
        ipv4_address: ${local.tm_networking[i].ip.private}
%{endfor~}
  ethstats:
    container_name: ${local.network_name}-ethstats
    hostname: ethstats
    image: "puppeth/ethstats:latest"
    expose:
      - ${local.container_ethstats_port}
    ports:
      - ${local.host_ethstats_port}:${local.container_ethstats_port}
    environment:
      - WS_SECRET=${random_id.ethstat_secret.hex}
    healthcheck:
      test: ["CMD", "nc", "-vz", "localhost", "${local.container_ethstats_port}"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 3s
    networks:
      ${local.network_name}-net:
        ipv4_address: ${local.ethstats_ip}
networks:
  ${local.network_name}-net:
    name: ${local.network_name}-net
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: ${local.container_network_cidr}
volumes:
%{for i in local.node_indices~}
  "vol${i}":
%{endfor~}
EOF
}
