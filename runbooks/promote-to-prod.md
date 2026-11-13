# Promote a change to prod

## When to use

A change has merged and applied to dev, and the **Deploy** run waits for a
reviewer on the `prod` environment.

## Steps

1. Check dev. Confirm the change in the Jamf UI of the dev tenant and on a test
   device. An approval that skips this step approves an untested change.

2. Open the waiting run:

   ```bash
   gh run list --workflow deploy.yml --limit 5
   ```

   ```bash
   gh run view <run-id> --web
   ```

3. Open the **Prod preview** job summary and read the plan. It lists what this
   commit changes in prod. Compare it with the prod plan comment on the pull
   request.

4. Click **Review deployments**, tick **prod**, and click **Approve and
   deploy**. To refuse, click **Reject**.

## Check it worked

The pull request gains a comment: ✅ Applied to **prod**. The run summary of
the **Prod** job shows the plan it applied.

## If it goes wrong

- **The preview shows a change nobody made in this pull request.** Prod has
  drifted. Reject, then see [Resolve drift](resolve-drift.md).
- **Two runs wait for approval.** Approve the newest one, which carries both
  changes, and reject the older one.
- **You approved and the apply failed.** See
  [Recover from a failed apply](recover-from-a-failed-apply.md). Prod now
  differs from `main` until you fix it.
- **The change must not reach prod.** Reject the run, then
  [revert the change](revert-a-change.md) so dev and `main` return to the
  previous state.
