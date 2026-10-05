-- Reverso de 0011_universidades_2027.
--
-- 1. Devuelve su nombre anterior a las siete que se renombraron —y el texto
--    de quienes las tienen asignadas, por la misma razón de la ida— salvo que
--    el nombre anterior ya lo tenga otra fila.
-- 2. Borra SOLO las agregadas que no tienen a nadie apuntando, como el reverso
--    de 0006: una universidad a la que ya se le asignaron personas no se quita
--    sin decidir a dónde va esa gente. Revertir puede dejar filas, y es
--    correcto.

WITH cambios(viejo, nuevo, corto) AS (VALUES
  ('Corporación Universitaria de la Costa (CUC)', 'Universidad de la Costa (CUC)', 'CUC'),
  ('ESAP', 'Escuela Superior de Administración Pública (ESAP)', 'ESAP'),
  ('Fundación Universitaria del Área Andina', 'Fundación Universitaria del Área Andina (Areandina)', 'Área Andina'),
  ('Institución Universitaria Antonio José Camacho', 'Institución Universitaria Antonio José Camacho (UNIAJC)', 'UNIAJC'),
  ('Institución Universitaria de Envigado', 'Institución Universitaria de Envigado (IUE)', 'IUE'),
  ('Institución Universitaria del Putumayo', 'Institución Universitaria del Putumayo (ITP)', 'IUP'),
  ('Universidad Popular del Cesar', 'Universidad Popular del Cesar (UPC)', 'UPC')
),
restauradas AS (
  UPDATE universities un
     SET name = c.viejo,
         slug = enactus_normalizar_universidad(c.viejo),
         short_name = c.corto,
         updated_at = now()
    FROM cambios c
   WHERE un.slug = enactus_normalizar_universidad(c.nuevo)
     AND un.deleted_at IS NULL
     AND NOT EXISTS (
       SELECT 1 FROM universities otra
        WHERE otra.slug = enactus_normalizar_universidad(c.viejo)
          AND otra.deleted_at IS NULL)
  RETURNING un.id, un.name, enactus_normalizar_universidad(c.nuevo) AS slug_anterior
),
personas AS (
  UPDATE users u
     SET university = r.name, updated_at = now()
    FROM restauradas r
   WHERE u.university_id = r.id
  RETURNING u.id
)
UPDATE groups g
   SET university = r.name, updated_at = now()
  FROM restauradas r
 WHERE enactus_normalizar_universidad(g.university) = r.slug_anterior;
--> statement-breakpoint

DELETE FROM universities un
 WHERE un.slug IN (SELECT enactus_normalizar_universidad(c.n) FROM (VALUES
  ('Corporación Unificada Nacional de Educación Superior (CUN)'),
  ('Corporación Universitaria del Meta (Unimeta)'),
  ('Corporación Universitaria Unitec'),
  ('Escuela Normal Superior Sagrada Familia'),
  ('Fundación Academia de Dibujo Profesional (FADP)'),
  ('Fundación de Estudios Superiores Comfanorte (FESC)'),
  ('Fundación Universitaria Claretiana (Uniclaretiana)'),
  ('Fundación Universitaria Colombo Internacional (Unicolombo)'),
  ('Fundación Universitaria Comfamiliar Risaralda'),
  ('Fundación Universitaria de Asturias'),
  ('Fundación Universitaria Konrad Lorenz'),
  ('Fundación Universitaria Monserrate (Unimonserrate)'),
  ('IDETEK'),
  ('IES INFOTEP'),
  ('Institución Educativa CESDE'),
  ('Institución Universitaria de Barranquilla (IUB)'),
  ('Institución Universitaria de Colombia (IUDC)'),
  ('Institución Universitaria Digital de Antioquia (IU Digital)'),
  ('Instituto de Educación Técnica Profesional de Roldanillo (INTEP)'),
  ('Instituto Universitario Politécnico Santiago Mariño (Venezuela)'),
  ('Politécnico Colombiano Jaime Isaza Cadavid'),
  ('Unidades Tecnológicas de Santander (UTS)'),
  ('Universidad Autónoma de Manizales (UAM)'),
  ('Universidad Autónoma del Caribe (Uniautónoma)'),
  ('Universidad Católica de Oriente (UCO)'),
  ('Universidad Colegio Mayor de Cundinamarca'),
  ('Universidad Cooperativa de Colombia'),
  ('Universidad de Boyacá (Uniboyacá)'),
  ('Universidad de Ciencias Aplicadas y Ambientales (UDCA)'),
  ('Universidad de Granada (España)'),
  ('Universidad de La Salle'),
  ('Universidad de los Andes'),
  ('Universidad de Nariño'),
  ('Universidad de Pamplona'),
  ('Universidad de Santander (UDES)'),
  ('Universidad de Sucre'),
  ('Universidad del Cauca (Unicauca)'),
  ('Universidad del Magdalena'),
  ('Universidad del Norte (Uninorte)'),
  ('Universidad del Valle'),
  ('Universidad EAFIT'),
  ('Universidad El Bosque'),
  ('Universidad Externado de Colombia'),
  ('Universidad Industrial de Santander (UIS)'),
  ('Universidad Libre'),
  ('Universidad Pontificia Bolivariana (UPB)'),
  ('Universidad Surcolombiana'),
  ('Universidad Tecnológica del Chocó Diego Luis Córdoba')
  ) AS c(n))
   AND NOT EXISTS (SELECT 1 FROM users u WHERE u.university_id = un.id)
   AND NOT EXISTS (SELECT 1 FROM projects p WHERE p.university_id = un.id)
   AND NOT EXISTS (SELECT 1 FROM university_advisors a WHERE a.university_id = un.id);
