# Make an emergency change in Jamf

## When to use

Something is broken on devices now, and a pull request takes too long. You
change Jamf by hand and bring the code in line afterwards.

Keep this rare. Each use bypasses review.

## Steps

1. Tell the team before you touch Jamf. **The next apply overwrites your
   change**, so nobody merges or publishes a release until step 4 is done.

2. Make the change in the Jamf UI. Note what you changed and why.

3. Record it. Run the drift check, which opens an issue showing the difference:

   ```bash
   gh workflow run drift.yml
   ```

4. Bring the code in line the same day. Copy the change into the configuration
   and follow [Make a change](make-a-change.md). The plan on that pull request
   must show no changes for the object you edited. If you changed prod,
   publish a release afterwards. Its preview must show no changes for the
   object either.

5. If you created a new object by hand, follow
   [Import an existing object](import-an-existing-object.md) instead.

## Check it worked

The pull request merges with nothing to apply, and the next **Drift detection**
run closes the issue.

## If it goes wrong

- **A deploy ran and undid your change.** Make the change again in Jamf, then
  complete step 4 before anything else merges.
- **The plan still shows changes after you copied the edit.** Your code does
  not match Jamf yet. Compare the plan's values with yours.
- **The emergency change was wrong.** Apply the configuration again to restore
  the managed settings. [Resolve drift](resolve-drift.md) has the commands
  for dev and for prod.
