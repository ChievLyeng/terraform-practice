terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# A private network so the containers can reach each other by name,
# the same way pods on a Kubernetes network reach each other by
# service name. Nothing else can start until this exists.
resource "docker_network" "practice_net" {
  name = "tf-practice-net"
}

resource "docker_image" "whoami" {
  name         = "traefik/whoami:latest"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

# for_each turns ONE resource block into N real resources, one per
# entry in the set/map you give it. This is exactly the mechanism
# you'll use later to create N cluster nodes from one block instead
# of copy-pasting a resource three times.
resource "docker_container" "backend" {
  for_each = toset([for i in range(var.backend_count) : "backend-${i}"])

  name  = "tf-practice-${each.key}"
  image = docker_image.whoami.image_id

  networks_advanced {
    name = docker_network.practice_net.name
  }

  # WHOAMI_NAME shows up in the response body so you can tell which
  # backend answered a given request.
  env = ["WHOAMI_NAME=${each.key}"]
}

# Render an nginx upstream block listing every backend container we
# just created. This is the config-generation pattern: Terraform
# doesn't just create resources, it can compute config FROM other
# resources' attributes and hand it to the next resource.
resource "local_file" "nginx_conf" {
  filename = "${path.module}/generated/nginx.conf"
  content = templatefile("${path.module}/nginx.conf.tftpl", {
    backend_names = [for c in docker_container.backend : c.name]
  })
}

resource "docker_container" "lb" {
  name  = "tf-practice-lb"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.practice_net.name
  }

  ports {
    internal = 80
    external = var.host_port
  }

  volumes {
    host_path      = local_file.nginx_conf.filename
    container_path = "/etc/nginx/conf.d/default.conf"
    read_only      = true
  }

  # Make sure the config file is fully written and every backend
  # container exists before nginx starts, even though nothing above
  # forces that ordering through a direct attribute reference.
  depends_on = [local_file.nginx_conf, docker_container.backend]
}
