# Hierro de Salón

Web estática (sin servidor ni base de datos) de comparativas de material de fitness y fuerza para casa, con enlaces de afiliado a Amazon.es. Publicada en https://hierrodesalon.com con **Cloudflare Pages**: cada `git push` a la rama `main` se publica sola en un minuto.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La web: portada, productos, guías «Qué comprar» y «Cómo elegimos». Los datos de los productos están en el array `P` del script |
| `aviso-legal.html`, `privacidad.html`, `cookies.html`, `legal.css`, `cookies.js` | Páginas legales y banner de cookies |
| `404.html` | Página de error |
| `fonts/` | Tipografías Inter y Barlow Condensed (licencia SIL OFL), servidas desde la propia web |
| `_headers` | Cabeceras de seguridad y caché de Cloudflare Pages (no se publica como página) |
| `robots.txt`, `sitemap.xml`, `site.webmanifest` | SEO e información para móviles |
| `og.jpg`, `favicon.svg`, `favicon-32.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png` | Imagen para compartir e iconos (se generan con `tools\make-images.ps1`) |
| `google7045589a039bc88c.html` | Verificación antigua de Search Console (ya se verifica por DNS; se puede conservar) |
| `prerender.ps1`, `check.ps1`, `tools/` | Herramientas para trabajar con la web (no son parte de la web) |

## Cómo trabajar (cada vez que cambies algo)

Hace falta Windows con Microsoft Edge. Desde esta carpeta:

1. **Edita** `index.html` (datos, textos o diseño).
2. **Genera el contenido para buscadores**: las tarjetas las crea JavaScript, y este paso guarda el resultado dentro del HTML para que Google y las IA lo vean sin ejecutar nada.
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\prerender.ps1
   ```
3. **Comprueba la calidad** (sin precios ni estrellas, enlaces de afiliado, HTML bien formado, enlaces internos, prerender al día…):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\check.ps1
   ```
   Si hay algún FALLO, no publiques hasta arreglarlo.
4. **Publica**: `git add -A`, `git commit` y `git push`.
5. **Comprueba la web publicada** (pasado un minuto):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\check.ps1 -Live
   ```

Para ver la web en local con las tipografías y las cabeceras reales hace falta un servidor; abrir `index.html` con doble clic también funciona, pero sin las tipografías propias.

### Actualizar un producto

Edita su línea en el array `P` de `index.html` (nombre, `y`/`no` = «para quién sí / no», datos de la ficha) y la constante `DATE` (fecha de consulta de las fichas). Después, pasos 2 a 4. Para añadir un tipo de producto nuevo hay que añadirlo a los objetos `C` (nombre), `CT` (color), `IC` (icono), `G` (grupo) y a su guía en `#guides`.

### Imagen para compartir e iconos

Cambia el texto en `tools\og.html` (o el icono en `tools\icon.html`) y ejecuta `powershell -ExecutionPolicy Bypass -File .\tools\make-images.ps1`.

## Reglas de Amazon Afiliados (ya aplicadas)

- **No se muestran precios, valoraciones con estrellas ni número de opiniones.** Las políticas del programa solo lo permiten con datos de su API oficial. El botón lleva a Amazon, que muestra precio y opiniones actualizados. `check.ps1` vigila que no reaparezcan.
- Los enlaces llevan `tag=hierrodesalon-21` y `rel="nofollow sponsored noopener"`; el aviso obligatorio («En calidad de Afiliado de Amazon, obtengo ingresos…») está en el pie.
- **Pendiente de revisar:** las fotos de producto se cargan desde `m.media-amazon.com` (las políticas leídas no aclaran si el enlace directo está permitido); la vía segura es la API oficial.

## Hosting, dominio y Search Console

- **Cloudflare Pages** (proyecto `hierrodesalon`, conectado a GitHub). Sin comando de build; la carpeta raíz es la carpeta de publicación.
- **DNS en Cloudflare**: `hierrodesalon.com` y `www` apuntan a `hierrodesalon.pages.dev`; una regla de redirección (Rules > Redirect Rules) manda `www` al dominio principal con un 301. Hay un registro **TXT** `google-site-verification=…` que verifica Search Console: **no lo borres**.
- Cloudflare Pages redirige `/pagina.html` a `/pagina`; por eso los enlaces internos van sin `.html`.

## Cookies y terceros

- La web no instala cookies propias salvo guardar tu elección del banner (`hds-consent`, en el almacenamiento local).
- Estadísticas: **Cloudflare Web Analytics** (instalación automática, sin cookies; se ven en Cloudflare → Observability → Web analytics). Su script está permitido en la CSP de `_headers` (`static.cloudflareinsights.com` y `cloudflareinsights.com`) y declarado en `cookies.html` y `privacidad.html`. Por eso el aviso de cookies es un único botón.
- Si añades analítica que use cookies, cárgala **solo** dentro de `onAccept()` de `cookies.js`, vuelve a un banner con Aceptar y Rechazar del mismo peso y actualiza `cookies.html` y `privacidad.html`.
- Los enlaces `/#c-<categoria>` (esterillas, gomas, balones, dominadas, lastre, accesorios, mancuernas, bancos; también `#g-…` o el grupo `fit`, `tra`, `pes`, `acc`) abren la categoría y bajan a la comparativa: son los que usan los pines de Pinterest.
- Las tipografías se sirven desde `/fonts` (sin Google Fonts). Terceros que intervienen: Cloudflare (alojamiento y CDN) y Amazon (fotos y enlaces).
