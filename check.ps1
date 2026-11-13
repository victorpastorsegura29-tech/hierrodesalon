# Control de calidad de la web. Comprueba, de una vez, que todo lo acordado se cumple.
#
# Uso (desde esta carpeta):
#   powershell -ExecutionPolicy Bypass -File .\check.ps1          revisa los archivos locales (antes de hacer commit)
#   powershell -ExecutionPolicy Bypass -File .\check.ps1 -Live    revisa ademas la web publicada (tras el git push)
#
# Termina con codigo 0 si todo esta bien y 1 si hay algun FALLO. Los AVISOS no son fallos.

param([switch]$Live)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:ok = 0
$script:fails = New-Object System.Collections.ArrayList
$script:warns = New-Object System.Collections.ArrayList

function Pass([string]$m) { $script:ok++; Write-Host ("  OK     " + $m) -ForegroundColor Green }
function Fail([string]$m) { [void]$script:fails.Add($m); Write-Host ("  FALLO  " + $m) -ForegroundColor Red }
function Warn([string]$m) { [void]$script:warns.Add($m); Write-Host ("  AVISO  " + $m) -ForegroundColor Yellow }
function Check([bool]$cond, [string]$msg) { if ($cond) { Pass $msg } else { Fail $msg } }
function Section([string]$t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Read([string]$rel) { [System.IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

# ---------- 1. Archivos ----------
Section "1. Archivos necesarios"
$need = @("index.html", "privacidad.html", "aviso-legal.html", "cookies.html", "404.html", "legal.css", "cookies.js",
          "robots.txt", "sitemap.xml", "site.webmanifest", "_headers", "favicon.svg", "favicon-32.png", "apple-touch-icon.png",
          "icon-192.png", "icon-512.png", "og.jpg", "google7045589a039bc88c.html",
          "fonts\LICENSE.txt", "fonts\OFL.txt", "fonts\inter-latin.woff2", "fonts\inter-latin-ext.woff2", "fonts\barlow-condensed-600-latin.woff2",
          "fonts\barlow-condensed-600-latin-ext.woff2", "fonts\barlow-condensed-700-latin.woff2", "fonts\barlow-condensed-700-latin-ext.woff2")
$missing = $need | Where-Object { -not (Test-Path (Join-Path $root $_) -PathType Leaf) }
Check ($missing.Count -eq 0) ("Estan los $($need.Count) archivos necesarios" + $(if ($missing) { " (faltan: " + ($missing -join ", ") + ")" } else { "" }))
$ogSize = (Get-Item (Join-Path $root "og.jpg")).Length
Check ($ogSize -lt 300000) ("og.jpg pesa " + [math]::Round($ogSize / 1024) + " KB (menos de 300 KB, para que WhatsApp lo muestre)")

$index = Read "index.html"
$static = $index -replace '(?s)<script\b.*?</script>', '' -replace '(?s)<style\b.*?</style>', '' -replace '(?s)<!--.*?-->', ''

# ---------- 2. Cumplimiento con Amazon ----------
Section "2. Cumplimiento con Amazon (sin precios, estrellas ni opiniones copiadas)"
Check (-not $index.Contains([string][char]0x20AC)) "No aparece el simbolo del euro en index.html"
Check (-not $index.Contains([string][char]0x2605)) "No aparecen estrellas (la estrella de valoracion)"
Check (-not [regex]::IsMatch($index, '\d[\d.,]*\s*opiniones', 'IgnoreCase')) "No hay cifras de opiniones (por ejemplo 1.234 opiniones)"
Check (-not [regex]::IsMatch($index, '\b\d(,\d)?\s*(/|de)\s*5\b(?!\d)')) "No hay notas del tipo 4,5/5 o 4,5 de 5"
Check (-not [regex]::IsMatch($index, '[{,]\s*(pc|rt|nr|pq|pu|kc)\s*:\s*[\d."]')) "Los datos de productos no guardan precio, valoracion ni opiniones"
Check (-not [regex]::IsMatch($static, 'Mejor puntuado|puntuaci[oó]n orientativa', 'IgnoreCase')) "No queda la puntuacion calculada ni el apartado Mejor puntuados"
$amz = [regex]::Matches($static, '<a\b[^>]*href="https://www\.amazon\.es[^"]*"[^>]*>')
Check ($amz.Count -ge 17) ("Hay $($amz.Count) enlaces a Amazon en el HTML (al menos 17, uno por producto)")
$badAmz = $amz | Where-Object { $_.Value -notmatch 'tag=hierrodesalon-21' -or $_.Value -notmatch 'rel="[^"]*sponsored' -or $_.Value -notmatch 'rel="[^"]*nofollow' }
Check (@($badAmz).Count -eq 0) "Todos los enlaces a Amazon llevan tu etiqueta (tag=hierrodesalon-21) y rel con sponsored y nofollow"
Check ($static -match 'En calidad de Afiliado de Amazon, obtengo ingresos por las compras adscritas') "Esta el aviso obligatorio de Afiliado de Amazon"

# ---------- 3. Cabecera, SEO y datos estructurados ----------
Section "3. SEO y cabecera"
$title = [regex]::Match($static, '<title>(.*?)</title>', 'Singleline').Groups[1].Value
Check ($title.Length -ge 20 -and $title.Length -le 70) ("Titulo de $($title.Length) caracteres: $title")
$desc = [regex]::Match($static, '<meta name="description" content="([^"]*)"').Groups[1].Value
Check ($desc.Length -ge 70 -and $desc.Length -le 170) ("Descripcion de $($desc.Length) caracteres (entre 70 y 170)")
Check ($static -match '<link rel="canonical" href="https://hierrodesalon\.com/">') "El canonical apunta a https://hierrodesalon.com/"
Check ($static -match '<html lang="es"') "Idioma declarado: es"
Check ($static -match '<meta name="viewport"') "Tiene meta viewport"
Check ($static -match 'og:image" content="https://hierrodesalon\.com/og\.jpg"') "La imagen para compartir (og.jpg) esta declarada"
$ld = [regex]::Match($index, '(?s)<script type="application/ld\+json">(.*?)</script>').Groups[1].Value
$ldOk = $false; try { $null = $ld | ConvertFrom-Json; $ldOk = ($ld.Length -gt 10) } catch { }
Check $ldOk "Los datos estructurados (JSON-LD) son JSON valido"
Check (([regex]::Matches($static, '<h1\b')).Count -eq 1) "Hay un unico h1"

# ---------- 4. Privacidad: sin terceros innecesarios ----------
Section "4. Privacidad"
$allText = (Get-ChildItem $root -Include *.html, *.css, *.js, *.webmanifest -Recurse -File | Where-Object { $_.FullName -notmatch '\\(\.git|tools)\\' } |
            ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, $utf8) }) -join "`n"
Check (-not ($allText -match 'fonts\.googleapis\.com|fonts\.gstatic\.com')) "Ninguna pagina carga tipografias de Google (se sirven desde /fonts)"
Check (-not ($allText -match '(?i)netlify')) "No queda ninguna mencion a Netlify (el alojamiento es Cloudflare)"
Check ((Read "privacidad.html") -match 'Cloudflare') "La politica de privacidad nombra a Cloudflare como proveedor"
$hdr = Read "_headers"
Check ($hdr -match 'Content-Security-Policy' -and $hdr -match 'X-Content-Type-Options: nosniff' -and $hdr -match 'Strict-Transport-Security') "_headers define CSP, nosniff y HSTS"

# ---------- 5. HTML bien formado ----------
Section "5. Estructura del HTML"
function Test-Balance([string]$s) {
  $void = 'area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr'
  $stack = New-Object System.Collections.Stack
  $errs = New-Object System.Collections.ArrayList
  foreach ($m in [regex]::Matches($s, '<(/?)([a-zA-Z][a-zA-Z0-9-]*)\b[^>]*?(/?)>')) {
    $close = $m.Groups[1].Value -eq '/'; $name = $m.Groups[2].Value.ToLower(); $self = $m.Groups[3].Value -eq '/'
    if ($self -or $name -match "^($void)$") { continue }
    if (-not $close) { $stack.Push($name); continue }
    if ($stack.Count -eq 0) { [void]$errs.Add("cierre sobrante </$name>"); continue }
    if ($stack.Peek() -eq $name) { [void]$stack.Pop() }
    else {
      [void]$errs.Add("</$name> no coincide con <$($stack.Peek())>")
      if ($stack.Contains($name)) { while ($stack.Peek() -ne $name) { [void]$stack.Pop() }; [void]$stack.Pop() }
    }
  }
  if ($stack.Count -gt 0) { [void]$errs.Add("sin cerrar: " + (($stack.ToArray() | Select-Object -First 5) -join ", ")) }
  return ,$errs
}
foreach ($f in "index.html", "privacidad.html", "aviso-legal.html", "cookies.html", "404.html") {
  $s = (Read $f) -replace '(?s)<script\b.*?</script>', '' -replace '(?s)<style\b.*?</style>', '' -replace '(?s)<!--.*?-->', ''
  $e = Test-Balance $s
  Check ($e.Count -eq 0) ("$f : etiquetas abiertas y cerradas en orden" + $(if ($e.Count) { " (" + (($e | Select-Object -First 3) -join "; ") + ")" } else { "" }))
}
$ids = [regex]::Matches($static, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$dups = $ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
Check (@($dups).Count -eq 0) ("Ningun id repetido en index.html" + $(if ($dups) { " (repetidos: " + ($dups -join ", ") + ")" } else { "" }))
$noAlt = [regex]::Matches($static, '<img\b(?![^>]*\balt=)[^>]*>').Count
Check ($noAlt -eq 0) "Todas las imagenes tienen texto alternativo (alt)"

# ---------- 6. Enlaces y recursos internos ----------
Section "6. Enlaces internos"
function Local-Exists([string]$ref) {
  $h = ($ref -split '#')[0]; $h = ($h -split '\?')[0]
  if ($h -eq '' -or $h -match '^(https?:|mailto:|tel:|data:|javascript:|//)') { return $true }
  $p = $h.TrimStart('/'); if ($p -eq '') { $p = 'index.html' }
  $p = $p -replace '/', '\'
  return ((Test-Path (Join-Path $root $p) -PathType Leaf) -or (Test-Path (Join-Path $root "$p.html") -PathType Leaf))
}
$broken = New-Object System.Collections.ArrayList
foreach ($f in "index.html", "privacidad.html", "aviso-legal.html", "cookies.html", "404.html") {
  $s = (Read $f) -replace '(?s)<script\b.*?</script>', '' -replace '(?s)<!--.*?-->', ''
  foreach ($m in [regex]::Matches($s, '\b(?:href|src)="([^"]*)"')) { if (-not (Local-Exists $m.Groups[1].Value)) { [void]$broken.Add("$f -> " + $m.Groups[1].Value) } }
  foreach ($m in [regex]::Matches($s, 'url\(([^)]+)\)')) { $u = $m.Groups[1].Value.Trim("'", '"', ' '); if (-not (Local-Exists $u)) { [void]$broken.Add("$f css -> $u") } }
}
foreach ($m in [regex]::Matches((Read "legal.css"), 'url\(([^)]+)\)')) { $u = $m.Groups[1].Value.Trim("'", '"', ' '); if (-not (Local-Exists $u)) { [void]$broken.Add("legal.css -> $u") } }
foreach ($m in [regex]::Matches((Read "site.webmanifest"), '"src":\s*"([^"]+)"')) { if (-not (Local-Exists $m.Groups[1].Value)) { [void]$broken.Add("site.webmanifest -> " + $m.Groups[1].Value) } }
Check ($broken.Count -eq 0) ("Todos los enlaces, imagenes y fuentes internas existen" + $(if ($broken.Count) { " (rotos: " + (($broken | Select-Object -First 4) -join "; ") + ")" } else { "" }))
$smap = Read "sitemap.xml"
$locs = [regex]::Matches($smap, '<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value }
$badLoc = $locs | Where-Object { $_ -notmatch '^https://hierrodesalon\.com/' -or $_ -match '\.html$' -or -not (Local-Exists ($_ -replace '^https://hierrodesalon\.com', '')) }
Check ($locs.Count -ge 4 -and @($badLoc).Count -eq 0) ("El sitemap lista $($locs.Count) URL validas (con https, sin .html y con archivo)")

# ---------- 7. El HTML generado esta al dia ----------
Section "7. Prerender (lo que ven Google y las IA)"
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "prerender.ps1") -Check
Check ($LASTEXITCODE -eq 0) "index.html lleva el contenido generado al dia (si falla: ejecuta .\prerender.ps1)"

# ---------- 8. La web publicada ----------
if ($Live) {
  Section "8. Web publicada (https://hierrodesalon.com)"
  $B = "https://hierrodesalon.com"
  function Code([string]$u) { [string](& curl.exe -s -o NUL -w "%{http_code}" $u) }
  function Head([string]$u) { (& curl.exe -s -I $u) -join "`n" }
  Check ((Code "$B/") -eq "200") "La portada responde 200"
  $tmpBody = Join-Path $env:TEMP ("hds-body-" + [guid]::NewGuid().ToString("N") + ".html")
  & curl.exe -s -o $tmpBody "$B/?check=$([guid]::NewGuid().ToString('N'))"
  $body = [System.IO.File]::ReadAllText($tmpBody, $utf8); Remove-Item $tmpBody -Force
  $pre = ($body -split '<script>')[0]
  $cards = [regex]::Matches($pre, 'class="card"').Count
  Check ($cards -ge 17) "Sin ejecutar JavaScript se ven $cards tarjetas de producto (para Google y las IA)"
  Check (-not ($body -match [string][char]0x20AC)) "La web publicada no muestra precios (sin simbolo de euro)"
  $h = Head "$B/"
  Check ($h -match '(?i)content-security-policy') "Cabecera Content-Security-Policy activa"
  Check ($h -match '(?i)x-content-type-options:\s*nosniff') "Cabecera X-Content-Type-Options activa"
  Check ($h -match '(?i)strict-transport-security') "Cabecera HSTS activa"
  Check (-not ($h -match '(?i)set-cookie')) "La web no instala cookies"
  Check (-not ($h -match 'fonts\.googleapis')) "No hay precarga de Google Fonts en las cabeceras"
  foreach ($u in $locs) { Check ((Code $u) -eq "200") "$u responde 200" }
  Check ((Code "$B/robots.txt") -eq "200") "robots.txt responde 200"
  Check ((Code "$B/og.jpg") -eq "200") "og.jpg responde 200"
  Check ((Code "$B/fonts/inter-latin.woff2") -eq "200") "Las tipografias propias responden 200"
  Check ((Head "$B/fonts/inter-latin.woff2") -match '(?i)immutable') "Las tipografias se guardan en cache un ano"
  Check ((Code "$B/pagina-que-no-existe-$([guid]::NewGuid().ToString('N'))") -eq "404") "Una URL inexistente devuelve 404"
  $httpCode = Code "http://hierrodesalon.com/"
  Check ($httpCode -in "301", "308") "http:// redirige a https:// (codigo $httpCode)"
  $www = Head "https://www.hierrodesalon.com/"
  if ($www -match '(?i)^HTTP/\S+\s+30[1278]' -and $www -match '(?i)location:\s*https://hierrodesalon\.com') { Pass "www redirige al dominio principal" }
  else { Warn "www.hierrodesalon.com no redirige al dominio principal (sirve lo mismo; el canonical evita duplicados)" }
}

# ---------- Resumen ----------
Write-Host ""
$color = $(if ($script:fails.Count) { "Red" } else { "Green" })
Write-Host ("Resultado: {0} correctas, {1} fallos, {2} avisos." -f $script:ok, $script:fails.Count, $script:warns.Count) -ForegroundColor $color
if ($script:fails.Count) { Write-Host "Hay que arreglar los FALLOS antes de publicar." -ForegroundColor Red; exit 1 }
exit 0
