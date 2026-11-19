# One-off: generate simple extension icons (16/48/128) with System.Drawing.
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'extension\icons'
foreach ($s in 16, 48, 128) {
	$bmp = New-Object System.Drawing.Bitmap $s, $s
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'
	$g.Clear([System.Drawing.Color]::Transparent)
	$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 26, 115, 232))), 0, 0, $s - 1, $s - 1)
	$pw = [Math]::Max(2, $s / 8)
	$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), $pw
	$pen.StartCap = 'Round'; $pen.EndCap = 'Round'
	# power glyph: open circle + vertical bar
	$m = $s * 0.28; $d = $s - 2 * $m
	$g.DrawArc($pen, $m, $m + $s * 0.03, $d, $d, -60, 300)
	$g.DrawLine($pen, $s / 2, $s * 0.2, $s / 2, $s * 0.5)
	$g.Dispose()
	$bmp.Save((Join-Path $out "icon$s.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}
