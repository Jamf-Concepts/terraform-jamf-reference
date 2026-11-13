# Every policy, profile and blueprint in this project targets this one group.
# The serial numbers come from environments/<name>.tfvars.

resource "jamfplatform_device_group" "pilot_computers" {
  name        = "Pilot Computers"
  description = "Managed by Terraform"
  group_type  = "smart"
  device_type = "computer"

  criteria = [
    for index, serial_number in var.pilot_serial_numbers : {
      and_or   = index == 0 ? null : "or"
      criteria = "Serial Number"
      operator = "is"
      value    = serial_number
    }
  ]
}
