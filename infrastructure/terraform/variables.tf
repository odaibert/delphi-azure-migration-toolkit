variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-isapi-migration"
}

variable "location" {
  description = "The Azure region to deploy resources"
  type        = string
  default     = "East US"
}

variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "delphi-isapi-app"
}

variable "app_service_plan_sku" {
  description = "The SKU of the App Service Plan"
  type        = string
  default     = "S1"
  
  validation {
    condition = contains([
      "F1", "D1", "B1", "B2", "B3", 
      "S1", "S2", "S3", 
      "P1", "P2", "P3", 
      "P1v2", "P2v2", "P3v2"
    ], var.app_service_plan_sku)
    error_message = "The app_service_plan_sku must be a valid App Service Plan SKU."
  }
}

variable "enable_application_insights" {
  description = "Enable Application Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_azure_files" {
  description = "Enable Azure Files for shared folder replacement"
  type        = bool
  default     = true
}

variable "file_share_name" {
  description = "The name of the Azure File Share"
  type        = string
  default     = "isapi-shared-folder"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "ISAPI Migration"
    ManagedBy   = "Terraform"
  }
}
