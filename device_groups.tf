# Every policy, profile and blueprint in this project targets this one group.
#
# Terraform manages the group. People manage who is in it, in Jamf. Leave the
# members attribute out: declaring it hands membership to Terraform, and an
# empty list removes every member.

resource "jamfplatform_device_group" "pilot_computers" {
  name        = "Pilot Computers"
  description = "Managed by Terraform. Add and remove members in Jamf."
  group_type  = "static"
  device_type = "computer"

  # Other resources refer to this one. When a change removes it, Terraform
  # updates those resources first and deletes this one last.
  lifecycle {
    create_before_destroy = true
  }
}
