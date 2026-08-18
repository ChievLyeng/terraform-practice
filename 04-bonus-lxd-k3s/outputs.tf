output "server_ip" {
  value = data.external.node_ip[var.server_node].result.ip
}

output "how_to_use_kubectl" {
  value = "lxc exec ${lxd_instance.node[var.server_node].name} -- cat /etc/rancher/k3s/k3s.yaml"
}

output "node_ips" {
  value = { for k, v in data.external.node_ip : k => v.result.ip }
}
