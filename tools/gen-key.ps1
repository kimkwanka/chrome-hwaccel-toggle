# One-off: create the extension key (if missing), write it into manifest.json, print the extension ID.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'keylib.ps1')
$info = Get-ExtensionKeyInfo -KeyPath (Join-Path $root 'extension.key.xml')
Update-ManifestKey -ManifestPath (Join-Path $root 'extension\manifest.json') -Base64 $info.Base64
Write-Host "Extension ID: $($info.Id)"
