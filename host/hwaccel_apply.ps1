# Waits for Chrome to exit, edits Local State, relaunches Chrome. Started detached by the host.
# -Enable takes 'true' or 'false' (a string, because it arrives via -File).
param(
	[Parameter(Mandatory)][string]$Enable,
	[string]$LocalStatePath,
	[switch]$DryRun,       # edit the file but don't wait for / kill / relaunch Chrome
	[int]$WaitSeconds = 20,
	[int]$GracefulSeconds = 10
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hwaccel_lib.ps1')

function Wait-ChromeExit {
	param([int]$Seconds)
	$deadline = (Get-Date).AddSeconds($Seconds)
	while ((Get-Date) -lt $deadline) {
		if (-not (Get-Process -Name chrome -ErrorAction SilentlyContinue)) { return $true }
		Start-Sleep -Milliseconds 300
	}
	-not (Get-Process -Name chrome -ErrorAction SilentlyContinue)
}

try {
	$target = [Convert]::ToBoolean($Enable)
	if (-not $LocalStatePath) { $LocalStatePath = Get-LocalStatePath }
	Write-Log "apply start: enable=$target path=$LocalStatePath dryRun=$DryRun"

	if (-not $DryRun) {
		if (-not (Wait-ChromeExit $WaitSeconds)) {
			Write-Log 'Chrome still running; trying graceful taskkill'
			& taskkill.exe /IM chrome.exe 2>&1 | Out-Null
			if (-not (Wait-ChromeExit $GracefulSeconds)) {
				Write-Log 'Chrome did not exit (background apps?). Aborting without editing.'
				exit 1
			}
		}
	}

	Set-HwAccelInFile -Path $LocalStatePath -Enabled $target

	if (-not $DryRun) {
		$chrome = Find-ChromeExe
		if ($chrome) { Start-Process -FilePath $chrome -ArgumentList '--restore-last-session'; Write-Log "relaunched $chrome" }
		else { Write-Log 'chrome.exe not found; cannot relaunch' }
	}
}
catch {
	Write-Log "apply failed: $_"
	exit 1
}
