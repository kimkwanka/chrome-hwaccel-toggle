# Registers the native messaging host for Chrome and Brave for the current user (HKCU only, no admin).
# -SkipRegistry: only generate the manifests (for testing).
param([switch]$SkipRegistry)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'tools\keylib.ps1')

$info = Get-ExtensionKeyInfo -KeyPath (Join-Path $root 'extension.key.xml')
Update-ManifestKey -ManifestPath (Join-Path $root 'extension\manifest.json') -Base64 $info.Base64

$hostName = 'com.local.hwaccel_toggle'
# Same host name and extension ID for both browsers; only the launcher and registry key differ.
$targets = @(
	@{ Label = 'Chrome'; Manifest = "$hostName.json"; Bat = 'hwaccel_host.bat'; Reg = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$hostName" },
	@{ Label = 'Brave'; Manifest = "$hostName.brave.json"; Bat = 'hwaccel_host_brave.bat'; Reg = "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\$hostName" }
)
foreach ($t in $targets) {
	$manifestPath = Join-Path $root "host\$($t.Manifest)"
	$manifest = [ordered]@{
		name            = $hostName
		description     = 'Toggles browser hardware acceleration via Local State'
		path            = (Join-Path $root "host\$($t.Bat)")
		type            = 'stdio'
		allowed_origins = @("chrome-extension://$($info.Id)/")
	}
	[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
	if (-not $SkipRegistry) {
		New-Item -Path $t.Reg -Force | Out-Null
		Set-ItemProperty -Path $t.Reg -Name '(default)' -Value $manifestPath
	}
	Write-Host "$($t.Label): $manifestPath"
	if (-not $SkipRegistry) { Write-Host "       registry: $($t.Reg)" }
}

Write-Host ''
Write-Host "Extension ID: $($info.Id)"
Write-Host ''
Write-Host 'Next: open chrome://extensions (or brave://extensions), enable Developer mode, click "Load unpacked",'
Write-Host "and select: $(Join-Path $root 'extension')"
Write-Host 'Then confirm the extension ID shown there matches the one above.'
