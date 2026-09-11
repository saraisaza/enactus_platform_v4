-- Catálogo de universidades de la red Enactus Colombia.
--
-- Las 33 que hoy participan. Se meten como DATOS y no como enum ni constante
-- del cliente: la lista cambia —entran y salen universidades— y cambiarla no
-- puede exigir un despliegue.
--
-- Idempotente por el índice único sobre `slug`: correr esto dos veces no
-- duplica, y volver a correrlo tras agregar una fila nueva mete solo la nueva.
--
-- El `slug` NO se escribe a mano: sale de `enactus_normalizar_universidad`,
-- la misma función que usa el relleno de 0005. Si se escribiera a mano, una
-- universidad del catálogo y la misma escrita por una persona podrían
-- normalizar distinto y entrar como dos — que es justo lo que este trabajo
-- viene a impedir.
--
-- OJO con lo que este catálogo NO hace: no fusiona lo que ya estaba. Si una
-- base tiene «Universidad Nacional» de antes y acá entra «Universidad
-- Nacional de Colombia», son dos slugs distintos y quedan dos filas. Eso sale
-- en el bloque 3 del reporte como par candidato, para que una persona decida.
-- Fusionarlas automáticamente sería adivinar.

INSERT INTO universities (name, slug, short_name)
SELECT c.nombre,
       enactus_normalizar_universidad(c.nombre),
       c.corto
  FROM (VALUES
  ('Corporación Universitaria Americana', 'Americana'),
  ('Corporación Universitaria Comfacauca (Unicomfacauca)', 'Unicomfacauca'),
  ('Corporación Universitaria Iberoamericana', 'Iberoamericana'),
  ('Corporación Universitaria Minuto de Dios (UNIMINUTO)', 'UNIMINUTO'),
  ('Corporación Universitaria de la Costa (CUC)', 'CUC'),
  ('ESAP', 'ESAP'),
  ('Escuela Colombiana de Ingeniería Julio Garavito', 'Escuela Colombiana de Ingeniería'),
  ('Fundación Universidad de América', 'U. de América'),
  ('Fundación Universitaria de San Gil (UNISANGIL)', 'UNISANGIL'),
  ('Fundación Universitaria del Área Andina', 'Área Andina'),
  ('Institución Universitaria Antonio José Camacho', 'UNIAJC'),
  ('Institución Universitaria de Envigado', 'IUE'),
  ('Institución Universitaria del Putumayo', 'IUP'),
  ('Instituto Universitario de la Paz (UNIPAZ)', 'UNIPAZ'),
  ('Servicio Nacional de Aprendizaje (SENA)', 'SENA'),
  ('Universidad Autónoma Latinoamericana (UNAULA)', 'UNAULA'),
  ('Universidad CES', 'CES'),
  ('Universidad Católica de Pereira', 'UCP'),
  ('Universidad Distrital Francisco José de Caldas', 'Universidad Distrital'),
  ('Universidad EAN', 'EAN'),
  ('Universidad Nacional Abierta y a Distancia (UNAD)', 'UNAD'),
  ('Universidad Nacional de Colombia', 'UNAL'),
  ('Universidad Pedagógica Nacional', 'UPN'),
  ('Universidad Pedagógica y Tecnológica de Colombia (UPTC)', 'UPTC'),
  ('Universidad Popular del Cesar', 'UPC'),
  ('Universidad Santo Tomás', 'USTA'),
  ('Universidad Sergio Arboleda', 'Sergio Arboleda'),
  ('Universidad Simón Bolívar', 'Unisimón'),
  ('Universidad de Antioquia', 'UdeA'),
  ('Universidad de Caldas', 'U. de Caldas'),
  ('Universidad de La Guajira', 'Uniguajira'),
  ('Universidad de Medellín', 'UdeM'),
  ('Universidad del Atlántico', 'Uniatlántico')
  ) AS c(nombre, corto)
ON CONFLICT DO NOTHING;
