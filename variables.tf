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

# prefix for autotag resources, must be alphanumeric only to conform with storage account naming restrictions
variable autotag_resource_prefix         {type = string}

# azure subscription to monitor for write events
variable azure_subscription_id           {type = string}  

# resource group name
variable resource_group_name             {type = string}

# resource group location
variable resource_group_location         {type = string}

# storage account name needs to be globally unique, will be prefixed by autotag_resource_prefix
variable storage_account_name_suffix     {type = string}

# azure storage account tier
variable storage_tier                    {default = "Standard"}

# azure storage account replication type
variable storage_replication             {default = "LRS"}

# review terraform documentation if changing to Free tier, has quota size impacts
variable log_analytics_sku               {default = "PerGB2018"}

# default to consumption plan
variable app_service_plan_sku            {default = "Y1"}

# function app name needs to be globally unique, will be prefixed by autotag_resource_prefix
variable function_app_name_suffix        {type = string}

# function app version
variable function_app_version            {default = "~4"}

# function app powershell version
variable function_app_powershell_version {default = "7.2"}

# function app required powershell modules
variable function_app_powershell_modules {
  default = <<-EOT
            @{
                'Az.Accounts' = '2.*'
                'Az.Resources' = '6.*'
            }
            EOT
}

# app insights retention days
variable app_insights_retention_days     {default = 30}

# app insights max daily data cap in GB
variable app_insights_daily_data_cap_gb  {default = 5}

# app insights detection rules
variable app_insights_detection_rules    {
  default = {
    "Abnormal rise in daily data volume"  = false
    "Abnormal rise in exception volume"   = false
    "Degradation in dependency duration"  = false
    "Degradation in server response time" = false
    "Degradation in trace severity ratio" = false
    "Long dependency duration"            = false
    "Potential memory leak detected"      = false
    "Potential security issue detected"   = false
    "Slow page load time"                 = false
    "Slow server response time"           = false
  }
}

# app insights smart detection rules
variable app_insights_action_group_rules {
  default = {
    "DependencyPerformanceDegradationDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "P1D"
    }
    "ExceptionVolumeChangedDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "P1D"
    }
    "FailureAnomaliesDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "PT1M"
    }
    "MemoryLeakDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "P1D"
    }
    "RequestPerformanceDegradationDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "P1D"
    }
    "TraceSeverityDetector" = {
      enabled   = false
      severity  = "Sev3"
      frequency = "P1D"
    }
  }
}
