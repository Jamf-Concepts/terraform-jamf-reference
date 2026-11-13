# Other resources reference a category by its map key, for example
# jamfplatform_pro_category.main["maintenance"].id.

locals {
  categories = {
    maintenance = "Maintenance"
    security    = "Security"
  }
}

resource "jamfplatform_pro_category" "main" {
  for_each = local.categories

  name     = each.value
  priority = 9

  # Other resources refer to this one. When a change removes it, Terraform
  # updates those resources first and deletes this one last.
  lifecycle {
    create_before_destroy = true
  }
}
