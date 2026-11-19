# Removes the native messaging host registration and the generated host manifest.
$hostName = 'com.local.hwaccel_toggle'
$regKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$hostName"
if (Test-Path $regKey) { Remove-Item -Path $regKey -Recurse -Force; Write-Host "Removed $regKey" }
$manifestPath = Join-Path $PSScriptRoot "host\$hostName.json"
if (Test-Path $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force; Write-Host "Removed $manifestPath" }
Write-Host 'Done. Remove the extension from chrome://extensions manually.'
