# Terraform Practice — from fundamentals to a real cluster

A staged project to learn Terraform on your own VPS, no cloud account or
credit card required. Each folder is a self-contained Terraform project.
Work through them in order — each one builds on a concept the last one
introduced.

| Stage | Folder | What you learn | Needs |
|---|---|---|---|
| 0 | `00-fundamentals` | init/plan/apply/destroy, state, variables, outputs, resource dependencies | nothing but Terraform itself |
| 1 | `01-docker-single-container` | a real provider, resource lifecycle, ports | Docker |
| 2 | `02-docker-multi-tier` | multiple resources, `for_each`, networks, dependencies between resources | Docker |
| 3 | `03-k3d-cluster` | provisioning a full Kubernetes cluster, then managing what runs inside it with the Kubernetes provider | Docker, k3d, kubectl |
| 4 (bonus) | `04-bonus-lxd-k3s` | a "real" multi-node cluster: separate machines (LXD containers) bootstrapped into k3s over SSH, the way a production cluster is actually built | LXD |

## One-time setup on your VPS

```bash
# Terraform CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Docker (needed from stage 1 onward)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # log out/in after this
```

Copy each stage's folder to your VPS (`scp -r` or `git clone` if you put
this in a repo), `cd` into it, and run:

```bash
terraform init      # downloads the provider plugins for this stage
terraform plan       # shows what WOULD change — read this every time
terraform apply       # actually creates the resources
# ... poke around, break things, look at what got created ...
terraform destroy      # tear it all down cleanly
```

Do this for every stage, even the trivial ones — the muscle memory of
`init → plan → apply → destroy` is 80% of learning Terraform. Read the
plan output carefully before typing `yes`; that habit is what prevents
expensive mistakes once you're doing this against a real cloud account.

A couple of housekeeping notes: never commit `.terraform/` or
`terraform.tfstate*` to git (each stage's `.gitignore` already excludes
them), and if `terraform apply` ever gets interrupted, always run
`terraform plan` again before touching anything — it tells you exactly
what state the world is actually in.

## The core idea running through every stage

Terraform's job is always the same shape: read the config, compare it to
its state file (what it thinks exists), diff that against reality-ish,
and make the minimum number of API calls to reconcile the two. Whether
the "API" is Docker's daemon, Kubernetes' API server, or AWS, the mental
model doesn't change — that's why practicing on a VPS with free providers
transfers directly to practicing on real cloud infrastructure later.
