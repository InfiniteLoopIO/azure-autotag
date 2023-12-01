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

# various details about the deployed autotag resources
output "autotag_deployment_details" {
  value = {
    tenant_id               = data.azurerm_subscription.autotag_target.tenant_id
    subscription_id         = data.azurerm_subscription.autotag_target.subscription_id
    subscription_name       = data.azurerm_subscription.autotag_target.display_name
    
    resource_group_name     = azurerm_resource_group.autotag.name
    resource_group_location = azurerm_resource_group.autotag.location
    resource_group_id       = azurerm_resource_group.autotag.id
    
    function_app_id         = azurerm_windows_function_app.autotag.id
    function_app_name       = azurerm_windows_function_app.autotag.name
    
    storage_account_name    = azurerm_storage_account.autotag.name
    storage_account_id      = azurerm_storage_account.autotag.id
    
    app_insights_id         = azurerm_application_insights.autotag.id
    app_insights_name       = azurerm_application_insights.autotag.name
  }
}
