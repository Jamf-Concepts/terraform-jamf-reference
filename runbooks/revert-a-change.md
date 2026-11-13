# Revert a change

## When to use

A change merged and applied, and you want the previous configuration back.

Do not use this for a provider upgrade that has applied. See
[Upgrade the provider](upgrade-the-provider.md).

## Steps

1. Find the number of the pull request that made the change:

   ```bash
   gh pr list --state merged --limit 5
   ```

2. Create the revert:

   ```bash
   gh pr revert <number>
   ```

   GitHub creates a branch holding one commit that undoes the pull request and
   opens a new pull request for it. The **Revert** button at the bottom of the
   merged pull request on GitHub does the same.

3. Read the plan comment on the new pull request. It should show the reverse of
   the original change.

4. Merge:

   ```bash
   gh pr merge <revert-number> --squash --delete-branch
   ```

5. If prod received the change, publish a release once dev has applied the
   revert. See [Promote a change to prod](promote-to-prod.md). If no release
   contains the change, prod never received it and you are done.

## Check it worked

The revert pull request gains a comment: ✅ Applied to **dev**. The object in
Jamf holds its previous settings.

## If it goes wrong

- **Prod is broken and cannot wait for a pull request.** Publish a release
  that names the last good commit. Prod returns to it while `main` stays
  ahead. Then complete the steps above, or the next release delivers the bad
  change again.

  ```bash
  gh release create prod-<yyyy-mm-dd>-rollback --notes "Roll back to <commit-id>" --target <commit-id>
  ```

- **The plan shows 🟢 create for an object the original change deleted.**
  Terraform restores the configuration and Jamf issues a new ID. Anything that
  referred to the old ID outside Terraform needs updating by hand.
- **The revert has a merge conflict.** A later change touched the same lines.
  Edit the files by hand on a new branch to restore the values you want, and
  follow [Make a change](make-a-change.md).
- **You have the commit and no pull request.** A commit ID, or SHA, is the
  string of letters and digits that names a commit. Find it and revert it on a
  branch, then open a pull request:

   ```bash
   git log --oneline -10
   ```

   ```bash
   git switch -c revert-<short-description>
   ```

   ```bash
   git revert --no-edit <sha>
   ```

   ```bash
   git push -u origin HEAD
   ```

   ```bash
   gh pr create --fill
   ```
