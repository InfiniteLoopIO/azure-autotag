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

#requires -modules Az.Websites

[cmdletbinding()]
param(
    [parameter(Mandatory)]
    [string]$appName,
    [parameter(Mandatory)]
    [string]$appResourceGroupName,
    [parameter(Mandatory)]
    [string]$fileToUpload
)

write-host "`n^^^^^^^^^^^^^^^^^^^^"
write-host "appName: $appName`nappResourceGroupName: $appResourceGroupName`nfileToUpload:$fileToUpload"
write-host "`n^^^^^^^^^^^^^^^^^^^^"

write-host "CurrentDir: $((get-location).path)"
write-host "ScriptDir: $scriptDir"

write-host "Get fileToUpload Details"
if(test-path $fileToUpload){
    write-host "file exists"
    $fileObj = Get-Item $fileToUpload
}
else{
    write-host "file not found"
    exit 1
}

write-host "`nCreation session with`nARM_CLIENT_ID: $env:ARM_CLIENT_ID `nARM_SUBSCRIPTION_ID: $env:ARM_SUBSCRIPTION_ID `nARM_TENANT_ID: $env:ARM_TENANT_ID `n"

# current session is expected to have the required environmental variables
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:ARM_CLIENT_ID, ($env:ARM_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force)
Connect-AzAccount -ServicePrincipal -TenantId $env:ARM_TENANT_ID -Subscription $env:ARM_SUBSCRIPTION_ID -Credential $creds -Scope Process | Out-Null

write-host "Get Publishing Profile for $appName"
$xmlProfiles = [xml](Get-AzWebAppPublishingProfile -Name $appName -ResourceGroupName $appResourceGroupName)
$ftpProfile  = $xmlProfiles.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]") 
$ftpUrl      = $ftpProfile.publishUrl
$ftpUser     = $ftpProfile.userName
$ftpPw       = $ftpProfile.userPWD

# https://learn.microsoft.com/en-us/azure/app-service/scripts/powershell-deploy-ftp

$uri = New-Object System.Uri(("$ftpUrl/$($fileObj.Name)") -replace '^ftps','ftp')

$request             = [System.Net.FtpWebRequest]([System.net.WebRequest]::Create($uri))
$request.Method      = [System.Net.WebRequestMethods+Ftp]::UploadFile
$request.Credentials = New-Object System.Net.NetworkCredential($ftpUser,$ftpPw)

# Enable SSL for FTPS. Should be $false if FTP.
$request.EnableSsl = $true;

# Write the file to the request object.
$fileBytes = [System.IO.File]::ReadAllBytes($fileObj.FullName)
$request.ContentLength = $fileBytes.Length
$requestStream = $request.GetRequestStream()


try{
    Write-Host "`nUploading $fileToUpload to $($uri.AbsoluteUri)"
    $requestStream.Write($fileBytes, 0, $fileBytes.Length)
}
catch{
    exit 1
}
finally{
    $requestStream.Dispose()
}

try{
    $response = [System.Net.FtpWebResponse]($request.GetResponse())
    Write-Host "Status: $($response.StatusDescription)"
}
catch{
    exit 1
}
finally{
    if ($null -ne $response) {
        $response.Close()
    }
}

Write-Host "`nRestarting $appName to pick up new settings"
Restart-AzFunctionApp -Name $appName -ResourceGroupName $appResourceGroupName -Force -Verbose

Disconnect-AzAccount | Out-Null