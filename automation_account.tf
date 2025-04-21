resource "azuread_app_role_assignment" "app_role_assignment" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
  principal_object_id = module.automation_account.config.identity[0].principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

module "automation_account" {
  source  = "cloudnationhq/aa/azure"
  version = "~> 2.6"

  config = {
    name           = module.naming.automation_account.name
    resource_group = var.resource_group_name
    location       = var.location

    modules = {
      # https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication/2.25.0
      "Microsoft.Graph.Authentication" = {
        uri  = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication/2.25.0"
        type = "powershell72"
      }
      # https://www.powershellgallery.com/packages/Microsoft.Graph.Applications/2.26.1
      "Microsoft.Graph.Applications" = {
        uri  = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Applications/2.25.0"
        type = "powershell72"
      }
    }
  }
}
