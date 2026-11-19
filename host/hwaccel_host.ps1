# Chrome/Brave native messaging host: one message in, one reply out (4-byte LE length + UTF-8 JSON).
# stdout carries only the framed reply. Env overrides for testing:
#   HWACCEL_BROWSER      chrome or brave; fallback when the parent process is not a browser
#   HWACCEL_LOCAL_STATE  path to a sample Local State
#   HWACCEL_DRYRUN=1     set/toggle reply ok but do not spawn the apply script
#   HWACCEL_DRYRUN=apply spawn apply with -DryRun (edits the sample only; no Chrome wait/kill/launch)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hwaccel_lib.ps1')

function Read-Exact {
	param([IO.Stream]$Stream, [int]$Count)
	$buf = New-Object byte[] $Count
	$off = 0
	while ($off -lt $Count) {
		$n = $Stream.Read($buf, $off, $Count - $off)
		if ($n -le 0) { throw 'stdin closed early' }
		$off += $n
	}
	, $buf
}

function Write-Message {
	param([IO.Stream]$Stream, $Object)
	$bytes = [Text.Encoding]::UTF8.GetBytes(($Object | ConvertTo-Json -Compress))
	$Stream.Write([BitConverter]::GetBytes([int]$bytes.Length), 0, 4)
	$Stream.Write($bytes, 0, $bytes.Length)
	$Stream.Flush()
}

# Fully detached: created via WMI so it is not a child of the host (survives host/Chrome exit and job objects).
function Start-Apply {
	param([bool]$Enable, [string]$LocalStatePath, [string]$Browser)
	$ps = Join-Path $PSHOME 'powershell.exe'
	$apply = Join-Path $PSScriptRoot 'hwaccel_apply.ps1'
	$cmd = '"{0}" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}" -Enable {2} -Browser {3}' -f $ps, $apply, $Enable.ToString().ToLower(), $Browser
	if ($env:HWACCEL_LOCAL_STATE) { $cmd += ' -LocalStatePath "{0}"' -f $LocalStatePath }
	if ($env:HWACCEL_DRYRUN -eq 'apply') { $cmd += ' -DryRun' }
	try {
		$si = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
		$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; ProcessStartupInformation = $si }
		if ($r.ReturnValue -ne 0) { throw "Win32_Process.Create returned $($r.ReturnValue)" }
	}
	catch {
		Write-Log "WMI spawn failed ($_); falling back to Start-Process"
		Start-Process -FilePath $ps -WindowStyle Hidden -ArgumentList ($cmd.Substring($ps.Length + 2))
	}
}

$stdin = [Console]::OpenStandardInput()
$stdout = [Console]::OpenStandardOutput()
try {
	$len = [BitConverter]::ToInt32((Read-Exact $stdin 4), 0)
	if ($len -le 0 -or $len -gt 1MB) { throw "bad message length $len" }
	$msg = [Text.Encoding]::UTF8.GetString((Read-Exact $stdin $len)) | ConvertFrom-Json
	Write-Log "request: $($msg.cmd)"

	$resolved = Resolve-Browser
	$cfg = $resolved.Config
	Write-Log "browser=$($cfg.Name) (from $($resolved.Source))"
	$path = Get-LocalStatePath $cfg
	$current = if (Test-Path -LiteralPath $path) { Get-HwAccelEnabledFromText ([IO.File]::ReadAllText($path)) } else { $true }

	switch ($msg.cmd) {
		'get' { $reply = @{ ok = $true; enabled = $current; browser = $cfg.Name } }
		{ $_ -in 'set', 'toggle' } {
			if ($_ -eq 'set') {
				if ($msg.enabled -isnot [bool]) { throw "'enabled' must be a boolean" }
				$target = [bool]$msg.enabled
			}
			else { $target = -not $current }
			if (-not (Test-Path -LiteralPath $path)) { throw "Local State not found for $($cfg.Display): $path" }
			if ($env:HWACCEL_DRYRUN -ne '1') { Start-Apply -Enable $target -LocalStatePath $path -Browser $cfg.Name }
			$reply = @{ ok = $true; target = $target }
		}
		default { throw "unknown cmd '$($msg.cmd)'" }
	}
}
catch {
	Write-Log "host error: $_"
	$reply = @{ ok = $false; error = "$_" }
}
Write-Message $stdout $reply
