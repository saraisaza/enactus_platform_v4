-- Reporte del relleno de universidades (migración 0005).
--
-- Se corre DESPUÉS de migrar, y su salida es un insumo de R2 y R3: hasta que
-- «Sin asignar» esté en cero y los pares candidatos estén resueltos, R3 no se
-- puede desplegar. Ver `docs/asignaciones-reconciliacion.md`.
--
--   aws lambda invoke --function-name enactus-db-admin … (ver RUNBOOK)

-- 1. Qué quedó creado.
SELECT 'universidades creadas' AS que, count(*)::text AS valor FROM universities
UNION ALL
SELECT 'personas con universidad', count(*)::text FROM users WHERE university_id IS NOT NULL
UNION ALL
SELECT 'personas SIN universidad', count(*)::text FROM users WHERE university_id IS NULL
UNION ALL
SELECT 'asesores en la tabla puente', count(*)::text FROM university_advisors
UNION ALL
SELECT 'proyectos con universidad', count(*)::text FROM projects WHERE university_id IS NOT NULL;

-- 2. Cada universidad con su carga. `sin asignar` arriba: es la que hay que
--    vaciar antes de R3.
SELECT un.slug,
       un.name,
       un.active,
       count(*) FILTER (WHERE u.role IN ('student','alumni')) AS estudiantes,
       count(*) FILTER (WHERE u.role = 'advisor')             AS asesores,
       (SELECT count(*) FROM projects p WHERE p.university_id = un.id) AS proyectos
  FROM universities un
  LEFT JOIN users u ON u.university_id = un.id AND u.deleted_at IS NULL
 GROUP BY un.id, un.slug, un.name, un.active
 ORDER BY (un.slug = 'sin asignar') DESC, estudiantes DESC, un.slug;

-- 3. LOS PARES CANDIDATOS QUE **NO** SE FUSIONARON.
--
-- El relleno solo fusiona variantes tipográficas —mayúsculas, tildes,
-- espacios—. NO fusiona abreviaturas: «U. de los Andes» y «Universidad de los
-- Andes» son slugs distintos, y unirlas exigiría adivinar. Adivinar mal junta
-- dos universidades de verdad, que es peor que dejarlas separadas.
--
-- Se listan acá para que una persona decida. El criterio de sospecha es que
-- una contenga a la otra tras quitar los conectores y los puntos: es amplio a
-- propósito —mejor un par de más que uno de menos— porque el costo de revisar
-- un falso positivo es leerlo, y el de perder uno es un asesor que no ve a sus
-- estudiantes.
WITH reducidas AS (
  -- El núcleo: lo que queda tras quitar el punto de la abreviatura, la
  -- palabra genérica del principio y los conectores.
  --
  --   «u. de los andes»          -> «andes»
  --   «universidad de los andes» -> «andes»      (se detectan)
  --   «universidad nacional»     -> «nacional»   (no se confunde con Andes)
  --
  -- La primera versión solo quitaba conectores, y por eso NO encontraba el
  -- par canónico: dejaba «u los andes» contra «universidad los andes», que no
  -- se contienen. Quitar la palabra genérica inicial es lo que los junta.
  --
  -- Sin `pg_trgm` ni similitud difusa, por lo mismo que sin `unaccent`: es una
  -- extensión, y una regla del dominio no debe depender de que alguien la
  -- instale en la RDS.
  SELECT id, slug, name,
         trim(regexp_replace(
           ' ' || regexp_replace(
                    replace(slug, '.', ''),
                    '^(universidad|univ|u|corporacion|fundacion|instituto|institucion|politecnico|escuela|colegio|centro)\s+',
                    '', 'g'
                  ) || ' ',
           '(\s+(de|del|la|las|los|el|y))+\s+', ' ', 'g'
         )) AS nucleo
    FROM universities
   WHERE deleted_at IS NULL AND slug <> 'sin asignar'
),
carga AS (
  SELECT un.id,
         (SELECT count(*) FROM users u
           WHERE u.university_id = un.id AND u.deleted_at IS NULL) AS filas
    FROM universities un
)
SELECT a.name AS candidata_a,
       ca.filas AS filas_a,
       b.name AS candidata_b,
       cb.filas AS filas_b,
       'UPDATE users SET university_id = ''' || a.id || ''' WHERE university_id = ''' || b.id || ''';'
       || ' UPDATE projects SET university_id = ''' || a.id || ''' WHERE university_id = ''' || b.id || ''';'
       || ' UPDATE universities SET deleted_at = now(), active = false WHERE id = ''' || b.id || ''';'
         AS como_fusionar
  FROM reducidas a
  JOIN reducidas b ON a.id < b.id
   AND a.nucleo <> '' AND b.nucleo <> ''
   AND (a.nucleo = b.nucleo
        OR b.nucleo LIKE '%' || a.nucleo || '%'
        OR a.nucleo LIKE '%' || b.nucleo || '%')
  JOIN carga ca ON ca.id = a.id
  JOIN carga cb ON cb.id = b.id
 ORDER BY ca.filas + cb.filas DESC;

-- 4. Quién quedó en «Sin asignar», con nombre y correo para poder ir a
--    preguntarle. Sin esto el conteo del punto 1 no es accionable: saber que
--    hay 7 no dice a quién escribirle.
SELECT u.name, u.email, u.role, u.student_type,
       nullif(u.university, '') AS texto_original
  FROM users u
  JOIN universities un ON un.id = u.university_id
 WHERE un.slug = 'sin asignar' AND u.deleted_at IS NULL
 ORDER BY u.role, u.name;

-- 5. Asesores sin universidad: no entraron en la tabla puente, así que en R3
--    no van a ver a NADIE. Es la lista más urgente de las cuatro.
SELECT u.name, u.email, nullif(u.university, '') AS texto_original
  FROM users u
 WHERE u.role = 'advisor'
   AND u.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM university_advisors ua WHERE ua.user_id = u.id)
 ORDER BY u.name;

-- 6. Texto e id que NO coinciden. Tiene que dar CERO antes de R3: es la
--    condición para que cambiar las lecturas de texto a id no mueva a nadie
--    de sitio.
SELECT u.name, u.email, u.university AS texto, un.name AS por_id
  FROM users u
  LEFT JOIN universities un ON un.id = u.university_id
 WHERE u.deleted_at IS NULL
   AND enactus_normalizar_universidad(u.university) IS DISTINCT FROM un.slug
   AND NOT (u.university = '' AND un.slug = 'sin asignar')
   AND NOT (u.university = '' AND un.id IS NULL)
 ORDER BY u.name;
