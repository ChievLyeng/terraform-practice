output "url" {
  value = "http://<your-vps-ip>:${var.host_port}"
}

output "backend_names" {
  value = [for c in docker_container.backend : c.name]
}
