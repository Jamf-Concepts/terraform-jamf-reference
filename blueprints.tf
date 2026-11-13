resource "jamfplatform_blueprints_blueprint" "software_update" {
  name        = "Software Update Settings"
  description = "Managed by Terraform"
  deployed    = true

  device_groups = [jamfplatform_device_group.pilot_computers.id]

  component_blocks = [
    {
      name = "Software Update Settings"
      software_update_settings = {
        automatic_download                 = "AlwaysOn"
        automatic_install_os_updates       = "AlwaysOn"
        automatic_install_security_updates = "AlwaysOn"
        notifications_enabled              = true
        rapid_security_response_enabled    = true
      }
    },
  ]
}
