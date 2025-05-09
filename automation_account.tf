locals {
  uai_client_id_var_name = join("-", [local.naming.automation_variable, "uai-client-id", var.name_suffix])
}

module "automation_account" {
  source  = "cloudnationhq/aa/azure"
  version = "~> 2.6"

  naming         = local.naming
  resource_group = var.resource_group_name
  tags           = var.tags

  config = {
    name     = "${module.naming.automation_account.name}-${var.name_suffix}"
    location = var.location

    modules = {
      # https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication/2.25.0
      "Microsoft.Graph.Authentication" = {
        uri  = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication/2.25.0"
        type = "powershell72"
      }
      # https://www.powershellgallery.com/packages/Microsoft.Graph.Applications/2.25.0
      "Microsoft.Graph.Applications" = {
        uri  = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Applications/2.25.0"
        type = "powershell72"
      }
      # https://www.powershellgallery.com/packages/Microsoft.Graph.Users.Actions/2.25.0
      "Microsoft.Graph.Users.Actions" = {
        uri  = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Users.Actions/2.25.0"
        type = "powershell72"
      }
    }

    identity = {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.default.id]
    }
  }
}

resource "azurerm_automation_variable_string" "default" {
  name                    = local.uai_client_id_var_name
  automation_account_name = module.automation_account.config.name
  resource_group_name     = var.resource_group_name
  value                   = azurerm_user_assigned_identity.default.client_id
  encrypted               = false
}

resource "azurerm_user_assigned_identity" "default" {
  name                = "${module.naming.user_assigned_identity.name}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azuread_app_role_assignment" "app_role_assignment" {
  for_each = toset(var.automation_account_permissions)

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  principal_object_id = azurerm_user_assigned_identity.default.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azurerm_role_assignment" "default" {
  for_each = merge([
    for role in var.keyvault_rbac_roles : {
      for kv in var.keyvaults : replace("${role}-${kv.name}", " ", "") => {
        scope = kv.id
        role  = role
      }
  }]...)

  principal_id         = azurerm_user_assigned_identity.default.principal_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}
