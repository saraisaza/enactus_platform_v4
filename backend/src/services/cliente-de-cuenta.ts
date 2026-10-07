import { eq } from 'drizzle-orm';

import type { Database } from '../db/client';
import { clients } from '../db/schema';
import { createDownloadUrl, isStorageConfigured } from '../lib/s3';
import { AppError, conflict } from '../lib/errors';

/**
 * A qué cliente puede pertenecer una cuenta, y la marca que ve al entrar.
 *
 * Las reglas salen de cómo funciona cada cliente:
 * - **Administración es de eduXaction**: admin y superadmin no llevan cliente.
 * - **Enactus** (el cliente con laboratorios) tiene sus cuentas especiales:
 *   estudiantes eduXaction, asesores, mentores de laboratorio, donantes y
 *   empresas aliadas. Un estudiante de Open Learning no va ahí: no tiene
 *   laboratorios ni Ruta.
 * - **Una empresa cliente** funciona como Open Learning con su marca: sus
 *   estudiantes son de Open Learning, y puede tener sus propios LXD.
 * - Sin cliente = de eduXaction directamente (LXD propios, Open Learning sin
 *   empresa).
 */

/** Roles de la red Enactus que no son estudiantes. */
const ROLES_DE_LA_RED = ['advisor', 'mentor', 'donor', 'company'] as const;

const esEstudiante = (role: string) => role === 'student' || role === 'alumni';

type Cuenta = { role: string; studentType: string | null | undefined };

/** El cliente que le toca a una cuenta cuando nadie lo eligió. */
async function clientePorDefecto(db: Database, cuenta: Cuenta): Promise<string | null> {
  const esDeEnactus =
    (esEstudiante(cuenta.role) && cuenta.studentType === 'enactus') ||
    (ROLES_DE_LA_RED as readonly string[]).includes(cuenta.role);
  if (!esDeEnactus) return null;
  const [enactus] = await db
    .select({ id: clients.id })
    .from(clients)
    .where(eq(clients.hasLaboratories, true))
    .limit(1);
  return enactus?.id ?? null;
}

/**
 * El cliente con el que queda la cuenta, ya validado.
 *
 * [pedido]: `undefined` = no lo mandaron (alta: el que le toca; edición: el
 * que tenía, si sigue siendo válido para su rol y tipo — si no, el que le
 * toca); `null` = sin cliente; un id = ese cliente.
 */
export async function clienteParaCuenta(
  db: Database,
  cuenta: Cuenta,
  pedido: string | null | undefined,
  anterior?: string | null,
): Promise<string | null> {
  if (cuenta.role === 'admin' || cuenta.role === 'superadmin') {
    if (pedido) {
      throw conflict('Administración es de eduXaction: una cuenta de admin no lleva cliente.');
    }
    return null;
  }

  if (pedido === undefined) {
    if (anterior !== undefined && anterior !== null) {
      // Edición sin tocar el cliente: se conserva si sigue valiendo para el
      // rol y el tipo nuevos. Pasar a un estudiante de eduXaction a Open
      // Learning lo saca de Enactus; al revés, lo lleva.
      // Sin exigir que esté activo: editar el teléfono de alguien cuyo
      // cliente está desactivado no puede sacarlo de su cliente en silencio.
      try {
        await validar(db, cuenta, anterior, { exigirActivo: false });
        return anterior;
      } catch {
        return clientePorDefecto(db, cuenta);
      }
    }
    if (anterior === null && !debeSerDeEnactus(cuenta)) return null;
    return clientePorDefecto(db, cuenta);
  }
  if (pedido === null) {
    if (debeSerDeEnactus(cuenta)) {
      throw conflict(
        'Esta cuenta es de la red Enactus: tiene que pertenecer al cliente Enactus.',
      );
    }
    return null;
  }
  // Conservar el que ya tenía no es asignar: no se le exige que esté activo.
  await validar(db, cuenta, pedido, { exigirActivo: pedido !== anterior });
  return pedido;
}

/** Estudiantes eduXaction y cuentas de la red: no pueden quedar sin Enactus. */
function debeSerDeEnactus(cuenta: Cuenta): boolean {
  return (
    (esEstudiante(cuenta.role) && cuenta.studentType === 'enactus') ||
    (ROLES_DE_LA_RED as readonly string[]).includes(cuenta.role)
  );
}

async function validar(
  db: Database,
  cuenta: Cuenta,
  clientId: string,
  { exigirActivo }: { exigirActivo: boolean },
): Promise<void> {
  const [cliente] = await db
    .select({ name: clients.name, active: clients.active, labs: clients.hasLaboratories })
    .from(clients)
    .where(eq(clients.id, clientId))
    .limit(1);
  if (!cliente) throw conflict('No existe ese cliente.');
  if (exigirActivo && !cliente.active) {
    throw conflict(`${cliente.name} está desactivado: no admite cuentas.`);
  }

  if (cliente.labs) {
    if (esEstudiante(cuenta.role) && cuenta.studentType !== 'enactus') {
      throw conflict(
        `${cliente.name} es para cuentas eduXaction, con laboratorios y Ruta. Una cuenta de Open Learning va sin cliente o en una empresa.`,
      );
    }
    return;
  }

  // Una empresa cliente: Open Learning con su marca.
  if (esEstudiante(cuenta.role) && cuenta.studentType !== 'open_learning') {
    throw conflict(
      `${cliente.name} es una empresa: sus estudiantes son de Open Learning. Las cuentas eduXaction pertenecen a Enactus.`,
    );
  }
  if ((ROLES_DE_LA_RED as readonly string[]).includes(cuenta.role)) {
    throw conflict(
      `Asesores, mentores de laboratorio, donantes y empresas aliadas son de la red Enactus: no pueden pertenecer a ${cliente.name}.`,
    );
  }
}

/**
 * Corta el paso a una cuenta cuyo cliente está desactivado.
 *
 * Va en los tres lugares por donde se entra: el inicio de sesión, la
 * renovación de la sesión y CADA pedido con sesión (`requireAuth`). Con solo el
 * primero, quien ya tenía la sesión abierta seguiría adentro hasta que venciera
 * —doce horas— después de desactivado su cliente.
 *
 * 403 con su propio código (`client_inactive`): la app lo distingue de una
 * contraseña equivocada y le dice a la persona qué pasa y con quién hablar.
 */
export async function exigirClienteActivo(
  db: Database,
  user: { clientId: string | null },
): Promise<void> {
  if (!user.clientId) return;
  const [cliente] = await db
    .select({ name: clients.name, active: clients.active })
    .from(clients)
    .where(eq(clients.id, user.clientId))
    .limit(1);
  if (cliente && !cliente.active) {
    throw new AppError(
      403,
      'client_inactive',
      `El acceso de ${cliente.name} a la plataforma está desactivado. Si cree que es un error, comuníquese con quien administra la plataforma en su organización.`,
    );
  }
}

/** La marca que ve una cuenta al entrar, o `null` si no tiene cliente. */
export async function marcaDelCliente(db: Database, clientId: string | null) {
  if (!clientId) return null;
  const [c] = await db
    .select({
      id: clients.id,
      name: clients.name,
      logoS3Key: clients.logoS3Key,
      logoWidth: clients.logoWidth,
      logoHeight: clients.logoHeight,
      logoLightPlate: clients.logoLightPlate,
      primaryColor: clients.primaryColor,
      secondaryColor: clients.secondaryColor,
      hasLaboratories: clients.hasLaboratories,
    })
    .from(clients)
    .where(eq(clients.id, clientId))
    .limit(1);
  if (!c) return null;

  let logoUrl: string | null = null;
  if (c.logoS3Key && isStorageConfigured()) {
    try {
      logoUrl = (await createDownloadUrl({ key: c.logoS3Key })).url;
    } catch {
      // Sin logo antes que sin sesión: el encabezado muestra el nombre.
    }
  }
  const { logoS3Key: _key, ...resto } = c;
  return { ...resto, logoUrl };
}
