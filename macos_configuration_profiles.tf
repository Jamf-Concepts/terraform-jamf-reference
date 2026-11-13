# Profile payloads live in support_files/macos_configuration_profiles/.

resource "jamfplatform_pro_macos_configuration_profile" "login_window_banner" {
  general = {
    name                = "Login Window Banner"
    description         = "Managed by Terraform"
    distribution_method = "Install Automatically"
    redeploy_on_update  = "All"
    category_id         = jamfplatform_pro_category.main["security"].id
    payloads            = file("${path.module}/support_files/macos_configuration_profiles/login_window_banner.mobileconfig")
  }

  scope = {
    targets = {
      computer_group_ids = [jamfplatform_device_group.pilot_computers.jamf_pro_id]
    }
  }
}
