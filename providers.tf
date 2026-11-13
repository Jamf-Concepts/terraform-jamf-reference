# base_url and environment_id come from environments/<name>.tfvars and identify
# the tenant. The provider reads the client ID and secret from the
# JAMFPLATFORM_CLIENT_ID and JAMFPLATFORM_CLIENT_SECRET environment variables.

provider "jamfplatform" {
  base_url       = var.jamfplatform_base_url
  environment_id = var.jamfplatform_environment_id
}
