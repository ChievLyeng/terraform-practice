variable "node_names" {
  description = "Logical names for the cluster nodes; the first match of server_node becomes the k3s server, the rest join as agents"
  type        = list(string)
  default     = ["server", "agent-0", "agent-1"]
}

variable "server_node" {
  description = "Which entry in node_names runs the k3s server"
  type        = string
  default     = "server"
}

variable "lxd_image" {
  description = "LXD image alias — ubuntu images are the most reliable for the k3s install script"
  type        = string
  default     = "ubuntu:22.04"
}