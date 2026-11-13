# From sandbox to production with Terraform and the Jamf Platform API

> **You are on the `ref-jamfplatform-gitops` branch.** This is the companion
> for the second Jamf IaC Enablement session. It follows
> `ref-jamfplatform-starter`. Other branches in this repository are unrelated.

A Terraform project you can use as a template for production. You copy it into
your own GitHub repository, store state in a remote backend, and change Jamf
through pull requests. Pipelines check each change, show you the plan, apply it
to a dev tenant, and promote a tested commit to prod when you run a release
and a reviewer approves it.

The session uses one sandbox tenant as dev. Every step that needs a second
tenant lives in [PRODUCTION.md](PRODUCTION.md), for you to follow after the
session.

---

## 1. Learning outcomes

By the end of this session you will be able to:

- Store Terraform state in a remote backend, with one state per environment
- Keep one configuration for several environments and vary values per
  environment
- Change Jamf through a pull request and read the plan the pipeline posts
- Revert a change you regret, and know what to do when an apply fails
- Detect drift on a schedule and decide how to resolve it
- Bring an object that already exists in Jamf under Terraform management
  through a pull request
- Describe how a change reaches production, who approves it, and where the
  audit trail lives

## 2. What you'll build

| Piece | Where | Purpose |
| --- | --- | --- |
| Configuration | `*.tf` at the repository root | Two categories, a static group, a script, a policy, a configuration profile and a blueprint |
| Environment values | `environments/dev.tfvars`, `environments/prod.tfvars` | The tenant each environment targets, and the values that differ between tenants |
| Remote state | PostgreSQL on [Neon](https://neon.com) | One state per environment, with locking |
| Pipelines | `.github/workflows/` | Check, plan, apply and drift detection |
| Pipeline scripts | `.github/scripts/` | Turn a plan into a table and a coloured diff |

---

## 3. Prerequisites

- A Jamf sandbox tenant. **Do not use production**
- The tools from the first session: git, Terraform >= 1.14.0, VS Code with the
  HashiCorp Terraform extension
- A GitHub account, working knowledge of GitHub, and the GitHub CLI (see below)
- A Neon account, signed up with your GitHub account (see below)
- Platform API credentials with the permissions below

### 3.1 Learn the GitHub basics

The session assumes you can create a branch, commit, open a pull request and
merge it. If any of those is new to you, complete these free
[GitHub Skills](https://learn.github.com/skills) courses first. Each runs in
your own GitHub account.

| Course | Covers | Time | Take it if |
| --- | --- | --- | --- |
| [Introduction to GitHub](https://github.com/skills/introduction-to-github) | Repositories, branches, commits, pull requests, merging | Under 1 hour | You have not merged a pull request before. Required. |
| [Introduction to Git](https://github.com/skills/introduction-to-git) | Commits, branches and history from the command line and VS Code | Under 1 hour | You have not committed and pushed from a terminal before |
| [Hello GitHub Actions](https://github.com/skills/hello-github-actions) | Creating and running a workflow | Under 30 minutes | You want to read the pipeline files with more confidence |

### 3.2 Install the GitHub CLI

The session creates the repository, its secrets and its pull requests from the
terminal, and reads plans and results in the browser.

```bash
brew install gh
```

```bash
gh auth login
```

Choose **GitHub.com**, **HTTPS** and **Login with a web browser**.

### 3.3 Create a Neon account

[Neon](https://neon.com) hosts PostgreSQL. Its free plan covers this session.
Neon stands in for the backend your organisation will choose, and
[PRODUCTION.md](PRODUCTION.md) covers the swap to another one.

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
collect its connection string in section 4.4.

### 3.4 Create Platform API credentials

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

## 4. Setup

Setup builds the path a change travels. You create a repository, tell
Terraform which tenant dev is, give it credentials and a place to keep state,
then hand the same credentials to the pipeline. The first push proves the path
by building the baseline in your sandbox.

### 4.1 Create your repository

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

### 4.2 Point dev at your sandbox

Open `environments/dev.tfvars` and set two values:

```hcl
jamfplatform_base_url = "https://us.api.jamfcloud.com"

jamfplatform_environment_id = "your-environment-uuid"
```

Use the gateway URL for your region and your environment ID. Neither is a
secret, so the file lives in the repository and reviewers see changes to it.

### 4.3 Set your credentials

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

### 4.4 Connect the remote state

1. In the [Neon console](https://console.neon.tech), open your project.
2. Click **Connect** at the top of the left sidebar. The **Connect to your
   branch** dialog opens on the **Postgres database** tab.
3. Check that **Database** shows `neondb` and the box below is labelled
   **Connection string**.
4. Turn the **Connection pooling** toggle off. The hostname in the box loses
   its `-pooler` suffix. Terraform's state lock does not work through the
   pooler.
5. Click **Copy snippet**. The copied string includes the password that the
   dialog masks.

Run this command to load the string from your clipboard into the variable
Terraform reads:

```bash
export PG_CONN_STR="$(pbpaste | sed -e 's/-pooler//' -e 's/sslmode=require/sslmode=verify-full/')"
```

The command sets `sslmode=verify-full`, which Terraform needs to reach Neon,
and removes `-pooler` in case the toggle was on. On Windows or Linux, paste
the string into the `export` by hand and make the same two edits.

Choose the state for dev:

```bash
export PG_SCHEMA_NAME=dev
```

Each environment keeps its state under its own name in the database.

Initialise. Terraform downloads the provider and creates an empty state for
dev:

```bash
terraform init
```

A successful init ends with:

```text
Terraform has been successfully initialized!
```

### 4.5 Plan from your machine

```bash
terraform plan -var-file=environments/dev.tfvars -parallelism=1
```

A plan from your machine proves three things before the pipeline gets
involved: your credentials work, the state is reachable, and the configuration
is valid for your tenant.

`-var-file` selects the environment. `-parallelism=1` sends one request at a
time, which the Jamf API needs. Use it on each plan and destroy.

The plan should end with `Plan: 7 to add, 0 to change, 0 to destroy`.

Stop there. You plan on your machine to check your work, and the pipeline
applies.

### 4.6 Give the pipeline its secrets

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
> and one that can write, held behind an approval. Section 1.2 of
> [PRODUCTION.md](PRODUCTION.md) sets that up, and shows how to give dev the
> same split.

### 4.7 Push and watch the first apply

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

**Pilot Computers** is a static group with no members, and everything else
targets it. Terraform manages the group and leaves its membership to you. Add
a test Mac to it in the Jamf UI, and no later plan reports that as a change.
You decide what Terraform owns, and it need not own everything.

### 4.8 Protect main

A merge to `main` is what changes Jamf, so the rule that guards `main` is your
change control. Create it:

1. On GitHub, open **Settings**, **Rules**, **Rulesets**, then **New ruleset**
   and **New branch ruleset**.
2. Enter a **Ruleset Name** such as `main`, and set **Enforcement status** to
   **Active**.
3. Under **Target branches**, click **Add target** and choose **Include
   default branch**.
4. Under **Branch rules**, tick **Require a pull request before merging** and
   **Require status checks to pass**. Add the checks **Format, validate, lint**
   and **Dev / Plan dev**.
5. Click **Create**.

GitHub enforces a ruleset on a private repository only when an organisation on
a paid plan owns it. On a personal account the page shows a warning and saves
the ruleset without enforcing it. Create it anyway, so you know where the
control lives, and follow the pull request flow by convention during the
session.

---

## 5. Tour of the project

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
├── PRODUCTION.md                 Adding a production tenant and adapting the project
├── CONVENTIONS.md                Naming, file layout and how to grow the project
├── AGENTS.md                     Rules for AI agents that change this repository
├── .terraform.lock.hcl           Exact provider version and checksums
├── .tflint.hcl                   Linter rules
└── .github/
    ├── workflows/                Pipelines
    └── scripts/                  Plan rendering and reporting
```

### 5.1 What differs between environments

Dev and prod share every `.tf` file. Three things differ, and each has one
home:

| What differs | Where it lives |
| --- | --- |
| The tenant: gateway URL and environment ID | `environments/<name>.tfvars` |
| Any other value tied to a tenant | `environments/<name>.tfvars`, declared in `variables.tf` |
| Secrets: API credentials, the state connection string | The GitHub environment of the same name |

To make a new value differ, declare a variable in `variables.tf`, use it in a
resource, and set it in each tfvars file. `providers.tf` shows the pattern
with `var.jamfplatform_base_url`. Add a variable only for a value that must
differ.

### 5.2 The lock file

`.terraform.lock.hcl` records the provider version Terraform selected and its
checksums. The repository commits it, so your machine and the pipeline run the
same provider. `terraform.tf` sets the minimum version, and the lock file sets
the exact one.

[Upgrade the provider](runbooks/upgrade-the-provider.md) shows how to move to
a newer version.

### 5.3 The pipelines

| Workflow | Runs on | Does | Changes Jamf |
| --- | --- | --- | --- |
| **Pull request** | Each pull request to `main` | Checks formatting, validates, lints, then posts a plan per environment as a comment | No |
| **Deploy** | Each merge to `main`, or on demand | Plans and applies to dev. Comments the result on the pull request. | Yes |
| **Release** | On demand | Requires prod. Checks the commit, shows the prod plan, waits for approval, applies to prod, then publishes a release that lists the pull requests it delivered. | Yes |
| **Drift detection** | Weekday mornings, or on demand | Plans each environment and opens an issue if dev differs from `main` or prod differs from its last release | No |
| **Terraform** | Called by the four above | Holds the init, plan and apply steps once | |

The workflows run on GitHub Actions and hold little logic. The scripts under
`.github/scripts/` do the work, and the one that renders a plan needs only
`terraform` and `jq`.

The workflows and scripts are a reference implementation, provided as-is. Read
them, test them against your own tenants, and adapt them to your platform and
your change policy before you rely on them.

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

## 6. Change Jamf through a pull request

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

## 7. Revert a change

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
- A plan can pass and the apply still fail, because the Jamf API enforces
  rules that surface only when it receives the change. Terraform does not roll
  back: objects that changed before the error keep their new values. The pull
  request gains a comment that quotes the error. Revert the change as above,
  or correct it in a new pull request. See
  [Recover from a failed apply](runbooks/recover-from-a-failed-apply.md).

---

## 8. Detect and resolve drift

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

---

## 9. Import an existing object

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
- For a whole tenant, use jamformer. Section 1.6 of
  [PRODUCTION.md](PRODUCTION.md) covers it.

---

## 10. How a change reaches production

Nothing in this section needs a second tenant. Read it to see where the
session's workflow leads. [PRODUCTION.md](PRODUCTION.md) has the steps.

| Step | Who | What happens |
| --- | --- | --- |
| 1 | Author | Opens a pull request. It gains a plan for dev and a plan for prod. |
| 2 | Reviewer | Reads the code and both plans, then approves the pull request. |
| 3 | Author | Merges. The pipeline applies to dev. Prod does not change. |
| 4 | Team | Tests the change in dev. |
| 5 | Release owner | Starts the **Release** workflow once dev holds what prod should receive. |
| 6 | Pipeline | Checks that the commit is on `main` and that dev applied it, then shows the plan for prod. |
| 7 | Approver | Reads the prod plan and approves. The approver is a named reviewer on the `prod` environment. |
| 8 | Pipeline | Applies to prod with credentials that only this step can read, then publishes a release that lists the pull requests it delivered. |

**Key points:**

- Two people look at each change before prod: the reviewer of the pull request
  and the approver of the release.
- A merge never changes prod. A release does, and it carries every merged
  change up to the commit it names.
- The audit trail has three parts: the pull request holds the change, its
  review and its plans; the release run holds the prod plan, the approver and
  the apply log; the published release names what prod runs.
- Plans for prod use credentials that can read and nothing more.

---

## 11. Cleaning up

The pipelines create and change. Removing a whole environment is a deliberate
act you run from your machine, with the variables from sections 4.3 and 4.4
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

## 12. What's next

- **[Taking the project to production](PRODUCTION.md)**, the guide to adding a
  prod tenant, releasing changes to it with an approval, and swapping the
  state backend or CI platform for your own.
- **[Conventions](CONVENTIONS.md)**, the rules for naming, file layout and
  growth once the project is yours, and **[AGENTS.md](AGENTS.md)**, which
  holds AI agents to those rules.
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
