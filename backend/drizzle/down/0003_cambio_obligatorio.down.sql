-- Reverso de 0003_cambio_obligatorio.sql
--
-- Quitar la columna hace que ninguna cuenta quede obligada a cambiar su
-- contraseña. Es una pérdida de seguridad, no de datos: quien estuviera
-- pendiente de cambiarla simplemente deja de estarlo y entra con la que le
-- dieron. Si se revierte, hay que restablecer esas contraseñas a mano.

ALTER TABLE "users" DROP COLUMN "must_change_password";
