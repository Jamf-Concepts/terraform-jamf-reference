# Instructions for AI agents

This repository manages Jamf tenants with Terraform. A merge to `main` changes
real devices. Follow these rules over your own defaults.

## Before you write

- Read [CONVENTIONS.md](CONVENTIONS.md). It decides file names, resource
  names, when to use `for_each`, and where values and payloads go.
- Look up each resource in the provider documentation for the version in
  `.terraform.lock.hcl`. Do not write attributes from memory.
- Match the code around your change. If the conventions and the existing code
  disagree, follow the conventions and say so.

## What you may run

- `terraform fmt -recursive`, `terraform validate` and `tflint`
- `terraform plan -var-file=environments/dev.tfvars -parallelism=1`

## What you must not do

- Run `terraform apply`, `destroy`, `import`, `force-unlock` or any
  `terraform state` command. The pipeline applies.
- Plan against, or change anything in, an environment other than dev.
- Read, print or write a secret. No secret goes in a file.
- Push to `main`, merge a pull request, start the Release workflow or approve
  anything.
- Change `.github/`, `backend.tf`, `providers.tf`, `terraform.tf`,
  `.terraform.lock.hcl` or `environments/prod.tfvars`, unless the task asks
  for that change by name.
- Introduce anything listed in section 11 of CONVENTIONS.md.

## How to deliver a change

1. Work on a new branch named for the change.
2. Make one change. Leave code you were not asked about alone.
3. Run the format, validate and lint commands, and a plan against dev if you
   have credentials.
4. Open a pull request whose title states the change in Jamf.

## Stop and ask when

- A plan shows a replace or a destroy the task did not ask for.
- The task needs something the conventions rule out.
- The task needs a new variable that differs between environments, or a
  change to the environment setup.
- You cannot confirm an attribute in the provider documentation.

## What to report

State what you changed, what the plan showed, and what you did not verify.
