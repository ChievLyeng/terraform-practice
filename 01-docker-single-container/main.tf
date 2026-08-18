terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  # Defaults to the local Docker socket (/var/run/docker.sock).
  # If your user isn't in the `docker` group, run terraform with sudo
  # instead of changing this.
}

resource "docker_image" "nginx" {
  name         = "nginx:${var.nginx_version}"
  keep_locally = true # don't delete the image from your VPS on destroy
}

resource "docker_container" "web" {
  name  = "tf-practice-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.host_port
  }
}
