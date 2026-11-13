# Genera los pines de Pinterest (1000 x 1500) en la carpeta pins\ a partir de tools\pin-*.html, con Microsoft Edge sin ventana.
# Uso:  powershell -ExecutionPolicy Bypass -File .\tools\make-pins.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "No se encuentra Microsoft Edge." }
$out = Join-Path $root "pins"; New-Item -ItemType Directory -Force $out | Out-Null
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
foreach ($f in Get-ChildItem (Join-Path $root "tools") -Filter "pin-*.html") {
  $tmp = Join-Path $env:TEMP ("pin-" + [guid]::NewGuid().ToString("N")); New-Item -ItemType Directory $tmp | Out-Null
  $raw = Join-Path $tmp "raw.png"
  try {
    $url = ([System.Uri]$f.FullName).AbsoluteUri
    $a = @("--headless=new","--disable-gpu","--hide-scrollbars","--force-device-scale-factor=1","--user-data-dir=`"$tmp\profile`"",
           "--window-size=1000,1700","--virtual-time-budget=8000","--screenshot=`"$raw`"","`"$url`"")
    Start-Process $edge -ArgumentList $a -Wait -NoNewWindow -RedirectStandardError (Join-Path $tmp "err.txt")
    if (-not (Test-Path $raw)) { throw "Edge no generó la captura de $($f.Name)" }
    $img = [System.Drawing.Image]::FromFile($raw)
    $bmp = New-Object System.Drawing.Bitmap 1000, 1500
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0,0,1000,1500), (New-Object System.Drawing.Rectangle 0,0,1000,1500), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $img.Dispose()
    $p = New-Object System.Drawing.Imaging.EncoderParameters 1
    $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]90)
    $dst = Join-Path $out ($f.BaseName + ".jpg")
    $bmp.Save($dst, $codec, $p); $bmp.Dispose()
    "{0,-26} {1,8:N0} bytes" -f (Split-Path $dst -Leaf), (Get-Item $dst).Length
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
