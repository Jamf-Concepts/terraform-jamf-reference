# From sandbox to production with Terraform and the Jamf Platform API

> **You are on the `ref-jamfplatform-gitops` branch.** This is the companion
> for the second Jamf IaC Enablement session. It follows
> `ref-jamfplatform-starter`. Other branches in this repository are unrelated.

A Terraform project you can use as a template for production. You copy it into
your own GitHub repository, store state in a remote backend, and change Jamf
through pull requests. Pipelines check each change, show you the plan, apply it
to a dev tenant, and promote the same commit to prod after an approval.

The session uses one sandbox tenant as dev. Section 12 holds every step that
needs a second tenant, so you can skip it during the session and return to it
later.

---

## 1. Learning outcomes

By the end of this session you will be able to:

- Store Terraform state in a remote backend and explain what the state lock
  protects
- Keep one configuration for several environments and vary values per
  environment
- Change Jamf through a pull request and read the plan the pipeline posts
- Revert a change you regret and recover from an apply that fails
- Detect drift on a schedule and decide how to resolve it
- Bring an object that already exists in Jamf under Terraform management
  through a pull request
- Describe how a change reaches production, who approves it, and where the
  audit trail lives

## 2. What you'll build

| Piece | Where | Purpose |
| --- | --- | --- |
| Configuration | `*.tf` at the repository root | Two categories, a smart group, a script, a policy, a configuration profile and a blueprint |
| Environment values | `environments/dev.tfvars`, `environments/prod.tfvars` | The tenant each environment targets, and the values that differ between tenants |
| Remote state | PostgreSQL on [Neon](https://neon.com) | One state per environment, with locking |
| Pipelines | `.github/workflows/` | Check, plan, apply and drift detection |
| Pipeline scripts | `.github/scripts/` | Turn a plan into a table and a coloured diff |

---

## 3. Design decisions

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
| Promotion | Merge applies to dev. An approval promotes the same commit to prod. | The approval is the audit record. Every CI platform has an equivalent gate. |
| Rollback | Revert the commit through a pull request | The revert gets the same checks, plan and approval as any change. |
| Who applies | The pipeline | People plan on their own machines and never apply. State and the audit trail stay in one place. |

The workflows run on GitHub Actions. Their logic lives in shell scripts that
need `terraform` and `jq`, so you can call the same scripts from GitLab CI,
Azure Pipelines or Bitbucket Pipelines.

---

## 4. Prerequisites

- A Jamf sandbox tenant. **Do not use production**
- The tools from the first session: git, Terraform >= 1.14.0, VS Code with the
  HashiCorp Terraform extension
- A GitHub account, working knowledge of GitHub, and the GitHub CLI (see below)
- A Neon account, signed up with your GitHub account (see below)
- Platform API credentials with the permissions below

### 4.1 Learn the GitHub basics

The session assumes you can create a branch, commit, open a pull request and
merge it. If any of those is new to you, complete these free
[GitHub Skills](https://learn.github.com/skills) courses first. Each runs in
your own GitHub account.

| Course | Covers | Time | Take it if |
| --- | --- | --- | --- |
| [Introduction to GitHub](https://github.com/skills/introduction-to-github) | Repositories, branches, commits, pull requests, merging | Under 1 hour | You have not merged a pull request before. Required. |
| [Introduction to Git](https://github.com/skills/introduction-to-git) | Commits, branches and history from the command line and VS Code | Under 1 hour | You have not committed and pushed from a terminal before |
| [Hello GitHub Actions](https://github.com/skills/hello-github-actions) | Creating and running a workflow | Under 30 minutes | You want to read the pipeline files with more confidence |

### 4.2 Install the GitHub CLI

The session creates the repository, its secrets and its pull requests from the
terminal, and reads plans and results in the browser.

```bash
brew install gh
```

```bash
gh auth login
```

Choose **GitHub.com**, **HTTPS** and **Login with a web browser**.

### 4.3 Create a Neon account

[Neon](https://neon.com) hosts PostgreSQL. Its free plan covers this session.
Neon stands in for the backend your organisation will choose, and section 13
covers the swap to another one.

1. Open [console.neon.tech/signup](https://console.neon.tech/signup).
2. Choose GitHub as the sign-in method and authorise Neon when GitHub asks.
   Signing in with GitHub means no extra password to manage.
3. If Neon walks you through creating a first project, use the values in
   step 5.
4. Otherwise, on the **Projects** page, click **New project**.
5. Enter a **Project name** such as `jamf-iac`. Pick the **Region** nearest to
   you. Under **Services**, leave **Postgres database** on and the rest off.
6. Click **Create project**.

Neon creates a database named `neondb` on a branch named `production`. You
collect its connection string in section 5.4.

### 4.4 Create Platform API credentials

Create an integration at [account.jamf.com](https://account.jamf.com) the way
you did in the first session: **Integrations**, **Create integration**, level
**Platform environment**, then your region and the platform environment holding
your sandbox. Grant these permissions:

| Category | Permission | Actions |
| --- | --- | --- |
| Organizational context | Categories | Create, Read, Update, Delete |
| Global settings | Self Service configuration | Read |
| Inventory | Device groups | Create, Read, Update, Delete |
| Deployment | Scripts | Create, Read, Update, Delete |
| Deployment | Policies | Create, Read, Update, Delete |
| Deployment | Configuration profiles | Create, Read, Update, Delete |
| Deployment | Blueprints | Create, Read, Update, Delete, Deploy |
| Admin identity and access | LDAP / cloud IdP | Read |

Copy the client ID, the client secret and the environment ID.

---

## 5. Setup

Setup builds the path a change travels. You create a repository, tell
Terraform which tenant dev is, give it credentials and a place to keep state,
then hand the same credentials to the pipeline. The first push proves the path
by building the baseline in your sandbox.

### 5.1 Create your repository

Your project needs its own repository with its own history. Download this
branch, then swap the reference repository's history for a fresh one whose
first branch is `main`:

```bash
git clone --branch ref-jamfplatform-gitops --single-branch https://github.com/Jamf-Concepts/terraform-jamf-reference.git jamf-iac
```

```bash
cd jamf-iac
```

```bash
rm -rf .git
```

```bash
git init -b main
```

Create a private repository on GitHub from the folder. `--remote origin` links
your local folder to it, so later pushes know where to go:

```bash
gh repo create jamf-iac --private --source . --remote origin
```

Keep the repository private. Plans show the contents of your scripts and
profiles, and the pipelines post plans as comments.

### 5.2 Point dev at your sandbox

Open `environments/dev.tfvars` and set three values:

```hcl
jamfplatform_base_url = "https://us.api.jamfcloud.com"

jamfplatform_environment_id = "your-environment-uuid"

pilot_serial_numbers = [
  "C02DEV00001",
]
```

Use the gateway URL for your region, your environment ID, and the serial number
of a test Mac. None of these is a secret, so the file lives in the repository
and reviewers see changes to it.

### 5.3 Set your credentials

The provider reads the client ID and secret from environment variables. A
variable lasts as long as the terminal, so no secret reaches a file that git
could commit. Run each command on its own, paste the value, and press Enter.
The terminal shows nothing while you paste.

```bash
read -s JAMFPLATFORM_CLIENT_ID
```

```bash
read -s JAMFPLATFORM_CLIENT_SECRET
```

```bash
export JAMFPLATFORM_CLIENT_ID JAMFPLATFORM_CLIENT_SECRET
```

### 5.4 Connect the remote state

1. In the [Neon console](https://console.neon.tech), open your project.
2. Click **Connect** at the top of the left sidebar. The **Connect to your
   branch** dialog opens on the **Postgres database** tab.
3. Check that **Database** shows `neondb` and the box below is labelled
   **Connection string**.
4. Turn the **Connection pooling** toggle off. The hostname in the box loses
   its `-pooler` suffix.
5. Click **Copy snippet**. The copied string includes the password that the
   dialog masks.

Terraform locks state with a lock that lives as long as its database
connection. A pooler shares connections between clients, so a pooled
connection string connects and plans, and the lock protects nothing.

Run this command to load the string from your clipboard into the variable
Terraform reads:

```bash
export PG_CONN_STR="$(pbpaste | sed -e 's/-pooler//' -e 's/sslmode=require/sslmode=verify-full/')"
```

The `sed` step changes `sslmode=require` to `sslmode=verify-full`, the setting
Terraform's PostgreSQL client needs to reach Neon. It also removes `-pooler` in
case the toggle was on. On Windows or Linux, paste the string into the
`export` by hand and make the same two edits.

Choose the state for dev:

```bash
export PG_SCHEMA_NAME=dev
```

`backend.tf` holds an empty `backend "pg" {}` block. Terraform takes the
connection string from `PG_CONN_STR` and the schema from `PG_SCHEMA_NAME`. Each
environment uses its own schema in the database, so each has its own state.

Initialise. Terraform downloads the provider version the lock file names and
connects to the backend. On first contact it creates the `dev` schema and an
empty state inside it:

```bash
terraform init
```

A successful init ends with:

```text
Terraform has been successfully initialized!
```

### 5.5 Plan from your machine

```bash
terraform plan -var-file=environments/dev.tfvars -parallelism=1
```

A plan from your machine proves three things before the pipeline gets
involved: your credentials work, the state is reachable, and the configuration
is valid for your tenant.

`-var-file` selects the environment. `-parallelism=1` makes Terraform send one
request at a time. The Jamf API returns errors under concurrent requests, so
use the flag on each plan, apply and destroy. The pipelines set it too.

The plan should end with `Plan: 7 to add, 0 to change, 0 to destroy`.

Stop there. You plan on your machine to check your work, and the pipeline
applies.

### 5.6 Give the pipeline its secrets

The pipeline runs on GitHub's machines, which hold none of the variables in
your terminal. A GitHub environment holds the secrets for one tenant, and a
job reads them only when it names that environment. Create `dev` and store the
three secrets in it:

```bash
gh api --method PUT "repos/{owner}/{repo}/environments/dev" --silent
```

```bash
gh secret set JAMFPLATFORM_CLIENT_ID --env dev --body "$JAMFPLATFORM_CLIENT_ID"
```

```bash
gh secret set JAMFPLATFORM_CLIENT_SECRET --env dev --body "$JAMFPLATFORM_CLIENT_SECRET"
```

```bash
gh secret set PG_CONN_STR --env dev --body "$PG_CONN_STR"
```

> **Dev shares one integration between plan and apply to keep the session
> short. Do not copy that to production.** A plan on a pull request runs code
> nobody has reviewed yet, and here it runs with credentials that can change
> the tenant. Production uses two integrations: one that can read, for plans,
> and one that can write, held behind an approval. Section 12.2 sets that up.
> To give dev the same split, create a `dev-plan` environment with a read-only
> integration, then add `github_environment: dev-plan` to the dev job in
> `pull-request.yml` and in `drift.yml`, the way the prod jobs pass
> `prod-plan`.

### 5.7 Push and watch the first apply

Commit the project, including your edit to `environments/dev.tfvars`, and push
it. A push to `main` is the one event that makes the pipeline apply.

```bash
git add -A
```

```bash
git commit -m "Initial commit"
```

```bash
git push -u origin main
```

The push to `main` starts the **Deploy** workflow. Watch it:

```bash
gh run watch
```

Then open it in the browser:

```bash
gh run view --web
```

The run summary shows the plan as a table and the result of the apply. Check
the Jamf UI for the **Pilot Computers** group, the **Flush DNS Cache** policy
and script, the **Login Window Banner** profile and the **Software Update
Settings** blueprint.

### 5.8 Protect main

On GitHub, open **Settings**, **Rules**, **Rulesets** and add a branch ruleset
for `main` that requires a pull request and requires the **Format, validate,
lint** and **Dev / Plan dev** status checks to pass. From then on nobody can
push to `main` or merge a change that fails its plan. Since a merge to `main`
is what changes Jamf, this rule is your change control.

GitHub offers rulesets on private repositories in paid plans. On a free plan,
skip this step for the session and follow the pull request flow by convention.

---

## 6. Tour of the project

```text
.
├── terraform.tf                  Terraform and provider versions
├── backend.tf                    Remote state
├── providers.tf                  Provider configuration
├── variables.tf                  Inputs that differ between environments
├── environments/
│   ├── dev.tfvars                Values for dev
│   └── prod.tfvars               Values for prod
├── categories.tf                 One file per resource type
├── device_groups.tf
├── scripts.tf
├── policies.tf
├── macos_configuration_profiles.tf
├── blueprints.tf
├── support_files/                Script bodies and profile payloads
├── runbooks/                     Step-by-step guides for routine tasks
├── .terraform.lock.hcl           Exact provider version and checksums
├── .tflint.hcl                   Linter rules
└── .github/
    ├── workflows/                Pipelines
    └── scripts/                  Plan rendering and reporting
```

### 6.1 What differs between environments

Dev and prod share every `.tf` file. Three things differ, and each has one
home:

| What differs | Where it lives |
| --- | --- |
| The tenant: gateway URL and environment ID | `environments/<name>.tfvars` |
| Values tied to a tenant, such as the serial numbers in `pilot_serial_numbers` | `environments/<name>.tfvars`, declared in `variables.tf` |
| Secrets: API credentials, the state connection string | The GitHub environment of the same name |

To make a new value differ, declare a variable in `variables.tf`, use it in a
resource, and set it in each tfvars file. `device_groups.tf` shows the pattern
with `var.pilot_serial_numbers`.

### 6.2 The lock file

`.terraform.lock.hcl` records the provider version Terraform selected and its
checksums. The repository commits it, so your machine and the pipeline run the
same provider. `terraform.tf` sets the minimum version, and the lock file sets
the exact one.

To move to a newer provider, run this on a branch and open a pull request with
the result:

```bash
terraform init -upgrade
```

```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64
```

The second command records checksums for the pipeline's Linux runners and for
your team's machines.

### 6.3 The pipelines

| Workflow | Runs on | Does | Changes Jamf |
| --- | --- | --- | --- |
| **Pull request** | Each pull request to `main` | Checks formatting, validates, lints, then posts a plan per environment as a comment | No |
| **Deploy** | Each merge to `main`, or on demand | Plans and applies to dev, then to prod after approval. Comments the result on the pull request. | Yes |
| **Drift detection** | Weekday mornings, or on demand | Plans each environment and opens an issue if the tenant differs from `main` | No |
| **Terraform** | Called by the three above | Holds the init, plan and apply steps once | |

The checks in **Pull request** each catch a different class of mistake:

- `terraform fmt -check` fails on code that `terraform fmt` would reformat.
- `terraform validate` fails on syntax errors, unknown attributes and broken
  references.
- `tflint` fails on unused variables, missing descriptions and names that break
  convention.

Read the plan table by its first column: 🟢 create, 🟡 update, 🟠 replace,
🔴 destroy, 🔵 import or move. Under the table, **Show the full diff** expands
the plan with additions in green, removals in red and changed lines in amber.

---

## 7. Change Jamf through a pull request

Add a category. Start a branch:

```bash
git switch -c add-network-category
```

In `categories.tf`, add a line to the map:

```hcl
locals {
  categories = {
    maintenance = "Maintenance"
    network     = "Network"
    security    = "Security"
  }
}
```

Format, commit and push:

```bash
terraform fmt
```

```bash
git commit -am "Add Network category"
```

```bash
git push -u origin add-network-category
```

Open a pull request and watch its checks. `--fill` takes the title from your
commit message. Write that message as the change it makes in Jamf, because it
becomes the entry in the history of `main`. If your organisation has a commit
message convention, use it.

```bash
gh pr create --fill
```

```bash
gh pr checks --watch
```

```bash
gh pr view --web
```

The pull request carries a comment headed **Terraform plan: dev** with one row:
🟢 create `jamfplatform_pro_category.main["network"]`. A reviewer reads the
code change and the plan side by side. Each push to the branch replaces the
comment with a fresh plan.

Merge:

```bash
gh pr merge --squash --delete-branch
```

```bash
git switch main
```

```bash
git pull
```

`--squash` combines every commit on the branch into one commit on `main`,
titled with the pull request title. One pull request then equals one commit,
one deploy and one thing to revert. The commits you made along the way stay
visible in the pull request.

The merge starts **Deploy**. Once it finishes, the pull request gains a second
comment: ✅ Applied to **dev**. The pull request now records the change, its
review, its plan and its outcome.

---

## 8. Revert a change

Make a change you will regret. On a new branch, open
`support_files/macos_configuration_profiles/login_window_banner.mobileconfig`
and change the banner text:

```bash
git switch -c change-banner
```

```xml
<string>This computer belongs to Pretend Co. Have a nice day.</string>
```

```bash
git commit -am "Change login window banner"
```

```bash
git push -u origin change-banner
```

```bash
gh pr create --fill
```

Wait for the plan, merge, and let **Deploy** apply it:

```bash
gh pr merge --squash --delete-branch
```

```bash
git switch main
```

```bash
git pull
```

The security team objects. Revert the pull request that made the change. List
the latest merged pull requests to find its number:

```bash
gh pr list --state merged --limit 3
```

```bash
gh pr revert <number>
```

GitHub creates a branch holding one commit that undoes the pull request, and
opens a new pull request for it. The **Revert** button at the bottom of a
merged pull request on GitHub does the same.

The command prints the address of the new pull request. Open it and read the
plan comment, which shows the banner text returning to its previous value:

```bash
gh pr view <revert-number> --web
```

Merge it, and **Deploy** restores the profile:

```bash
gh pr merge <revert-number> --squash --delete-branch
```

```bash
git pull
```

**Key points:**

- A revert is a new commit that undoes an old one. History keeps both, so the
  record shows the change and its withdrawal.
- The revert passes through the same checks and plan as any change. Read its
  plan: Terraform restores configuration, and anything the original change
  deleted returns as a new object with a new ID.
- Squash merging makes this simple. Each pull request is one commit on `main`,
  so reverting the pull request undoes the whole change.
- A provider upgrade is the exception. Once an apply writes state with a newer
  provider, an older provider refuses to read it. See
  [Upgrade the provider](runbooks/upgrade-the-provider.md).

---

## 9. Recover from a failed apply

A plan checks your change against the provider's schema. The Jamf API applies
further rules, and some surface only during apply.

On a new branch, edit `blueprints.tf`:

```bash
git switch -c relax-download
```

```hcl
automatic_download                 = "Allowed"
```

```bash
git commit -am "Relax automatic download"
```

```bash
git push -u origin relax-download
```

```bash
gh pr create --fill
```

The checks pass and the plan shows one update. Merge it:

```bash
gh pr merge --squash --delete-branch
```

```bash
git switch main
```

```bash
git pull
```

**Deploy** fails. The comment on the pull request quotes the error:

```text
[VALID_AUTOMATIC_ACTIONS]
steps[0].components[0].configuration.automaticActions: If InstallOSUpdates
is AlwaysOn, Download must be included and also AlwaysOn
```

Jamf rejected the blueprint, so the tenant still holds the old settings while
`main` holds the new ones.

**Key points:**

- Terraform does not roll back. Resources that changed before the error keep
  their new values, and the rest keep their old ones. State records what
  happened.
- Fix forward. Revert the commit as in section 8, or correct the value in a
  new pull request. The next apply closes the gap.
- Until you do, drift detection reports that dev differs from `main`.

Revert the commit now, using the steps from section 8, and merge the revert.

---

## 10. Detect and resolve drift

Drift is a difference between `main` and the tenant. Someone edits an object in
the Jamf UI, or a merged change fails to apply.

In the Jamf UI, rename the **Maintenance** category to **Housekeeping**. Then
run the check without waiting for its schedule:

```bash
gh workflow run drift.yml
```

```bash
gh run watch
```

The run fails, and the repository gains an issue titled **Terraform drift:
dev**:

```bash
gh issue list
```

The issue shows the plan that would bring the tenant back in line with `main`:
🟡 update `jamfplatform_pro_category.main["maintenance"]`.

You now choose who wins.

- **The configuration wins.** Run **Deploy** on `main`. Terraform renames the
  category back.
- **The UI change wins.** Open a pull request that copies the change into the
  configuration, here by setting `maintenance = "Housekeeping"`. Its plan shows
  no changes, and merging it ends the drift.

Let the configuration win:

```bash
gh workflow run deploy.yml
```

```bash
gh run watch
```

Run the drift check again. It passes and closes the issue.

**Key points:**

- The check runs a normal plan and applies nothing. It needs the same secrets
  as a plan.
- A drift issue for an environment stays open, and each run updates it, until a
  run finds no difference.
- GitHub pauses scheduled workflows in a repository with no activity for 60
  days.

---

## 11. Import an existing object

Most tenants hold objects that predate Terraform. Importing one adds it to
state without recreating it.

In the Jamf UI, create a category named **Printers**. Then try to manage it. On
a new branch, add it to the map in `categories.tf`:

```bash
git switch -c adopt-printers
```

```hcl
    printers    = "Printers"
```

```bash
terraform fmt
```

```bash
git commit -am "Adopt the Printers category"
```

```bash
git push -u origin adopt-printers
```

```bash
gh pr create --fill
```

The plan fails. The provider checks names during plan, finds the existing
category, and the comment on the pull request shows its ID and the block that
adopts it:

```text
The category with the name "Printers" already exists in Jamf Pro (ID 6900),
...
  import {
    to = <this resource's address>
    id = "6900"
  }
```

Create `imports.tf` with that block, using your ID and the address of the
resource:

```hcl
import {
  to = jamfplatform_pro_category.main["printers"]
  id = "6900"
}
```

```bash
git add imports.tf
```

```bash
git commit -m "Import the existing Printers category"
```

```bash
git push
```

The new plan shows 🔵 import for the category, with an update beside it if the
object's settings differ from your configuration. Merge the pull request, and
**Deploy** records the category in state.

An import block has done its job once the apply succeeds. Delete `imports.tf`
in your next pull request.

**Key points:**

- Read the plan of an import before you merge. An import with no other action
  changes nothing in Jamf. An update beside it overwrites the object's settings
  with yours.
- For an object you have not written configuration for, run
  `terraform plan -var-file=environments/dev.tfvars -parallelism=1 -generate-config-out=generated.tf`
  on your machine with the import block in place, then move the generated
  block into the right file.
- For a whole tenant, use jamformer. Section 12.6 covers it.

---

## 12. Add production

> **Requires prod.** Every step in this section needs a second tenant and
> credentials for it. Skip the section during the session.
>
> A mistake in this section reaches real devices. Scope the first resources you
> promote to a pilot group, read each prod plan in full, and treat a 🟠 replace
> or 🔴 destroy row as a reason to stop and ask.

### 12.1 Describe the prod tenant

Set the gateway URL, the environment ID and the pilot serial numbers of your
production tenant in `environments/prod.tfvars`.

### 12.2 Create two GitHub environments

| GitHub environment | Used by | Credentials | Protection |
| --- | --- | --- | --- |
| `prod-plan` | Plans on pull requests, the preview before approval, drift detection | An integration with the Read action of each permission in section 4.4 and no other action | None |
| `prod` | The apply | An integration with the permissions from section 4.4 | Required reviewers |

Two environments keep the write credentials behind the approval. A plan on a
pull request runs code nobody has reviewed yet, so it gets credentials that can
read and nothing more.

```bash
gh api --method PUT "repos/{owner}/{repo}/environments/prod-plan" --silent
```

```bash
gh api --method PUT "repos/{owner}/{repo}/environments/prod" --silent
```

Store `JAMFPLATFORM_CLIENT_ID`, `JAMFPLATFORM_CLIENT_SECRET` and `PG_CONN_STR`
in each, as in section 5.6, with `--env prod-plan` and `--env prod`. Use a
separate database for prod state if your organisation separates access to
production data.

On GitHub, open **Settings**, **Environments**, **prod**, tick **Required
reviewers** and add the people who approve production changes. GitHub offers
required reviewers on private repositories in paid plans.

### 12.3 Turn prod on

```bash
gh variable set PROD_ENABLED --body true
```

The workflows skip every prod job until this variable is `true`.

### 12.4 How a change reaches prod

1. You open a pull request. It gains two plan comments, one for dev and one for
   prod. The reviewer reads both.
2. You merge. **Deploy** applies the commit to dev.
3. **Deploy** plans the same commit against prod and shows the plan in the run
   summary. The run then waits.
4. A required reviewer opens the run, reads the prod plan, and clicks **Review
   deployments**, then **Approve and deploy**.
5. **Deploy** applies to prod and comments the result on the pull request.

GitHub records who approved and when, next to the plan and the apply log.

**Key points:**

- Dev is your test. Check the change on a dev device before you approve prod.
- The prod job plans again after the approval and applies that plan. If the
  tenant changed between the preview and the approval, the applied plan differs
  from the preview. The run summary shows the plan it applied.
- If a second commit merges while the first waits for approval, approve the
  newest run. It carries both changes. Reject the older one.
- Drift detection reports a commit that waits for approval as drift in prod,
  because prod differs from `main` until you approve.

### 12.5 Revert in prod

Revert through a pull request, as in section 8. The revert applies to dev and
then waits for the same approval. No faster path to prod exists, and that is
deliberate: the revert of a bad change is a production change too.

If the bad commit still waits for approval, reject it. Prod never received it,
so only dev needs the revert.

### 12.6 Import with two tenants

An import block names an ID, and each tenant assigns its own IDs. A block that
is right for prod fails in dev.

**Adopting an existing production tenant.** Most teams start here: production
holds years of configuration and the sandbox is empty.

1. Run [jamformer](https://github.com/Jamf-Concepts/jamformer) against prod. It
   writes resource files in this project's layout, with import blocks beside
   them.
2. On your machine, with prod credentials and `PG_SCHEMA_NAME=prod`, plan with
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

### 12.7 Secrets that differ per tenant

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

## 13. Make it yours

### 13.1 Another state backend

Neon keeps the session short. Your organisation may prefer S3, Azure Storage,
Google Cloud Storage or HCP Terraform. To switch:

1. Replace the block in `backend.tf` with the block for your backend. Give each
   environment its own state through a
   [partial configuration](https://developer.hashicorp.com/terraform/language/backend#partial-configuration),
   for example a state key per environment.
2. In `.github/workflows/terraform.yml`, replace the `PG_CONN_STR` and
   `PG_SCHEMA_NAME` lines with your backend's credentials, and delete the
   **Check the state connection string** step.
3. Run `terraform init -migrate-state` once per environment to copy the state
   across.

### 13.2 State locks

Terraform locks the state for the length of a plan or an apply. A second run
waits up to five minutes for the lock, then fails with
`Error acquiring the state lock`.

The PostgreSQL backend releases its lock the moment the connection closes, so a
cancelled pipeline run leaves nothing behind. Other backends can keep a stale
lock after a run dies. Clear one from your machine with the lock ID from the
error message:

```bash
terraform force-unlock <lock-id>
```

Check first that no run is in progress. Unlocking under a live apply corrupts
state. [Clear a state lock](runbooks/clear-a-state-lock.md) has the full
procedure, including the PostgreSQL case.

### 13.3 Another CI platform

Each platform needs the same four things:

| Need | GitHub Actions | Elsewhere |
| --- | --- | --- |
| Run on pull requests and on merges to `main` | `on: pull_request`, `on: push` | Merge request and branch pipelines |
| Secrets per environment | Environments | Protected or scoped variables, variable groups |
| An approval before prod | Required reviewers | Protected environments, manual jobs, approval checks |
| One apply at a time | `concurrency` | Resource groups, exclusive locks |

`plan-summary.sh` runs anywhere with `terraform` and `jq`. `pr-comment.sh`,
`apply-report.sh` and `drift-issue.sh` call the GitHub CLI, and each needs its
`gh` commands swapped for your platform's API.

---

## 14. Cleaning up

The pipelines create and change. Removing a whole environment is a deliberate
act you run from your machine, with the variables from sections 5.3 and 5.4
set:

```bash
terraform destroy -var-file=environments/dev.tfvars -parallelism=1
```

Type `yes` when prompted. If the destroy stops with an error on the device
group, run it again. Jamf needs a moment to release a group that a deleted
blueprint used.

Then remove what the session created outside Jamf:

- Delete the **Printers** category if you skipped its import.
- Delete the Neon project in the [Neon console](https://console.neon.tech).
- Delete the integration at [account.jamf.com](https://account.jamf.com) under
  **Integrations**.
- Delete or archive the GitHub repository if you have no further use for it.

---

## 15. What's next

- **[Runbooks](runbooks/README.md)**, short procedures for the tasks you
  repeat once this project runs your tenants: making and reverting changes,
  resolving drift, upgrading the provider, rotating credentials and adding an
  environment.
- **[Importing existing objects](https://registry.terraform.io/providers/jamf/jamfplatform/latest/docs/guides/importing)**,
  the provider guide on what the first plan after an import shows and what
  applying it does.
- **[Impact alerts](https://registry.terraform.io/providers/jamf/jamfplatform/latest/docs/guides/impact-alerts)**,
  a provider option that reports during plan how many devices a change affects.
- **[HashiCorp's Terraform style guide](https://developer.hashicorp.com/terraform/language/style)**,
  the conventions this project follows.
- **[Resources for getting started with Terraform and Jamf](https://concepts.jamf.com/guides/infrastructure-as-code/resources-for-getting-started-with-terraform-and-jamf/)**,
  curated reading for Jamf admins new to IaC.
