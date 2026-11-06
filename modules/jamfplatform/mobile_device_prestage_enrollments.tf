# https://learn.jamf.com/en-US/bundle/jamf-pro-documentation-current/page/Automated_Device_Enrollment_for_Mobile_Devices.html
#
# Default mobile device ADE prestage. References jamfpro_device_enrollments.default,
# so an ADE token is required. See device_enrollments.tf and variables.tf.

resource "jamfplatform_pro_mobile_device_prestage_enrollment" "default" {
  display_name                                          = "Default (Managed by Terraform)"
  make_mdm_profile_mandatory                            = true
  prevent_unenrollment                                  = true
  automatically_assign_new_devices                      = false
  prevent_activation_lock                               = true
  device_enrollment_program_instance_id                 = jamfplatform_pro_automated_device_enrollment.default.id
  allow_pairing                                         = true
  supervise_devices_with_ios_12_or_earlier              = true
  install_configuration_profiles_before_setup_assistant = true
  timezone                                              = "UTC"
  prestage_minimum_os_target_version_type_ios           = "MINIMUM_OS_LATEST_MINOR_VERSION"
  prestage_minimum_os_target_version_type_ipad          = "MINIMUM_OS_LATEST_MINOR_VERSION"
  skip_setup_items = {
    location                           = false
    privacy                            = true
    biometric                          = false
    software_update                    = false
    app_analytics                      = true
    imessage_and_facetime              = true
    intelligence                       = true
    where_is_this_apple_tv             = true
    passcode                           = false
    add_cellular_plan                  = true
    screen_time                        = true
    restore_completed                  = true
    tv_provider_sign_in                = true
    siri                               = true
    apps_and_data                      = true
    see_the_world_screensaver          = true
    home_button_sensitivity            = true
    cloud_storage                      = true
    action_button                      = true
    transfer_data                      = true
    enable_lockdown_mode               = true
    display_zoom                       = true
    preferred_language                 = true
    voice_selection                    = true
    one_home_screen_for_every_apple_tv = true
    emergency_sos                      = true
    terms_of_address                   = true
    express_language                   = true
    camera_button                      = true
    apple_id                           = true
    true_tone_display                  = true
    apple_watch                        = true
    software_update_completed          = false
    choose_your_look                   = false
    android                            = true
    payment                            = true
    new_feature_highlights             = true
    terms_and_conditions               = true
    get_started                        = true
    safety_and_handling                = true
    set_up_your_apple_tv               = true
    multitasking                       = true
    keyboard                           = true
    os_showcase                        = true
    dictation                          = true
  }
}
