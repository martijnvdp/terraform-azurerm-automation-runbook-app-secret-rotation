locals {

  naming = {
    # lookup outputs to have consistent naming
    for type in local.naming_types : type => module.naming[type].name
  }

  naming_types = [
    "automation_account",
    "automation_runbook",
    "automation_schedule",
    "automation_webhook",
    "eventgrid_domain",
    "eventgrid_event_subscription",
    "eventgrid_topic"
  ]
}

data "azuread_application_published_app_ids" "well_known" {
}

data "azurerm_key_vault" "default" {
  for_each = { for kv in var.keyvault_subscriptions : kv.name => kv }

  name                = each.key
  resource_group_name = each.value.resource_group_name
}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

module "naming" {
  source  = "CloudNationHQ/naming/azure"
  version = "~> 0.23"
  suffix  = [var.environment, var.workload, var.location_code]
}
