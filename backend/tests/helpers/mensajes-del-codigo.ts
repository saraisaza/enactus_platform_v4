import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

import ts from 'typescript';

/**
 * Todos los mensajes de error que el servidor le puede mostrar a una persona,
 * sacados del código con el compilador de TypeScript (no con expresiones
 * regulares: un mensaje partido en tres líneas con `+`, o con un ternario
 * adentro, se lee igual que uno de una línea).
 *
 * Se buscan los argumentos de mensaje de `badRequest`, `unauthorized`,
 * `forbidden`, `notFound`, `conflict`, `payloadTooLarge`, `tooManyRequests` y
 * `new AppError(...)`, más lo que el manejador de errores pasa directo a
 * `traducir` (sus mensajes propios: JSON mal formado, error inesperado…).
 *
 * Cada interpolación `${...}` queda como `{0}`, `{1}`… —la misma forma que
 * usa el catálogo de `src/i18n/mensajes.ts`—. Un ternario entre dos textos
 * produce los dos mensajes por separado.
 */
export interface MensajeDelCodigo {
  texto: string;
  archivo: string;
  linea: number;
}

const AYUDANTES = new Set([
  'badRequest',
  'unauthorized',
  'forbidden',
  'notFound',
  'conflict',
  'payloadTooLarge',
  'tooManyRequests',
]);

/** Las variantes de texto de una expresión, o `null` si no es texto fijo. */
function textos(n: ts.Expression): string[] | null {
  if (ts.isParenthesizedExpression(n)) return textos(n.expression);
  if (ts.isStringLiteral(n) || ts.isNoSubstitutionTemplateLiteral(n)) {
    return [n.text];
  }
  if (ts.isTemplateExpression(n)) {
    let s = n.head.text;
    n.templateSpans.forEach((span, i) => {
      s += `{${i}}` + span.literal.text;
    });
    return [s];
  }
  if (ts.isConditionalExpression(n)) {
    const a = textos(n.whenTrue);
    const b = textos(n.whenFalse);
    if (a && b) return [...a, ...b];
    return a ?? b;
  }
  if (ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const a = textos(n.left);
    const b = textos(n.right);
    if (!a || !b) return null;
    // Al concatenar dos plantillas, la numeración de la segunda sigue a la
    // de la primera: `${a}. ` + `${b}` es «{0}. {1}», no «{0}. {0}».
    const out: string[] = [];
    for (const x of a) {
      const usados = (x.match(/\{\d+\}/g) ?? []).length;
      for (const y of b) {
        out.push(x + y.replace(/\{(\d+)\}/g, (_, d) => `{${Number(d) + usados}}`));
      }
    }
    return out;
  }
  return null;
}

function archivosTs(dir: string): string[] {
  const out: string[] = [];
  for (const nombre of readdirSync(dir)) {
    const p = join(dir, nombre);
    if (statSync(p).isDirectory()) out.push(...archivosTs(p));
    else if (p.endsWith('.ts')) out.push(p);
  }
  return out;
}

export function mensajesDelCodigo(raiz: string): MensajeDelCodigo[] {
  const src = join(raiz, 'src');
  const out: MensajeDelCodigo[] = [];
  const archivos = archivosTs(src)
    // El catálogo mismo no es fuente de mensajes.
    .filter((a) => !a.includes(join('src', 'i18n')))
    .map((archivo) => ({
      archivo,
      sf: ts.createSourceFile(archivo, readFileSync(archivo, 'utf8'), ts.ScriptTarget.ES2022, true),
    }));

  // Constantes de texto de todo `src`, por nombre: un mensaje puede vivir en
  // una constante exportada y lanzarse desde otro archivo.
  const constantes = new Map<string, { n: ts.Expression; sf: ts.SourceFile }[]>();
  for (const { sf } of archivos) {
    const buscar = (n: ts.Node) => {
      if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name) && n.initializer) {
        const lista = constantes.get(n.name.text) ?? [];
        lista.push({ n: n.initializer, sf });
        constantes.set(n.name.text, lista);
      }
      ts.forEachChild(n, buscar);
    };
    buscar(sf);
  }

  for (const { archivo, sf } of archivos) {
    const agregarDe = (n: ts.Expression, origen: ts.SourceFile) => {
      const t = textos(n);
      if (!t) return false;
      const linea = origen.getLineAndCharacterOfPosition(n.getStart()).line + 1;
      for (const texto of t) {
        if (texto.trim()) out.push({ texto, archivo: relative(raiz, origen.fileName), linea });
      }
      return true;
    };

    /**
     * El mensaje de un error. Si es una variable, se busca su valor: una
     * constante (`MENSAJE_LENGUAJE_NO_PERMITIDO`) o el parámetro de una
     * función de este archivo, en cuyo caso cuenta lo que le pasa cada llamada.
     */
    const agregar = (n: ts.Expression | undefined) => {
      if (!n || agregarDe(n, sf)) return;
      if (!ts.isIdentifier(n)) return;
      for (const c of constantes.get(n.text) ?? []) agregarDe(c.n, c.sf);
      // ¿Es un parámetro? Entonces, los argumentos de las llamadas.
      let f: ts.Node | undefined = n.parent;
      while (f && !ts.isFunctionDeclaration(f)) f = f.parent;
      if (!f || !ts.isFunctionDeclaration(f) || !f.name) return;
      const idx = f.parameters.findIndex((p) => ts.isIdentifier(p.name) && p.name.text === n.text);
      if (idx < 0) return;
      const nombre = f.name.text;
      const llamadas = (m: ts.Node) => {
        if (ts.isCallExpression(m) && ts.isIdentifier(m.expression) && m.expression.text === nombre) {
          const arg = m.arguments[idx];
          if (arg) agregarDe(arg, sf);
        }
        ts.forEachChild(m, llamadas);
      };
      llamadas(sf);
    };

    const visitar = (n: ts.Node) => {
      if (ts.isCallExpression(n) && ts.isIdentifier(n.expression) && AYUDANTES.has(n.expression.text)) {
        agregar(n.arguments[0]);
      }
      if (ts.isNewExpression(n) && ts.isIdentifier(n.expression) && n.expression.text === 'AppError') {
        agregar(n.arguments?.[2]);
      }
      // Lo que se pasa a traducir directamente (`t('…')`, `traducir('…', …)`).
      if (
        ts.isCallExpression(n) &&
        ts.isIdentifier(n.expression) &&
        (n.expression.text === 't' || n.expression.text === 'traducir')
      ) {
        agregar(n.arguments[0]);
      }
      // Los mensajes por defecto de `lib/errors.ts` (`message = 'No tiene
      // permiso para esto.'`).
      if (
        archivo.endsWith(join('lib', 'errors.ts')) &&
        ts.isParameter(n) &&
        ts.isIdentifier(n.name) &&
        n.name.text === 'message' &&
        n.initializer
      ) {
        agregar(n.initializer);
      }
      ts.forEachChild(n, visitar);
    };
    visitar(sf);
  }
  return out;
}
