variable "namespace" {
  type    = string
  default = "practice"
}

variable "replicas" {
  description = "How many nginx pods to run — this is your cluster-level for_each equivalent"
  type        = number
  default     = 3
}

variable "node_port" {
  description = "Must be in the 30000-32767 range k3d/Kubernetes reserves for NodePort services"
  type        = number
  default     = 30080
}
