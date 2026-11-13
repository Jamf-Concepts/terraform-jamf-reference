# Import an existing object

## When to use

An object exists in Jamf, Terraform does not manage it, and you want it under
management without recreating it.

## Steps

1. Write the resource block for the object on a new branch, as in
   [Make a change](make-a-change.md), and open a pull request.

   If you would rather generate the block, add the import block from step 3
   first and run this on your machine, then move the generated block into the
   right file:

   ```bash
   terraform plan -var-file=environments/dev.tfvars -parallelism=1 -generate-config-out=generated.tf
   ```

2. Read the failed plan. For an object type that enforces unique names, the
   comment says `Name already in use` and gives the object's ID.

3. Add an import block to `imports.tf`, with the resource address and the ID:

   ```hcl
   import {
     to = jamfplatform_pro_category.main["printers"]
     id = "6900"
   }
   ```

4. Push, and read the new plan. 🔵 import alone changes nothing in Jamf. An
   update beside it overwrites the object's settings with yours.

5. Merge.

6. Delete the import block in your next pull request. You no longer need it.

### An object with a payload file

A configuration profile or a script carries a payload, and the conventions
keep payloads in files under `support_files/`. Terraform reads the payload
from Jamf during the import plan, so you can lift it out of that plan. Run
these on your machine in place of step 1.

1. Add the import block to `imports.tf`, as in step 3.

2. Generate a draft and save the plan:

   ```bash
   terraform plan -var-file=environments/dev.tfvars -parallelism=1 -generate-config-out=generated.tf -out=import.tfplan
   ```

3. Write the payload to a file named after the resource. For a configuration
   profile:

   ```bash
   terraform show -json import.tfplan | jq -r '.resource_changes[] | select(.address == "jamfplatform_pro_macos_configuration_profile.legacy_banner") | .change.after.general.payloads' > support_files/macos_configuration_profiles/legacy_banner.mobileconfig
   ```

   For a script, read `.change.after.script_contents` and write to
   `support_files/scripts/`.

4. Write the resource block in the file for its type. Copy the settings you
   want Terraform to manage from `generated.tf`, and read the payload from the
   file:

   ```hcl
   resource "jamfplatform_pro_macos_configuration_profile" "legacy_banner" {
     general = {
       name                = "Legacy Banner"
       distribution_method = "Install Automatically"
       payloads            = file("${path.module}/support_files/macos_configuration_profiles/legacy_banner.mobileconfig")
     }
   }
   ```

5. Delete `generated.tf` and `import.tfplan`, then open the pull request and
   continue from step 4.

The plan shows 🟡 import + update, and the diff lists rows that end `-> null`
for each block you left out, such as scope. On most resources that drops the
block from state and leaves Jamf as it was. Check the guide linked under "If
it goes wrong" before you merge.

## Check it worked

The pull request gains ✅ Applied to **dev**, and a later plan shows no changes
for the object.

## If it goes wrong

- **The plan proposes removing blocks you never wrote.** Import records
  everything Jamf holds. Read the provider's
  [Importing existing objects](https://registry.terraform.io/providers/jamf/jamfplatform/latest/docs/guides/importing)
  guide before you merge. Two resource types reset what you leave out.
- **The object exists in one tenant and not the other.** Limit the import to
  the tenant that holds it. Section 1.6 of [PRODUCTION.md](../PRODUCTION.md)
  shows the pattern.
- **You need to import many objects.** Use
  [jamformer](https://github.com/Jamf-Concepts/jamformer).
