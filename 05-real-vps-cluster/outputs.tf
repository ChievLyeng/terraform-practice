output "how_to_use_kubectl" {
  value = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${local.server_node.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "server_public_ip" {
  value = local.server_node.public_ip
}

output "agent_names" {
  value = [for n in local.agent_nodes : n.name]
}
