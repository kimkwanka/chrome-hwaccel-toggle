# Registers the native messaging host for the current user (HKCU only, no admin).
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'tools\keylib.ps1')

$info = Get-ExtensionKeyInfo -KeyPath (Join-Path $root 'extension.key.xml')
Update-ManifestKey -ManifestPath (Join-Path $root 'extension\manifest.json') -Base64 $info.Base64

$hostName = 'com.local.hwaccel_toggle'
$manifestPath = Join-Path $root "host\$hostName.json"
$manifest = [ordered]@{
	name            = $hostName
	description     = 'Toggles Chrome hardware acceleration via Local State'
	path            = (Join-Path $root 'host\hwaccel_host.bat')
	type            = 'stdio'
	allowed_origins = @("chrome-extension://$($info.Id)/")
}
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

$regKey = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$hostName"
New-Item -Path $regKey -Force | Out-Null
Set-ItemProperty -Path $regKey -Name '(default)' -Value $manifestPath

Write-Host "Extension ID: $($info.Id)"
Write-Host "Host manifest: $manifestPath"
Write-Host "Registry:      $regKey"
Write-Host ''
Write-Host 'Next: open chrome://extensions, enable Developer mode, click "Load unpacked",'
Write-Host "and select: $(Join-Path $root 'extension')"
Write-Host 'Then confirm the extension ID shown there matches the one above.'
