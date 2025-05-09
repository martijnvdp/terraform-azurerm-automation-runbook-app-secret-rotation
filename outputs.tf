output "webhook_endpoint" {
  description = "webhook url for the runbook to receive the keyvault grid events"
  value       = module.runbooks.webhook["az-aa-client-secret-rotation-event"].uri
  sensitive   = true
}

output "automation_account_name" {
  description = "automation account"
  value       = module.automation_account.config.name
}

output "user_assigned_identity" {
  description = "user assigned identity name"
  value       = azurerm_user_assigned_identity.default
}
