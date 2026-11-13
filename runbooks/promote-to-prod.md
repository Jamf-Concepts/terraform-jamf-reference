# Promote a change to prod

## When to use

One or more changes have merged and applied to dev, you have tested them
there, and you want them in prod.

Publishing a release starts the promotion. A reviewer on the `prod`
environment approves it.

## Steps

### Publish the release

1. Check dev. Confirm each change in the Jamf UI of the dev tenant and on a
   test device.

2. See what the release will contain: every pull request merged since the last
   release.

   ```bash
   gh release view --json tagName --jq .tagName
   ```

   ```bash
   git log --oneline <last-release-tag>..origin/main
   ```

3. Publish. Name the release `prod-` and the date.

   ```bash
   gh release create prod-<yyyy-mm-dd> --generate-notes
   ```

   To hold back the newest changes, name the last commit you want. The first
   column of the `git log` output above is the commit ID.

   ```bash
   gh release create prod-<yyyy-mm-dd> --generate-notes --target <commit-id>
   ```

### Approve the release

4. Open the **Release** run:

   ```bash
   gh run list --workflow release.yml --limit 3
   ```

   ```bash
   gh run view <run-id> --web
   ```

5. Open the **Prod preview** job summary and read the plan. Compare it with the
   release notes. Each row should trace to a pull request in the notes.

6. Click **Review deployments**, tick **prod**, and click **Approve and
   deploy**. To refuse, click **Reject**.

## Check it worked

Each pull request in the release gains a comment: ✅ Applied to **prod**, with
the release name. The run summary of the **Prod** job shows the plan it
applied.

## If it goes wrong

- **Check the release fails: the commit is not on main.** The tag points at a
  branch commit. Delete the release and publish it from `main`.

  ```bash
  gh release delete <tag> --cleanup-tag --yes
  ```

- **Check the release fails: no successful Deploy run.** Dev has not applied
  that commit. Fix dev first, then delete the release and publish again.
- **The preview shows a change that is in no pull request.** Prod has drifted.
  Reject, then see [Resolve drift](resolve-drift.md).
- **An earlier change is not ready and a later one is.** A release carries
  every commit up to the one it names. [Revert](revert-a-change.md) the
  earlier change and merge it again later, or ship it switched off or scoped
  to a pilot group through a value in `environments/prod.tfvars`.
- **You approved and the apply failed.** See
  [Recover from a failed apply](recover-from-a-failed-apply.md).
- **You rejected the release.** Prod is unchanged. Delete the release so its
  tag does not suggest prod runs it.
