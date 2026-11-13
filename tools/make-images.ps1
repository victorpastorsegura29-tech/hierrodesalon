# Genera las imágenes de la web a partir de las plantillas de esta carpeta, con Microsoft Edge sin ventana:
#   og.jpg (imagen que se ve al compartir la web), icon-512.png, icon-192.png, apple-touch-icon.png y favicon-32.png
#
# Uso (cuando cambies el texto de tools\og.html o el icono):
#   powershell -ExecutionPolicy Bypass -File .\tools\make-images.ps1
# Después: git add . ; git commit ; git push

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "No se encuentra Microsoft Edge." }

# Hace una captura de una plantilla HTML y la recorta al tamaño exacto (Edge a veces añade margen).
function Shot([string]$html, [string]$out, [int]$w, [int]$h) {
  $tmp = Join-Path $env:TEMP ("shot-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $raw = Join-Path $tmp "raw.png"
  try {
    $url = ([System.Uri](Join-Path $root $html)).AbsoluteUri
    $edgeArgs = @("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                  "--user-data-dir=`"$tmp\profile`"", "--window-size=$w,$($h + 200)", "--virtual-time-budget=8000",
                  "--screenshot=`"$raw`"", "`"$url`"")
    Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -NoNewWindow -RedirectStandardError (Join-Path $tmp "err.txt")
    if (-not (Test-Path $raw)) { throw "Edge no generó la captura de $html" }
    $img = [System.Drawing.Image]::FromFile($raw)
    try {
      if ($img.Width -lt $w -or $img.Height -lt $h) { throw "La captura de $html mide $($img.Width)x$($img.Height) y se esperaba al menos ${w}x${h}." }
      $bmp = New-Object System.Drawing.Bitmap $w, $h
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle 0, 0, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
      $g.Dispose()
      $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
      $bmp.Dispose()
    } finally { $img.Dispose() }
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}

function Resize([string]$src, [string]$dst, [int]$size) {
  $img = [System.Drawing.Image]::FromFile($src)
  try {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  } finally { $img.Dispose() }
}

function SaveJpeg([string]$src, [string]$dst, [int]$quality) {
  $img = [System.Drawing.Image]::FromFile($src)
  try {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $p = New-Object System.Drawing.Imaging.EncoderParameters 1
    $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
    $img.Save($dst, $codec, $p)
  } finally { $img.Dispose() }
}

$tmpOg = Join-Path $env:TEMP "hds-og.png"
Shot "tools\og.html" $tmpOg 1200 630
SaveJpeg $tmpOg (Join-Path $root "og.jpg") 88
Remove-Item $tmpOg -Force

$icon512 = Join-Path $root "icon-512.png"
Shot "tools\icon.html" $icon512 512 512
Resize $icon512 (Join-Path $root "icon-192.png") 192
Resize $icon512 (Join-Path $root "apple-touch-icon.png") 180
Resize $icon512 (Join-Path $root "favicon-32.png") 32

Get-ChildItem $root -Include og.jpg, icon-512.png, icon-192.png, apple-touch-icon.png, favicon-32.png -Recurse -File |
  ForEach-Object { "{0,-22} {1,8:N0} bytes" -f $_.Name, $_.Length }
