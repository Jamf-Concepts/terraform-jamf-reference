# Promote a change to prod

## When to use

One or more changes have merged and applied to dev, you have tested them
there, and you want them in prod.

Running the **Release** workflow starts the promotion. A reviewer on the
`prod` environment approves it.

## Steps

### Start the release

1. Check dev. Confirm each change in the Jamf UI of the dev tenant and on a
   test device.

2. See what the release will contain: every pull request merged since the last
   release.

   ```bash
   git fetch --tags
   ```

   ```bash
   gh release view --json tagName --jq .tagName
   ```

   ```bash
   git log --oneline <last-release-tag>..origin/main
   ```

3. Start the release. On GitHub, the same control is **Actions**, **Release**,
   **Run workflow**.

   ```bash
   gh workflow run release.yml
   ```

   To hold back the newest changes, name the last commit you want. The first
   column of the `git log` output above is the commit ID.

   ```bash
   gh workflow run release.yml -f commit=<commit-id>
   ```

### Approve the release

4. Open the **Release** run:

   ```bash
   gh run list --workflow release.yml --limit 3
   ```

   ```bash
   gh run view <run-id> --web
   ```

5. Open the **Prod preview** job summary and read the plan. Each row should
   trace to a pull request from step 2.

6. Click **Review deployments**, tick **prod**, and click **Approve and
   deploy**. To refuse, click **Reject**.

## Check it worked

The workflow publishes a release named `prod-` and the date and time. Its
notes list the pull requests it delivered, and the newest of them gains a
comment: ✅ Applied to **prod**.

```bash
gh release view
```

## If it goes wrong

- **Check the release fails: the commit is not on main.** Release a commit
  from `main`.
- **Check the release fails: no successful Deploy run.** Dev has not applied
  that commit. Fix dev first, then start the release again.
- **Check the release fails: the pipeline has changed since this commit.**
  GitHub refuses to publish a release for a commit whose pipeline files differ
  from `main`. Release a newer commit.
- **The preview shows a change that is in no pull request.** Prod has drifted.
  Reject, then see [Resolve drift](resolve-drift.md).
- **An earlier change is not ready and a later one is.** A release carries
  every commit up to the one it names. [Revert](revert-a-change.md) the
  earlier change and merge it again later, or ship it switched off or scoped
  to a pilot group through a value in `environments/prod.tfvars`.
- **You approved and the apply failed.** The workflow publishes no release.
  See
  [Recover from a failed apply](recover-from-a-failed-apply.md).
- **You rejected the release.** Prod stays as it was and the workflow
  publishes nothing.
