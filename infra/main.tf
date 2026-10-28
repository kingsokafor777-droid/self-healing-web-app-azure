terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "main" {
  name = var.app_resource_group_name
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "${var.name_prefix}-appi"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  worker_count        = var.instance_count
  tags                = var.tags
}

resource "azurerm_linux_web_app" "main" {
  name                                           = var.web_app_name
  location                                       = data.azurerm_resource_group.main.location
  resource_group_name                            = data.azurerm_resource_group.main.name
  service_plan_id                                = azurerm_service_plan.main.id
  https_only                                     = true
  public_network_access_enabled                  = true
  client_affinity_enabled                        = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string
    WEBSITE_HEALTHCHECK_MAXPINGFAILURES   = "3"
    SCM_DO_BUILD_DURING_DEPLOYMENT        = "true"
    ENABLE_FAILURE_SIMULATION             = var.enable_failure_simulation ? "true" : "false"
    SIMULATE_UNHEALTHY_INSTANCE_ID        = var.failure_target_instance_id
    PYTHONUNBUFFERED                      = "1"
  }

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    http2_enabled                     = true
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2
    app_command_line                  = "gunicorn --bind=0.0.0.0:8000 --workers=2 --access-logfile=- --error-logfile=- app:app"

    application_stack {
      python_version = "3.12"
    }

    auto_heal_setting {
      trigger {
        status_code {
          count             = 10
          interval          = "00:05:00"
          status_code_range = "500-599"
        }
      }
      action {
        action_type                    = "Recycle"
        minimum_process_execution_time = "00:05:00"
      }
    }
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  depends_on = [azurerm_application_insights.main]
}

resource "azurerm_monitor_action_group" "operations" {
  name                = "${var.name_prefix}-ops-ag"
  resource_group_name = data.azurerm_resource_group.main.name
  short_name          = "${var.name_prefix}-ops"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email == "" ? [] : [var.alert_email]
    content {
      name                    = "operations"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "${var.name_prefix}-http-5xx"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Sustained HTTP 5xx responses. App Service Health Check and Auto-Heal are the automated mitigations; investigate the incident in Application Insights."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.http_5xx_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}
