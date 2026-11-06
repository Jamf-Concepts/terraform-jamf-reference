terraform {
  required_version = ">= 1.13.0"

  required_providers {
    jamfplatform = {
      source  = "jamf/jamfplatform"
      version = ">= 1.8.0"
    }
  }
}
