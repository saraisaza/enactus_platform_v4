import type * as schema from '../db/schema';

type UserRow = typeof schema.users.$inferSelect;

/**
 * Usuario tal como sale de la API.
 *
 * `passwordHash` NUNCA se incluye — ni acá, ni en el respaldo. Hoy
 * `DataProvider.users` devuelve el objeto completo con la contraseña en texto
 * plano a cualquier pantalla, y `exportBackupJson()` la vuelca a un archivo
 * descargable (AUDITORIA_BACKEND.md § A.8.1).
 */
export function publicUser(user: UserRow) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    studentType: user.studentType,
    phone: user.phone,
    cedula: user.cedula,
    city: user.city,
    university: user.university,
    universityId: user.universityId,
    career: user.career,
    companyName: user.companyName,
    impactCode: user.impactCode,
    companyId: user.companyId,
    donorId: user.donorId,
    avatarS3Key: user.avatarS3Key,
    canGradeOpenLearning: user.canGradeOpenLearning,
    canGradeEnactus: user.canGradeEnactus,
    profile: user.profile,
    joinedAt: user.joinedAt,
  };
}

/**
 * Versión reducida para quien no debería ver datos personales: la usan
 * BuscaTalento (Donante y Empresa ven a TODOS los estudiantes Enactus) y
 * cualquier listado de terceros.
 *
 * Sin cédula, sin teléfono, sin correo — decisión C.2 de la Fase 0: la
 * función se mantiene, la exposición que no se usa se recorta.
 */
export function limitedUser(user: UserRow) {
  return {
    id: user.id,
    name: user.name,
    role: user.role,
    university: user.university,
    universityId: user.universityId,
    career: user.career,
    city: user.city,
    avatarS3Key: user.avatarS3Key,
    // El nombre comercial no es un dato personal: es cómo se llama la
    // organización, y ya aparece como patrocinador en todo el resto de la
    // plataforma. Sin él, una lista de empresas no se puede ni etiquetar.
    companyName: user.companyName,
  };
}
