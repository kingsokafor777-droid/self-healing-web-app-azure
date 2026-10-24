output "resource_group_name" {
  description = "Resource group containing the application and monitoring resources."
  value       = azurerm_resource_group.main.name
}

output "web_app_name" {
  description = "Azure Linux Web App resource name."
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "HTTPS endpoint for the deployed application."
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "application_insights_name" {
  description = "Application Insights component for telemetry queries."
  value       = azurerm_application_insights.main.name
}

output "system_assigned_identity_principal_id" {
  description = "System-assigned managed identity principal ID; no app permissions are granted by default."
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}
