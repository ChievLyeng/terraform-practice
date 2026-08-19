terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 1.10"
    }
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

provider "lxd" {} # talks to the local LXD daemon on this VPS

# A dedicated bridge so the "nodes" have their own private subnet,
# separate from the LXD default bridge and from your Docker networks
# in earlier stages. IPv6 is disabled on this bridge — we only set up
# IPv4 NAT, so any IPv6 address would be a dead end for outbound traffic.
resource "lxd_network" "practice" {
  name = "tf-practice-br0"
  config = {
    "ipv4.address" = "10.10.20.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

# Three real, separate machines (system containers, not Docker
# containers) — this is the difference from stage 3: each of these
# has its own init system, its own kernel-visible process tree, and
# gets bootstrapped over a real command channel, the same shape as
# provisioning EC2 instances and configuring them with user-data.
resource "lxd_instance" "node" {
  for_each = toset(var.node_names)

  name  = "tf-practice-${each.key}"
  image = var.lxd_image
  type  = "container"

  # k3s runs its own embedded container runtime (containerd) inside
  # the instance, which needs cgroup/namespace operations LXD blocks
  # by default for unprivileged containers. "nesting" turns that on.
  config = {
    "security.nesting"                    = "true"
    "security.syscalls.intercept.mknod"    = "true"
    "security.syscalls.intercept.setxattr" = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = lxd_network.practice.name
    }
  }
}

# Pull each node's DHCP-assigned IP into Terraform so later steps can
# reference it as a normal value, even though no provider "owns" that
# IP the way docker_container owns a port mapping.
data "external" "node_ip" {
  for_each = lxd_instance.node

  program = ["bash", "${path.module}/scripts/get_ip.sh"]
  query   = { name = each.value.name }

  depends_on = [lxd_instance.node]
}

# Bootstrap the k3s SERVER first. We reach into the container with
# `lxc exec` instead of SSH because Terraform is already running on
# the same VPS that's hosting LXD — no need for an extra credential.
resource "null_resource" "k3s_server" {
  triggers = {
    instance_name = lxd_instance.node[var.server_node].name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      lxc exec ${self.triggers.instance_name} -- sh -c 'curl -4 -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --kubelet-arg=feature-gates=KubeletInUserNamespace=true" sh -'
      mkdir -p ${path.module}/generated
      lxc exec ${self.triggers.instance_name} -- cat /var/lib/rancher/k3s/server/node-token > ${path.module}/generated/node-token
    EOT
  }

  depends_on = [lxd_instance.node]
}

data "local_file" "node_token" {
  filename   = "${path.module}/generated/node-token"
  depends_on = [null_resource.k3s_server]
}

# Bootstrap every OTHER node as an agent, pointing it at the server's
# IP and join token. for_each here again turns one block into N real
# join operations — the same pattern as stage 2's backend containers.
resource "null_resource" "k3s_agent" {
  for_each = toset([for n in var.node_names : n if n != var.server_node])

  triggers = {
    instance_name = lxd_instance.node[each.key].name
    server_ip     = data.external.node_ip[var.server_node].result.ip
    token         = trimspace(data.local_file.node_token.content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      lxc exec ${self.triggers.instance_name} -- sh -c \
        'curl -4 -sfL https://get.k3s.io | K3S_URL=https://${self.triggers.server_ip}:6443 K3S_TOKEN=${self.triggers.token} INSTALL_K3S_EXEC="agent --kubelet-arg=feature-gates=KubeletInUserNamespace=true" sh -'
    EOT
  }

  depends_on = [null_resource.k3s_server, data.external.node_ip]
}