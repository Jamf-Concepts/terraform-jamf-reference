# Make a change

## When to use

You want to add, change or delete an object in Jamf.

## Steps

1. Start from an up-to-date `main` on a new branch:

   ```bash
   git switch main
   ```

   ```bash
   git pull
   ```

   ```bash
   git switch -c <short-description>
   ```

2. Edit the `.tf` files or the files under `support_files/`. To delete an
   object, delete its resource block.

3. Format, and plan if you want to see the result before the pipeline does:

   ```bash
   terraform fmt -recursive
   ```

   ```bash
   terraform plan -var-file=environments/dev.tfvars -parallelism=1
   ```

4. Commit and push. Write the message as the change it makes in Jamf. It
   becomes the pull request title and the entry in the history of `main`.

   ```bash
   git commit -am "<what changes in Jamf>"
   ```

   ```bash
   git push -u origin HEAD
   ```

5. Open a pull request and wait for the checks:

   ```bash
   gh pr create --fill
   ```

   ```bash
   gh pr checks --watch
   ```

6. Read the plan comment for each environment. Ask a colleague to review the
   code and the plans.

7. Merge. Squash merging keeps one commit per pull request on `main`.

   ```bash
   gh pr merge --squash --delete-branch
   ```

## Check it worked

The pull request gains a comment: ✅ Applied to **dev**. Confirm the object in
the Jamf UI, and on a test device if the change reaches devices.

## If it goes wrong

- **A check fails.** Fix the code on the same branch and push. The pipeline
  runs again and replaces the plan comment.
- **The plan shows 🟠 replace or 🔴 destroy and you did not expect it.** Stop.
  A replace deletes the object and creates a new one with a new ID. Find the
  attribute the plan marks `# forces replacement` before you merge.
- **The plan fails with `Name already in use`.** The object exists in Jamf
  already. See [Import an existing object](import-an-existing-object.md).
- **The apply fails after the merge.** See
  [Recover from a failed apply](recover-from-a-failed-apply.md).
