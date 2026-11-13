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

4. Try again. With the PostgreSQL backend the lock lives as long as the
   database connection that took it, so it ends when the run ends.

5. If nothing is running and the lock remains, a connection is stuck open. End
   it from the Neon console, in **SQL Editor**:

   ```sql
   SELECT pg_terminate_backend(pid) FROM pg_locks WHERE locktype = 'advisory';
   ```

   This ends every session that holds a Terraform lock in that database, for
   every environment that stores state there. Check step 1 for each of them
   first.

**On other backends.** S3, Azure Storage and Google Cloud Storage can keep a
lock after a run dies. Clear it from your machine with the ID from the error
message, after step 1 confirms nothing is running:

```bash
terraform force-unlock <lock-id>
```

The PostgreSQL backend does not support this command.

## Check it worked

```bash
terraform plan -var-file=environments/<environment>.tfvars -parallelism=1
```

The plan runs.

## If it goes wrong

- **You ended the session of a live apply.** That apply fails part-way. See
  [Recover from a failed apply](recover-from-a-failed-apply.md).
- **The lock returns each time.** Two schedules or two people overlap. Check
  for a second copy of the pipeline, such as a fork with the same secrets.
