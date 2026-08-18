terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# A resource with no config knobs at all — just to show that EVERY
# resource, no matter the provider, gets tracked in state the same way.
resource "random_pet" "server_name" {
  length = 2
}

# This resource's config references the one above. That reference is
# what builds Terraform's dependency graph — Terraform will always
# create random_pet.server_name before this, because it can see the
# reference, not because of the order these blocks appear in the file.
resource "local_file" "server_config" {
  filename = "${path.module}/generated/${random_pet.server_name.id}.conf"
  content  = <<-EOT
    # pretend server config for ${var.environment}
    server_name = ${random_pet.server_name.id}
    port        = ${var.app_port}
  EOT
}

# A provisioner-style resource: null_resource has no real-world effect
# of its own, it just gives you a hook to run local commands. This is
# the same mechanism (local-exec / remote-exec) you'll use in later
# stages to bootstrap a Kubernetes cluster over SSH.
resource "null_resource" "announce" {
  triggers = {
    # changing this value forces the provisioner to re-run on next apply
    config_path = local_file.server_config.filename
  }

  provisioner "local-exec" {
    command = "echo 'Wrote config for ${random_pet.server_name.id} at ${local_file.server_config.filename}'"
  }
}
