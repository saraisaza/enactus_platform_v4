// Visor de PDF dentro de la página. Lo carga `lib/widgets/pdf_view_web.dart`.
//
// Por qué pdf.js y no un <iframe> con la URL firmada: el iframe depende de que
// `frame-src` de la CSP liste el bucket, y la CSP vive en CloudFront, fuera
// del repositorio. pdf.js se sirve desde el propio sitio (`script-src 'self'`)
// y baja el archivo con fetch, que ya está permitido: es el mismo camino por el
// que se suben los archivos.
//
// `pdfjs/` es la compilación `legacy` de pdfjs-dist 4.10.38, con extensión .js
// en vez de .mjs: `aws s3 sync` no siempre reconoce .mjs, y un módulo servido
// como application/octet-stream el navegador lo rechaza.

const BASE = new URL('pdfjs/', document.baseURI).href;

let pdfjsCargado;

function cargarPdfjs() {
  pdfjsCargado ??= import(BASE + 'pdf.min.js').then((pdfjs) => {
    pdfjs.GlobalWorkerOptions.workerSrc = BASE + 'pdf.worker.min.js';
    return pdfjs;
  });
  return pdfjsCargado;
}

/**
 * Dibuja el PDF de `url` dentro de `contenedor`, una página debajo de otra.
 *
 * Las páginas se dibujan a medida que entran en pantalla: un PDF de cien
 * páginas no se rasteriza entero de entrada.
 *
 * Nunca rechaza: resuelve con '' si se dibujó, o con el mensaje para mostrar
 * si no. Un string es más fácil de cruzar a Dart que un `Error` de JS.
 */
export async function mostrarPdf(contenedor, url) {
  try {
    await dibujarDocumento(contenedor, url);
    return '';
  } catch (error) {
    return error instanceof Error && error.message
      ? error.message
      : 'No se pudo mostrar el PDF.';
  }
}

async function dibujarDocumento(contenedor, url) {
  let pdfjs;
  try {
    pdfjs = await cargarPdfjs();
  } catch (_) {
    pdfjsCargado = undefined; // que el próximo intento vuelva a probar
    throw new Error('No se pudo cargar el visor de PDF. Recargue la página.');
  }

  let respuesta;
  try {
    respuesta = await fetch(url);
  } catch (_) {
    throw new Error('No se pudo descargar el archivo. Revise su conexión.');
  }
  if (!respuesta.ok) {
    throw new Error(`No se pudo descargar el archivo (${respuesta.status}).`);
  }
  const datos = new Uint8Array(await respuesta.arrayBuffer());

  let documento;
  try {
    documento = await pdfjs.getDocument({
      data: datos,
      // Sin esto pdf.js prueba `new Function`, que la CSP bloquea.
      isEvalSupported: false,
    }).promise;
  } catch (_) {
    throw new Error('El archivo no es un PDF válido o está dañado.');
  }

  contenedor.replaceChildren();

  const observador = new IntersectionObserver(
    (entradas) => {
      for (const entrada of entradas) {
        if (!entrada.isIntersecting) continue;
        observador.unobserve(entrada.target);
        dibujarPagina(documento, entrada.target);
      }
    },
    { root: contenedor, rootMargin: '600px 0px' },
  );

  for (let n = 1; n <= documento.numPages; n++) {
    const base = (await documento.getPage(n)).getViewport({ scale: 1 });

    // El ancho lo pone el CSS y el alto sale de la proporción de la página:
    // así sirve igual en un teléfono que en un monitor, sin medir nada antes
    // de que el contenedor exista en pantalla.
    const hoja = document.createElement('div');
    hoja.dataset.pagina = String(n);
    hoja.style.cssText =
      'width:calc(100% - 32px);max-width:900px;margin:16px auto;' +
      `aspect-ratio:${base.width}/${base.height};` +
      'background:#fff;box-shadow:0 2px 8px rgba(0,0,0,.4);';
    contenedor.appendChild(hoja);
    observador.observe(hoja);
  }
}

async function dibujarPagina(documento, hoja) {
  const pagina = await documento.getPage(Number(hoja.dataset.pagina));
  const base = pagina.getViewport({ scale: 1 });
  const viewport = pagina.getViewport({
    scale: (hoja.clientWidth / base.width) * (window.devicePixelRatio || 1),
  });

  const lienzo = document.createElement('canvas');
  lienzo.width = Math.floor(viewport.width);
  lienzo.height = Math.floor(viewport.height);
  lienzo.style.cssText = 'width:100%;height:100%;display:block;';
  hoja.appendChild(lienzo);

  await pagina.render({ canvasContext: lienzo.getContext('2d'), viewport })
    .promise;
}
