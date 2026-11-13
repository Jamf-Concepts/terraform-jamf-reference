# Script bodies live in support_files/scripts/ so a pull request shows them as
# shell, with syntax highlighting and line-by-line review.

resource "jamfplatform_pro_script" "flush_dns_cache" {
  name            = "Flush DNS Cache"
  category_id     = jamfplatform_pro_category.main["maintenance"].id
  info            = "Clears the DNS cache and restarts mDNSResponder."
  notes           = "Managed by Terraform"
  priority        = "AFTER"
  script_contents = file("${path.module}/support_files/scripts/flush_dns_cache.sh")
}
