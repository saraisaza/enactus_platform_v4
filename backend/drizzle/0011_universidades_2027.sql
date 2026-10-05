-- Universidades del menú de inscripción 2027: 81 instituciones.
--
-- La lista la armó Enactus Colombia juntando la base completa 2026, la base
-- MOU, la hoja de asesores, las universidades de Classroom y los preinscritos.
-- Incluye las que no estuvieron en el National Expo (SENA, EAFIT, Univalle).
-- Una opción por institución, sin sede, con el nombre oficial y su sigla.
--
-- Dos pasos, los dos idempotentes: correr esto dos veces no cambia nada.
--
-- 1. SIETE universidades del catálogo de 0006 cambiaron de nombre oficial
--    («Corporación Universitaria de la Costa» ahora es «Universidad de la
--    Costa»). Se RENOMBRAN, no se duplican: agregar la nueva al lado dejaría
--    dos opciones para la misma universidad en el desplegable.
--
--    Con la fila se renombra el texto de quienes la tienen asignada. Hasta R3
--    la visibilidad del asesor compara TEXTO (`users.university`): si la fila
--    cambiara de nombre y las personas no, un estudiante nuevo quedaría con el
--    nombre nuevo y su asesor —con el viejo— dejaría de verlo, sin error. Es
--    exactamente el defecto D2 que el catálogo vino a cerrar.
--
--    Si ya existe una fila con el nombre NUEVO (por ejemplo, la creó el
--    relleno de 0005 a partir de lo que alguien escribió), no se renombra:
--    serían dos filas para la misma universidad, y fusionarlas lo decide una
--    persona mirando el bloque 3 del reporte, no una migración.
--
-- 2. Se agregan las que faltan. El `slug` sale de
--    `enactus_normalizar_universidad`, la misma función del relleno de 0005 y
--    del catálogo de 0006, y el índice único sobre `slug` hace que lo que ya
--    existe no se duplique.

WITH cambios(viejo, nuevo, corto) AS (VALUES
  ('Corporación Universitaria de la Costa (CUC)', 'Universidad de la Costa (CUC)', 'CUC'),
  ('ESAP', 'Escuela Superior de Administración Pública (ESAP)', 'ESAP'),
  ('Fundación Universitaria del Área Andina', 'Fundación Universitaria del Área Andina (Areandina)', 'Areandina'),
  ('Institución Universitaria Antonio José Camacho', 'Institución Universitaria Antonio José Camacho (UNIAJC)', 'UNIAJC'),
  ('Institución Universitaria de Envigado', 'Institución Universitaria de Envigado (IUE)', 'IUE'),
  ('Institución Universitaria del Putumayo', 'Institución Universitaria del Putumayo (ITP)', 'ITP'),
  ('Universidad Popular del Cesar', 'Universidad Popular del Cesar (UPC)', 'UPC')
),
renombradas AS (
  UPDATE universities un
     SET name = c.nuevo,
         slug = enactus_normalizar_universidad(c.nuevo),
         short_name = c.corto,
         updated_at = now()
    FROM cambios c
   WHERE un.slug = enactus_normalizar_universidad(c.viejo)
     AND un.deleted_at IS NULL
     AND NOT EXISTS (
       SELECT 1 FROM universities otra
        WHERE otra.slug = enactus_normalizar_universidad(c.nuevo)
          AND otra.deleted_at IS NULL)
  RETURNING un.id, un.name, enactus_normalizar_universidad(c.viejo) AS slug_anterior
),
personas AS (
  UPDATE users u
     SET university = r.name, updated_at = now()
    FROM renombradas r
   WHERE u.university_id = r.id
  RETURNING u.id
)
UPDATE groups g
   SET university = r.name, updated_at = now()
  FROM renombradas r
 WHERE enactus_normalizar_universidad(g.university) = r.slug_anterior;
--> statement-breakpoint

INSERT INTO universities (name, slug, short_name)
SELECT c.nombre,
       enactus_normalizar_universidad(c.nombre),
       c.corto
  FROM (VALUES
  ('Corporación Unificada Nacional de Educación Superior (CUN)', 'CUN'),
  ('Corporación Universitaria Americana', ''),
  ('Corporación Universitaria Comfacauca (Unicomfacauca)', 'Unicomfacauca'),
  ('Corporación Universitaria del Meta (Unimeta)', 'Unimeta'),
  ('Corporación Universitaria Iberoamericana', ''),
  ('Corporación Universitaria Minuto de Dios (UNIMINUTO)', 'UNIMINUTO'),
  ('Corporación Universitaria Unitec', ''),
  ('Escuela Colombiana de Ingeniería Julio Garavito', ''),
  ('Escuela Normal Superior Sagrada Familia', ''),
  ('Escuela Superior de Administración Pública (ESAP)', 'ESAP'),
  ('Fundación Academia de Dibujo Profesional (FADP)', 'FADP'),
  ('Fundación de Estudios Superiores Comfanorte (FESC)', 'FESC'),
  ('Fundación Universidad de América', ''),
  ('Fundación Universitaria Claretiana (Uniclaretiana)', 'Uniclaretiana'),
  ('Fundación Universitaria Colombo Internacional (Unicolombo)', 'Unicolombo'),
  ('Fundación Universitaria Comfamiliar Risaralda', ''),
  ('Fundación Universitaria de Asturias', ''),
  ('Fundación Universitaria de San Gil (UNISANGIL)', 'UNISANGIL'),
  ('Fundación Universitaria del Área Andina (Areandina)', 'Areandina'),
  ('Fundación Universitaria Konrad Lorenz', ''),
  ('Fundación Universitaria Monserrate (Unimonserrate)', 'Unimonserrate'),
  ('IDETEK', ''),
  ('IES INFOTEP', ''),
  ('Institución Educativa CESDE', ''),
  ('Institución Universitaria Antonio José Camacho (UNIAJC)', 'UNIAJC'),
  ('Institución Universitaria de Barranquilla (IUB)', 'IUB'),
  ('Institución Universitaria de Colombia (IUDC)', 'IUDC'),
  ('Institución Universitaria de Envigado (IUE)', 'IUE'),
  ('Institución Universitaria del Putumayo (ITP)', 'ITP'),
  ('Institución Universitaria Digital de Antioquia (IU Digital)', 'IU Digital'),
  ('Instituto de Educación Técnica Profesional de Roldanillo (INTEP)', 'INTEP'),
  ('Instituto Universitario de la Paz (UNIPAZ)', 'UNIPAZ'),
  ('Instituto Universitario Politécnico Santiago Mariño (Venezuela)', ''),
  ('Politécnico Colombiano Jaime Isaza Cadavid', ''),
  ('Servicio Nacional de Aprendizaje (SENA)', 'SENA'),
  ('Unidades Tecnológicas de Santander (UTS)', 'UTS'),
  ('Universidad Autónoma de Manizales (UAM)', 'UAM'),
  ('Universidad Autónoma del Caribe (Uniautónoma)', 'Uniautónoma'),
  ('Universidad Autónoma Latinoamericana (UNAULA)', 'UNAULA'),
  ('Universidad Católica de Oriente (UCO)', 'UCO'),
  ('Universidad Católica de Pereira', ''),
  ('Universidad CES', ''),
  ('Universidad Colegio Mayor de Cundinamarca', ''),
  ('Universidad Cooperativa de Colombia', ''),
  ('Universidad de Antioquia', ''),
  ('Universidad de Boyacá (Uniboyacá)', 'Uniboyacá'),
  ('Universidad de Caldas', ''),
  ('Universidad de Ciencias Aplicadas y Ambientales (UDCA)', 'UDCA'),
  ('Universidad de Granada (España)', ''),
  ('Universidad de la Costa (CUC)', 'CUC'),
  ('Universidad de La Guajira', ''),
  ('Universidad de La Salle', ''),
  ('Universidad de los Andes', ''),
  ('Universidad de Medellín', ''),
  ('Universidad de Nariño', ''),
  ('Universidad de Pamplona', ''),
  ('Universidad de Santander (UDES)', 'UDES'),
  ('Universidad de Sucre', ''),
  ('Universidad del Atlántico', ''),
  ('Universidad del Cauca (Unicauca)', 'Unicauca'),
  ('Universidad del Magdalena', ''),
  ('Universidad del Norte (Uninorte)', 'Uninorte'),
  ('Universidad del Valle', ''),
  ('Universidad Distrital Francisco José de Caldas', ''),
  ('Universidad EAFIT', ''),
  ('Universidad EAN', ''),
  ('Universidad El Bosque', ''),
  ('Universidad Externado de Colombia', ''),
  ('Universidad Industrial de Santander (UIS)', 'UIS'),
  ('Universidad Libre', ''),
  ('Universidad Nacional Abierta y a Distancia (UNAD)', 'UNAD'),
  ('Universidad Nacional de Colombia', ''),
  ('Universidad Pedagógica Nacional', ''),
  ('Universidad Pedagógica y Tecnológica de Colombia (UPTC)', 'UPTC'),
  ('Universidad Pontificia Bolivariana (UPB)', 'UPB'),
  ('Universidad Popular del Cesar (UPC)', 'UPC'),
  ('Universidad Santo Tomás', ''),
  ('Universidad Sergio Arboleda', ''),
  ('Universidad Simón Bolívar', ''),
  ('Universidad Surcolombiana', ''),
  ('Universidad Tecnológica del Chocó Diego Luis Córdoba', '')
  ) AS c(nombre, corto)
ON CONFLICT DO NOTHING;
