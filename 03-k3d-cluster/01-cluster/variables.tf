variable "cluster_name" {
  description = "Name k3d gives the cluster (also the kubeconfig context name)"
  type        = string
  default     = "tf-practice"
}

variable "agent_count" {
  description = "Number of worker nodes in addition to the server node"
  type        = number
  default     = 2
}
