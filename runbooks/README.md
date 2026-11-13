# Runbooks

Short procedures for the tasks you repeat once this project runs your tenants.
Each one states when to use it, the steps, how to check it worked, and what to
do if it goes wrong.

Commands assume you are in the repository folder with the GitHub CLI signed in.
Commands that run Terraform on your machine also need the variables from
sections 4.3 and 4.4 of the [main README](../README.md).

| Task | Runbook |
| --- | --- |
| Change, add or delete an object | [Make a change](make-a-change.md) |
| Release tested changes to production | [Promote a change to prod](promote-to-prod.md) |
| Undo a change that applied | [Revert a change](revert-a-change.md) |
| Deploy failed after a merge | [Recover from a failed apply](recover-from-a-failed-apply.md) |
| A drift issue opened | [Resolve drift](resolve-drift.md) |
| Manage an object that already exists in Jamf | [Import an existing object](import-an-existing-object.md) |
| Rename a resource in the code | [Rename a resource](rename-a-resource.md) |
| Hand an object back to manual management | [Stop managing an object](stop-managing-an-object.md) |
| Someone must change Jamf by hand, now | [Make an emergency change in Jamf](emergency-change-in-jamf.md) |
| Move to a newer provider or Terraform | [Upgrade the provider](upgrade-the-provider.md) |
| Replace an API secret, database password or Apple token | [Rotate credentials](rotate-credentials.md) |
| Add a stage tenant, or any further tenant | [Add an environment](add-an-environment.md) |
| `Error acquiring the state lock` | [Clear a state lock](clear-a-state-lock.md) |
