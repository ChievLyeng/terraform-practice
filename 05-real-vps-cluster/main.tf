terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  server_node = [for n in var.nodes : n if n.role == "server"][0]
  agent_nodes = [for n in var.nodes : n if n.role == "agent"]
}

# --- Bootstrap the k3s SERVER over real SSH ---
# This is the whole point of this stage: no LXD, no lxc exec, no
# nesting flags, no fake bridge network. Terraform connects to a
# real machine over the network, the same way it would to any cloud
# VM, and just runs the install script.
resource "null_resource" "k3s_server" {
  triggers = {
    server_ip = local.server_node.public_ip
  }

  connection {
    type        = "ssh"
    host        = local.server_node.public_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -",
    ]
  }
}

# Pull the join token back from the server so we can hand it to the
# agents. remote-exec can't return values to Terraform, so we use a
# plain SSH command from local-exec instead — the same "pull a value
# out over a side channel" idea as stage 4's data.external, just
# simpler because we don't need to discover an IP this time; we
# already know it, it's a variable.
resource "null_resource" "fetch_token" {
  depends_on = [null_resource.k3s_server]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p ${path.module}/generated
      ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} \
        ${var.ssh_user}@${local.server_node.public_ip} \
        'sudo cat /var/lib/rancher/k3s/server/node-token' \
        > ${path.module}/generated/node-token
    EOT
  }
}

data "local_file" "node_token" {
  filename   = "${path.module}/generated/node-token"
  depends_on = [null_resource.fetch_token]
}

# --- Bootstrap every agent, pointing it at the server ---
# Notice server_url uses server_node.private_ip, not public_ip.
# If your 3 VPS are on the same provider's private network, use
# that private IP here — cluster traffic (API calls, the pod
# network) then never touches the public internet at all. If your
# VPS don't have a private network between them, set private_ip to
# the same value as public_ip in your nodes list, and make sure your
# firewall only allows ports 6443/10250/8472 from the OTHER TWO
# VPS's IPs specifically, not from the whole internet.
resource "null_resource" "k3s_agent" {
  for_each = { for n in local.agent_nodes : n.name => n }

  triggers = {
    instance_name = each.value.name
    server_url    = "https://${local.server_node.private_ip}:6443"
    token         = trimspace(data.local_file.node_token.content)
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | K3S_URL=${self.triggers.server_url} K3S_TOKEN=${self.triggers.token} sh -",
    ]
  }

  depends_on = [null_resource.fetch_token]
}
