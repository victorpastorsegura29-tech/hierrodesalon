# Hierro de Salón: guía de publicación

Web estática (sin servidor ni base de datos). Archivos:

| Archivo | Para qué sirve |
|---|---|
| `index.html` | Portada, comparativas, elección, guías y metodología |
| `aviso-legal.html`, `privacidad.html`, `cookies.html` | Páginas legales (plantillas) |
| `cookies.js` | Banner de consentimiento de cookies |
| `legal.css` | Estilo de las páginas legales y la 404 |
| `404.html`, `favicon.svg`, `robots.txt`, `sitemap.xml` | Errores, icono y SEO |
| `og.png` | Imagen que se muestra al compartir la web en redes (1200 × 630) |

## 0. Prerenderizado (cada vez que cambies `index.html`)

Las tarjetas, los «mejor puntuados» y la metodología los genera JavaScript. Para que Google y los asistentes de IA los vean sin ejecutar JavaScript, el HTML generado se guarda dentro de `index.html` (entre los marcadores `<!--pre:nombre-->`). Tras cambiar datos, textos o diseño, ejecuta desde esta carpeta (necesita Microsoft Edge):

```powershell
powershell -ExecutionPolicy Bypass -File .\prerender.ps1
```

Después haz commit de `index.html` y `git push`. Si no lo ejecutas, los visitantes ven los datos nuevos, pero Google y los asistentes de IA seguirán viendo la versión anterior.

## 1. Antes de publicar (obligatorio)

1. **Datos legales.** Busca en `aviso-legal.html`, `privacidad.html` y `cookies.html` los textos resaltados en amarillo (`class="dato"`) y sustitúyelos por tus datos reales: nombre o razón social, NIF/CIF, domicilio, email, proveedor de hosting y fecha. Después elimina el recuadro "Plantilla orientativa". Conviene que un profesional los revise.
2. **Dominio.** Sustituye `TU-DOMINIO.es` por tu dominio real en `index.html` (canonical y og:url), `robots.txt` y `sitemap.xml`.
3. **Etiqueta de afiliado.** Ya configurada: `hierrodesalon-21` (aparece en la función `A=` de `index.html`).
4. **Revisa los datos de producto** (precios, notas, opiniones) y la fecha "consultados el 13/11/2026" de la sección Metodología.

Atajo en PowerShell, desde esta carpeta:

```powershell
(Get-Content index.html -Raw) -replace 'TU-DOMINIO\.es','midominio.es' -replace 'TU-TAG-21','mitag-21' | Set-Content index.html -Encoding utf8
```
(repite el cambio de dominio en `robots.txt` y `sitemap.xml`).

## 2. Publicar (elige una opción, todas gratuitas)

**Cloudflare Pages / Netlify / Vercel (recomendado):** crea una cuenta, "nuevo proyecto", sube esta carpeta (arrastrar y soltar en Netlify) o conecta un repositorio de GitHub. Sin comando de build y con la carpeta raíz como directorio de publicación.

**GitHub Pages:** sube los archivos a un repositorio y activa Pages en Settings > Pages.

## 3. Conectar tu dominio .es / .com

1. Compra el dominio en un registrador (Cloudflare, Namecheap, Dinahosting...). Para `.es` te pedirán datos de titular.
2. En el hosting elegido, añade el dominio personalizado y copia los registros DNS que te indique (CNAME o A).
3. Pégalos en el panel DNS del registrador. El HTTPS se activa solo en unos minutos.
4. Si subes los archivos a un repositorio y lo conectas al hosting, cada cambio que guardes se publicará automáticamente.

## 4. Después de publicar

- Da de alta el sitio en Google Search Console y envía `sitemap.xml`.
- Comprueba en Amazon Afiliados que el dominio está dado de alta en tu cuenta.
- Prueba el banner de cookies en una ventana de incógnito.

## Cookies y terceros: qué hay que saber

- La web **no instala cookies propias** salvo guardar tu elección (`hds-consent`, en el almacenamiento local).
- Si añades analítica (Google Analytics, etc.), cárgala **solo** dentro de la función `onAccept()` de `cookies.js`, para que no se active sin consentimiento, y actualiza `cookies.html`.
- **Google Fonts** envía la IP del visitante a Google. Está declarado en la política de privacidad. Para evitarlo del todo, descarga las fuentes Inter y Barlow Condensed y sírvelas desde tu propio dominio.
- Las **fotos de producto** se cargan desde servidores de Amazon. Revisa las condiciones del programa de afiliados sobre uso de imágenes; la vía más segura es la API oficial de Amazon.