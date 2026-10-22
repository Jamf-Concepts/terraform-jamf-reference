## Call Terraform provider
terraform {
  required_providers {
    jamfpro = {
      source                = "deploymenttheory/jamfpro"
      configuration_aliases = [jamfpro.jpro]
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

## Create Categories
resource "jamfpro_category" "sentinelone" {
  name     = "SentinelOne"
  priority = 9
}

## SentinelOne Configuration Profiles
# Deploys 6 configuration profiles from .mobileconfig / .tpl files:
#   1. Service Management    — Managed Login Items
#   2. Network Filter        — Content Filter / socket filter validation
#   3. Network Extension     — System Extension for network monitoring
#   4. Privacy Control       — PPPC / Full Disk Access & Bluetooth
#   5. Notifications         — Agent notification settings
#   6. License               — Registration token (rendered from template)

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_service_management" {
  name                = "SentinelOne - Service Management"
  description         = "Prevents removal of SentinelOne Launch Agents and Launch Daemons via Managed Login Items."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = file("${path.module}/support_files/SentinelOne_Service_Management.mobileconfig")

  scope {
    all_computers = true
    all_jss_users = false
  }
}

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_network_filter" {
  name                = "SentinelOne - Network Filter Validation"
  description         = "Authorizes SentinelOne Network Filter automatic validation."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = file("${path.module}/support_files/SentinelOne_Network_Filter_Validation.mobileconfig")

  scope {
    all_computers = true
    all_jss_users = false
  }
}

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_network_extension" {
  name                = "SentinelOne - Network Monitoring Extension"
  description         = "Allows the SentinelOne System Extension to load and be removed without user approval."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = file("${path.module}/support_files/SentinelOne_Network_Monitoring_Extension.mobileconfig")

  scope {
    all_computers = true
    all_jss_users = false
  }
}

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_privacy_control" {
  name                = "SentinelOne - Privacy Control"
  description         = "Provides Full Disk Access and Bluetooth access to SentinelOne agent processes."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = file("${path.module}/support_files/SentinelOne_Privacy_Control.mobileconfig")

  scope {
    all_computers = true
    all_jss_users = false
  }
}

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_notifications" {
  name                = "SentinelOne - Notifications"
  description         = "Enables notifications for the SentinelOne agent."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = file("${path.module}/support_files/SentinelOne_Notifications.mobileconfig")

  scope {
    all_computers = true
    all_jss_users = false
  }
}

resource "jamfpro_macos_configuration_profile_plist" "sentinelone_license" {
  name                = "SentinelOne - License"
  description         = "Provides the SentinelOne registration token used to license the agent."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = jamfpro_category.sentinelone.id
  payload_validate    = false
  user_removable      = false

  payloads = local.sentinelone_license_profile

  scope {
    all_computers = false
    all_jss_users = false

    computer_group_ids = [jamfpro_smart_computer_group.sentinelone_target.id]
  }
}

## Extension Attributes
resource "jamfpro_computer_extension_attribute" "sentinelone_agent_status" {
  name                   = "SentinelOne - Agent Status"
  input_type             = "SCRIPT"
  enabled                = true
  data_type              = "STRING"
  inventory_display_type = "EXTENSION_ATTRIBUTES"
  script_contents        = file("${path.module}/support_files/computer_extension_attributes/SentinelOne_Agent_Status.sh")
}

## Smart Computer Groups
resource "jamfpro_smart_computer_group" "sentinelone_target" {
  name = "SentinelOne Target Group"
  criteria {
    name        = "Operating System Version"
    search_type = "greater than or equal"
    value       = "13.0"
    and_or      = "and"
    priority    = 0
  }
  criteria {
    name        = "Serial Number"
    search_type = "like"
    value       = "111222333444555"
    and_or      = "and"
    priority    = 1
  }
}

resource "jamfpro_smart_computer_group" "sentinelone_installed" {
  name = "SentinelOne Installed"

  criteria {
    name        = "Application Bundle ID"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "com.sentinelone.extensions-wrapper"
  }
}

resource "jamfpro_smart_computer_group" "sentinelone_not_installed" {
  name = "SentinelOne NOT Installed"

  criteria {
    name        = "Application Bundle ID"
    priority    = 0
    and_or      = "and"
    search_type = "is not"
    value       = "com.sentinelone.extensions-wrapper"
  }
}

## SentinelOne Package Upload
resource "jamfpro_package" "sentinelone_installer" {
  count                 = local.has_pkg_source ? 1 : 0
  package_name          = local.sentinelone_pkg_name
  package_file_source   = local.sentinelone_pkg_source
  category_id           = jamfpro_category.sentinelone.id
  info                  = "SentinelOne macOS Agent installer package"
  notes                 = "Managed by Terraform"
  priority              = 10
  reboot_required       = false
  fill_existing_users   = false
  fill_user_template    = false
  os_install            = false
  suppress_updates      = false
  suppress_from_dock    = false
  suppress_eula         = false
  suppress_registration = false

  timeouts {
    create = "90m"
  }
}

## SentinelOne Deployment Policy
resource "jamfpro_policy" "sentinelone_deploy" {
  count           = local.has_pkg_source ? 1 : 0
  name            = "Deploy SentinelOne Agent"
  enabled         = true
  trigger_checkin = true
  frequency       = "Once per computer"
  category_id     = jamfpro_category.sentinelone.id

  payloads {
    packages {
      distribution_point = "default"
      package {
        id                          = jamfpro_package.sentinelone_installer[0].id
        action                      = "Install"
        fill_user_template          = false
        fill_existing_user_template = false
      }
    }

    maintenance {
      recon                       = true
      reset_name                  = false
      install_all_cached_packages = false
      heal                        = false
      prebindings                 = false
      permissions                 = false
      byhost                      = false
      system_cache                = false
      user_cache                  = false
      verify                      = false
    }
  }

  scope {
    all_computers = false
    all_jss_users = false

    computer_group_ids = [jamfpro_smart_computer_group.sentinelone_target.id]
  }
}
