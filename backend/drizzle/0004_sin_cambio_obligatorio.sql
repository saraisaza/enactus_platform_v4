-- Se quita el cambio obligatorio de contraseña al primer ingreso.
--
-- Decisión de producto: las cuentas se crean con su contraseña y esa es la que
-- usan. La columna se va entera en vez de quedarse sin uso — una columna que
-- ya no lee nadie es una trampa para quien lea el esquema el año que viene y
-- suponga que sigue significando algo.
--
-- Lo que queda en su lugar: administración puede restablecer la contraseña de
-- cualquiera con `PATCH /users/:id`. Es el único camino ahora.

ALTER TABLE "users" DROP COLUMN "must_change_password";
