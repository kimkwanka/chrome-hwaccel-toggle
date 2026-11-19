# Removes the native messaging host registrations (Chrome and Brave) and the generated host manifests.
$hostName = 'com.local.hwaccel_toggle'
foreach ($reg in "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$hostName",
	"HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\$hostName") {
	if (Test-Path $reg) { Remove-Item -Path $reg -Recurse -Force; Write-Host "Removed $reg" }
}
foreach ($name in "$hostName.json", "$hostName.brave.json") {
	$p = Join-Path $PSScriptRoot "host\$name"
	if (Test-Path $p) { Remove-Item -LiteralPath $p -Force; Write-Host "Removed $p" }
}
Write-Host 'Done. Remove the extension from chrome://extensions or brave://extensions manually.'
