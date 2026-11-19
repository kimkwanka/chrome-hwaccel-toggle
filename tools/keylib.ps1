# Helpers for the stable extension key / ID. Dot-source this file.
# PS 5.1 / .NET Framework has no ExportSubjectPublicKeyInfo, so the SPKI DER is built by hand.

function Join-Bytes {
	param([byte[][]]$Parts)
	$ms = New-Object System.IO.MemoryStream
	foreach ($p in $Parts) { $ms.Write($p, 0, $p.Length) }
	, $ms.ToArray()
}

function New-DerElement {
	param([byte]$Tag, [byte[]]$Content)
	$n = $Content.Length
	if ($n -lt 128) { $len = [byte[]]@($n) }
	elseif ($n -lt 256) { $len = [byte[]]@(0x81, $n) }
	else { $len = [byte[]]@(0x82, [byte]($n -shr 8), [byte]($n -band 0xFF)) }
	Join-Bytes @([byte[]]@($Tag), $len, $Content)
}

function New-DerInteger {
	param([byte[]]$BigEndian)
	$i = 0
	while ($i -lt $BigEndian.Length - 1 -and $BigEndian[$i] -eq 0) { $i++ }
	$v = $BigEndian[$i..($BigEndian.Length - 1)]
	if ($v[0] -ge 0x80) { $v = @([byte]0) + $v }
	New-DerElement 0x02 ([byte[]]$v)
}

function Get-SpkiDer {
	param([System.Security.Cryptography.RSAParameters]$Params)
	$rsaPub = New-DerElement 0x30 (Join-Bytes @((New-DerInteger $Params.Modulus), (New-DerInteger $Params.Exponent)))
	# AlgorithmIdentifier: rsaEncryption (1.2.840.113549.1.1.1), NULL
	$oid = [byte[]]@(0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01)
	$alg = New-DerElement 0x30 (Join-Bytes @($oid, [byte[]]@(0x05, 0x00)))
	$bits = New-DerElement 0x03 (Join-Bytes @([byte[]]@(0x00), $rsaPub))
	New-DerElement 0x30 (Join-Bytes @($alg, $bits))
}

function Get-ExtensionId {
	param([byte[]]$Der)
	$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($Der)
	$hex = (($hash[0..15] | ForEach-Object { $_.ToString('x2') }) -join '')
	-join ($hex.ToCharArray() | ForEach-Object { [char]([int][char]'a' + [Convert]::ToInt32([string]$_, 16)) })
}

# Loads the RSA key from $KeyPath (XML), creating it if missing.
# Returns @{ Der; Base64; Id }.
function Get-ExtensionKeyInfo {
	param([Parameter(Mandatory)][string]$KeyPath)
	$rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
	$rsa.PersistKeyInCsp = $false
	if (Test-Path -LiteralPath $KeyPath) {
		$rsa.FromXmlString([IO.File]::ReadAllText($KeyPath))
	}
	else {
		[IO.File]::WriteAllText($KeyPath, $rsa.ToXmlString($true))
	}
	$der = Get-SpkiDer ($rsa.ExportParameters($false))
	@{ Der = $der; Base64 = [Convert]::ToBase64String($der); Id = (Get-ExtensionId $der) }
}

function Update-ManifestKey {
	param([string]$ManifestPath, [string]$Base64)
	$text = [IO.File]::ReadAllText($ManifestPath)
	$new = [regex]::Replace($text, '"key"\s*:\s*"[^"]*"', ('"key": "' + $Base64 + '"'))
	if ($new -ne $text) {
		[IO.File]::WriteAllText($ManifestPath, $new, (New-Object Text.UTF8Encoding($false)))
	}
}
