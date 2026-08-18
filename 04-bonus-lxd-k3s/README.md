# Stage 4 (bonus, advanced) — separate machines, bootstrapped over exec, into a real multi-node cluster

Treat this stage differently from the others: it's here to show you
what "provision separate machines, then bootstrap a cluster across
them" actually looks like end-to-end, closer to how you'd do this
against real cloud VMs. It's more fragile than the earlier stages —
LXD availability and behavior varies more by VPS/kernel than Docker
does — so read the config and adapt it rather than expecting a
guaranteed one-shot `apply`.

## Prerequisites

```bash
sudo snap install lxd
sudo lxd init --auto
sudo usermod -aG lxd $USER   # log out/in after this
sudo apt install jq          # used by the IP-lookup helper script
```

LXD needs kernel support for nested containers. This works fine on
most KVM/Xen VPS. It will NOT work inside an OpenVZ-based VPS, and may
need extra flags inside some other already-virtualized hosts. If `lxd
init` or `lxc launch images:ubuntu/22.04 test` fails outright, this
stage isn't available to you on this box — that's fine, stage 3
(k3d/Docker) already gave you real multi-node cluster practice, and
this stage is a bonus, not a requirement.

## Run it

```bash
terraform init
terraform apply
```

This creates a private LXD bridge network and three system containers
(`server`, `agent-0`, `agent-1`), waits for each to get a DHCP IP, then
uses `lxc exec` (not SSH — Terraform is already running on the same
host as LXD, so no key exchange is needed) to install k3s on the
server and join the two agents to it using the server's real node
token.

```bash
terraform output node_ips
lxc exec tf-practice-server -- kubectl get nodes
```

You should see three nodes, `Ready`, each one a completely separate
container with its own OS — this is the closest thing to a real
production cluster you can get without paying for VMs.

## What to pay attention to

Compare this file to `03-k3d-cluster`. In stage 3, k3d handled node
creation AND cluster bootstrap together as one CLI call. Here, those
are two distinct steps you can see explicitly: `lxd_instance` creates
bare machines that know nothing about Kubernetes, and separate
`null_resource` blocks bootstrap k3s onto them afterward. This is
exactly the split between Terraform (creates machines) and a
configuration tool (turns machines into a cluster) that came up when
comparing Terraform to Ansible — here the "configuration tool" step is
just a couple of shell commands instead of a full Ansible playbook,
but it's the same architectural split. If you've got Ansible from an
earlier lesson, replacing the `local-exec` provisioners here with an
Ansible playbook run against the three containers' IPs is a genuinely
good next exercise.

The `data "external"` block is worth understanding on its own: it's
how you pull an arbitrary value into Terraform when no provider
attribute exposes it (here, a DHCP-assigned IP). It runs a script,
passes it JSON on stdin, and expects JSON back — a general escape
hatch worth remembering.

## Tear down

```bash
terraform destroy
```

This deletes all three containers and the bridge network. The k3s
cluster dies with them — nothing persists outside of what Terraform
and LXD created.
