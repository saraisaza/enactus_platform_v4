#!/usr/bin/env node
/**
 * Pruebas de humo contra un entorno YA DESPLEGADO.
 *
 * No sustituyen a la suite de `vitest`: aquella prueba el código, esta prueba
 * el despliegue — que la Lambda arrancó, que alcanza la base, que CloudFront
 * sirve el frontend y que los permisos siguen puestos. Son cosas distintas y
 * fallan por motivos distintos.
 *
 *   node scripts/smoke.mjs --api https://staging-api.eduxaction.com \
 *                          --web https://staging.eduxaction.com
 *
 * Las que necesitan credenciales se saltan —anunciándolo— si no hay ninguna.
 * Saltarlas en silencio sería peor que no tenerlas: daría verde sin haber
 * probado nada.
 *
 * Sale con código 1 si algo falla. Ese código es el que dispara el rollback.
 */

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pares, actual, i, todos) => {
    if (actual.startsWith('--')) pares.push([actual.slice(2), todos[i + 1]]);
    return pares;
  }, []),
);

const API = (args.api ?? process.env.SMOKE_API ?? '').replace(/\/$/, '');
const WEB = (args.web ?? process.env.SMOKE_WEB ?? '').replace(/\/$/, '');
const VIDEOS = args.videos ?? process.env.SMOKE_VIDEOS ?? 'https://videos.eduxaction.com';

if (!API || !WEB) {
  console.error('Faltan --api y --web (o SMOKE_API y SMOKE_WEB).');
  process.exit(2);
}

/**
 * Credenciales por rol. En staging son las de demostración, que no son
 * secretas. En producción NO existen: se pasan por variable de entorno desde
 * los secretos de GitHub, y si no están, esas pruebas se saltan.
 */
const CUENTAS = process.env.SMOKE_CUENTAS
  ? JSON.parse(process.env.SMOKE_CUENTAS)
  : args.demo === 'si'
    ? {
        admin: ['admin@enactus.co', 'Admin123'],
        lxd: ['lxd.ia@enactus.co', 'Lxd123'],
        mentor: ['mentor.ia@enactus.co', 'Mentor123'],
        asesor: ['asesor@uniandes.edu.co', 'Asesor123'],
        empresa: ['empresa@bancolombia.com', 'Empresa123'],
        donante: ['donante@gmail.com', 'Donante123'],
        enactus: ['estudiante1@uniandes.edu.co', 'Est123'],
        openLearning: ['camila.rivas@gmail.com', 'Est123'],
      }
    : null;

let fallos = 0;
let saltadas = 0;

async function prueba(nombre, fn) {
  const t0 = Date.now();
  try {
    await fn();
    console.log(`  ok    ${nombre}  (${Date.now() - t0} ms)`);
  } catch (error) {
    fallos++;
    console.log(`  FALLA ${nombre}  (${Date.now() - t0} ms)`);
    console.log(`        ${error.message}`);
  }
}

function saltar(nombre, motivo) {
  saltadas++;
  console.log(`  salta ${nombre}  — ${motivo}`);
}

function igual(actual, esperado, que) {
  if (actual !== esperado) throw new Error(`${que}: esperaba ${esperado}, llegó ${actual}`);
}

async function login(correo, clave) {
  const r = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', origin: WEB },
    body: JSON.stringify({ email: correo, password: clave }),
  });
  if (!r.ok) throw new Error(`login de ${correo}: ${r.status} ${(await r.text()).slice(0, 160)}`);
  const cuerpo = await r.json();
  const token = cuerpo.accessToken ?? cuerpo.token ?? cuerpo.access_token;
  if (!token) throw new Error(`login de ${correo}: la respuesta no trae token (${Object.keys(cuerpo)})`);
  return { token, usuario: cuerpo.user ?? cuerpo.usuario };
}

const conToken = (token) => ({ authorization: `Bearer ${token}`, origin: WEB });

console.log(`\nPruebas de humo\n  api  ${API}\n  web  ${WEB}\n`);

// --- Sin credenciales -------------------------------------------------------

await prueba('GET /health responde 200', async () => {
  const r = await fetch(`${API}/health`);
  igual(r.status, 200, 'estado');
  const cuerpo = await r.json();
  if (cuerpo.status !== 'ok') throw new Error(`status = ${cuerpo.status}`);
});

await prueba('el frontend carga y trae el arranque de Flutter', async () => {
  const r = await fetch(`${WEB}/`);
  igual(r.status, 200, 'estado');
  const html = await r.text();
  if (!/flutter_bootstrap\.js|main\.dart\.js/.test(html)) {
    throw new Error('el HTML no referencia el bundle de Flutter');
  }
});

await prueba('una ruta del cliente devuelve la aplicación, no un 404', async () => {
  const r = await fetch(`${WEB}/login`);
  igual(r.status, 200, 'estado de /login');
});

await prueba('el frontend llega con las cabeceras de seguridad', async () => {
  const r = await fetch(`${WEB}/`);
  const csp = r.headers.get('content-security-policy');
  if (!csp) throw new Error('no llegó content-security-policy');
  const apiEnCsp = new URL(API).origin;
  if (!csp.includes(apiEnCsp)) {
    throw new Error(`la CSP no permite ${apiEnCsp} en connect-src — el frontend no podrá hablar con su API`);
  }
  for (const cabecera of ['strict-transport-security', 'x-content-type-options', 'x-frame-options']) {
    if (!r.headers.get(cabecera)) throw new Error(`falta ${cabecera}`);
  }
});

await prueba('un video sin firmar da 403', async () => {
  const r = await fetch(`${VIDEOS}/no-existe/video.mp4`, { redirect: 'manual' });
  igual(r.status, 403, 'estado de un video sin firma');
});

await prueba('un origen ajeno no recibe permiso de CORS', async () => {
  const r = await fetch(`${API}/auth/login`, {
    method: 'OPTIONS',
    headers: {
      origin: 'https://sitio-que-no-es-nuestro.example',
      'access-control-request-method': 'POST',
      'access-control-request-headers': 'content-type',
    },
  });
  const permitido = r.headers.get('access-control-allow-origin');
  if (permitido === 'https://sitio-que-no-es-nuestro.example' || permitido === '*') {
    throw new Error(`CORS le abrió a un origen ajeno: ${permitido}`);
  }
});

await prueba('el origen propio sí recibe permiso de CORS, con PUT entre los métodos', async () => {
  const r = await fetch(`${API}/auth/login`, {
    method: 'OPTIONS',
    headers: { origin: WEB, 'access-control-request-method': 'PUT', 'access-control-request-headers': 'content-type' },
  });
  const permitido = r.headers.get('access-control-allow-origin');
  if (permitido !== WEB) throw new Error(`allow-origin = ${permitido}, esperaba ${WEB}`);
  const metodos = r.headers.get('access-control-allow-methods') ?? '';
  if (!/PUT/i.test(metodos)) {
    throw new Error(`PUT no está en allow-methods (${metodos}) — el navegador bloqueará toda escritura`);
  }
});

// --- Con credenciales -------------------------------------------------------

if (!CUENTAS) {
  saltar('ingreso por rol', 'no hay credenciales (pase --demo si o SMOKE_CUENTAS)');
  saltar('un estudiante Enactus abre su Ruta de Impacto', 'idem');
  saltar('un Open Learning recibe 403 en lo de Enactus', 'idem');
  saltar('un LXD lista sus cursos', 'idem');
} else {
  const sesiones = {};

  for (const [rol, [correo, clave]] of Object.entries(CUENTAS)) {
    await prueba(`ingresa ${rol}`, async () => {
      sesiones[rol] = await login(correo, clave);
    });
  }

  await prueba('un estudiante Enactus abre su Ruta de Impacto', async () => {
    const s = sesiones.enactus;
    if (!s) throw new Error('no se pudo ingresar como estudiante Enactus');
    const r = await fetch(`${API}/students/${s.usuario.id}/ruta-progress`, { headers: conToken(s.token) });
    igual(r.status, 200, 'estado');
    const cuerpo = await r.json();
    if (cuerpo == null) throw new Error('respuesta vacía');
  });

  await prueba('un Open Learning recibe 403 en lo de Enactus', async () => {
    const s = sesiones.openLearning;
    if (!s) throw new Error('no se pudo ingresar como estudiante Open Learning');
    const r = await fetch(`${API}/students/${s.usuario.id}/ruta-progress`, { headers: conToken(s.token) });
    igual(r.status, 403, 'estado');
  });

  await prueba('un LXD lista sus cursos', async () => {
    const s = sesiones.lxd;
    if (!s) throw new Error('no se pudo ingresar como LXD');
    const r = await fetch(`${API}/courses`, { headers: conToken(s.token) });
    igual(r.status, 200, 'estado');
    const cuerpo = await r.json();
    const lista = Array.isArray(cuerpo) ? cuerpo : (cuerpo.items ?? cuerpo.data);
    if (!Array.isArray(lista)) throw new Error(`no llegó una lista: ${Object.keys(cuerpo)}`);
  });

  await prueba('el frontend autentica de verdad contra la API', async () => {
    const s = sesiones.admin ?? Object.values(sesiones)[0];
    if (!s) throw new Error('ninguna sesión disponible');
    const r = await fetch(`${API}/auth/me`, { headers: conToken(s.token) });
    igual(r.status, 200, 'estado de /auth/me');
  });

  await prueba('un token inventado no entra', async () => {
    const r = await fetch(`${API}/auth/me`, { headers: conToken('esto.no.es-un-token') });
    if (r.status !== 401) throw new Error(`esperaba 401, llegó ${r.status}`);
  });

  // Los dos entornos comparten instancia de base. Lo único que impide que una
  // sesión de staging valga en producción es que el `JWT_SECRET` sea distinto
  // — y eso se rompe en silencio el día que alguien copie un secreto de un
  // entorno al otro «para probar». No hay error, no hay log: simplemente los
  // tokens empiezan a valer en los dos lados.
  const OTRA = (args['otra-api'] ?? process.env.SMOKE_OTRA_API ?? '').replace(/\/$/, '');
  if (!OTRA) {
    saltar('un token de este entorno no vale en el otro', 'no se pasó --otra-api');
  } else {
    await prueba('un token de este entorno no vale en el otro', async () => {
      const s = Object.values(sesiones).find(Boolean);
      if (!s) throw new Error('ninguna sesión disponible');
      const r = await fetch(`${OTRA}/auth/me`, { headers: conToken(s.token) });
      if (r.status !== 401) {
        throw new Error(
          `${OTRA} aceptó un token de ${API} con ${r.status}. ` +
            'Los dos entornos comparten JWT_SECRET: una sesión de uno vale en el otro.',
        );
      }
    });
  }
}

console.log(`\n${fallos === 0 ? 'TODO EN VERDE' : `${fallos} FALLA(S)`}${saltadas ? ` · ${saltadas} saltada(s)` : ''}\n`);
process.exit(fallos === 0 ? 0 : 1);
