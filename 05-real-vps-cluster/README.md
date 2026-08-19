# Stage 5 — the real thing: 3 actual VPS, bootstrapped over SSH

This is what stage 4 was standing in for. No LXD, no fake bridge
network, no nesting flags, no `/dev/kmsg` workaround — none of that
exists as a problem on real, separate machines, because each one has
its own real kernel. This is also noticeably SIMPLER than stage 4,
which is the point: LXD was compensating for not having real
machines, and compensating for that added most of the complexity you
fought through.

## What you need before running this

Three VPS, from any provider, each with:
- A public IP you can SSH to
- Ubuntu (or any systemd-based Linux — Debian, Rocky, etc. all work,
  the k3s install script auto-detects it)
- Your SSH public key already authorized (`ssh-copy-id` to each one,
  or added at creation time if your provider supports it)
- Passwordless sudo for the user you'll connect as (default on most
  cloud images for the default user)

If your provider gives the 3 VPS a private network between them
(DigitalOcean VPCs, Hetzner private networks, AWS same-VPC, Linode
VLANs — most providers have some version of this), note down each
machine's private IP too. It's not required, but it means cluster
traffic never touches the public internet.

## Set up your variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your 3 real IPs, your SSH user, and the
path to your private key. This file is git-ignored — it's the one
file in this whole project meant to hold real values that shouldn't
end up in version control.

## Firewall — do this BEFORE running apply

Unlike every previous stage, these are real machines exposed to the
real internet, so their firewalls matter. Each VPS needs to accept,
from the OTHER TWO VPS specifically (not from the whole internet):

- TCP 6443 — the Kubernetes API server (agents and kubectl need this)
- TCP 10250 — kubelet API (nodes talk to each other's kubelet)
- UDP 8472 — flannel's VXLAN overlay (this is what makes pod-to-pod
  networking across nodes work — stage 4's whole IPv6/firewall saga
  was fighting a version of this exact requirement)

If you're using each VPS's private IP for cluster traffic, you can
often just allow all traffic on the private network interface between
these 3 machines and leave the public interface locked down to SSH
(22) and whatever ports your actual application needs. If you only
have public IPs, restrict those 3 ports to specifically the other 2
VPS's IPs using your provider's firewall/security-group feature —
don't leave 6443 open to the whole internet.

## Run it

```bash
terraform init
terraform apply
```

This SSHes into your server VPS, installs k3s, pulls the join token
back over SSH, then SSHes into each agent VPS and joins it to the
server — all real network hops this time, not `lxc exec` shortcuts.

Verify the same way as always, just over SSH now instead of `lxc
exec`:

```bash
ssh -i ~/.ssh/id_rsa root@<server_public_ip> kubectl get nodes
```

Or grab the kubeconfig and use `kubectl` from your own laptop:

```bash
ssh -i ~/.ssh/id_rsa root@<server_public_ip> 'sudo cat /etc/rancher/k3s/k3s.yaml' > k3s.yaml
# then edit k3s.yaml, replacing "127.0.0.1" with the server's public IP
export KUBECONFIG=$(pwd)/k3s.yaml
kubectl get nodes
```

## What's genuinely different from stage 4, and why it's simpler

The `connection` block in each `null_resource` is real SSH — the same
mechanism a human would use, with a real username, a real private
key, a real network hop. `remote-exec` runs commands over that
connection. There's no container sandbox to punch holes in, because
there's no container — each VPS is a full, independent machine with
its own kernel, its own `/dev/kmsg`, its own real cgroups, none of it
shared or restricted by a host you're borrowing space on.

This is also the version of "provision infrastructure, then configure
it" that scales to a real job: swap the `nodes` variable for VMs
created by a cloud provider's Terraform resource (`aws_instance`,
`digitalocean_droplet`, etc.) instead of pre-existing IPs you typed in
by hand, and the `remote-exec` bootstrap logic here barely changes —
you'd just reference the new VM resources' IP attributes instead of
`var.nodes[*].public_ip`.

## Tear down

Terraform only ran commands over SSH — it didn't create the VPS
themselves, so `terraform destroy` here just removes k3s from them,
not the machines:

```bash
terraform destroy
```

If you want the VPS completely clean again after that, you'd
uninstall k3s directly (the install script creates an uninstall
script at `/usr/local/bin/k3s-uninstall.sh` on the server and
`k3s-agent-uninstall.sh` on agents).
