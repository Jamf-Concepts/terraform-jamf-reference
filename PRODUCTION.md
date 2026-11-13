# Taking the project to production

> **You are on the `ref-jamfplatform-gitops` branch.** This guide follows the
> session in [README.md](README.md). Complete that first.

The session leaves you with one tenant, dev, changed through pull requests.
This guide adds a production tenant, explains how a change reaches it, and
lists what to adjust when you make the project your own. Section 3 gives the
reason behind each design choice. [CONVENTIONS.md](CONVENTIONS.md) sets the
rules for naming and layout as the project grows.

> **Requires prod.** Every step in section 1 needs a second tenant and
> credentials for it.
>
> A mistake here reaches real devices. Scope the first resources you promote
> to a pilot group, read each prod plan in full, and treat a 🟠 replace or
> 🔴 destroy row as a reason to stop and ask.

---

## 1. Add production

### 1.1 Describe the prod tenant

Set the gateway URL and the environment ID of your production tenant in
`environments/prod.tfvars`.

### 1.2 Create two GitHub environments

| GitHub environment | Used by | Credentials | Protection |
| --- | --- | --- | --- |
| `prod-plan` | Plans on pull requests, the release preview before approval, drift detection | An integration with the Read action of each permission in section 3.4 of the README and no other action | None |
| `prod` | The apply | An integration with the permissions from section 3.4 of the README | Required reviewers |

Two environments keep the write credentials behind the approval. A plan on a
pull request runs code nobody has reviewed yet, so it gets credentials that can
read and nothing more.

```bash
gh api --method PUT "repos/{owner}/{repo}/environments/prod-plan" --silent
```

```bash
gh api --method PUT "repos/{owner}/{repo}/environments/prod" --silent
```

Store the same three secrets in each, as in section 4.6 of the README, with
`--env prod-plan` and `--env prod`. Keep prod state apart from dev state if
your organisation separates access to production data.

On GitHub, open **Settings**, **Environments**, **prod**, tick **Required
reviewers** and add the people who approve production changes. GitHub offers
required reviewers on private repositories in paid plans.

To give dev the same split, create a `dev-plan` environment with a read-only
integration, then add `github_environment: dev-plan` to the dev job in
`pull-request.yml` and in `drift.yml`, the way the prod jobs pass `prod-plan`.

### 1.3 Turn prod on

```bash
gh variable set PROD_ENABLED --body true
```

The workflows skip every prod job until this variable is `true`.

### 1.4 How a change reaches prod

A merge changes dev and nothing else. Prod changes when you run the
**Release** workflow. You decide when that happens and how many merged changes
it carries.

1. You open a pull request. It gains two plan comments, one for dev and one for
   prod. The prod plan compares the pull request with prod, so it also lists
   changes that have merged and await a release.
2. You merge. **Deploy** applies the commit to dev. You test the change there.
3. When dev holds what you want in prod, you start a release:

   ```bash
   gh workflow run release.yml
   ```

   On GitHub, the same control is **Actions**, **Release**, **Run workflow**.
4. **Release** checks that the commit is on `main` and that dev applied it,
   plans the commit against prod, shows the plan in the run summary, and
   waits.
5. A required reviewer opens the run, reads the prod plan, and clicks **Review
   deployments**, then **Approve and deploy**.
6. **Release** applies to prod.
7. **Release** publishes a release named after the date and time in UTC, such
   as `prod-2026-11-13-1344`. Its notes list every pull request merged since
   the previous release. That list is your change record.

GitHub records who started the release, who approved it and when, next to the
plan and the apply log. The workflow publishes a release only after prod
applies, so the latest release names what prod runs.

**Key points:**

- Dev is your test. Check each change on a dev device before you release.
- A release carries every commit up to the one it names. To release some
  merged changes and hold back later ones, name the last commit you want:

  ```bash
  gh workflow run release.yml -f commit=<commit-id>
  ```

  `git log --oneline` lists the commits on `main` with the ID of each.
- You cannot release a later change without the earlier ones. If an earlier
  change is not ready, revert it as in section 7 of the README and merge it
  again later, or
  ship it to prod switched off or scoped to a pilot group through a value in
  `environments/prod.tfvars`.
- Release often. A long gap between dev and prod makes each release larger and
  harder to review.
- The prod job plans again after the approval and applies that plan. If the
  tenant changed between the preview and the approval, the applied plan differs
  from the preview. The run summary shows the plan it applied.
- Drift detection compares prod with the latest release, so merged changes
  that await a release do not count as drift.
- A failed check or a rejected approval publishes nothing and changes nothing.

### 1.5 Revert in prod

Revert through a pull request, as in section 7 of the README, let dev apply
it, then run a
release. The revert of a bad change is a production change too, so it takes
the same route and the same approval.

If prod is broken and cannot wait for that, release the last good commit:

```bash
gh workflow run release.yml -f commit=<commit-id>
```

Prod returns to that commit while `main` stays ahead. Then revert the bad
change on `main`, or the next release delivers it again. GitHub refuses to
publish a release for a commit that predates a change to the pipeline files,
and the workflow stops before it touches prod in that case. Use the revert.

If the bad change has merged and no release contains it, prod never received
it. Revert it and carry on.

### 1.6 Import with two tenants

An import block names an ID, and each tenant assigns its own IDs. A block that
is right for prod fails in dev.

**Adopting an existing production tenant.** Most teams start here: production
holds years of configuration and the sandbox is empty.

1. Run [jamformer](https://github.com/Jamf-Concepts/jamformer) against prod. It
   writes resource files in this project's layout, with import blocks beside
   them.
2. On your machine, with prod credentials and the prod state selected, plan with
   `-var-file=environments/prod.tfvars -parallelism=1`. Trim the generated configuration
   until the plan shows imports and no other action.
3. Apply from your machine. This is the one apply you run outside the
   pipeline, because it must finish before dev sees the configuration.
4. Delete the import blocks, then open a pull request with the configuration.
   The prod plan shows no changes. The dev plan creates every object, which
   brings the sandbox in line with production.

From then on, changes flow from dev to prod.

**Adopting one object later.** Limit the import block to the tenant that holds
the object. Declare the environment name as a variable:

```hcl
variable "environment" {
  description = "Name of the environment this run targets."
  type        = string
}
```

Set `environment = "dev"` and `environment = "prod"` in the two tfvars files,
then write the block:

```hcl
import {
  for_each = var.environment == "prod" ? ["6900"] : []

  to = jamfplatform_pro_category.main["printers"]
  id = each.value
}
```

The prod plan imports the object and the dev plan creates it.

### 1.7 Secrets that differ per tenant

Automated Device Enrollment and volume purchasing tokens come from Apple, and
each tenant needs its own. Treat a token as a secret that differs per
environment:

```hcl
variable "ade_server_token" {
  description = "Base64-encoded Automated Device Enrollment server token (.p7m) for this environment."
  type        = string
  sensitive   = true
}

resource "jamfplatform_pro_automated_device_enrollment" "main" {
  name                    = "Automated Device Enrollment"
  server_token            = var.ade_server_token
  server_token_wo_version = 1
}
```

Store the token in each GitHub environment:

```bash
base64 -i token.p7m | gh secret set ADE_SERVER_TOKEN --env dev
```

Then pass it to Terraform by adding one line to the `env` block in
`.github/workflows/terraform.yml`:

```yaml
      TF_VAR_ade_server_token: ${{ secrets.ADE_SERVER_TOKEN }}
```

The provider sends `server_token` to Jamf and keeps it out of state. To rotate
the token, update the secret and raise `server_token_wo_version` by one.

This example needs a token from Apple Business Manager, so the session does not
run it.

---

## 2. Make it yours

### 2.1 Another state backend

The session stores state in PostgreSQL on Neon because it is free and quick to
set up. Your organisation may prefer S3, Azure Storage, Google Cloud Storage
or HCP Terraform. The backend touches three places, and nothing else in the
project depends on it:

| Place | What is specific to the backend |
| --- | --- |
| `backend.tf` | The backend block |
| `.github/workflows/terraform.yml` | The lines under the comment **State backend**: two environment variables and one check step |
| GitHub environments | The secret that holds the backend credentials |

To switch:

1. Replace the block in `backend.tf` with the block for your backend. Give each
   environment its own state through a
   [partial configuration](https://developer.hashicorp.com/terraform/language/backend#partial-configuration),
   for example a state key per environment.
2. In `.github/workflows/terraform.yml`, replace the lines under **State
   backend** with your backend's credentials and settings.
3. Store the new credentials in each GitHub environment.
4. Run `terraform init -migrate-state` once per environment to copy the state
   across.

### 2.2 State locks

Terraform locks the state for the length of a plan or an apply. A second run
waits up to five minutes for the lock, then fails with
`Error acquiring the state lock`.
[Clear a state lock](runbooks/clear-a-state-lock.md) has the procedure.

### 2.3 Notes on the session backend

These apply to PostgreSQL on Neon and to no other backend.

- **Connection string.** Copy it with **Connection pooling** off and change
  `sslmode=require` to `sslmode=verify-full`, as in section 4.4 of the
  README. A pooled
  string connects and plans, and its lock protects nothing. The pipeline
  refuses a pooled string.
- **Locks.** The lock lives as long as the database connection that took it,
  so it ends when the run ends. `terraform force-unlock` does not work with
  this backend.
- **A lock that outlives its run.** End the stuck connection from the Neon
  console, in **SQL Editor**. This ends every session that holds a Terraform
  lock in that database, so check that no run is in progress for any
  environment that stores state there.

  ```sql
  SELECT pg_terminate_backend(pid) FROM pg_locks WHERE locktype = 'advisory';
  ```

- **New password.** In the Neon console, click **Connect**, then **Reset
  password**, and copy the new connection string.

### 2.4 Another CI platform

The workflows hold little logic. `plan-summary.sh` runs anywhere with
`terraform` and `jq`. `pr-comment.sh`, `apply-report.sh` and `drift-issue.sh`
call the GitHub CLI, and each needs those calls swapped for your platform's
API.

---

## 3. Why the project is built this way

Each decision below favours the option a team new to Terraform can read,
operate and explain to an auditor.

| Decision | Choice | Reason |
| --- | --- | --- |
| Repositories | One | Policies, profiles, groups and scripts reference each other. One repository keeps a change and its dependencies in one pull request. |
| Layout | Flat, no modules | Modules pay off once you deploy the same building blocks to many customers. One organisation with two tenants gains indirection and nothing else. This is also the layout [jamformer](https://github.com/Jamf-Concepts/jamformer) writes. |
| Environments | One configuration, one tfvars file per environment | Dev and prod run the same commit, so their configuration cannot diverge. A tfvars file holds what must differ. |
| State | Remote, one state per environment | An apply to dev cannot touch prod. The lock stops two runs writing state at once. |
| Secrets | Environment variables, stored as CI secrets | No secret enters the repository or a tfvars file. |
| Branching | One long-lived branch, `main` | Short-lived branches merge through pull requests. Environment branches drift apart and need merges to promote. |
| Promotion | A merge applies to dev. Running a release promotes a commit on `main` to prod, after an approval. | You choose when prod changes and how many merged changes go together. The release is the change record and the approval is the audit record. Every CI platform can run a pipeline on demand and gate it. |
| Rollback | Revert the commit through a pull request | The revert gets the same checks, plan and approval as any change. |
| Who applies | The pipeline | People plan on their own machines and never apply. State and the audit trail stay in one place. |
