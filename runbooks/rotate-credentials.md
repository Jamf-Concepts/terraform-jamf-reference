# Rotate credentials

## When to use

A secret has leaked, a team member with access has left, or your policy sets a
rotation interval.

Each GitHub environment holds its own copy of each secret. Update every
environment that uses the credential: `dev`, and for production both
`prod-plan` and `prod`.

## Jamf API client secret

1. In [Jamf Account](https://account.jamf.com), under **Integrations**, issue a
   new client secret for the integration, or create a new integration with the
   same permissions.

2. Store the new values in the GitHub environment. The command prompts for the
   value, so it stays out of your shell history:

   ```bash
   gh secret set JAMFPLATFORM_CLIENT_SECRET --env <environment>
   ```

   For a new integration, set `JAMFPLATFORM_CLIENT_ID` the same way.

3. Prove the new secret with a run that changes nothing:

   ```bash
   gh workflow run drift.yml
   ```

4. Revoke the old secret or delete the old integration in Jamf Account.

## State database password

1. Check that no pipeline run is in progress.

2. In the Neon console, click **Connect**, then **Reset password**. Copy the new
   connection string with **Connection pooling** off, and change
   `sslmode=require` to `sslmode=verify-full`.

3. Store it in every GitHub environment that uses that database:

   ```bash
   gh secret set PG_CONN_STR --env <environment>
   ```

4. Prove it:

   ```bash
   gh workflow run drift.yml
   ```

## Apple tokens

1. Download the renewed token from Apple Business Manager.

2. Store it in the GitHub environment:

   ```bash
   base64 -i token.p7m | gh secret set ADE_SERVER_TOKEN --env <environment>
   ```

3. Raise the token's `_wo_version` attribute by one in a pull request, as in
   [Make a change](make-a-change.md). Terraform sends the token to Jamf when
   that number changes.

## Check it worked

The **Drift detection** run passes for each environment you updated.

## If it goes wrong

- **The run fails with an authentication error.** The secret in GitHub does not
  match. Set it again. GitHub cannot show you a stored secret.
- **The run fails with `PG_CONN_STR points at a connection pooler`.** You
  copied the pooled string. Turn **Connection pooling** off and copy again.
- **You revoked the old secret first.** Pipelines fail until you store the new
  one. Nothing in Jamf changes meanwhile.
