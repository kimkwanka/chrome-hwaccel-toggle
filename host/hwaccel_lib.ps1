# Shared helpers for the host and apply scripts. Dot-source this file. Never writes to stdout.

$script:LogDir = Join-Path $env:LOCALAPPDATA 'hwaccel_toggle'

function Write-Log {
	param([string]$Message)
	try {
		if (-not (Test-Path -LiteralPath $script:LogDir)) { New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null }
		Add-Content -LiteralPath (Join-Path $script:LogDir 'log.txt') -Value ("{0} {1}" -f (Get-Date -Format 's'), $Message) -Encoding UTF8
	}
	catch { }
}

# Per-browser settings. $Name: 'chrome' (default) or 'brave'.
function Get-BrowserConfig {
	param([string]$Name)
	if (-not $Name) { $Name = 'chrome' }
	switch ($Name.ToLower()) {
		'chrome' { $vendor = 'Google\Chrome'; $proc = 'chrome'; $display = 'Chrome' }
		'brave' { $vendor = 'BraveSoftware\Brave-Browser'; $proc = 'brave'; $display = 'Brave' }
		default { throw "Unknown browser '$Name' (expected chrome or brave)" }
	}
	@{
		Name         = $Name.ToLower()
		Display      = $display
		Process      = $proc
		ExeName      = "$proc.exe"
		LocalState   = Join-Path $env:LOCALAPPDATA "$vendor\User Data\Local State"
		AppDir       = "$vendor\Application"
	}
}

function Get-LocalStatePath {
	param($Config = (Get-BrowserConfig $env:HWACCEL_BROWSER))
	if ($env:HWACCEL_LOCAL_STATE) { return $env:HWACCEL_LOCAL_STATE }
	$Config.LocalState
}
$script:ModeRx = '"hardware_acceleration_mode"\s*:\s*\{\s*"enabled"\s*:\s*(true|false)\s*\}'
$script:PrevRx = '"hardware_acceleration_mode_previous"\s*:\s*(true|false)'

# Reads the saved setting from Local State text. Key absent = enabled (Chrome default).
function Get-HwAccelEnabledFromText {
	param([string]$Text)
	$m = [regex]::Match($Text, $script:ModeRx)
	if ($m.Success) { return ($m.Groups[1].Value -eq 'true') }
	$true
}

# Targeted text edit (no JSON round-trip). Returns the new text.
function Set-HwAccelInText {
	param([string]$Text, [bool]$Enabled)
	$v = if ($Enabled) { 'true' } else { 'false' }
	$modeJson = '"hardware_acceleration_mode":{"enabled":' + $v + '}'
	$prevJson = '"hardware_acceleration_mode_previous":' + $v
	$missing = @()

	if ([regex]::IsMatch($Text, $script:ModeRx)) { $Text = [regex]::Replace($Text, $script:ModeRx, $modeJson) }
	else { $missing += $modeJson }
	if ([regex]::IsMatch($Text, $script:PrevRx)) { $Text = [regex]::Replace($Text, $script:PrevRx, $prevJson) }
	else { $missing += $prevJson }

	if ($missing.Count -gt 0) {
		$open = [regex]::Match($Text, '^\s*\{')
		if (-not $open.Success) { throw 'Local State does not start with {' }
		$rest = $Text.Substring($open.Length)
		$comma = if ($rest -match '^\s*\}') { '' } else { ',' }
		$Text = $Text.Substring(0, $open.Length) + ($missing -join ',') + $comma + $rest
	}
	$Text
}

# Backs up, edits, validates and writes the file; restores the backup on any failure.
function Set-HwAccelInFile {
	param([string]$Path, [bool]$Enabled)
	$bak = "$Path.hwaccel.bak"
	Copy-Item -LiteralPath $Path -Destination $bak -Force
	try {
		$text = [IO.File]::ReadAllText($Path)
		if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
		$new = Set-HwAccelInText -Text $text -Enabled $Enabled
		$null = $new | ConvertFrom-Json -ErrorAction Stop
		[IO.File]::WriteAllText($Path, $new, (New-Object Text.UTF8Encoding($false)))
		Write-Log "Local State updated: enabled=$Enabled"
	}
	catch {
		Write-Log "Edit failed, restoring backup: $_"
		Copy-Item -LiteralPath $bak -Destination $Path -Force
		throw
	}
}

function Find-BrowserExe {
	param($Config)
	foreach ($hive in 'HKCU', 'HKLM') {
		$p = (Get-ItemProperty -Path "${hive}:\Software\Microsoft\Windows\CurrentVersion\App Paths\$($Config.ExeName)" -ErrorAction SilentlyContinue).'(default)'
		if ($p -and (Test-Path -LiteralPath $p)) { return $p }
	}
	foreach ($base in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) {
		if (-not $base) { continue }
		$c = Join-Path $base (Join-Path $Config.AppDir $Config.ExeName)
		if (Test-Path -LiteralPath $c) { return $c }
	}
	$null
}
# Walks the parent-process chain from $StartPid (host -> cmd -> browser) and returns 'brave'/'chrome'
# for the first ancestor named brave.exe/chrome.exe, else $null. The registry key can't identify the
# caller because Brave may read Chrome's NativeMessagingHosts key.
function Get-CallingBrowser {
	param([int]$StartPid = $PID, [int]$MaxLevels = 6)
	$byId = @{}
	Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name | ForEach-Object { $byId[[int]$_.ProcessId] = $_ }
	$cur = $byId[$StartPid]
	for ($i = 0; $i -lt $MaxLevels -and $cur; $i++) {
		$cur = $byId[[int]$cur.ParentProcessId]
		if ($cur -and $cur.Name -ieq 'brave.exe') { return 'brave' }
		if ($cur -and $cur.Name -ieq 'chrome.exe') { return 'chrome' }
	}
	$null
}

# Ancestry first, then HWACCEL_BROWSER, then chrome. Returns @{ Config; Source }.
function Resolve-Browser {
	$name = Get-CallingBrowser
	if ($name) { $source = 'parent process' }
	elseif ($env:HWACCEL_BROWSER) { $name = $env:HWACCEL_BROWSER; $source = 'HWACCEL_BROWSER' }
	else { $name = 'chrome'; $source = 'default' }
	@{ Config = (Get-BrowserConfig $name); Source = $source }
}
