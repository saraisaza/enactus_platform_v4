-- Reverso de 0006_catalogo_universidades.
--
-- Borra SOLO las que no tienen a nadie apuntando. Una universidad del
-- catálogo a la que ya se le asignaron personas no se puede quitar sin decidir
-- a dónde va esa gente, y esa decisión no la toma un reverso de migración: la
-- toma alguien mirando el reporte.
--
-- Consecuencia práctica: revertir puede dejar filas. Es correcto — es la
-- diferencia entre deshacer un cambio de esquema y borrar datos de personas.

DELETE FROM universities un
 WHERE un.slug IN (
   enactus_normalizar_universidad('Corporación Universitaria Americana'),
   enactus_normalizar_universidad('Corporación Universitaria Comfacauca (Unicomfacauca)'),
   enactus_normalizar_universidad('Corporación Universitaria Iberoamericana'),
   enactus_normalizar_universidad('Corporación Universitaria Minuto de Dios (UNIMINUTO)'),
   enactus_normalizar_universidad('Corporación Universitaria de la Costa (CUC)'),
   enactus_normalizar_universidad('ESAP'),
   enactus_normalizar_universidad('Escuela Colombiana de Ingeniería Julio Garavito'),
   enactus_normalizar_universidad('Fundación Universidad de América'),
   enactus_normalizar_universidad('Fundación Universitaria de San Gil (UNISANGIL)'),
   enactus_normalizar_universidad('Fundación Universitaria del Área Andina'),
   enactus_normalizar_universidad('Institución Universitaria Antonio José Camacho'),
   enactus_normalizar_universidad('Institución Universitaria de Envigado'),
   enactus_normalizar_universidad('Institución Universitaria del Putumayo'),
   enactus_normalizar_universidad('Instituto Universitario de la Paz (UNIPAZ)'),
   enactus_normalizar_universidad('Servicio Nacional de Aprendizaje (SENA)'),
   enactus_normalizar_universidad('Universidad Autónoma Latinoamericana (UNAULA)'),
   enactus_normalizar_universidad('Universidad CES'),
   enactus_normalizar_universidad('Universidad Católica de Pereira'),
   enactus_normalizar_universidad('Universidad Distrital Francisco José de Caldas'),
   enactus_normalizar_universidad('Universidad EAN'),
   enactus_normalizar_universidad('Universidad Nacional Abierta y a Distancia (UNAD)'),
   enactus_normalizar_universidad('Universidad Nacional de Colombia'),
   enactus_normalizar_universidad('Universidad Pedagógica Nacional'),
   enactus_normalizar_universidad('Universidad Pedagógica y Tecnológica de Colombia (UPTC)'),
   enactus_normalizar_universidad('Universidad Popular del Cesar'),
   enactus_normalizar_universidad('Universidad Santo Tomás'),
   enactus_normalizar_universidad('Universidad Sergio Arboleda'),
   enactus_normalizar_universidad('Universidad Simón Bolívar'),
   enactus_normalizar_universidad('Universidad de Antioquia'),
   enactus_normalizar_universidad('Universidad de Caldas'),
   enactus_normalizar_universidad('Universidad de La Guajira'),
   enactus_normalizar_universidad('Universidad de Medellín'),
   enactus_normalizar_universidad('Universidad del Atlántico')
 )
   AND NOT EXISTS (SELECT 1 FROM users u WHERE u.university_id = un.id)
   AND NOT EXISTS (SELECT 1 FROM projects p WHERE p.university_id = un.id)
   AND NOT EXISTS (SELECT 1 FROM university_advisors ua WHERE ua.university_id = un.id);
