variable "nodes" {
  description = <<-EOT
    Your 3 real VPS. Exactly one must have role = "server"; the rest
    should be role = "agent". private_ip should be the VPS's private
    network IP if your provider gives you one between these 3
    machines (DigitalOcean, Hetzner, Linode, AWS same-VPC, etc all do)
    — that keeps cluster traffic off the public internet. If there's
    no private network available, set private_ip equal to public_ip
    and lock your firewall down accordingly (see the README).
  EOT

  type = list(object({
    name       = string # e.g. "server", "agent-0", "agent-1" — just a label
    role       = string  # "server" or "agent"
    public_ip  = string  # what Terraform SSHes to, to run the install
    private_ip = string  # what nodes use to reach each other
  }))
}

variable "ssh_user" {
  description = "User Terraform SSHes in as. Must have passwordless sudo (cloud-init default 'ubuntu'/'root' users usually do)."
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the private key matching a public key already authorized on all 3 VPS"
  type        = string
  default     = "~/.ssh/id_rsa"
}
