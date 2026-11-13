# Upgrade the provider

## When to use

A new release of the `jamf/jamfplatform` provider has a fix or a resource you
need, or you upgrade on a regular schedule.

`.terraform.lock.hcl` pins the exact version. Nothing upgrades until you
change that file.

## Steps

1. Read the provider's release notes for each version between yours and the
   target. Look for breaking changes and upgrade guides.

2. On a new branch, raise the minimum version in `terraform.tf` if you need
   to:

   ```hcl
   version = ">= 1.9.0"
   ```

3. Select the new version and record its checksums for each platform your team
   and the pipeline use:

   ```bash
   terraform init -upgrade
   ```

   ```bash
   terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=windows_amd64
   ```

4. Commit `terraform.tf` and `.terraform.lock.hcl`, and open a pull request, as
   in [Make a change](make-a-change.md).

5. Read the plan for each environment. A clean upgrade shows no changes. If it
   shows changes, the release notes should explain each one.

6. Merge, check dev, then release to prod. See
   [Promote a change to prod](promote-to-prod.md).

To require a newer Terraform, raise `required_version` in `terraform.tf` in the
same way. The pipeline installs the latest Terraform release on each run.

## Check it worked

`terraform version` on your machine lists the new provider version, and a plan
for each environment shows no changes.

## If it goes wrong

- **The plan shows changes you cannot explain.** Do not merge. Close the pull
  request. Nothing has changed, because the lock file on `main` still names
  the old version.
- **You merged, an apply ran, and you want the old version back.** You cannot
  go back. Once an apply writes state with the newer provider, the older one
  stops with `Resource instance managed by newer provider version`. Fix
  forward: correct the configuration for the new version. A revert works only
  while no apply has written state, which means the plan showed no changes
  and nothing has applied since.
- **The pipeline fails with a checksum error.** The lock file lacks the
  pipeline's platform. Run the `terraform providers lock` command in step 3.
