# Add an environment

## When to use

You have another tenant to manage with the same configuration, such as a stage
tenant between dev and prod.

The steps use `stage` as the name.

## Steps

1. Create an integration for the tenant in Jamf Account, with the permissions
   from section 4.4 of the [main README](../README.md).

2. Create the GitHub environment and store its secrets:

   ```bash
   gh api --method PUT "repos/{owner}/{repo}/environments/stage" --silent
   ```

   ```bash
   gh secret set JAMFPLATFORM_CLIENT_ID --env stage
   ```

   ```bash
   gh secret set JAMFPLATFORM_CLIENT_SECRET --env stage
   ```

   Store the state backend credentials the same way, under the secret name
   your pipeline reads for the backend.

3. On a new branch, copy `environments/dev.tfvars` to
   `environments/stage.tfvars` and set the tenant's gateway URL, environment
   ID and other values.

4. Add a plan job to `.github/workflows/pull-request.yml`:

   ```yaml
     plan-stage:
       name: Stage
       needs: checks
       uses: ./.github/workflows/terraform.yml
       with:
         environment: stage
       secrets: inherit
   ```

5. Add an apply job to `.github/workflows/deploy.yml`, after `dev`:

   ```yaml
     stage:
       name: Stage
       needs: dev
       uses: ./.github/workflows/terraform.yml
       with:
         environment: stage
         apply: true
       secrets: inherit
   ```

   A release checks that dev applied a commit before prod receives it. To make
   stage part of that test, start a release only after the **Stage** job
   succeeds.

6. Add a drift job to `.github/workflows/drift.yml`:

   ```yaml
     stage:
       name: Stage
       uses: ./.github/workflows/terraform.yml
       with:
         environment: stage
         report_drift: true
       secrets: inherit
   ```

7. Open a pull request. It gains a plan comment for stage that creates every
   object, because the state for stage starts empty.

8. Merge. **Deploy** applies to dev, then stage.

## Check it worked

The pull request gains ✅ Applied to **stage**, and the objects exist in the
stage tenant.

## If it goes wrong

- **The stage plan fails with `Name already in use`.** The tenant already holds
  objects with those names. See
  [Import an existing object](import-an-existing-object.md), and section 12.6
  of the main README for imports that apply to one tenant.
- **Stage should wait for an approval.** Add required reviewers to the `stage`
  GitHub environment, and give its plans a separate `stage-plan` environment
  with read-only credentials, as section 12.2 of the main README does for
  prod.
- **A value must differ in stage.** Set it in `environments/stage.tfvars`. See
  section 6.1 of the main README.
