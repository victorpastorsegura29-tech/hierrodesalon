/* Aviso de cookies - Hierro de Salón
   - Mientras la web NO use analítica ni seguimiento, se muestra un aviso compacto (un solo botón).
   - Si añades analítica, vuelve a un banner con Aceptar y Rechazar del mismo peso visual (criterio AEPD).
   - Hasta que el usuario acepte, no se carga nada que no sea técnico.
   - Para añadir analítica en el futuro, cárgala SOLO dentro de onAccept (abajo).
   - El consentimiento se guarda en localStorage ("hds-consent") durante 12 meses. */
(function(){
 var KEY="hds-consent",DAYS=365,VER=1;

 function read(){
  try{var c=JSON.parse(localStorage.getItem(KEY));
   if(c&&c.v===VER&&Date.now()-c.ts<DAYS*864e5)return c}catch(e){}
  return null;
 }
 function save(analytics){
  var c={v:VER,analytics:!!analytics,ts:Date.now()};
  try{localStorage.setItem(KEY,JSON.stringify(c))}catch(e){}
  apply(c);return c;
 }
 function apply(c){
  window.hdsConsent.state=c;
  document.dispatchEvent(new CustomEvent("hds-consent",{detail:c}));
  if(c.analytics)onAccept();
 }
 /* Punto de enganche: aquí iría el script de analítica (p. ej. Google Analytics) tras aceptar. */
 function onAccept(){}

 var css=".ck-b{position:fixed;left:12px;right:12px;bottom:12px;z-index:60;max-width:760px;margin:0 auto;padding:20px 22px;border-radius:20px;background:#0E1317;color:#E6EDF3;font:14px/1.55 Inter,system-ui,sans-serif;box-shadow:0 24px 60px -12px rgba(0,0,0,.6),0 0 0 1px rgba(255,255,255,.12)}"+
 ".ck-b h2{margin:0 0 6px;font:700 20px/1.1 'Barlow Condensed','Arial Narrow',sans-serif;letter-spacing:.04em;text-transform:uppercase;color:#fff}"+
 ".ck-b p{margin:0 0 14px;color:#B9C6D2}.ck-b a{color:#5EEAD4}"+
 ".ck-r{display:flex;flex-wrap:wrap;gap:10px}"+
 ".ck-x{flex:1 1 140px;padding:12px 18px;border-radius:12px;border:1px solid rgba(255,255,255,.3);background:transparent;color:#fff;font:600 14px Inter,system-ui,sans-serif;cursor:pointer}"+
 ".ck-x:hover{border-color:#5EEAD4}"+
 ".ck-x.ok{background:#F59E0B;border-color:#F59E0B;color:#1C1917;font-weight:700}.ck-x.ok:hover{background:#D97706;border-color:#D97706}"+
 ".ck-o{margin:0 0 14px;display:grid;gap:10px}"+
 ".ck-o label{display:flex;gap:12px;align-items:flex-start;padding:12px 14px;border-radius:12px;background:rgba(255,255,255,.06);cursor:pointer}"+
 ".ck-o input{margin-top:3px;width:18px;height:18px;accent-color:#5EEAD4}"+
 ".ck-o b{display:block;color:#fff}.ck-o span{color:#9FB0BF;font-size:13px}"+
 ".ck-s{display:flex;align-items:center;gap:14px;padding:12px 16px;border-radius:14px;font-size:13px;line-height:1.45}"+
 ".ck-s p{margin:0;flex:1}.ck-s .ck-x{flex:0 0 auto;padding:9px 16px}"+
 "@media(max-width:520px){.ck-b{left:0;right:0;bottom:0;border-radius:20px 20px 0 0}.ck-s{border-radius:14px 14px 0 0;padding:10px 12px;gap:10px;font-size:12px}}";
 var st=document.createElement("style");st.textContent=css;document.head.appendChild(st);

 var box=null;
 function close(){if(box){box.remove();box=null}}
 function show(cfg){
  close();
  box=document.createElement("div");box.className="ck-b";box.setAttribute("role","dialog");box.setAttribute("aria-label","Preferencias de cookies");
  var cur=window.hdsConsent.state;
  if(!cfg){
   /* Aviso compacto: la web no usa cookies de analítica ni de seguimiento, así que no hace falta pedir consentimiento. */
   box.className="ck-b ck-s";
   box.innerHTML='<p>Esta web no usa cookies de seguimiento. Al pulsar un producto sales a Amazon, que aplica su propia política. <a href="cookies">Más información</a></p>'+
   '<button class="ck-x ok" data-a="no">Entendido</button>';
  }else{
   box.innerHTML='<h2>Configurar cookies</h2><div class="ck-o">'+
   '<label><input type="checkbox" checked disabled><div><b>Técnicas (siempre activas)</b><span>Recuerdan tu elección de cookies. No recogen datos personales.</span></div></label>'+
   '<label><input type="checkbox" id="ck-an"'+(cur&&cur.analytics?" checked":"")+'><div><b>Analíticas</b><span>Miden de forma agregada el uso de la web. Actualmente no usamos ninguna.</span></div></label></div>'+
   '<div class="ck-r"><button class="ck-x" data-a="no">Rechazar todas</button><button class="ck-x ok" data-a="save">Guardar selección</button></div>';
  }
  box.addEventListener("click",function(e){
   var a=e.target.getAttribute&&e.target.getAttribute("data-a");if(!a)return;
   if(a==="yes"){save(true);close()}
   else if(a==="no"){save(false);close()}
   else if(a==="cfg"){show(true)}
   else if(a==="save"){save(document.getElementById("ck-an").checked);close()}
  });
  document.body.appendChild(box);
  var f=box.querySelector("button");if(f&&cfg)f.focus();
 }

 window.hdsConsent={state:null,open:function(){show(true)}};
 function init(){
  var c=read();
  if(c)apply(c);else show(false);
  document.addEventListener("click",function(e){
   var t=e.target.closest&&e.target.closest("[data-cookies]");
   if(t){e.preventDefault();show(true)}
  });
 }
 if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();
