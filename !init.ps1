$statePrefix = "TF_VAR_state_"
$backendDest = "./backend.hcl"

write-host "`nDiscover $statePrefix env vars, add to $backendDest" -f Cyan
get-childItem env:\$statePrefix* | ForEach-Object {"$($_.name -replace $statePrefix) = `"$($_.Value)`""} | Set-Content -Path $backendDest -Force

write-host "`nAttempt terraform init" -f Cyan
terraform.exe init -reconfigure -backend-config="$backendDest"

write-host "`nLast exit code: $LASTEXITCODE"