# Stage 0 — Fundamentals (no real infrastructure needed)

This stage has zero dependencies — it doesn't touch Docker, Kubernetes,
or any VPS resource. It exists purely to drill the workflow and the
core vocabulary before you point Terraform at anything real.

```bash
terraform init
```
Downloads the three providers this config uses (`random`, `local`,
`null`) into a local `.terraform/` folder. You do this once per project
(and again whenever you add a new provider).

```bash
terraform plan
```
Shows you exactly what Terraform WOULD do, without doing it. Read this
output line by line: `+` means create, `~` means update in place, `-`
means destroy. On a fresh run everything should be `+`.

```bash
terraform apply
```
Runs the plan for real (it'll ask you to confirm — type `yes`). Notice
it prints outputs at the end — those come from `outputs.tf`.

Now look around:
```bash
cat generated/*.conf         # the file Terraform actually created
cat terraform.tfstate | less  # Terraform's record of what it created — never hand-edit this
terraform show                # a human-readable view of the same state
```

Try changing `var.app_port` in a `terraform.tfvars` file or with
`-var="app_port=9090"` and run `terraform plan` again — you'll see it
wants to update `local_file.server_config` in place, but it will NOT
want to touch `random_pet.server_name`, because nothing about that
resource's inputs changed. This is the core Terraform idea: it only
touches what actually needs to change.

```bash
terraform destroy
```
Removes everything it created. Confirm the `generated/` folder is now
empty.

## Things to try before moving on

Run `terraform apply` a second time right after the first, with no
changes — Terraform should report "No changes." Then delete the
generated `.conf` file by hand (outside of Terraform) and run
`terraform plan` again — Terraform will notice the real world drifted
from its state and offer to recreate the file. This "drift detection"
is one of the most important things to internalize early: Terraform
doesn't trust that the world matches its state, it checks.
