# Prerenderizado de index.html y generacion de las paginas por tema
#
# La web genera las tarjetas de producto, los botones de categoria y las cifras con JavaScript. Este script abre
# cada pagina en Edge sin ventana, recoge el HTML ya generado y lo escribe dentro del propio archivo (entre los
# marcadores <!--pre:nombre--> ... <!--/pre:nombre-->). Asi Google, los asistentes de IA y las vistas previas
# ven los productos sin ejecutar JavaScript. Los visitantes siguen usando el JavaScript de siempre.
#
# Ademas genera 4 paginas por tema (yoga-pilates-fitness.html, dominadas-lastre.html, mancuernas-bancos.html y
# straps-levantamiento.html) a partir de index.html: mismo diseno y datos, pero con titulo, descripcion, H1,
# migas de pan y canonical propios y solo los productos de su grupo. NO se editan a mano: se cambia index.html
# (o los textos de $paginas aqui abajo) y se vuelve a ejecutar este script.
#
# Uso (desde esta carpeta, cada vez que cambies datos, textos o diseno de index.html):
#   powershell -ExecutionPolicy Bypass -File .\prerender.ps1
# Despues: git add -A; git commit; git push

param([switch]$Check)   # -Check: no escribe nada; solo avisa si algo esta desactualizado (devuelve 1)

$ErrorActionPreference = "Stop"
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "https://hierrodesalon.com"

# Paginas por tema. cat = clave del grupo en el objeto G de index.html. El texto es nuestro (no copia nada de Amazon).
$paginas = @(
  @{ slug = "yoga-pilates-fitness"; cat = "fit"; nombre = "Esterillas, gomas y balones de pilates";
     title = "Esterillas, gomas y balones de pilates: comparativa | Hierro de Salón";
     desc  = "Compara esterillas de yoga, gomas elásticas y balones de pilates: grosor, material, medidas y para quién es cada una. El precio lo ves en Amazon.es.";
     lead  = "Grosor y material de las esterillas, resistencia de las gomas y talla de los balones, con para quién es cada producto. El precio y las opiniones, en Amazon." },
  @{ slug = "dominadas-lastre"; cat = "tra"; nombre = "Barras de dominadas y cinturones de lastre";
     title = "Barras de dominadas y lastre: comparativa | Hierro de Salón";
     desc  = "Compara barras de dominadas de puerta y de pared y cinturones de lastre: carga máxima, medidas, instalación y para quién es cada una. El precio lo ves en Amazon.es.";
     lead  = "Barras de puerta y de pared, y cinturones para añadir lastre: carga máxima declarada, medidas, materiales y para quién es cada una. El precio y las opiniones, en Amazon." },
  @{ slug = "mancuernas-bancos"; cat = "pes"; nombre = "Mancuernas ajustables y bancos de musculación";
     title = "Mancuernas ajustables y bancos de musculación | Hierro de Salón";
     desc  = "Compara mancuernas ajustables y bancos de musculación para casa: carga máxima, medidas, peso, espacio que ocupan y para quién es cada uno. El precio lo ves en Amazon.es.";
     lead  = "Carga máxima por mano, medidas, peso y espacio que ocupa cada mancuerna o banco, con para quién es cada producto. El precio y las opiniones, en Amazon." },
  @{ slug = "straps-levantamiento"; cat = "acc"; nombre = "Straps de levantamiento";
     title = "Straps de levantamiento: comparativa | Hierro de Salón";
     desc  = "Compara straps de levantamiento para peso muerto, remos y tirones: material, longitud, muñequera y para quién es cada uno. El precio y las opiniones los ves en Amazon.es.";
     lead  = "Material, longitud y muñequera de cada strap, con para quién es cada producto. El precio y las opiniones, en Amazon." }
)

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "No se encuentra Microsoft Edge." }

$tmp = Join-Path $env:TEMP ("prerender-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$trabajo = New-Object System.Collections.ArrayList   # archivos temporales dentro de la carpeta del proyecto
$script:code = 0

function Esc([string]$s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;') }
function Sub([string]$html, [string]$re, [string]$nuevo, [string]$que) {
  if (-not [regex]::IsMatch($html, $re, 'Singleline')) { throw "No se encuentra '$que' en index.html (no se puede generar la pagina)." }
  return [regex]::Replace($html, $re, [System.Text.RegularExpressions.MatchEvaluator]{ param($x) $nuevo }, 'Singleline')
}

# Abre un archivo del proyecto en Edge con ?prerender y devuelve el JSON que genera la propia pagina.
function Render([string]$archivo) {
  $out = Join-Path $tmp ([guid]::NewGuid().ToString("N") + ".html")
  $err = Join-Path $tmp "err.txt"
  $url = ([System.Uri]$archivo).AbsoluteUri + "?prerender"
  $edgeArgs = @("--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=`"$tmp\profile`"",
                "--virtual-time-budget=15000", "--dump-dom", "`"$url`"")
  Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
  $dom = [System.IO.File]::ReadAllText($out, $utf8)
  $m = [regex]::Match($dom, '<pre id="prerender-out">(.*?)</pre>', 'Singleline')
  if (-not $m.Success) { throw "La pagina $([System.IO.Path]::GetFileName($archivo)) no genero el bloque de prerender (revisa index.html)." }
  return ([System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) | ConvertFrom-Json)
}

# Escribe en el HTML los bloques generados por la pagina (entre los marcadores) y la fecha de consulta.
function Inyectar([string]$html, $d, [string[]]$nombres) {
  foreach ($n in $nombres) {
    $val = [string]$d.$n
    if ([string]::IsNullOrWhiteSpace($val)) { throw "El bloque '$n' esta vacio: no se escribe nada." }
    $re = "(<!--pre:$n-->)(.*?)(<!--/pre:$n-->)"
    if (-not [regex]::IsMatch($html, $re, 'Singleline')) { throw "Falta el marcador pre:$n." }
    $html = [regex]::Replace($html, $re, [System.Text.RegularExpressions.MatchEvaluator]{
      param($x) $x.Groups[1].Value + $val + $x.Groups[3].Value }, 'Singleline')
  }
  $date = [string]$d.date
  return [regex]::Replace($html, '<span data-dc>[^<]*</span>', [System.Text.RegularExpressions.MatchEvaluator]{
    param($x) '<span data-dc>' + $date + '</span>' })
}

# Guarda el archivo o, con -Check, compara con el que hay y anota si esta desactualizado.
function Salida([string]$ruta, [string]$nuevo, [string]$existente, [string]$etiqueta) {
  if ($Check) {
    if ($existente -ceq $nuevo) { Write-Host "  al dia: $etiqueta" } else { Write-Host "  DESACTUALIZADO: $etiqueta"; $script:code = 1 }
  } else {
    [System.IO.File]::WriteAllText($ruta, $nuevo, $utf8)
    Write-Host "  escrito: $etiqueta"
  }
}

try {
  # ---- 1. Portada ----
  $homePath = Join-Path $dir "index.html"
  $homeOrig = [System.IO.File]::ReadAllText($homePath, $utf8)
  $homeSrc  = $homeOrig
  if ($Check) {
    $work = Join-Path $dir "~check-index.html"; [void]$trabajo.Add($work)
    [System.IO.File]::WriteAllText($work, $homeSrc, $utf8)
    $d = Render $work
  } else { $d = Render $homePath }
  $homeNew = Inyectar $homeSrc $d @("list", "chips", "s1", "s2")
  Salida $homePath $homeNew $homeOrig "index.html"

  # ---- 2. Paginas por tema (se generan desde la portada ya al dia) ----
  foreach ($p in $paginas) {
    $url  = "$base/" + $p.slug
    $nom  = Esc $p.nombre
    $html = $homeNew
    $html = Sub $html '<html lang="es">' ('<html lang="es" data-cat="' + $p.cat + '">') "etiqueta html"
    $html = Sub $html '<title>.*?</title>' ('<title>' + (Esc $p.title) + '</title>') "title"
    $html = Sub $html '<meta name="description" content="[^"]*">' ('<meta name="description" content="' + (Esc $p.desc) + '">') "meta description"
    $html = Sub $html '<link rel="canonical" href="[^"]*">' ('<link rel="canonical" href="' + $url + '">') "canonical"
    $html = Sub $html '<meta property="og:title" content="[^"]*">' ('<meta property="og:title" content="' + (Esc $p.title) + '">') "og:title"
    $html = Sub $html '<meta property="og:description" content="[^"]*">' ('<meta property="og:description" content="' + (Esc $p.desc) + '">') "og:description"
    $html = Sub $html '<meta property="og:url" content="[^"]*">' ('<meta property="og:url" content="' + $url + '">') "og:url"
    $html = Sub $html '<meta name="twitter:title" content="[^"]*">' ('<meta name="twitter:title" content="' + (Esc $p.title) + '">') "twitter:title"
    $html = Sub $html '<meta name="twitter:description" content="[^"]*">' ('<meta name="twitter:description" content="' + (Esc $p.desc) + '">') "twitter:description"
    # datos estructurados: se mantiene WebSite y se anade BreadcrumbList
    $ruta = '{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"' + $base + '/"},{"@type":"ListItem","position":2,"name":"' + $p.nombre + '","item":"' + $url + '"}]}'
    $ldRe = '(<script type="application/ld\+json">.*?</script>)'
    if (-not [regex]::IsMatch($html, $ldRe, 'Singleline')) { throw "No se encuentra el JSON-LD en index.html." }
    $html = [regex]::Replace($html, $ldRe, [System.Text.RegularExpressions.MatchEvaluator]{
      param($x) $x.Groups[1].Value + "`n" + '<script type="application/ld+json">' + $ruta + '</script>' }, 'Singleline')
    # cabecera de la portada: migas de pan, H1 y texto propios; se quita el bloque de cifras generales
    $hero = '<div class="bc" role="navigation" aria-label="Migas de pan"><a href="/">Inicio</a> <span aria-hidden="true">›</span> <span>' + $nom + '</span></div>' + "`n" +
            '  <h1>' + $nom + '</h1>' + "`n" +
            '  <p class="lead">' + (Esc $p.lead) + ' Fichas consultadas el <span data-dc>13/11/2026</span>.</p>'
    $html = Sub $html '<h1>.*?</h1>\s*<p class="lead">.*?</p>' $hero "H1 y texto de portada"
    $html = Sub $html '\s*<ul class="stats"[^>]*>.*?</ul>' '' "bloque de cifras"

    $destino = Join-Path $dir ($p.slug + ".html")
    $existente = if (Test-Path $destino) { [System.IO.File]::ReadAllText($destino, $utf8) } else { "" }
    $work = Join-Path $dir ("~gen-" + $p.slug + ".html"); [void]$trabajo.Add($work)
    [System.IO.File]::WriteAllText($work, $html, $utf8)
    $dp = Render $work
    $final = Inyectar $html $dp @("list", "chips")
    Salida $destino $final $existente ($p.slug + ".html")
  }
}
finally {
  foreach ($w in $trabajo) { Remove-Item $w -Force -ErrorAction SilentlyContinue }
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($Check) {
  if ($script:code -eq 0) { Write-Host "Prerender al dia." }
  else { Write-Host "DESACTUALIZADO: ejecuta  powershell -ExecutionPolicy Bypass -File .\prerender.ps1" }
  exit $script:code
}
