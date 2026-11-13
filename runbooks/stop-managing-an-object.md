# Stop managing an object

## When to use

An object should stay in Jamf, and Terraform should stop managing it. Another
team takes it over, or it needs frequent manual edits.

Deleting the resource block alone deletes the object from Jamf.

## Steps

1. On a new branch, replace the resource block with a `removed` block:

   ```hcl
   removed {
     from = jamfplatform_pro_category.temporary

     lifecycle {
       destroy = false
     }
   }
   ```

2. Remove every reference to the resource from other resources.

3. Open a pull request. The plan must show 🔵 forget for the object and no
   🔴 destroy.

4. Merge.

5. Delete the `removed` block in a later pull request, once the change has
   applied to every environment.

## Check it worked

The object still exists in Jamf, and a later plan shows no changes.

## If it goes wrong

- **The plan shows 🔴 destroy.** The `removed` block is missing, or `destroy`
  is not `false`. Fix it before you merge.
- **You want it back under management.** See
  [Import an existing object](import-an-existing-object.md).
- **The resource uses `for_each` and you want to release one instance.** A
  `removed` block covers the whole resource. Move the instance to its own
  resource block first with [Rename a resource](rename-a-resource.md), using
  the instance address such as
  `jamfplatform_pro_category.main["printers"]` as `from`.
