variable "nginx_version" {
  description = "Docker tag for the nginx image"
  type        = string
  default     = "alpine"
}

variable "host_port" {
  description = "Port on the VPS that maps to nginx's port 80"
  type        = number
  default     = 8081
}
