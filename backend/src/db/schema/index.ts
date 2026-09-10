/**
 * Esquema completo de la base. Drizzle lee este archivo para generar las
 * migraciones (ver `drizzle.config.ts`).
 *
 * Mapa rápido de dónde vive cada cosa:
 * - `enums`        — todos los enums del dominio
 * - `catalogs`     — ODS y competencias (catálogos fijos, hoy constantes Dart)
 * - `universities` — universidades (unidad de visibilidad del asesor)
 * - `users`        — usuarios, refresh tokens, bitácora de auditoría
 * - `orgs`         — proyectos, equipos e integrantes
 * - `labs`         — laboratorios, fases, objetivos y módulos de la Ruta
 * - `courses`      — cursos, módulos, lecciones, quiz y actividades
 * - `links`        — tablas puente entre cursos, Ruta y personas
 * - `progress`     — progreso de curso y de Ruta de Impacto
 * - `submissions`  — entregas, archivos, intentos de quiz, certificados
 * - `content`      — evidencias, recursos, foro, calendario, sitio, notas
 */
export * from './enums';
export * from './catalogs';
export * from './universities';
export * from './users';
export * from './orgs';
export * from './labs';
export * from './courses';
export * from './links';
export * from './progress';
export * from './submissions';
export * from './content';
