data "docker_registry_image" "geth" {
  name = var.geth.container.image
}

resource "docker_image" "geth" {
  name          = data.docker_registry_image.geth.name
  keep_locally  = true
  pull_triggers = [data.docker_registry_image.geth.sha256_digest]
}

data "docker_registry_image" "tessera" {
  name = var.tessera.container.image
}

resource "docker_image" "tessera" {
  name          = data.docker_registry_image.tessera.name
  keep_locally  = true
  pull_triggers = [data.docker_registry_image.tessera.sha256_digest]
}

data "docker_registry_image" "ethstats" {
  name = var.ethstats.container.image
}

resource "docker_image" "ethstats" {
  name          = data.docker_registry_image.ethstats.name
  keep_locally  = true
  pull_triggers = [data.docker_registry_image.ethstats.sha256_digest]
}