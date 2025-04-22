module "eventgrid" {
  source  = "cloudnationhq/eg/azure"
  version = "~> 1.4"

  naming = local.naming

  config = {
    name           = "${module.naming.eventgrid_domain.name}-${var.name_suffix}"
    resource_group = var.resource_group_name
    location       = var.location

    event_subscriptions = {
      for kv in var.keyvaults : ("${kv.name}-${var.name_suffix}") => {
        scope                 = kv.id
        event_delivery_schema = "EventGridSchema"

        included_event_types = [
          "Microsoft.KeyVault.SecretExpired",
          "Microsoft.KeyVault.SecretNearExpiry",
          "Microsoft.KeyVault.SecretNewVersionCreated"
        ]

        webhook_endpoint = {
          url                               = module.runbooks.webhook["az-aa-client-secret-rotation-event"].uri
          max_events_per_batch              = 1
          preferred_batch_size_in_kilobytes = 64
        }
      }
    }
  }
}
