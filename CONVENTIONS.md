# Conventions

How to name things, where to put them, and what to do as the project grows.
These rules apply to everyone who changes this repository, people and AI
agents alike. A project that follows one set of rules stays readable at 500
resources. A project where each author picks their own does not.

[HashiCorp's Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
covers formatting and general naming, and `terraform fmt` and `tflint` enforce
part of it on each pull request. This document adds the rules specific to Jamf
and to this project. Where the two disagree, this document wins.

---

## 1. Where things go

| File or folder | Holds |
| --- | --- |
| `terraform.tf` | Terraform and provider version requirements |
| `backend.tf` | The state backend |
| `providers.tf` | Provider configuration |
| `variables.tf` | Every input variable, in alphabetical order |
| `environments/<name>.tfvars` | The values of those variables for one tenant |
| `<type>.tf` | Every resource of one type |
| `settings.tf` | Tenant-wide settings. See section 3. |
| `imports.tf` | Temporary `import`, `moved` and `removed` blocks. See section 9. |
| `support_files/<type>/` | Scripts, profiles and other payloads. See section 8. |

Name a resource file after the plural of the resource type, without the
provider and product prefix:

| Resource type | File |
| --- | --- |
| `jamfplatform_pro_category` | `categories.tf` |
| `jamfplatform_pro_policy` | `policies.tf` |
| `jamfplatform_pro_script` | `scripts.tf` |
| `jamfplatform_pro_macos_configuration_profile` | `macos_configuration_profiles.tf` |
| `jamfplatform_pro_mobile_device_configuration_profile` | `mobile_device_configuration_profiles.tf` |
| `jamfplatform_device_group` | `device_groups.tf` |
| `jamfplatform_blueprints_blueprint` | `blueprints.tf` |
| `jamfplatform_cbengine_benchmark` | `compliance_benchmarks.tf` |

Keep every `.tf` file at the repository root. Terraform reads one folder as
one configuration, and a subfolder of `.tf` files is a module, which this
project does not use.

Put a `data` source and a `locals` block in the file of the resource that uses
them, above that resource. If several files share a local value, move it to
`locals.tf`.

---

## 2. When a file grows

One file per resource type works until you scroll to find things. Split a file
when it passes about 300 lines or 20 resources.

**Split by purpose, and put the type first:**

```text
policies.tf
```

becomes

```text
policies_maintenance.tf
policies_security.tf
policies_software.tf
```

- **Type first**, so files of one type sort together.
- **Purpose second**: what the objects do for the organisation. Your Jamf
  categories are a good source of purpose names.
- **One list of purposes for the whole project.** If policies split into
  `maintenance`, `security` and `software`, profiles and scripts use the same
  words: `macos_configuration_profiles_security.tf`, `scripts_maintenance.tf`.
- **Lower case, underscores, one or two words.**

Do not split by environment, team, author, date or ticket number. Those change
over time and the purpose of an object does not.

Moving a resource block from one file to another changes nothing in Jamf.
Terraform identifies a resource by its type and name, and the file it sits in
plays no part. The pull request for a split must show a plan with no changes.

Split `support_files/` the same way once a folder passes about 20 files:

```text
support_files/scripts/maintenance/flush_dns_cache.sh
support_files/scripts/security/rotate_recovery_key.sh
```

If files split by purpose still feel too large, or plans take many minutes,
the project may have outgrown one state. Splitting a project across states is
a design change with real costs. Take advice before you start.

---

## 3. Tenant-wide settings

Some resources exist once per tenant: check-in settings, inventory collection
settings, Self Service settings, single sign-on, the local administrator
password settings. They configure the tenant, where a policy or a profile
configures devices.

- Name the resource `main`. There is one, so a longer name adds nothing.
- Keep them together in `settings.tf`, apart from the resources that create
  objects.
- When `settings.tf` grows, split it by area with the same rule as section 2:
  `settings_enrollment.tf`, `settings_inventory.tf`, `settings_security.tf`,
  `settings_self_service.tf`.

```hcl
resource "jamfplatform_pro_computer_check_in_settings" "main" {
  # ...
}
```

---

## 4. Resource names

The resource name is the second label in
`resource "jamfplatform_pro_policy" "install_google_chrome"`. Terraform uses
it as the address of the object, and it never appears in Jamf.

- Lower case with underscores.
- Derive it from the object's name in Jamf: **Install Google Chrome** becomes
  `install_google_chrome`.
- Describe one object, in the singular.
- Leave out the resource type. `jamfplatform_pro_policy.install_google_chrome`
  already says policy.
- Leave out the environment, version numbers and dates.
- Use `main` for a resource of which there is one.

A resource that uses `for_each` has a name for the set and a key for each
member:

```hcl
jamfplatform_pro_category.main["security"]
```

Keys follow the same rules as names. Never use a number or a list position as
a key. Inserting a member would shift the others, and Terraform would destroy
and recreate them.

Changing a resource name or a key changes the address. Follow
[Rename a resource](runbooks/rename-a-resource.md), or Terraform destroys the
object and creates a new one.

---

## 5. One block or many

Use `for_each` over a map in `locals` when the objects differ in one or two
simple values and share everything else. Categories, departments, buildings
and a set of groups by operating system version fit.

```hcl
locals {
  categories = {
    maintenance = "Maintenance"
    security    = "Security"
  }
}

resource "jamfplatform_pro_category" "main" {
  for_each = local.categories

  name     = each.value
  priority = 9
}
```

Write one resource block per object when each object has its own settings.
Policies, configuration profiles, blueprints and PreStage enrollments fit.

Do not build a map of settings to generate policies or profiles from one
block. It saves lines and costs clarity: a reader can no longer see what one
policy does, and a plan no longer shows which line of code caused a change.

Use `count` to switch one resource on or off. Do not use it to create several.

---

## 6. Names in Jamf

The `name` attribute is what administrators and users see.

- Write it the way you would type it in the Jamf UI: **Login Window Banner**.
- Leave out the environment. Dev and prod are separate tenants, and the same
  name in each makes them comparable.
- Leave out markers such as `TF` or `[Terraform]`. Where the object has a
  description or notes field, write `Managed by Terraform` there, so someone
  in the UI knows where to make changes.
- Name a group for what it contains: **Pilot Computers**, **macOS 15
  Laptops**.
- Choose names you can keep. On some resource types, a new name replaces the
  object. The plan shows that as 🟠 replace.

---

## 7. References

- Refer to another managed object through its resource, and never through a
  typed ID. Terraform then creates objects in the right order, and the code
  works in every tenant.

  ```hcl
  category_id = jamfplatform_pro_category.main["maintenance"].id
  ```

- A Jamf Pro resource that scopes to a device group takes the group's
  `jamf_pro_id`. A Platform resource, such as a blueprint, takes its `id`.

  ```hcl
  computer_group_ids = [jamfplatform_device_group.pilot_computers.jamf_pro_id]
  ```

- To refer to an object Terraform does not manage, import it first. See
  [Import an existing object](runbooks/import-an-existing-object.md).

---

## 8. Variables, environments and payloads

**Variables**

- Add a variable only for a value that must differ between tenants. Write
  every other value in the resource.
- Give each variable a `type` and a `description`. Add a `validation` block
  where a wrong value does harm.
- Give no `default` to a value that must differ. Each tfvars file then has to
  set it, and a missing value fails the plan.
- Put values in `environments/<name>.tfvars`. Put secrets in the CI secret
  store and mark the variable `sensitive`. No secret goes in a file.
- Do not test the environment name inside a resource. To change how
  something behaves in prod, pass a value that changes it, such as a list of
  serial numbers or an `enabled` flag.

**Payloads**

- Keep scripts, profiles, JSON and XML under `support_files/<type>/`, in a
  file named after the resource: `support_files/scripts/flush_dns_cache.sh`
  for `jamfplatform_pro_script.flush_dns_cache`.
- Read the file with `file("${path.module}/support_files/...")`. Do not paste
  a script or a profile into a `.tf` file.
- Use `templatefile()` and a `.tpl` extension only when a value inside the
  payload comes from a variable.

---

## 9. Temporary blocks

`import`, `moved` and `removed` blocks do a job once. Keep them in
`imports.tf`, or in the `<type>_import.tf` files that jamformer writes, and
delete them in a later pull request once the change has applied to every
environment.

An import that applies to one tenant is the one place the environment name
appears in the code. Section 1.6 of [PRODUCTION.md](PRODUCTION.md) shows it.

---

## 10. Changes

- Name a branch for the change: `add-chrome-policy`, `fix-banner-text`.
- Make one change per pull request. A reviewer reads one plan with one
  purpose.
- Write the pull request title as the change it makes in Jamf. It becomes the
  entry in the history of `main` and in the release notes.
- Write a comment to say why, where the reason is not plain from the code.
  Delete code you no longer use. Do not comment it out.

---

## 11. What needs a team decision

Each item below changes how the project works for everyone. None is wrong in
itself. Agree it as a team and record the decision here before anyone, or any
agent, introduces it.

- A module, or `.tf` files in a subfolder
- A second provider
- Terraform workspaces
- A provisioner, `local-exec` or `null_resource`
- `lifecycle` rules such as `ignore_changes` or `prevent_destroy`
- An ID typed into the code
- A change to the pipelines, `backend.tf`, `providers.tf` or `terraform.tf`
