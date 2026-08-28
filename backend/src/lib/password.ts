import bcrypt from 'bcryptjs';

/**
 * Hasheo de contraseñas.
 *
 * `bcryptjs` (JavaScript puro) en vez del `bcrypt` nativo: el nativo compila
 * con node-gyp y obliga a empaquetar un binario por arquitectura en el bundle
 * de Lambda (x86_64 vs arm64), que es una fuente clásica de despliegues rotos.
 * El algoritmo es el mismo; el costo es unos ~100 ms por hash, que solo se
 * paga en login y en creación de cuentas.
 */
const COST = 10;

export function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, COST);
}

export function verifyPassword(
  plain: string,
  hash: string,
): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}
