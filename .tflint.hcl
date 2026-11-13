plugin "terraform" {
  enabled = true
  preset  = "all"
}

# This project keeps one file per resource type and has no main.tf or
# outputs.tf, so the standard module layout rule does not apply.
rule "terraform_standard_module_structure" {
  enabled = false
}
