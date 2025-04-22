output "webhook_endpoint" {
  description = "webhook url for the runbook to receive the keyvault grid events"
  value       = module.runbooks.webhook["az-aa-client-secret-rotation-event"].uri
  sensitive   = true
}

output "automation_account_name" {
  description = "automation account"
  value       = local.automation_account_name
}
