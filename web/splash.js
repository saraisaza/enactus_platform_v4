// Quita el splash cuando Flutter pinta su primer frame.
//
// Vive en un archivo propio y no en un `<script>` dentro de index.html por una
// razón concreta: la CSP de producción no permite scripts inline, así que un
// bloque inline queda BLOQUEADO en silencio — Flutter carga por debajo, el
// splash nunca se retira, y lo que ve la persona es una pantalla de carga
// eterna sin ningún error visible.
//
// Pasó exactamente eso el 3 de septiembre de 2026, en el primer despliegue.
// La alternativa era agregar 'unsafe-inline' a script-src, que abre la puerta
// a cualquier script inyectado; sacarlo a un archivo mantiene la CSP cerrada.
window.addEventListener('flutter-first-frame', function () {
  var splash = document.getElementById('enactus-splash');
  if (!splash) return;
  splash.style.opacity = '0';
  setTimeout(function () { splash.remove(); }, 400);
});

// Red de seguridad: si por lo que sea el evento no llega —un fallo de carga,
// un navegador que no lo dispara— el splash se va igual a los 15 segundos.
// Es preferible una pantalla rota y visible a una pantalla de carga infinita:
// la primera se reporta, la segunda se abandona.
setTimeout(function () {
  var splash = document.getElementById('enactus-splash');
  if (splash) splash.remove();
}, 15000);
