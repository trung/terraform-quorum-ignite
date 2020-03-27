variable "network_name" {
  description = "Name of the network"
}

variable "geth_datadirs" {
  type        = list(string)
  description = "List of node's datadirs"
}

variable "tessera_datadirs" {
  type        = list(string)
  description = "List of Tessera working directories"
}

variable "node_keys_hex" {
  type        = list(string)
  description = "List of node keys in hex"
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
  description = "tessera Docker container configuration"
}

variable "geth_networking" {
  type = list(object({
    port = object({
      http = object({ internal = number, external = number })
      ws   = object({ internal = number, external = number })
      p2p  = number
      raft = number
    })
    ip = object({ private = string, public = string })
  }))
  description = "Networking configuration for `geth` nodes in the network. Number of items must match `tm_networking`"
}

variable "tm_networking" {
  type = list(object({
    port = object({
      thirdparty = object({ internal = number, external = number })
      p2p        = number
    })
    ip = object({
      private = string
      public  = string
    })
  }))
  description = "Networking configuration for `tessera` nodes in the network. Number of items must match `geth_networking`"
}

variable "ethstats" {
  type = object({
    container = object({ image = string, port = number })
    host      = object({ port = number })
  })
  default = {
    container = { image = "puppeth/ethstats:latest", port = 3000 }
    host      = { port = 3000 }
  }
}

variable "consensus" {}

variable "network_id" {}

variable "ethstats_secret" {}

variable "ethstats_ip" {}

variable "password_file_name" {}

variable "network_cidr" {}