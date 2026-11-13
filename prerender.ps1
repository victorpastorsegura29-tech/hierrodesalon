# Prerenderizado de index.html
#
# La web genera las tarjetas, los "mejor puntuados" y la metodologia con JavaScript. Este script abre
# la pagina en Edge sin ventana, recoge el HTML ya generado y lo escribe dentro de index.html (entre los
# marcadores <!--pre:nombre--> ... <!--/pre:nombre-->). Asi Google, los asistentes de IA y las vistas
# previas ven los productos sin ejecutar JavaScript. Los visitantes siguen usando el JavaScript de siempre.
#
# Uso (desde esta carpeta, cada vez que cambies datos, textos o diseno de index.html):
#   powershell -ExecutionPolicy Bypass -File .\prerender.ps1
# Despues: git add index.html; git commit; git push

$ErrorActionPreference = "Stop"
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $dir "index.html"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "No se encuentra Microsoft Edge." }

$tmp = Join-Path $env:TEMP ("prerender-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$out = Join-Path $tmp "dom.html"
$err = Join-Path $tmp "err.txt"

try {
  $url = ([System.Uri]$file).AbsoluteUri + "?prerender"
  $args = @("--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=`"$tmp\profile`"",
            "--virtual-time-budget=15000", "--dump-dom", "`"$url`"")
  Start-Process -FilePath $edge -ArgumentList $args -Wait -NoNewWindow `
    -RedirectStandardOutput $out -RedirectStandardError $err
  $dom = [System.IO.File]::ReadAllText($out, $utf8)

  $m = [regex]::Match($dom, '<pre id="prerender-out">(.*?)</pre>', 'Singleline')
  if (-not $m.Success) { throw "La pagina no genero el bloque de prerender (revisa index.html)." }
  $json = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
  $d = $json | ConvertFrom-Json

  $html = [System.IO.File]::ReadAllText($file, $utf8)
  $names = "list", "picks", "chips", "crit", "frm", "s1", "s2", "s3"
  foreach ($n in $names) {
    $val = [string]$d.$n
    if ([string]::IsNullOrWhiteSpace($val)) { throw "El bloque '$n' esta vacio: no se escribe nada." }
    $re = "(<!--pre:$n-->)(.*?)(<!--/pre:$n-->)"
    if (-not [regex]::IsMatch($html, $re, 'Singleline')) { throw "Falta el marcador pre:$n en index.html." }
    $html = [regex]::Replace($html, $re, [System.Text.RegularExpressions.MatchEvaluator]{
      param($x) $x.Groups[1].Value + $val + $x.Groups[3].Value }, 'Singleline')
  }
  # Fecha de consulta de los datos
  $date = [string]$d.date
  $html = [regex]::Replace($html, '<span data-dc>[^<]*</span>', [System.Text.RegularExpressions.MatchEvaluator]{
    param($x) '<span data-dc>' + $date + '</span>' })

  [System.IO.File]::WriteAllText($file, $html, $utf8)
  $cards = ([regex]::Matches([string]$d.list, 'class="card"')).Count
  Write-Host "Listo: $cards tarjetas y el resto de bloques escritos en index.html (datos del $date)."
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
