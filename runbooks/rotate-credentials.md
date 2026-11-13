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

## State backend credentials

1. Check that no pipeline run is in progress.

2. Issue new credentials in your state backend. Section 12.3 of the
   [main README](../README.md) covers the backend the session uses.

3. Store them in every GitHub environment that reads that state. Use the name
   of the secret your pipeline reads for the backend:

   ```bash
   gh secret set <backend-secret> --env <environment>
   ```

4. Prove it:

   ```bash
   gh workflow run drift.yml
   ```

5. Revoke the old credentials in the backend.

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
- **The run cannot reach the state.** The backend secret does not match. Set
  it again, in the form your backend expects.
- **You revoked the old secret first.** Pipelines fail until you store the new
  one. Nothing in Jamf changes meanwhile.
