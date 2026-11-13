# Resolve drift

## When to use

An issue titled **Terraform drift: <environment>** opened, or a **Drift
detection** run failed.

## Steps

1. Open the issue and read the plan. Dev should match `main` and prod should
   match the latest release. The plan shows what applying that
   again would change, which is the reverse of the drift.

   ```bash
   gh issue list --search "Terraform drift"
   ```

2. Find the cause. Either someone changed Jamf outside Terraform, or an apply
   failed part-way.

3. Choose who wins:

   - **The configuration wins.** Apply it again. Terraform overwrites the
     change made in Jamf. For dev:

     ```bash
     gh workflow run deploy.yml
     ```

     For prod, release the latest release again. The workflow applies it,
     waits for approval, and publishes nothing new.

     ```bash
     gh release view --json tagName --jq .tagName
     ```

     ```bash
     gh workflow run release.yml -f commit=<release-tag>
     ```

   - **The change in Jamf wins.** Copy it into the configuration and follow
     [Make a change](make-a-change.md). The plan on that pull request must
     show no changes for the drifted object. If it shows changes, your code
     does not match Jamf yet. For prod, run a release afterwards.

4. Run the check again:

   ```bash
   gh workflow run drift.yml
   ```

## Check it worked

The **Drift detection** run passes and closes the issue.

## If it goes wrong

- **The plan lists objects nobody touched.** Read the attributes it changes. A
  new provider version or a Jamf Pro upgrade can alter how an attribute reads.
  Check the provider's release notes before you apply.
- **Drift returns each day on the same object.** Someone, or another system,
  keeps changing it. Agree who owns the object. If Terraform should not, see
  [Stop managing an object](stop-managing-an-object.md).
- **Prod shows drift right after a failed release.** The apply stopped
  part-way, and the workflow published no release. See
  [Recover from a failed apply](recover-from-a-failed-apply.md).
