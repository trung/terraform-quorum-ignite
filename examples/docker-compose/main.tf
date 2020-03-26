locals {
  number_of_nodes      = 4
  quorum_docker_image  = "quorumengineering/quorum:2.5.0"
  tessera_docker_image = "quorumengineering/tessera:0.10.3"

  out_dir            = module.quorum.generated_dir
  network_id         = module.quorum.network_id
  password_file_name = module.quorum.password_file_name
  network_name       = module.quorum.network_name

  node_indices = range(local.number_of_nodes) // 0-based node index

  container_network_cidr = cidrsubnet("172.16.0.0/16", 8, random_integer.additional_bits.id)
  container_tm_dir       = "/data/tm"
  container_qdata_dir    = "/data/qdata"
  container_tm_ipc       = "${local.container_tm_dir}/tm.ipc"

  container_raft_port_start     = 50400
  container_p2p_port            = 21000
  container_rpc_port            = 8545
  container_tm_p2p_port         = 9000
  container_tm_third_party_port = 9080

  host_rpc_port_start           = 22000
  host_tm_thirdparty_port_start = 9080

  ethstats_ip             = cidrhost(local.container_network_cidr, 2)
  container_ethstats_port = 3000
  host_ethstats_port      = 3000

  geth_networking = [for idx in local.node_indices :
    {
      port = {
        http = { internal = local.container_rpc_port, external = local.host_rpc_port_start + idx }
        ws   = { internal = -1, external = -1 }
        p2p  = local.container_p2p_port
        raft = local.container_raft_port_start + idx
      }
      ip = {
        private = cidrhost(local.container_network_cidr, idx + 1 + 10)
        public  = "localhost"
      }
    }
  ]
  tm_networking = [for idx in local.node_indices :
    {
      port = {
        thirdparty = { internal = local.container_tm_third_party_port, external = local.host_tm_thirdparty_port_start + idx }
        p2p        = local.container_tm_p2p_port
      }
      ip = {
        private = cidrhost(local.container_network_cidr, idx + 1 + 100)
        public  = "localhost"
      }
    }
  ]
  geth_consensus_args = [for idx in local.node_indices :
    (var.consensus == "istanbul" ? "--istanbul.blockperiod 1 --syncmode full --mine --minerthreads 1" : "--raft --raftport ${local.geth_networking[idx].port.raft}")
  ]
}

# randomize the docker network cidr
resource "random_integer" "additional_bits" {
  max = 254
  min = 1
}

resource "random_id" "ethstat_secret" {
  byte_length = 16
}

module "quorum" {
  source          = "../../"
  concensus       = var.consensus
  network_name    = "my-network"
  geth_networking = local.geth_networking
  tm_networking   = local.tm_networking
}

variable "consensus" {
  default = "istanbul"
}