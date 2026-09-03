import { readFileSync } from 'node:fs';
import postgres from 'postgres';

/**
 * Lambda de administración de la base.
 *
 * Existe porque la instancia vive en una subred privada sin salida a internet
 * —que es justo lo que se quería— y eso deja sin camino a tres cosas que hay
 * que poder hacer igual: crear la segunda base y los usuarios por base,
 * aplicar migraciones, y sembrar producción con `seed:prod`.
 *
 * La alternativa era abrir la instancia a internet "un rato" para hacerlo a
 * mano. Esto cuesta lo mismo (nada, dentro del millón de invocaciones
 * gratuitas al mes) y no abre nada.
 *
 * **Las credenciales llegan en la invocación, no se guardan.** Quien invoca
 * corre fuera de la VPC y lee Secrets Manager fresco. Importa porque la
 * contraseña maestra la rota RDS sola cada 7 días: cualquier copia que esta
 * función guardara quedaría vencida antes de la semana siguiente.
 */

// El bundle de CA de RDS viaja en el paquete y se valida de verdad. Conectar
// con `ssl: 'require'` a secas cifra el tráfico pero acepta cualquier
// certificado — es decir, no protege de que alguien se ponga en el medio, que
// es de lo único que protege TLS.
const ca = readFileSync(new URL('./rds-ca.pem', import.meta.url), 'utf8');

/** Nunca devolver la contraseña, ni siquiera dentro de un error. */
const limpiar = (texto, secreto) =>
  secreto ? String(texto).split(secreto).join('«contraseña»') : String(texto);

/**
 * Tapa cualquier literal de contraseña dentro de una sentencia SQL.
 *
 * Hace falta porque el DDL no se puede parametrizar: `CREATE ROLE ... PASSWORD
 * 'x'` lleva la contraseña en el texto. Sin esto, el eco de la sentencia en la
 * respuesta —y en los logs de CloudWatch— la mostraría.
 */
const taparClaves = (sql) =>
  sql.replace(/(password\s+)'[^']*'/gi, "$1'«oculta»'");

export async function handler(evento) {
  const {
    host,
    port = 5432,
    user,
    password,
    database,
    statements,
    /**
     * Conectar SIN TLS, a propósito.
     *
     * Existe para UNA cosa: comprobar que el servidor rechaza el texto plano,
     * que es la única forma de verificar `rds.force_ssl` de verdad — dentro de
     * PostgreSQL ese parámetro no se puede consultar.
     *
     * No debilita nada: quien decide es el servidor. Si `force_ssl` está
     * puesto, esta opción solo consigue un rechazo; si algún día alguien la
     * usara esperando conectar, el fallo sería la prueba de que la protección
     * funciona.
     */
    sinTls = false,
  } = evento ?? {};

  if (!host || !user || !password || !database) {
    throw new Error(
      'Faltan datos de conexión: host, user, password y database son obligatorios.',
    );
  }
  if (!Array.isArray(statements) || statements.length === 0) {
    throw new Error('No mandaste ninguna sentencia en `statements`.');
  }

  const sql = postgres({
    host,
    port,
    user,
    password,
    database,
    ssl: sinTls ? false : { ca, rejectUnauthorized: true },
    max: 1,
    prepare: false,
    idle_timeout: 5,
    connect_timeout: 10,
    onnotice: () => undefined,
  });

  const resultados = [];
  try {
    for (const sentencia of statements) {
      const texto = typeof sentencia === 'string' ? sentencia : sentencia?.sql;
      if (!texto) throw new Error('Una sentencia llegó vacía.');
      const filas = await sql.unsafe(texto);
      resultados.push({
        // Se devuelve la sentencia recortada para poder seguir el hilo en la
        // salida, no la completa: una sentencia puede llevar una contraseña.
        sentencia: taparClaves(texto).slice(0, 80).replace(/\s+/g, ' '),
        filas: filas.length,
        datos: filas.slice(0, 50),
      });
    }
    return { ok: true, resultados };
  } catch (error) {
    // El mensaje de PostgreSQL puede repetir lo que se le mandó, contraseña
    // incluida. Se limpia antes de devolverlo o registrarlo.
    const mensaje = limpiar(error?.message ?? error, password);
    console.error('[admin] falló:', mensaje);
    return { ok: false, error: mensaje, resultados };
  } finally {
    await sql.end({ timeout: 5 });
  }
}
