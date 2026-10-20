# base_url and environment_id come from terraform.tfvars. client_id and client_secret come from TF_VAR_ environment variables. See README.md.

provider "jamfplatform" {
  base_url       = var.jamfplatform_base_url
  client_id      = var.jamfplatform_client_id
  client_secret  = var.jamfplatform_client_secret
  environment_id = var.jamfplatform_environment_id
}
