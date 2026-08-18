# Stage 2 — multiple resources, `for_each`, generated config

This is a mini load-balancer setup: one nginx container in front of N
identical backend containers on a private Docker network. It's the
same shape as a real load-balanced service tier (or a Kubernetes
Deployment + Service), just built from Docker primitives.

```bash
terraform init
terraform apply
```

Then hit the load balancer a few times in a row and watch the backend
change:
```bash
for i in 1 2 3 4 5; do curl -s localhost:8082 | grep -i whoami_name; done
```

## What to pay attention to

`docker_container.backend` is ONE resource block that produced THREE
real containers, because of `for_each`. Run `terraform state list` and
you'll see three separate addresses
(`docker_container.backend["backend-0"]`, `["backend-1"]`,
`["backend-2"]`) — each tracked independently in state.

`local_file.nginx_conf` reads `docker_container.backend`'s names to
render `nginx.conf.tftpl`. This means the nginx config resource
depends on all three backend containers existing first, and Terraform
figured that out automatically from the reference — you didn't have
to tell it the order.

`docker_container.lb` has an explicit `depends_on` even though it
already references `local_file.nginx_conf.filename` through the
`volumes` block. That reference alone would have been enough for
ordering — the explicit `depends_on` here is mostly for clarity, and a
good example of a case where you often DON'T need `depends_on` at all
if you're already referencing an attribute.

## Things to try

Change `backend_count` to 5 and `terraform apply` — Terraform will show
a plan that ONLY adds two new containers and regenerates the nginx
config (to add them to the upstream list); the existing three backends
and the load balancer's port mapping are untouched. Watch closely
though: because the nginx config file changes, Terraform will also
show the `lb` container as needing to be replaced (the mounted file
changed) — this is worth noticing, since it's a common real-world
gotcha with bind-mounted config files.

Delete one backend container by hand with `docker rm -f
tf-practice-backend-1` and run `terraform plan` — same drift-detection
idea as stage 0, now against real infrastructure.
