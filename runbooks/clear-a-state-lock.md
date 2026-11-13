# Clear a state lock

## When to use

A plan or apply stops with `Error acquiring the state lock`.

The lock stops two runs writing state at once. In most cases it is doing its
job and the right action is to wait.

## Steps

1. Find the holder. Look for a pipeline run in progress, and ask whether a
   colleague is running Terraform on their machine.

   ```bash
   gh run list --status in_progress
   ```

2. If a run is in progress, wait for it. The pipeline waits five minutes for a
   lock before it fails, so a short overlap clears without help.

3. If the run is stuck, cancel it and wait until it shows as cancelled. The
   lock stays held while the run winds down.

   ```bash
   gh run cancel <run-id>
   ```

4. Try again.

5. If nothing is running and the lock remains, it is stale. Clear it from your
   machine with the lock ID from the error message:

   ```bash
   terraform force-unlock <lock-id>
   ```

   Some backends tie the lock to a connection and have no such command. Follow
   your backend's own procedure. Section 12.3 of the
   [main README](../README.md) covers the backend the session uses.

## Check it worked

```bash
terraform plan -var-file=environments/<environment>.tfvars -parallelism=1
```

The plan runs.

## If it goes wrong

- **You unlocked under a live apply.** Two runs may have written state, and the
  apply may have failed part-way. Plan the environment, read every row, and
  see [Recover from a failed apply](recover-from-a-failed-apply.md). If the
  plan wants to create objects that exist, restore the previous state version
  from your backend.
- **The lock returns each time.** Two schedules or two people overlap. Check
  for a second copy of the pipeline, such as a fork with the same secrets.
