variable "jamfplatform_base_url" {
  description = "Jamf Platform API gateway URL. US: https://us.api.jamfcloud.com, EU: https://eu.api.jamfcloud.com, APAC: https://apac.api.jamfcloud.com"
  type        = string
}

variable "jamfplatform_environment_id" {
  description = "Platform environment UUID. The Integration details panel at account.jamf.com shows it."
  type        = string
}
