variable "automation_account_permissions" {
  type        = list(string)
  description = "Graph permissions for the automation account"
  default     = ["Application.ReadWrite.All", "Mail.Send"]
}

variable "automation_operators" {
  type = map(object({
    type      = string
    client_id = optional(string, null)
    object_id = optional(string, null)
  }))
  description = "map with operators for the runbook and automation account"
  default     = {}
}

variable "environment" {
  type        = string
  description = "environment"
}

variable "keyvaults" {
  type = list(object({
    name = string
    id   = string
  }))
  description = "list of keyvaults to add to the eventgrid subscription"
  default     = []
}

variable "keyvault_rbac_roles" {
  type        = list(string)
  description = "default required rbac roles to assign to the automation account"
  default     = ["Owner", "Key Vault Secrets Officer"]
}

variable "location" {
  type        = string
  description = "location code"
}

variable "location_code" {
  type        = string
  description = "location code"
}

variable "name_suffix" {
  type        = string
  description = "name suffix"
  default     = "asr-rb"
}

variable "resource_group_id" {
  type        = string
  description = "resource group id"
}

variable "resource_group_name" {
  type        = string
  description = "resource group name"
}

variable "tags" {
  type        = map(string)
  description = "tags"
  default     = {}
}

variable "webhook_expiration_end_year" {
  type        = number
  description = "webhook expiration in years"
  default     = 2027
}

variable "workload" {
  type        = string
  description = "workload"
}
