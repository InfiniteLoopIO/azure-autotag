/*
Copyright 2023 infiniteloop.io

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

terraform {
  
  required_version = ">=1.6.4"
  
  backend "azurerm" {
    # using ARM ARM_CLIENT_ID,ARM_CLIENT_SECRET,ARM_TENANT_ID,ARM_SUBSCRIPTION_ID to connect
    # using init script to config backend with env vars
  }
  
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=3.81.0"
    }
    
    azuread = {
      source = "hashicorp/azuread"
      version = ">=2.46.0"
    }
    
    local = {
      source = "hashicorp/local"
      version = ">=2.4.0"
    }
  }
  
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PROVIDER - AZURERM
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
provider "azurerm" {
  features {
    
    application_insights {
      disable_generated_rule = false
    }
    
    # Azure monitor will recreate a default action group and prevent terraform destroy from completing
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DATA - AZURE SUBSCRIPTION
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription
data "azurerm_subscription" "autotag_target" {
  subscription_id = var.azure_subscription_id
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE TAG CONTRIBUTOR ROLE ASSIGNMENT
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
# service account must have 'Microsoft.Authorization/roleAssignments/write' permission on the subsription or Owner + Constrained to assign Tag Contributor
resource "azurerm_role_assignment" "autotag_tag_contributor_azure_subscription_scope" {
  scope                = data.azurerm_subscription.autotag_target.id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_windows_function_app.autotag.identity[0].principal_id

  depends_on = [ azurerm_windows_function_app.autotag ]
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE RESOURCE GROUP
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "autotag" {
  name     = var.resource_group_name
  location = var.resource_group_location
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE STORAGE ACCOUNT
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "autotag" {
  name                     = "${var.autotag_resource_prefix}${var.storage_account_name_suffix}"
  resource_group_name      = azurerm_resource_group.autotag.name
  location                 = azurerm_resource_group.autotag.location
  account_tier             = var.storage_tier
  account_replication_type = var.storage_replication
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE LOG ANALYTICS WORKSPACE
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "autotag" {
  name                = "${var.autotag_resource_prefix}-workspace"
  resource_group_name = azurerm_resource_group.autotag.name
  location            = azurerm_resource_group.autotag.location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.app_insights_retention_days
  daily_quota_gb      = var.app_insights_daily_data_cap_gb
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE APPLICATION INSIGHTS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights
resource "azurerm_application_insights" "autotag" {
  name                 = "${var.autotag_resource_prefix}-app-insights"
  resource_group_name  = azurerm_resource_group.autotag.name
  location             = azurerm_resource_group.autotag.location
  application_type     = "web"
  retention_in_days    = var.app_insights_retention_days
  daily_data_cap_in_gb = var.app_insights_daily_data_cap_gb
  workspace_id         = azurerm_log_analytics_workspace.autotag.id
  
  depends_on = [ azurerm_monitor_action_group.autotag, azurerm_log_analytics_workspace.autotag ]
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE APPLICATION INSIGHTS SMART DETECTION RULES
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights_smart_detection_rule
resource "azurerm_application_insights_smart_detection_rule" "autotag" {
  for_each                = var.app_insights_detection_rules
  name                    = each.key
  application_insights_id = azurerm_application_insights.autotag.id
  enabled                 = each.value
  
  depends_on = [ azurerm_application_insights.autotag ]
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE MONITOR ACTION GROUP
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group
resource "azurerm_monitor_action_group" "autotag" {
  name                = "${var.autotag_resource_prefix}-action-group"
  resource_group_name = azurerm_resource_group.autotag.name
  short_name          = "autotag" # 1-12 chars
  
  arm_role_receiver {
    name                    = "Monitoring Reader"
    role_id                 = "43d0d8ad-25c7-4714-9337-8ba259a9fe05"
    use_common_alert_schema = true
  }

  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE MONITOR ACTION GROUP SMART DECTOR RULES
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_smart_detector_alert_rule
resource "azurerm_monitor_smart_detector_alert_rule" "autotag" {
  for_each            = var.app_insights_action_group_rules
  
  resource_group_name = azurerm_resource_group.autotag.name

  name                = "${azurerm_application_insights.autotag.name}-smart-alert-${each.key}"
  detector_type       = each.key
  enabled             = each.value.enabled
  severity            = each.value.severity
  scope_resource_ids  = [azurerm_application_insights.autotag.id]
  frequency           = each.value.frequency
  
  action_group {
    ids = [azurerm_monitor_action_group.autotag.id]
  }
  
  depends_on = [ azurerm_monitor_action_group.autotag, azurerm_application_insights.autotag ]
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE APP SERVICE PLAN
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# SKU Y1 = consumption based pricing
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
resource "azurerm_service_plan" "autotag" {
  name                = "${var.autotag_resource_prefix}-app-service-plan"
  resource_group_name = azurerm_resource_group.autotag.name
  location            = azurerm_resource_group.autotag.location
  os_type             = "Windows"
  sku_name            = var.app_service_plan_sku
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE WINDOWS FUNCTION APP
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_function_app
resource "azurerm_windows_function_app" "autotag" {
  name                = "${var.autotag_resource_prefix}-${var.function_app_name_suffix}"
  resource_group_name = azurerm_resource_group.autotag.name
  location            = azurerm_resource_group.autotag.location
  
  storage_account_name       = azurerm_storage_account.autotag.name
  storage_account_access_key = azurerm_storage_account.autotag.primary_access_key
  service_plan_id            = azurerm_service_plan.autotag.id
  
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }
  
  functions_extension_version = var.function_app_version
  
  # IMPORTANT: must be TRUE or events cannot be delivered to function using this module as is
  public_network_access_enabled = true
  
  https_only = true
  
  site_config {
    ftps_state = "FtpsOnly"
    
    application_insights_connection_string = azurerm_application_insights.autotag.connection_string
    
    application_stack {
      powershell_core_version = var.function_app_powershell_version
    }
  }
  
  depends_on = [ azurerm_application_insights.autotag ]
  
  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"],
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
  
  # run script to gran directory.read.all to MSI
  provisioner "local-exec" {
      command     = ".'./files/New-MsiApiPermission.ps1' -msiPrincipalId \"${self.identity[0].principal_id}\" "
      interpreter = ["pwsh", "-Command"]
      environment = {
        # If passed on command line, secrets from Azure Key or AWS Secrets manager, or variables marked as sensitive, will trigger all script output to be
        # (local-exec): (output suppressed due to sensitive value in config)
        #SAMPLESENSITIVE = nonsensitive(var.sensitive_pw)
      }
      on_failure  = fail
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE FUNCTION APP FUNCTION
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/function_app_function
resource "azurerm_function_app_function" "autotag" {
  name            = "${var.autotag_resource_prefix}-function"
  function_app_id = azurerm_windows_function_app.autotag.id
  language        = "PowerShell"
  
  file {
    name    = "Get-AutoTagDetails.ps1"
    content = templatefile("./files/Get-AutoTagDetails.tftpl", {functionAppName = azurerm_windows_function_app.autotag.name})
  }
  
  config_json = jsonencode({
    "bindings" = [
      {
        "direction" = "in"
        "name"      = "eventGridEvent"
        "type"      = "eventGridTrigger"
      }
    ]
  })
  
  depends_on = [ azurerm_windows_function_app.autotag ]
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE FUNCTION POWERSHELL MODULE REQUIREMENTS
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "autotag_powershell_module_requirements" {
  content  = templatefile("./files/requirements.tftpl", {requiredModules = var.function_app_powershell_modules})
  filename = "./files/requirements.psd1"
  
  provisioner "local-exec" {
      command     = ".'./files/New-FtpUpload.ps1' -appName \"${azurerm_windows_function_app.autotag.name}\" -appResourceGroupName \"${var.resource_group_name}\" -fileToUpload \"${self.filename}\" "
      interpreter = ["pwsh", "-Command"]
      environment = {
        # If passed on command line, secrets from Azure Key or AWS Secrets manager, or variables marked as sensitive, will trigger all script output to be
        # (local-exec): (output suppressed due to sensitive value in config)
        #SAMPLESENSITIVE = nonsensitive(var.sensitive_pw)
      }
      on_failure  = fail
  }
  
  depends_on = [ azurerm_windows_function_app.autotag ]
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE EVENT GRID SYSTEM TOPIC
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventgrid_system_topic
resource "azurerm_eventgrid_system_topic" "autotag_azure_subscription_scope" {
  name                   = "${var.autotag_resource_prefix}-system-topic-azure-subscription-scope"
  resource_group_name    = azurerm_resource_group.autotag.name
  location               = "Global"
  source_arm_resource_id = "/subscriptions/${var.azure_subscription_id}" 
  topic_type             = "Microsoft.Resources.Subscriptions"
  
  depends_on = [ azurerm_storage_account.autotag ]
  
  lifecycle {
    ignore_changes = [
      tags["autotag-createdBy"],
      tags["autotag-createdDate"]
    ]
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RESOURCE - AZURE EVENT GRID SYSTEM TOPIC SUBSCRIPTION
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventgrid_system_topic_event_subscription
resource "azurerm_eventgrid_system_topic_event_subscription" "autotag" {
  name                                 = "${var.autotag_resource_prefix}-event-subscription"
  resource_group_name                  = azurerm_resource_group.autotag.name
  system_topic                         = azurerm_eventgrid_system_topic.autotag_azure_subscription_scope.name
  advanced_filtering_on_arrays_enabled = true
  event_delivery_schema                = "EventGridSchema"
  included_event_types                 = ["Microsoft.Resources.ResourceWriteSuccess"]
  
  azure_function_endpoint {
    function_id                       = azurerm_function_app_function.autotag.id
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
  
  retry_policy {
    event_time_to_live    = 1440
    max_delivery_attempts = 30
  }
  
  depends_on = [ azurerm_eventgrid_system_topic.autotag_azure_subscription_scope ]
}
