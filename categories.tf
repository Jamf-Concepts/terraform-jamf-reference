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
}
