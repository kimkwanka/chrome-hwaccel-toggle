# Waits for the browser to exit, edits Local State, relaunches the browser. Started detached by the host.
# -Enable takes 'true' or 'false' (a string, because it arrives via -File). -Browser: chrome (default) or brave.
param(
	[Parameter(Mandatory)][string]$Enable,
	[string]$Browser = 'chrome',
	[string]$LocalStatePath,
	[switch]$DryRun,       # edit the file but don't wait for / kill / relaunch the browser
	[int]$WaitSeconds = 20,
	[int]$GracefulSeconds = 10
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hwaccel_lib.ps1')

function Wait-BrowserExit {
	param([string]$ProcessName, [int]$Seconds)
	$deadline = (Get-Date).AddSeconds($Seconds)
	while ((Get-Date) -lt $deadline) {
		if (-not (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)) { return $true }
		Start-Sleep -Milliseconds 300
	}
	-not (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

try {
	$cfg = Get-BrowserConfig $Browser
	$target = [Convert]::ToBoolean($Enable)
	if (-not $LocalStatePath) { $LocalStatePath = $cfg.LocalState }
	Write-Log "apply start: browser=$($cfg.Name) enable=$target path=$LocalStatePath dryRun=$DryRun"

	if (-not $DryRun) {
		if (-not (Wait-BrowserExit $cfg.Process $WaitSeconds)) {
			Write-Log "$($cfg.Display) still running; trying graceful taskkill"
			& taskkill.exe /IM $cfg.ExeName 2>&1 | Out-Null
			if (-not (Wait-BrowserExit $cfg.Process $GracefulSeconds)) {
				Write-Log "$($cfg.Display) did not exit (background apps?). Aborting without editing."
				exit 1
			}
		}
	}

	Set-HwAccelInFile -Path $LocalStatePath -Enabled $target

	if (-not $DryRun) {
		$exe = Find-BrowserExe $cfg
		if ($exe) { Start-Process -FilePath $exe -ArgumentList '--restore-last-session'; Write-Log "relaunched $exe" }
		else { Write-Log "$($cfg.ExeName) not found; cannot relaunch" }
	}
}
catch {
	Write-Log "apply failed: $_"
	exit 1
}
