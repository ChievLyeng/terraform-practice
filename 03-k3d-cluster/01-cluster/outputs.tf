output "kubeconfig_path" {
  description = "Absolute path other Terraform projects (or kubectl) should point at"
  value       = abspath("${path.module}/../kubeconfig.yaml")
}

output "cluster_name" {
  value = var.cluster_name
}
