import { sql } from 'drizzle-orm';

import type { Database } from '../db/client';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import { isStudentLike } from '../middleware/auth';
import type { AuthUser } from '../middleware/context';

/**
 * Quién puede LEER qué archivo.
 *
 * Una URL firmada de lectura es un permiso que después viaja suelto, sin token
 * y sin sesión: quien tenga el enlace abre el objeto. Por eso la autorización
 * no puede estar en el prefijo de la key —eso es adivinar— sino en la fila que
 * la referencia.
 *
 * El procedimiento es siempre el mismo:
 *
 * 1. Se busca la key en las tablas que pueden contenerla. Cada tabla trae su
 *    propia regla de visibilidad, la MISMA que ya usa el listado
 *    correspondiente: si un donante solo ve sus evidencias en
 *    `GET /evidences`, tampoco puede firmar la foto de otro.
 * 2. Si ninguna tabla la referencia → 404. No 403: una key que nadie referencia
 *    no existe para esta API, y un 403 confirmaría que el objeto está en el
 *    bucket.
 *
 * Los videos quedan deliberadamente fuera (ver [assertNotVideo]).
 */

/** Lo que se sabe de un archivo una vez autorizado. */
export type FileGrant = {
  key: string;
  fileName: string | null;
  contentType: string | null;
  /** De dónde salió el permiso. Va al log, no a la respuesta. */
  source: string;
};

/**
 * El video NUNCA se sirve por S3 directo.
 *
 * Es una decisión de costo, no de estilo: la transferencia de salida de S3 se
 * cobra desde el primer byte, mientras que CloudFront trae 1 TB al mes. Servir
 * un curso en video desde S3 firmado es la forma más cara de hacerlo.
 *
 * Se rechaza acá, en el único punto que firma lecturas, para que la regla no
 * dependa de que nadie se olvide.
 */
async function assertNotVideo(db: Database, key: string): Promise<void> {
  const rechazar = (): never => {
    throw badRequest(
      'Los videos no se sirven por URL firmada de S3: se reproducen por CloudFront. ' +
        'Usá GET /lessons/:id/video-url o GET /courses/:id/intro-video-url.',
      { key },
    );
  };

  // Camino rápido: es la forma que genera `videoKeyFor`, así que cubre todo lo
  // que se suba de acá en adelante sin tocar la base.
  if (/^lessons\//.test(key) || /^course-intros\//.test(key)) rechazar();

  // Y el camino seguro, que es el que manda: el prefijo es una convención de
  // nombres y este archivo entero existe porque adivinar por el prefijo no
  // alcanza. Las keys del seed —`lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4`—
  // no empiezan por `lessons/` y la regla de costo tiene que valer igual.
  const [video] = await db.execute<{ ok: number }>(sql`
    select 1 as ok
      from lessons where video_s3_key = ${key}
     union all
    select 1 as ok
      from courses where intro_video_s3_key = ${key} and deleted_at is null
     limit 1
  `);
  if (video) rechazar();
}

/**
 * Resuelve y autoriza una key. Devuelve el permiso, o lanza 404/403.
 *
 * El orden de las consultas no es casual: las más baratas y frecuentes
 * (avatares) van primero.
 */
export async function authorizeFileRead(
  db: Database,
  user: AuthUser,
  key: string,
): Promise<FileGrant> {
  await assertNotVideo(db, key);

  const isAdmin = user.role === 'admin' || user.role === 'superadmin';

  // --- Avatares --------------------------------------------------------
  // Visibles para cualquier cuenta con sesión: la foto de perfil ya aparece
  // en el directorio de proyectos, en el foro y en los listados de equipo.
  const [avatar] = await db.execute<{ name: string }>(sql`
    select name from users
     where avatar_s3_key = ${key} and deleted_at is null
     limit 1
  `);
  if (avatar) {
    return { key, fileName: null, contentType: null, source: 'avatar' };
  }

  // --- Galería del landing ---------------------------------------------
  const [gallery] = await db.execute<{ id: string }>(sql`
    select id from site_gallery_images where s3_key = ${key} limit 1
  `);
  if (gallery) {
    return { key, fileName: null, contentType: null, source: 'site_gallery' };
  }

  // --- Portada de curso -------------------------------------------------
  const [cover] = await db.execute<{
    id: string;
    laboratoryId: string | null;
    creatorId: string | null;
    status: string;
  }>(sql`
    select id, laboratory_id as "laboratoryId", creator_id as "creatorId", status
      from courses
     where cover_s3_key = ${key} and deleted_at is null
     limit 1
  `);
  if (cover) {
    await assertCourseVisible(db, user, cover.id);
    return { key, fileName: null, contentType: null, source: 'course_cover' };
  }

  // --- Recurso de una lección (PDF, plantilla, adjunto) ------------------
  // Una lección cuelga de un módulo de curso O de un módulo de Ruta —el CHECK
  // `lessons_exactly_one_parent` garantiza que sea exactamente uno— y cada
  // caso se autoriza distinto. `lessons` no tiene borrado lógico: se va con
  // su módulo.
  const [resource] = await db.execute<{
    courseId: string | null;
    laboratoryId: string | null;
    fileName: string | null;
    contentType: string | null;
  }>(sql`
    select cm.course_id as "courseId",
           ph.laboratory_id as "laboratoryId",
           l.resource_file_name as "fileName",
           l.resource_content_type as "contentType"
      from lessons l
      left join course_modules cm on cm.id = l.course_module_id
      left join ruta_modules rm on rm.id = l.ruta_module_id
      left join phases ph on ph.id = rm.phase_id
     where l.resource_s3_key = ${key}
     limit 1
  `);
  if (resource) {
    if (resource.courseId) {
      await assertCourseVisible(db, user, resource.courseId);
    } else if (resource.laboratoryId) {
      await assertLabVisible(db, user, resource.laboratoryId);
    } else {
      // Una lección sin ninguno de los dos padres no debería existir (lo
      // impide `lessons_exactly_one_parent`). Si aparece, no se firma.
      throw notFound('No encontramos ese archivo.');
    }
    return {
      key,
      fileName: resource.fileName,
      contentType: resource.contentType,
      source: 'lesson_resource',
    };
  }

  // --- Recurso de comunicaciones ---------------------------------------
  const [commResource] = await db.execute<{
    fileName: string | null;
    contentType: string | null;
  }>(sql`
    select file_name as "fileName", content_type as "contentType"
      from communication_resources
     where s3_key = ${key} and deleted_at is null
     limit 1
  `);
  if (commResource) {
    // Misma lista que `GET /communication-resources`.
    const readers = ['admin', 'superadmin', 'advisor', 'mentor', 'lxd'];
    if (!readers.includes(user.role)) {
      throw forbidden('Los recursos de comunicaciones son para el equipo docente.');
    }
    return { ...commResource, key, source: 'communication_resource' };
  }

  // --- Evidencia de impacto --------------------------------------------
  const [evidence] = await db.execute<{
    donorId: string;
    fileName: string | null;
    contentType: string | null;
  }>(sql`
    select donor_id as "donorId", file_name as "fileName",
           content_type as "contentType"
      from evidences
     where s3_key = ${key} and deleted_at is null
     limit 1
  `);
  if (evidence) {
    // Misma regla que `GET /evidences`: el donante ve las suyas, el admin
    // todas, nadie más tiene evidencias en su portal.
    if (!isAdmin && !(user.role === 'donor' && user.id === evidence.donorId)) {
      throw forbidden('Esta evidencia no es de tu portal.');
    }
    return {
      key,
      fileName: evidence.fileName,
      contentType: evidence.contentType,
      source: 'evidence',
    };
  }

  // --- Adjunto de una entrega ------------------------------------------
  const [attachment] = await db.execute<{
    submissionId: string;
    fileName: string;
    contentType: string;
  }>(sql`
    select submission_id as "submissionId", file_name as "fileName",
           content_type as "contentType"
      from submission_files
     where s3_key = ${key}
     limit 1
  `);
  if (attachment) {
    await assertSubmissionVisible(db, user, attachment.submissionId);
    return {
      key,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      source: 'submission_file',
    };
  }

  throw notFound('No encontramos ese archivo.');
}

/**
 * Autoriza la REPRODUCCIÓN del video propio de una lección.
 *
 * Es el otro lado de [assertNotVideo]: los videos no se firman por S3, pero
 * alguien tiene que poder verlos. La regla de acceso es exactamente la misma
 * que para el material de la lección —una lección cuelga de un módulo de curso
 * o de uno de Ruta, y cada caso se autoriza distinto—, así que se reusa
 * [assertCourseVisible] / [assertLabVisible] en vez de escribir una segunda
 * definición de "sus cursos" que pueda separarse de la primera.
 *
 * Devuelve la key. Firmar es responsabilidad de `lib/cloudfront.ts`.
 */
export async function authorizeLessonVideo(
  db: Database,
  user: AuthUser,
  lessonId: string,
): Promise<{ key: string }> {
  const [lesson] = await db.execute<{
    videoType: string | null;
    videoS3Key: string | null;
    videoUrl: string | null;
    courseId: string | null;
    laboratoryId: string | null;
  }>(sql`
    select l.video_type as "videoType",
           l.video_s3_key as "videoS3Key",
           l.video_url as "videoUrl",
           cm.course_id as "courseId",
           ph.laboratory_id as "laboratoryId"
      from lessons l
      left join course_modules cm on cm.id = l.course_module_id
      left join ruta_modules rm on rm.id = l.ruta_module_id
      left join phases ph on ph.id = rm.phase_id
     where l.id = ${lessonId}
     limit 1
  `);
  if (!lesson) throw notFound('No se encontró la lección.');

  // El acceso se comprueba ANTES de contar qué tipo de video tiene: si no,
  // el 409 "esta lección no tiene video propio" delataría la existencia y la
  // configuración de una lección ajena.
  if (lesson.courseId) {
    await assertCourseVisible(db, user, lesson.courseId);
  } else if (lesson.laboratoryId) {
    await assertLabVisible(db, user, lesson.laboratoryId);
  } else {
    throw notFound('No se encontró la lección.');
  }

  if (lesson.videoType !== 'uploaded' || !lesson.videoS3Key) {
    // Un video externo (YouTube/Vimeo) se abre con su propia URL, que ya viaja
    // en el detalle de la lección. Pedir una URL firmada para él es un error
    // del cliente, no una falta de permiso.
    throw conflict(
      lesson.videoType === 'external'
        ? 'Esta lección tiene video externo: se reproduce con su propia URL.'
        : 'Esta lección no tiene video propio.',
      { videoType: lesson.videoType },
    );
  }

  return { key: lesson.videoS3Key };
}

/**
 * Lo mismo para el video de introducción de un curso, que usa las mismas
 * columnas con prefijo `intro_video_`.
 */
export async function authorizeCourseIntroVideo(
  db: Database,
  user: AuthUser,
  courseId: string,
): Promise<{ key: string }> {
  const [course] = await db.execute<{
    id: string;
    introVideoType: string | null;
    introVideoS3Key: string | null;
  }>(sql`
    select id,
           intro_video_type as "introVideoType",
           intro_video_s3_key as "introVideoS3Key"
      from courses
     where id = ${courseId} and deleted_at is null
     limit 1
  `);
  if (!course) throw notFound('No se encontró el curso.');

  await assertCourseVisible(db, user, course.id);

  if (course.introVideoType !== 'uploaded' || !course.introVideoS3Key) {
    throw conflict(
      course.introVideoType === 'external'
        ? 'Este curso tiene video de intro externo: se reproduce con su propia URL.'
        : 'Este curso no tiene video de introducción propio.',
      { videoType: course.introVideoType },
    );
  }

  return { key: course.introVideoS3Key };
}

/**
 * ¿Puede esta persona ver este curso?
 *
 * Se apoya en `student_course_access`, la misma vista con la que el servidor
 * calcula la completitud: si un curso no está en el acceso de un estudiante,
 * tampoco cuenta para su avance. Una sola definición de "sus cursos".
 */
async function assertCourseVisible(
  db: Database,
  user: AuthUser,
  courseId: string,
): Promise<void> {
  if (user.role === 'admin' || user.role === 'superadmin') return;

  if (isStudentLike(user.role)) {
    const [row] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from student_course_access
       where student_id = ${user.id} and course_id = ${courseId}
       limit 1
    `);
    if (!row) throw notFound('No encontramos ese archivo.');
    return;
  }

  if (user.role === 'lxd') {
    const [row] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from courses
       where id = ${courseId} and creator_id = ${user.id} and deleted_at is null
       limit 1
    `);
    if (!row) throw notFound('No encontramos ese archivo.');
    return;
  }

  if (user.role === 'mentor') {
    const [row] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from courses c
       where c.id = ${courseId}
         and c.deleted_at is null
         and c.laboratory_id in (select lm.laboratory_id from laboratory_mentors lm
                                  where lm.user_id = ${user.id})
       limit 1
    `);
    if (!row) throw notFound('No encontramos ese archivo.');
    return;
  }

  // Asesor, Empresa y Donante no abren material de curso.
  throw forbidden('Tu rol no tiene acceso al material de este curso.');
}

/**
 * ¿Puede esta persona ver este laboratorio?
 *
 * Mismo alcance por rol que `scopeFor` en `routes/labs.ts`, expresado como una
 * comprobación de una sola fila. Un Open Learning nunca llega acá con un sí:
 * no está en `student_laboratories`.
 */
async function assertLabVisible(
  db: Database,
  user: AuthUser,
  laboratoryId: string,
): Promise<void> {
  if (user.role === 'admin' || user.role === 'superadmin') return;

  const clause = (() => {
    if (isStudentLike(user.role)) {
      return sql`exists (select 1 from student_laboratories sl
                          where sl.student_id = ${user.id}
                            and sl.laboratory_id = ${laboratoryId})`;
    }
    if (user.role === 'mentor') {
      return sql`exists (select 1 from laboratory_mentors lm
                          where lm.user_id = ${user.id}
                            and lm.laboratory_id = ${laboratoryId})`;
    }
    if (user.role === 'lxd') {
      return sql`exists (select 1 from courses c
                          where c.creator_id = ${user.id}
                            and c.laboratory_id = ${laboratoryId})`;
    }
    if (user.role === 'advisor') {
      return sql`exists (select 1 from student_laboratories sl
                           join users u on u.id = sl.student_id
                          where sl.laboratory_id = ${laboratoryId}
                            and u.university = ${user.university}
                            and u.university <> '')`;
    }
    return null;
  })();

  // Empresa y Donante no abren material formativo.
  if (!clause) {
    throw forbidden('Tu rol no tiene acceso al material de este laboratorio.');
  }

  const [ok] = await db.execute<{ ok: number }>(
    sql`select 1 as ok where ${clause}`,
  );
  if (!ok) throw notFound('No encontramos ese archivo.');
}

/**
 * ¿Puede esta persona ver esta entrega?
 *
 * Réplica exacta del alcance de `GET /submissions`. Está duplicada a
 * propósito en vez de compartir el `where`: aquel filtra un listado y este
 * responde por una fila puntual, y mezclarlos haría que un cambio de
 * paginación tocara una regla de seguridad.
 */
async function assertSubmissionVisible(
  db: Database,
  user: AuthUser,
  submissionId: string,
): Promise<void> {
  if (user.role === 'admin' || user.role === 'superadmin') return;

  const [row] = await db.execute<{
    studentId: string | null;
    courseId: string | null;
  }>(sql`
    select student_id as "studentId", course_id as "courseId"
      from submissions
     where id = ${submissionId} and deleted_at is null
     limit 1
  `);
  if (!row) throw notFound('No encontramos ese archivo.');

  if (isStudentLike(user.role)) {
    if (row.studentId !== user.id) {
      throw notFound('No encontramos ese archivo.');
    }
    return;
  }

  if (user.role === 'lxd') {
    const [ok] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from courses
       where id = ${row.courseId} and creator_id = ${user.id}
       limit 1
    `);
    if (!ok) throw notFound('No encontramos ese archivo.');
    return;
  }

  if (user.role === 'mentor') {
    const [ok] = await db.execute<{ ok: number }>(sql`
      select 1 as ok
       where (case when exists (select 1 from mentor_review_courses m
                                 where m.mentor_id = ${user.id})
                then ${row.courseId} in (select m.course_id from mentor_review_courses m
                                          where m.mentor_id = ${user.id})
                else ${row.courseId} in (
                       select c.id from courses c
                        where c.laboratory_id in (select lm.laboratory_id
                                                    from laboratory_mentors lm
                                                   where lm.user_id = ${user.id}))
              end)
    `);
    if (!ok) throw notFound('No encontramos ese archivo.');
    return;
  }

  if (user.role === 'advisor') {
    const [ok] = await db.execute<{ ok: number }>(sql`
      select 1 as ok from users u
       where u.id = ${row.studentId}
         and u.university = ${user.university}
         and u.university <> ''
       limit 1
    `);
    if (!ok) throw notFound('No encontramos ese archivo.');
    return;
  }

  // Empresa y Donante no ven entregas.
  throw forbidden('Tu rol no tiene acceso a las entregas.');
}
