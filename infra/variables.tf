variable "subscription_id" {
  description = "Azure subscription ID targeted by the provider. Set through ARM_SUBSCRIPTION_ID or terraform.tfvars."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid GUID."
  }
}

variable "app_resource_group_name" {
  description = "Name of the pre-existing application resource group; all Terraform-managed Azure resources are scoped to this group."
  type        = string

  validation {
    condition     = length(trimspace(var.app_resource_group_name)) > 0 && length(var.app_resource_group_name) <= 90
    error_message = "app_resource_group_name must contain 1-90 non-whitespace characters."
  }
}

variable "name_prefix" {
  description = "Short lowercase prefix used for Azure resource names."
  type        = string
  default     = "healweb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,7}$", var.name_prefix))
    error_message = "name_prefix must be 3-8 lowercase letters or digits and start with a letter."
  }
}

variable "web_app_name" {
  description = "Globally unique Azure Web App name (the public hostname is <name>.azurewebsites.net)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,58}[a-zA-Z0-9]$", var.web_app_name))
    error_message = "web_app_name must be 2-60 characters, start and end with a letter or digit, and contain only letters, digits, or hyphens."
  }
}

variable "app_service_sku" {
  description = "Linux App Service plan SKU. Use a supported paid tier with two workers for load-balanced health recovery."
  type        = string
  default     = "P1v3"
}

variable "instance_count" {
  description = "Fixed number of App Service plan workers for the demo."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 2 && var.instance_count <= 10 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be an integer from 2 through 10 so health-check traffic removal can leave a healthy worker."
  }
}

variable "log_retention_days" {
  description = "Application Insights and Log Analytics retention period."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days must be an integer from 30 through 730."
  }
}

variable "alert_email" {
  description = "Optional email receiver for the HTTP 5xx alert. Leave empty to keep the alert action group without an email receiver."
  type        = string
  default     = ""
}

variable "http_5xx_threshold" {
  description = "Number of HTTP 5xx responses within the alert window that triggers notification."
  type        = number
  default     = 5

  validation {
    condition     = var.http_5xx_threshold > 0
    error_message = "http_5xx_threshold must be greater than zero."
  }
}

variable "enable_failure_simulation" {
  description = "Expose demo-only instance diagnostics and targeted fault injection routes. Never enable in production."
  type        = bool
  default     = false
}

variable "failure_target_instance_id" {
  description = "App Service instance ID that reports unhealthy during the isolated demo. Leave empty by default."
  type        = string
  default     = ""

  validation {
    condition     = var.failure_target_instance_id == "" || var.enable_failure_simulation
    error_message = "Set enable_failure_simulation=true before selecting a failure target instance."
  }
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    project     = "self-healing-web-app"
    environment = "portfolio"
    managed_by  = "terraform"
  }
}
