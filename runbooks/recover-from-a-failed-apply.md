# Recover from a failed apply

## When to use

A **Deploy** run failed in dev or a **Release** run failed in prod, and the
pull request carries a comment that starts ❌ The apply failed.

## Steps

1. Read the error in the comment. The Jamf API names the rule the change broke.

2. Work out what changed. Terraform does not roll back: resources that changed
   before the error keep their new values, and the rest keep their old ones.
   Plan from your machine to see what remains:

   ```bash
   terraform plan -var-file=environments/<environment>.tfvars -parallelism=1
   ```

3. Choose one fix:

   - **Correct the change.** Follow [Make a change](make-a-change.md) with a
     value the API accepts.
   - **Withdraw the change.** Follow [Revert a change](revert-a-change.md).

   A fix for prod reaches it through a release. See
   [Promote a change to prod](promote-to-prod.md).

4. If the error was temporary, such as a timeout, run it again with no code
   change. For dev:

   ```bash
   gh workflow run deploy.yml
   ```

   For prod, start the release again with the same commit. It waits for
   approval again.

   ```bash
   gh workflow run release.yml -f commit=<commit-id>
   ```

## Check it worked

The next **Deploy** or **Release** run succeeds, and a plan for the
environment shows no changes.

## If it goes wrong

- **Drift detection opens an issue.** Expect this. The tenant differs from
  the configuration until an apply succeeds, and the issue closes after the
  fix.
- **The same error returns after a retry.** The error is in the configuration.
  Correct or withdraw the change.
- **The run failed in dev.** Prod is safe. A release refuses a commit that dev
  did not apply.
