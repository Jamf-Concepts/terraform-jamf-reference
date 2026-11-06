# https://learn.jamf.com/en-US/bundle/jamf-pro-documentation-current/page/Automated_Device_Enrollment_for_Computers.html
#
# Two ADE prestages are defined:
#   generic       - baseline config, no IdP onboarding
#   entra_id_psso - installs the Entra ID SSO Extension profile and
#                   Company Portal during Setup Assistant, enabling Platform SSO
#
# Both reference jamfplatform_pro_automated_device_enrollment.default, so an ADE token is
# required. See device_enrollments.tf and variables.tf.
#
# entra_id_psso sets psso_enabled = true, which Jamf Pro refuses unless the
# tenant already has SAML single sign-on configured:
#
#   [INVALID_CONTENT] pssoEnabled: Cannot enable Platform Single Sign-On
#   (PSSO) 403 workflow when SAML is not configured
#
# Configure SSO in Jamf Pro under Settings > System > Single sign-on before
# applying, or comment this resource out.
#
# Only non-default values are set. Optional fields left unset (support
# contact details, location/purchasing/account info, recovery lock, etc.)
# fall back to the provider's "unset" behaviour.

resource "jamfplatform_pro_computer_prestage_enrollment" "generic" {
  display_name                                  = "Generic (Managed by Terraform)"
  make_mdm_profile_mandatory                    = true
  allow_mdm_profile_removal                     = false
  prevent_activation_lock                       = true
  enable_device_based_activation_lock           = false
  require_authentication                        = false
  use_existing_site_membership                  = false
  use_existing_location_information             = false
  automatically_advance_through_setup_assistant = false
  device_enrollment_program_instance_id         = jamfplatform_pro_automated_device_enrollment.default.id
  prestage_minimum_os_target_version_type       = "MINIMUM_OS_LATEST_MINOR_VERSION"

  skip_setup_items = {
    biometric                   = false
    terms_of_address            = true
    filevault                   = false
    icloud_diagnostics          = true
    app_analytics               = true
    accessibility               = false
    apple_id                    = true
    screen_time                 = true
    siri                        = true
    true_tone_display           = true
    transfer_information        = true
    choose_your_look            = false
    privacy                     = true
    payment                     = true
    registration                = true
    terms_and_conditions        = true
    all_your_files_in_icloud    = true
    location                    = false
    intelligence                = true
    enable_lockdown_mode        = true
    get_started                 = true
    wallpaper                   = true
    software_update             = true
    additional_privacy_settings = true
    os_showcase                 = true
  }
}

resource "jamfplatform_pro_computer_prestage_enrollment" "entra_id_psso" {
  display_name                                  = "Entra ID Platform SSO (Managed by Terraform)"
  make_mdm_profile_mandatory                    = true
  allow_mdm_profile_removal                     = false
  prevent_activation_lock                       = true
  enable_device_based_activation_lock           = false
  require_authentication                        = false
  use_existing_site_membership                  = false
  use_existing_location_information             = false
  automatically_advance_through_setup_assistant = false
  device_enrollment_program_instance_id         = jamfplatform_pro_automated_device_enrollment.default.id
  prestage_minimum_os_target_version_type       = "MINIMUM_OS_LATEST_MINOR_VERSION"
  psso_enabled                                  = true
  platform_sso_app_bundle_id                    = "com.microsoft.CompanyPortalMac"
  custom_package_distribution_point_id          = "-2"

  configuration_profile_ids = [
    jamfplatform_pro_macos_configuration_profile.microsoft_autoupdate.id,
    jamfplatform_pro_macos_configuration_profile.sso_extension_entra_id.id
  ]

  custom_package_ids = [
    jamfplatform_pro_package.default["microsoft_company_portal"].id
  ]

  skip_setup_items = {
    biometric                   = false
    terms_of_address            = true
    filevault                   = false
    icloud_diagnostics          = true
    app_analytics               = true
    accessibility               = false
    apple_id                    = true
    screen_time                 = true
    siri                        = true
    true_tone_display           = true
    transfer_information        = true
    choose_your_look            = false
    privacy                     = true
    payment                     = true
    registration                = true
    terms_and_conditions        = true
    all_your_files_in_icloud    = true
    location                    = false
    intelligence                = true
    enable_lockdown_mode        = true
    get_started                 = true
    wallpaper                   = true
    software_update             = true
    additional_privacy_settings = true
    os_showcase                 = true
  }
}
