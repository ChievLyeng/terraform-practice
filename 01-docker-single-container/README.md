# Stage 1 — a real provider (Docker), one resource

Prerequisite: Docker installed on your VPS and your user able to run
`docker ps` without `sudo` (or just run `terraform` with `sudo`).

```bash
terraform init
terraform apply
```

Now check what actually happened, outside of Terraform:
```bash
docker ps                 # your container is really running
curl localhost:8081       # nginx's default page
```

Notice this config has TWO resources — `docker_image` (pulls the image)
and `docker_container` (runs it) — and the container references the
image's ID (`docker_image.nginx.image_id`). That reference is what
tells Terraform "pull the image before starting the container," the
same dependency mechanism from stage 0, just against a real API this
time.

## Things to try

Change `var.host_port` and run `terraform apply` again — Terraform will
show a plan that destroys and recreates the container (port mappings
can't be changed in place on a running container, only replaced).
Notice the image itself is untouched in that plan — only the container
resource is marked for replacement.

Change `var.nginx_version` to `"1.27"` instead of `"alpine"` and apply
again — this time both the image and the container get replaced, since
the container depends on the image's ID and that ID changed.

Run `terraform destroy` and confirm with `docker ps -a` that the
container is gone. Because `keep_locally = true`, the image itself
should still be sitting in `docker images` — try setting that to
`false` and destroying again to see the difference.
