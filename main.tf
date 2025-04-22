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

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

module "naming" {
  source  = "CloudNationHQ/naming/azure"
  version = "~> 0.23"
  suffix  = [var.environment, var.workload, var.location_code]
}
