## Call Terraform provider
terraform {
  required_providers {
    jamfplatform = {
      source                = "jamf/jamfplatform"
      version               = ">= 1.8.0"
      configuration_aliases = [jamfplatform.jpro]
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

## jsc_ap (Jamf-Concepts/jsctfprovider) is replaced by the native
## jamfplatform_security_cloud_activation_profile resource below -- no more
## hand-built plist payloads or a manual "remove the placeholder serial number
## criteria" cleanup step. The deploy action creates and scopes the Jamf Pro
## configuration profile itself; this module no longer creates one directly.

resource "jamfplatform_pro_category" "jsc_all_services_profiles" {
  name     = "[Foundations] Jamf Security Cloud - Activation Profiles"
  priority = 9
}

## UEM Connect scoping below deliberately does not create Foundations-named
## device groups. deploy-to-uem's scoping is additive-only and cannot be
## narrowed or removed via any documented API once applied (confirmed
## 2026-10-28 against letstest.jamfcloud.com) -- a Foundations-created group
## used for this would become permanently undeletable the moment it's
## scoped, blocking `tofu destroy`/rollback forever (HAS_DEPENDENCIES).
## Instead this scopes to Jamf Pro's own built-in default groups, which
## Terraform never creates or destroys, so there is nothing for this module
## to ever get stuck deleting. The `platform` value on each deploy()
## call (SUPERVISED_MAC/SUPERVISED_IOS) is what Jamf's backend uses to
## restrict delivery to actually-supervised devices within the broader
## built-in group -- not verified device-side yet (letstest has zero
## enrolled mobile devices to check against), so confirm this in the first
## real end-to-end run against a tenant with real supervised/unsupervised
## mobile devices before relying on it.
data "jamfplatform_device_groups" "all_managed_clients_search" {
  filter = [
    {
      selector = "name"
      argument = "All Managed Clients"
    },
  ]
}

data "jamfplatform_device_group" "all_managed_clients" {
  id = data.jamfplatform_device_groups.all_managed_clients_search.device_groups[0].id
}

## No single built-in "All Mobile Devices" group exists in Jamf Pro --
## confirmed live against letstest.jamfcloud.com 2026-10-28: built-ins are
## split by device subtype (All Managed iPhones, All Managed iPads, All
## Managed Apple TVs, All Managed Vision Pros, All Managed Watches, All
## Managed iPod touches). SUPERVISED_IOS only applies to iPhone/iPad, so
## both of those are passed to deploy-to-uem's uemGroups (which accepts an
## array) rather than a single group.
data "jamfplatform_device_groups" "all_managed_iphones_search" {
  filter = [
    {
      selector = "name"
      argument = "All Managed iPhones"
    },
  ]
}

data "jamfplatform_device_group" "all_managed_iphones" {
  id = data.jamfplatform_device_groups.all_managed_iphones_search.device_groups[0].id
}

data "jamfplatform_device_groups" "all_managed_ipads_search" {
  filter = [
    {
      selector = "name"
      argument = "All Managed iPads"
    },
  ]
}

data "jamfplatform_device_group" "all_managed_ipads" {
  id = data.jamfplatform_device_groups.all_managed_ipads_search.device_groups[0].id
}

resource "jamfplatform_security_cloud_activation_profile" "all_services" {
  name      = "Network Threat and Content Control"
  platforms = ["ios", "mac"]

  capabilities = {
    content_controls = true
    network_security = true
  }
}

## Deploy the activation profile's macOS and supervised-iOS configuration
## profiles to Jamf Pro. The provider only exposes this as
## jamfplatform_security_cloud_activation_profile_deploy, a Terraform "action"
## block (Terraform 1.14+, HashiCorp-only) -- every onboarder in this repo
## runs on OpenTofu (see providers.tf's `>= 1.14` comment and this repo's
## history), whose parser rejects `action`/`action_trigger` syntax outright.
## This calls the same REST operation the action wraps directly instead:
## POST .../uem-connect/v1/activation-profiles/{code}/deploy-to-uem (platform-api
## "JSC UEM Connect API" spec). That operation is documented idempotent, so a
## re-apply is safe. Auth is X-Environment-Id with the plain Platform API
## environment_id -- the OpenAPI spec names the header X-Tenant-Id and implies
## a separate Jamf Security Cloud tenant id, but wire-verified against
## letstest.jamfcloud.com 2026-09-07: X-Tenant-Id with either the environment_id
## or the CSA tenant id (GET /pro/v1/csa/tenant-id) both fail (OWNERSHIP_FORBIDDEN
## / BAD_PERMISSIONS); X-Environment-Id with the environment_id succeeds, and
## matches every other securitycloud/pro call this module already makes.
## uem_connect_dependency only exists to order this resource
## after the sibling UEM Connect module's connector.
resource "null_resource" "deploy_activation_profile" {
  triggers = {
    uem_connect_dependency  = var.uem_connect_dependency
    activation_profile_code = jamfplatform_security_cloud_activation_profile.all_services.id
    mac_group_id            = data.jamfplatform_device_group.all_managed_clients.jamf_pro_id
    ios_iphone_group_id     = data.jamfplatform_device_group.all_managed_iphones.jamf_pro_id
    ios_ipad_group_id       = data.jamfplatform_device_group.all_managed_ipads.jamf_pro_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      JAMFPLATFORM_BASE_URL       = var.jamfplatform_base_url
      JAMFPLATFORM_CLIENT_ID      = var.jamfplatform_client_id
      JAMFPLATFORM_CLIENT_SECRET  = var.jamfplatform_client_secret
      JAMFPLATFORM_ENVIRONMENT_ID = var.jamfplatform_environment_id
      ACTIVATION_PROFILE_CODE     = jamfplatform_security_cloud_activation_profile.all_services.id
      MAC_GROUP_ID                = data.jamfplatform_device_group.all_managed_clients.jamf_pro_id
      IOS_IPHONE_GROUP_ID         = data.jamfplatform_device_group.all_managed_iphones.jamf_pro_id
      IOS_IPAD_GROUP_ID           = data.jamfplatform_device_group.all_managed_ipads.jamf_pro_id
    }
    command = <<-EOT
      set -euo pipefail

      case "$JAMFPLATFORM_BASE_URL" in
        us|eu|apac) BASE_URL="https://$JAMFPLATFORM_BASE_URL.api.jamfcloud.com" ;;
        *)          BASE_URL="$JAMFPLATFORM_BASE_URL" ;;
      esac

      TOKEN=$(curl -sf -X POST "$BASE_URL/auth/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$JAMFPLATFORM_CLIENT_ID&client_secret=$JAMFPLATFORM_CLIENT_SECRET" \
        | jq -r '.access_token')

      # The UEM Connect connector this depends on (see uem_connect_dependency
      # above) can report created in Terraform before JSC's backend has
      # actually indexed it -- deploy-to-uem 404s with "Config doesn't exist
      # for customer" in that window. Retry on 404 only; any other status is
      # a real failure and fails fast.
      deploy() {
        platform="$1"
        shift
        groups_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
        attempt=1
        max_attempts=6
        while :; do
          body_file=$(mktemp)
          status=$(curl -s -o "$body_file" -w '%%{http_code}' -X POST \
            "$BASE_URL/securitycloud/uem-connect/v1/activation-profiles/$ACTIVATION_PROFILE_CODE/deploy-to-uem" \
            -H "Authorization: Bearer $TOKEN" \
            -H "X-Environment-Id: $JAMFPLATFORM_ENVIRONMENT_ID" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg platform "$platform" --argjson groups "$groups_json" '{uem: "JAMF", platform: $platform, uemGroups: $groups}')")
          if [ "$status" = "204" ]; then
            rm -f "$body_file"
            return 0
          fi
          if [ "$status" = "404" ] && [ "$attempt" -lt "$max_attempts" ]; then
            echo "Activation profile deploy for platform=$platform got 404 (UEM Connect config not indexed yet), retrying in 10s (attempt $attempt/$max_attempts)..." >&2
            rm -f "$body_file"
            attempt=$((attempt + 1))
            sleep 10
            continue
          fi
          echo "Activation profile deploy failed for platform=$platform (HTTP $status):" >&2
          cat "$body_file" >&2
          rm -f "$body_file"
          exit 1
        done
      }

      deploy "SUPERVISED_MAC" "$MAC_GROUP_ID"
      deploy "SUPERVISED_IOS" "$IOS_IPHONE_GROUP_ID" "$IOS_IPAD_GROUP_ID"
    EOT
  }
}
