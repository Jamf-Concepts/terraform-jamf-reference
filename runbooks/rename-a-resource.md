# Rename a resource

## When to use

You want to change a resource's name in the code, the part after the type in
`resource "jamfplatform_pro_script" "flush_dns_cache"`, and keep the object in
Jamf.

Without the step below, Terraform reads a rename as one object to destroy and
one to create.

To rename the object in Jamf, change its `name` attribute and follow
[Make a change](make-a-change.md).

## Steps

1. On a new branch, rename the resource block and update every reference to
   it.

2. Add a `moved` block beside the resource:

   ```hcl
   moved {
     from = jamfplatform_pro_script.flush_dns_cache
     to   = jamfplatform_pro_script.flush_dns
   }
   ```

3. Open a pull request. The plan must show 🔵 move and nothing else for the
   resource.

4. Merge.

5. Delete the `moved` block in a later pull request, once the change has
   applied to every environment.

## Check it worked

The pull request gains ✅ Applied for each environment, and a later plan shows
no changes.

## If it goes wrong

- **The plan shows 🔴 destroy and 🟢 create.** The `moved` block does not match
  the old or new address. Fix it before you merge.
- **You removed the `moved` block before prod applied.** Prod's plan shows a
  destroy and a create. Put the block back.
