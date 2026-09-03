-- Cambio obligatorio de contraseña al primer ingreso.
--
-- La revisión previa al lanzamiento dejó esto como casilla abierta: el plan de
-- go-live decía "contraseñas iniciales entregadas de forma segura, con cambio
-- obligatorio en el primer ingreso" y **no existía el campo que lo marcara**.
-- El "cambio obligatorio" era un acuerdo verbal con la persona, no algo que el
-- sistema pudiera garantizar ni auditar.
--
-- Importa por quiénes reciben esas contraseñas: las cuentas de arranque
-- administran la plataforma entera y su contraseña la eligió otra persona, que
-- la escribió en algún lado para poder entregarla. Mientras no se cambie, esa
-- copia sigue sirviendo.
--
-- `default false` a propósito: las cuentas que YA existen eligieron su
-- contraseña en su momento, así que esta migración no debe echar a nadie de la
-- plataforma al aplicarse. Solo lo ponen en `true` los dos caminos donde
-- alguien recibe una contraseña ajena: `seed:prod` y el restablecimiento por
-- parte de administración.

ALTER TABLE "users"
  ADD COLUMN "must_change_password" boolean NOT NULL DEFAULT false;
