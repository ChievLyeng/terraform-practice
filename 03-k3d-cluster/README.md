# Stage 3 — provisioning a Kubernetes cluster, then managing it

Prerequisites on your VPS:
```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install kubectl /usr/local/bin/kubectl
```

## Why this is TWO Terraform projects, not one

This is deliberate, and it's a real-world pattern, not a workaround:
`01-cluster` creates the cluster, `02-workloads` deploys things into
it. They have separate state files and you run `terraform apply` in
each one separately, in order.

The technical reason is that the Kubernetes provider needs a
kubeconfig file to exist before Terraform can even plan against it —
and that file doesn't exist until the cluster is created. Mixing
"create the cluster" and "deploy into the cluster" in one Terraform run
is a well-known source of pain for exactly this reason. The deeper
reason this split is actually a good idea is organizational: in real
companies, the team that owns cluster infrastructure and the team (or
CI pipeline) that deploys applications into it are usually different,
with different change cadences, and separate Terraform state is how
that separation is normally modeled.

## Run it

```bash
cd 01-cluster
terraform init
terraform apply          # creates a k3d cluster: 1 server + 2 agent nodes

cd ../02-workloads
terraform init
terraform apply          # deploys 3 nginx pods + a NodePort service into it
```

Check the cluster with kubectl, outside of Terraform, the same way
you'd check Docker containers in earlier stages:
```bash
export KUBECONFIG=$(pwd)/../kubeconfig.yaml   # from 02-workloads, or ../kubeconfig.yaml from 01-cluster
kubectl get nodes                # your "cluster" — 1 server + 2 agents, each a Docker container
kubectl get pods -n practice     # 3 nginx pods, scheduled across those nodes
curl localhost:30080             # hits the NodePort service
```

## What to pay attention to

`kubectl get nodes -o wide` and then `docker ps` side by side — every
"node" in this cluster is just a Docker container on your VPS. This is
exactly what a real cloud-managed Kubernetes cluster looks like from
one level up: EKS/GKE/AKS nodes are VMs, these nodes are containers,
but the Kubernetes control plane's job (scheduling pods across nodes,
restarting failed ones, load-balancing a Service across replicas) is
identical.

`kubectl get pods -n practice -o wide` — the 3 nginx replicas from
`var.replicas` are spread across your 2 agent nodes automatically by
Kubernetes' scheduler. Terraform never chose which node runs which
pod — it told Kubernetes "I want 3 replicas of this pod spec" and
Kubernetes' own control loop did the rest. This is the layering to
internalize: Terraform provisions and declares desired state,
Kubernetes' own controllers continuously reconcile it.

## Things to try

Scale `var.replicas` from 3 to 5 in `02-workloads` and `terraform
apply` — Terraform shows an in-place update to the Deployment, not a
replace, because Kubernetes deployments support scaling without
recreating anything.

Kill a pod directly with `kubectl delete pod <name> -n practice` and
watch `kubectl get pods -n practice -w` — Kubernetes recreates it
immediately on its own, without Terraform doing anything. Then run
`terraform plan` in `02-workloads` — it should report no changes,
because from Terraform's point of view the Deployment (3 replicas
desired) still matches; it doesn't track individual pods.

When you're done, tear down in reverse order:
```bash
cd 02-workloads && terraform destroy
cd ../01-cluster && terraform destroy
```
