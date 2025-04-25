module "runbooks" {
  source  = "cloudnationhq/aa/azure//modules/runbooks"
  version = "~> 2.6"

  naming             = local.naming
  resource_group     = var.resource_group_name
  location           = var.location
  automation_account = local.automation_account_name

  config = {
    az-aa-client-secret-rotation = {
      runbook_type = "PowerShell72"
      log_verbose  = false
      log_progress = true
      content      = file("${path.module}/runbooks/az_aa_client_secret_rotation.ps1")
      webhooks = {
        event = {
          # using time date functions result in: The "for_each" map includes keys derived from resource attributes that cannot be determined until apply
          expiry_time = "${var.webhook_expiration_end_year}-12-31T23:59:59Z"
        }
      }
    }
  }

  depends_on = [module.automation_account]
}

module "rbac" {
  source  = "cloudnationhq/rbac/azure"
  version = "~> 2.2.0"

  role_assignments = {
    for name, properties in var.automation_operators : name => {
      client_id    = try(properties.client_id, null)
      display_name = name
      object_id    = try(properties.object_id, null)
      type         = title(properties.type)
      upn          = name
      roles = {
        "Automation Job Operator" = {
          scopes = {
            aa = module.automation_account.config.id
          }
        }
        "Automation Runbook Operator" = {
          scopes = {
            rb = module.runbooks.runbook["az-aa-client-secret-rotation"].id
          }
        }
      }
    }
  }
}
