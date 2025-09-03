# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Generate a random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Create a storage account for shared folder replacement
resource "azurerm_storage_account" "main" {
  count                    = var.enable_azure_files ? 1 : 0
  name                     = "st${replace(var.app_name, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  min_tls_version = "TLS1_2"
  
  tags = var.tags
}

# Create a file share
resource "azurerm_storage_share" "main" {
  count                = var.enable_azure_files ? 1 : 0
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main[0].name
  quota                = 100
}

# Create Application Insights
resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "ai-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  
  tags = var.tags
}

# Create an App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = var.app_service_plan_sku
  
  tags = var.tags
}

# Create the App Service
resource "azurerm_windows_web_app" "main" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on                = var.app_service_plan_sku != "F1" && var.app_service_plan_sku != "D1"
    use_32_bit_worker        = false
    managed_pipeline_mode    = "Classic"
    default_document_list    = ["default.htm", "default.html", "default.asp", "index.html", "iisstart.htm"]
    http_logging_enabled     = true
    detailed_error_logging_enabled = true
    request_tracing_enabled  = true
    
    application_stack {
      dotnet_version = "v4.0"
    }
  }

  app_settings = merge(
    {
      "ISAPI_FILTER_ENABLED" = "true"
    },
    var.enable_application_insights ? {
      "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main[0].instrumentation_key
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main[0].connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
    } : {},
    var.enable_azure_files ? {
      "SHARED_FOLDER_CONNECTION" = azurerm_storage_account.main[0].primary_connection_string
      "SHARED_FOLDER_NAME" = var.file_share_name
    } : {}
  )

  tags = var.tags
}

# Outputs
output "app_service_name" {
  value = azurerm_windows_web_app.main.name
}

output "app_service_url" {
  value = "https://${azurerm_windows_web_app.main.default_hostname}"
}

output "storage_account_name" {
  value = var.enable_azure_files ? azurerm_storage_account.main[0].name : ""
}

output "storage_account_key" {
  value = var.enable_azure_files ? azurerm_storage_account.main[0].primary_access_key : ""
  sensitive = true
}

output "file_share_name" {
  value = var.enable_azure_files ? var.file_share_name : ""
}

output "application_insights_instrumentation_key" {
  value = var.enable_application_insights ? azurerm_application_insights.main[0].instrumentation_key : ""
  sensitive = true
}
