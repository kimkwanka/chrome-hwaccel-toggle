# One-off: generate extension icons with System.Drawing.
# icon<N>.png = acceleration ON (blue power glyph); icon<N>-off.png = OFF (grey, with a diagonal slash).
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'extension\icons'

function New-Icon {
	param([int]$s, [bool]$on)
	$bmp = New-Object System.Drawing.Bitmap $s, $s
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'
	$g.Clear([System.Drawing.Color]::Transparent)
	$fill = if ($on) { [System.Drawing.Color]::FromArgb(255, 26, 115, 232) } else { [System.Drawing.Color]::FromArgb(255, 128, 128, 128) }
	$g.FillEllipse((New-Object System.Drawing.SolidBrush $fill), 0, 0, $s - 1, $s - 1)
	$pw = [Math]::Max(2, $s / 8)
	$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), $pw
	$pen.StartCap = 'Round'; $pen.EndCap = 'Round'
	# power glyph: open circle + vertical bar
	$m = $s * 0.28; $d = $s - 2 * $m
	$g.DrawArc($pen, $m, $m + $s * 0.03, $d, $d, -60, 300)
	$g.DrawLine($pen, $s / 2, $s * 0.2, $s / 2, $s * 0.5)
	if (-not $on) {
		# dark slash with a white halo so it reads on light and dark toolbars
		$a = $s * 0.14; $b = $s - 1 - $a
		$halo = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ($pw * 2)
		$halo.StartCap = 'Round'; $halo.EndCap = 'Round'
		$slash = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 40, 40, 40)), $pw
		$slash.StartCap = 'Round'; $slash.EndCap = 'Round'
		$g.DrawLine($halo, $a, $a, $b, $b)
		$g.DrawLine($slash, $a, $a, $b, $b)
	}
	$g.Dispose()
	$bmp
}

foreach ($s in 16, 32, 48, 128) {
	foreach ($on in $true, $false) {
		$name = if ($on) { "icon$s.png" } else { "icon$s-off.png" }
		$bmp = New-Icon $s $on
		$bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
		$bmp.Dispose()
	}
}
