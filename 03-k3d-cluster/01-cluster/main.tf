terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# k3d (k3s-in-Docker) has no official Terraform provider, so we drive
# its CLI with local-exec. This is a common, honest pattern in real
# Terraform code too: when no provider exists for a tool, you shell
# out to its CLI from a null_resource and accept that Terraform can
# only track "did the command run," not the cluster's actual state.
resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    agent_count  = var.agent_count
  }

  provisioner "local-exec" {
    command = <<-EOT
      k3d cluster create ${self.triggers.cluster_name} \
        --agents ${self.triggers.agent_count} \
        -p "30080:30080@loadbalancer" \
        --wait --timeout 120s
      k3d kubeconfig write ${self.triggers.cluster_name} \
        --output ${path.module}/../kubeconfig.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name}"
  }
}