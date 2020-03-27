variable "number_of_nodes" {
  description = "Number of nodes in the network"
}

variable "consensus" {
  description = "Consensus algorithm being used in the network. Supported values are: istanbul and raft"
}

variable "geth" {
  type = object({
    container = object({
      image = string
      port  = object({ raft_start = number, p2p = number, http = number, ws = number })
    })
    host = object({
      port = object({ http_start = number, ws_start = number })
    })
  })
  default = {
    container = {
      image = "quorumengineering/quorum:2.5.0"
      port  = { raft_start = 50400, p2p = 21000, http = 8545, ws = -1 }
    }
    host = {
      port = { http_start = 21000, ws_start = -1 }
    }
  }
  description = "geth Docker container configuration "
}

variable "tessera" {
  type = object({
    container = object({
      image = string
      port  = object({ thirdparty = number, p2p = number })
    })
    host = object({
      port = object({ thirdparty_start = number })
    })
  })
  default = {
    container = {
      image = "quorumengineering/tessera:0.10.3"
      port  = { thirdparty = 9080, p2p = 9000 }
    }
    host = {
      port = { thirdparty_start = 9080 }
    }
  }
  description = "tessera Docker container configuration"
}