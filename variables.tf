variable "environment" {
  type        = string
  description = "environment"
}

variable "keyvault_subscriptions" {
  type = list(object({
    name                = string
    resource_group_name = string
  }))
  description = "list of keyvaults to add to the eventgrid subscription"
  default     = []
}

variable "location" {
  type        = string
  description = "location code"
}

variable "location_code" {
  type        = string
  description = "location code"
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
  description = "webhook expiration year"
  default     = 2027
}

variable "workload" {
  type        = string
  description = "workload"
}
