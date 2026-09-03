-- Reverso de 0004_sin_cambio_obligatorio.sql
--
-- Devuelve la columna con su default en `false`, así que revertir no deja a
-- nadie fuera de la plataforma. Para volver a obligar el cambio habría que
-- restaurar además el bloqueo de `requireAuth`, el endpoint
-- `POST /auth/change-password` y la pantalla del cliente: la columna sola no
-- hace nada.

ALTER TABLE "users"
  ADD COLUMN "must_change_password" boolean NOT NULL DEFAULT false;
