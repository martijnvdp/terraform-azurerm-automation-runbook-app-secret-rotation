module "naming" {
  source  = "cloudnationhq/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "rg" {
  source  = "cloudnationhq/rg/azure"
  version = "~> 2.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = "westeurope"
    }
  }
}

module "kv" {
  source  = "cloudnationhq/kv/azure"
  version = "~> 3.0"

  vault = {
    name           = module.naming.key_vault.name_unique
    location       = module.rg.groups.demo.location
    resource_group = module.rg.groups.demo.name

    network_acls = {
      ip_rules = [
        "127.3.11.248/32" # Example allowed ip list
    ] }
  }
}

module "rbac" {
  source  = "cloudnationhq/rbac/azure"
  version = "~> 2.0"

  role_assignments = {
    (module.client_secret_rotation.automation_account_name) = {
      type = "ServicePrincipal"
      roles = {
        "Key Vault Secrets Officer" = {
          scopes = {
            kv = module.rg.groups.main.id
          }
        }
        # requires owner for adding the runbook runners public ip to the allow list of the kv
        "Owner" = {
          scopes = {
            kv = module.rg.groups.main.id
          }
        }
      }
    }
  }
}

module "client_secret_rotation" {
  source = "../../"

  environment         = "tst"
  resource_group_id   = module.rg.groups.demo.id
  resource_group_name = module.rg.groups.demo.name
  location            = "location"
  location_code       = "weu"
  workload            = "myworkloadname"

  automation_operators = {
    "AUTOMATION_OPERATORS_GROUP" = {
      type = "Group"
    }
  }
  keyvaults = [
    {
      id   = module.naming.key_vault.id
      name = module.naming.key_vault.name_unique
    }
  ]
}

resource "azurerm_key_vault_secret" "default" {
  name            = "my_rotating_secret"
  content_type    = "password"
  expiration_date = timeadd(timestamp(), "24h")
  key_vault_id    = module.kv.vault.id
  value           = ""

  tags = {
    "az_aa_client_secret_rotation.app_name"                   = "AZURE_APPLICATION_NAME_TO_ROTATE_CLIENT_SECRET"
    "az_aa_client_secret_rotation.client_secret_display_name" = "auto_rotated_client_secret"
    "az_aa_client_secret_rotation.enabled"                    = "true"
    "az_aa_client_secret_rotation.expiration_in_days"         = "90"
    "az_aa_client_secret_rotation.notification_recipients"    = "person1@mail.com,person2@mail.com"
    "az_aa_client_secret_rotation.notification_sender"        = "existing_sender_mail@mail.com"
  }

  lifecycle {
    ignore_changes = [
      expiration_date,
      value
    ]
  }
}
