resource "jamfplatform_pro_policy" "flush_dns_cache" {
  general = {
    name        = "Flush DNS Cache"
    enabled     = true
    frequency   = "Ongoing"
    category_id = jamfplatform_pro_category.main["maintenance"].id
  }

  scope = {
    targets = {
      computer_group_ids = [jamfplatform_device_group.pilot_computers.jamf_pro_id]
    }
  }

  script_assignments = [
    {
      id       = jamfplatform_pro_script.flush_dns_cache.id
      priority = "After"
    },
  ]

  self_service = {
    use_for_self_service     = true
    self_service_description = "Clears the DNS cache. Run this when a website fails to load after a network change."
    install_button_text      = "Flush"
  }
}
