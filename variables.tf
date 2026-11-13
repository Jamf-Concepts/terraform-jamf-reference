variable "jamfplatform_base_url" {
  description = "Jamf Platform API gateway URL. US: https://us.api.jamfcloud.com, EU: https://eu.api.jamfcloud.com, APAC: https://apac.api.jamfcloud.com"
  type        = string
}

variable "jamfplatform_environment_id" {
  description = "Platform environment UUID. The Integration details panel at account.jamf.com shows it."
  type        = string
}

variable "pilot_serial_numbers" {
  description = "Serial numbers of the computers in the Pilot Computers group. Each tenant enrols different hardware, so each environment sets its own list."
  type        = list(string)

  validation {
    condition     = length(var.pilot_serial_numbers) > 0
    error_message = "List at least one serial number. A smart group with no criteria matches every computer."
  }
}
