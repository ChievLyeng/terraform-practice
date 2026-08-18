output "url" {
  description = "Open this in a browser (or curl it) once apply finishes"
  value       = "http://<your-vps-ip>:${var.host_port}"
}

output "container_name" {
  value = docker_container.web.name
}
