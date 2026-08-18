variable "backend_count" {
  description = "How many backend containers to create behind the load balancer"
  type        = number
  default     = 3
}

variable "host_port" {
  description = "Port on the VPS that maps to the nginx load balancer"
  type        = number
  default     = 8082
}
