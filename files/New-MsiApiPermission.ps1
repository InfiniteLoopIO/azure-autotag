<#
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
#>

#requires -modules Microsoft.Graph.Applications, Microsoft.Graph.Authentication

[cmdletbinding()]
param(
    [parameter(Mandatory)]
    [string]$msiPrincipalId
)

write-host "`n^^^^^^^^^^^^^^^^^^^^"
write-host "msiPrincipalId: $msiPrincipalId"
write-host "`n^^^^^^^^^^^^^^^^^^^^"

write-host "CurrentDir: $((get-location).path)"
write-host "ScriptDir: $scriptDir"

try{
    write-host "`nCreation session with`nARM_CLIENT_ID: $env:ARM_CLIENT_ID `nARM_SUBSCRIPTION_ID: $env:ARM_SUBSCRIPTION_ID `nARM_TENANT_ID: $env:ARM_TENANT_ID `n"
    
    # current session is expected to have the required environmental variables
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:ARM_CLIENT_ID, ($env:ARM_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force)
    Connect-MgGraph -ClientSecretCredential $creds -TenantId $env:ARM_TENANT_ID -NoWelcome -ErrorAction Stop
    
    write-host "`nGet MSI service principal object"
    $msiObj = Get-MgServicePrincipal -ServicePrincipalId $msiPrincipalId -ErrorAction Stop
    
    write-host "`nGet Microsoft Graph object"
    $msGraphObj = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
    
    write-host "`nGet directory.read.all object"
    $DirectoryReadAll = $msGraphObj.AppRoles | Where-Object {$_.value -eq 'directory.read.all'}
    
    $assignRole = $true
    
    # check current assignments
    $currentAssignments = @(Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $msiObj.id -ErrorAction Stop)
    if($currentAssignments.count -gt 0){
        if(($currentAssignments).appRoleId -contains $DirectoryReadAll.id){
            write-host "$($DirectoryReadAll.value) already assigned to MSI $($msiObj.DisplayName), no changes made"
            $assignRole = $false
        }
    }
    
    # assign role if needed
    if($assignRole) {
        write-host "Assign $($DirectoryReadAll.value) to MSI $($msiObj.DisplayName)"
        
        $params = @{
            principalId = $msiObj.Id
            resourceId  = $msGraphObj.Id
            appRoleId   = $DirectoryReadAll.Id
        }
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $msiObj.id -BodyParameter $params -ErrorAction Stop | Out-Null
        write-host "SUCCESS"
    }
    
    exit 0
}
catch{
    write-host "ERROR: $($_.exception.message)"
    exit 1
}
finally {
    Disconnect-MgGraph | Out-Null
}
