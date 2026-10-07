# Clientes con marca propia

Cada cliente de la plataforma —una empresa, y también Enactus, que es el
cliente con laboratorios y Ruta de Impacto— puede tener su logo y su paleta.
Quien inicia sesión ve la plataforma con la marca de su cliente: el logo de
eduXaction siempre, el del cliente al lado, y los acentos en sus colores. La
tipografía y la estructura siguen siendo las de eduXaction.

El trabajo va por etapas, cada una probada en staging antes de la siguiente:

1. **Tema cambiable sin cambio visible** — hecha.
2. **Clientes en el panel de admin** — hecha: nombre, logo, colores, vista
   previa, informe de legibilidad, editar y desactivar.
3. **Asignar cuentas y aplicar la marca** — hecha: cada cuenta con su
   cliente, la marca al entrar, el logo en el encabezado y el cliente
   desactivado deja afuera.
4. Portal del Manager / Supervisor.
5. Blindaje (aislamiento entre clientes) y producción.
6. Certificados con molde, para toda la plataforma.

## Cómo funciona el color

Todo color de marca sale de `Marca.instancia.paleta` (`lib/utils/marca.dart`):

| Se lee como | Es | Con eduXaction |
|---|---|---|
| `AppColors.gold` | `tintaSobreOscuro`: texto, íconos, bordes e indicadores sobre el gris | `#FFC107` |
| `AppColors.relleno` | `primario`: FONDOS con algo encima (botón, avatar, contador) | `#FFC107` |
| `AppColors.acentoHover` | `tintaSobreOscuroBrillante`: texto de un botón con borde bajo el mouse | `#FFCF3D` |
| `AppColors.secundario` / `secundarioTinta` | la opción activa del menú y las barras de progreso | `#FFC107` |
| `AppColors.goldBright` | `primarioBrillante`: el botón con el mouse encima | `#FFCF3D` |
| `AppColors.ink` | `sobrePrimario`: texto e íconos encima del acento | `#21120A` |
| `ContentColors.dark.goldInk` | `tintaSobreOscuro`: la marca como texto en oscuro | `#FFC107` |
| `ContentColors.light.goldInk` | `tintaSobreClaro`: la marca como texto en claro | `#8A6A00` |
| `ContentColors.*.goldSoft` | fondo suave de marca | ámbar al 16 % / 24 % |

`Marca.instancia.aplicar(paleta)` repinta toda la app al instante, sin perder
lo que la persona tenía abierto; `restablecer()` vuelve a eduXaction.

La paleta de un cliente se arma con `PaletaMarca.desde(primario:, secundario:)`.
Los rellenos usan el color exacto que eligió el cliente; los usos como texto se
aclaran u oscurecen lo justo para llegar a 4.5:1 (AA de WCAG) sobre los fondos
de la plataforma. `test/marca_test.dart` lo exige sobre 666 tonos.

### Reglas

- **Un color de marca nunca va dentro de `const`.** Ya no es una constante; el
  compilador lo rechaza. Tampoco como valor por defecto de un parámetro: se
  deja `Color? color` y se resuelve al dibujar (`color ?? AppColors.gold`).
- **No guardar un color de marca en una variable `static final` ni en el
  estado de una pantalla**: se calcularía una vez y no seguiría a la marca.
- **El logo de eduXaction usa `AppColors.ambarEduXaction`**, que es fijo. El
  logo nunca toma el color de un cliente.
- **`gold` es para texto; `relleno`, para fondos.** Con eduXaction valen lo
  mismo; con un cliente no: un azul medio como botón se ve bien y como título
  sobre el gris no se lee. Un fondo con `ink` encima va siempre en `relleno`
  (la tinta se calcula para el color exacto).
- **Los colores de dato no siguen a la marca**: gráficos, ODS, laboratorios y
  estados. `inkSobre` usa `AppColors.tintaOscura`, no `ink`.
- Los certificados PDF tienen su propia copia del ámbar (`PdfColor` no acepta
  un `Color`); se resuelven en la etapa 6.

## Comprobar que nada cambió de aspecto

`test/capturas/capturas_test.dart` toma 92 imágenes (cada pestaña de los nueve
portales en escritorio, cada portal en teléfono, las páginas públicas y el
modo claro del estudiante) y las compara píxel a píxel:

```
# en el código de partida
flutter test test/capturas --run-skipped --update-goldens
# con el cambio
flutter test test/capturas --run-skipped
```

Las imágenes dependen de cómo dibuja las letras cada sistema, así que no se
guardan en el repositorio ni corren en CI. Se comprobó que la comparación es
estable (cero diferencias sin cambios) y sensible (mover el ámbar de `#FFC107`
a `#FFC108` hace fallar las 92).

## Los clientes (etapa 2)

Tabla `clients` (migración 0013). La migración crea **Enactus**, el único
cliente con laboratorios y Ruta (`has_laboratories`; un índice impide un
segundo). Sin colores ni logo, un cliente se ve con la marca de eduXaction.

| Ruta (solo admin y superadmin) | Qué hace |
|---|---|
| `GET /clients` | La lista, Enactus primero, con la URL del logo ya firmada |
| `POST /clients/logo-upload-url` | Permiso para subir un PNG de hasta 1 MB a `client-logos/` |
| `POST /clients` | Crear: nombre, colores (`#RRGGBB`), logo, placa clara |
| `PATCH /clients/:id` | Editar, cambiar o quitar el logo, desactivar (`active`) |

Reglas que no se ven a simple vista:

- **El logo se verifica mirando el archivo**, no lo que dijo el navegador: la
  firma de PNG, el peso (1 MB) y las medidas (lado mayor de al menos 200 px,
  ninguno de más de 4000). La app hace la misma revisión antes de subir, para
  no hacer esperar; la que cuenta es la del servidor.
- **Un logo reemplazado se borra de S3** por la cola de borrado, que antes de
  borrar comprueba que ningún cliente lo use (restaurar un respaldo puede
  volver a apuntarlo).
- **Enactus no se desactiva desde el panel** (409): dejaría sin acceso a toda
  su red.
- **Placa clara**: la app la propone si el logo tiene transparencia y su color
  promedio da menos de 3:1 contra el gris del encabezado. El admin decide.
- **Respaldo**: `clients` va en el respaldo. Un respaldo anterior a la tabla
  no la trae, y restaurarlo la deja como estaba en vez de vaciarla
  (`TABLAS_POSTERIORES_A_RESPALDOS_VIEJOS` en `routes/admin.ts`).

El informe de legibilidad del editor (`InformeDeContraste`) dice qué hizo la
plataforma con cada color —se usó tal cual, se aclaró o se oscureció— y avisa
cuando un primario muy oscuro deja el botón casi igual a las tarjetas (menos
de 3:1): ahí no se corrige, porque es el color exacto del cliente.

En la interfaz, el rol `company` de siempre se llama ahora **Empresa aliada**
(la que patrocina laboratorios), para no confundirlo con una empresa cliente.

## Las cuentas de un cliente (etapa 3)

`users.client_id` (migración 0014), nulo para lo que es de eduXaction
directamente. La migración asignó a Enactus a sus estudiantes eduXaction, sus
asesores, mentores de laboratorio, donantes y empresas aliadas.

Quién puede pertenecer a qué (`services/cliente-de-cuenta.ts`):

| Cuenta | Cliente |
|---|---|
| Admin y superadmin | Ninguno (lo exige también la base) |
| Estudiante o alumni eduXaction | Enactus, siempre |
| Asesor, mentor de laboratorio, donante, empresa aliada | Enactus, siempre |
| Estudiante o alumni de Open Learning | Ninguno, o una empresa |
| LXD | Ninguno, o una empresa |

Sin mandar el cliente, cada cuenta queda con el que le toca. En el panel,
«Empresa» en el tipo de estudiante es una cuenta de Open Learning con su
empresa.

**La marca al entrar.** `/auth/me` (y el ingreso) traen `client`: la marca
del cliente de esa cuenta, leída de su fila. La app la aplica en
`AuthProvider._setUser` y vuelve a la de eduXaction al cerrar sesión. El
encabezado muestra el logo del cliente al lado del de eduXaction: el nuestro
no cambia; el del cliente toma el espacio que sobra.

**Cliente desactivado.** 403 `client_inactive` en el ingreso, al renovar la
sesión y en cualquier pedido con la sesión abierta. La app cierra la sesión y
la pantalla de ingreso dice por qué. Editar una cuenta de un cliente
desactivado no la saca de su cliente; asignar una nueva, sí se rechaza.

**Restaurar un respaldo** inserta las cuentas sin sus referencias a otras
cuentas (empresa aliada, donante, asesor) y las completa al final: el orden
del archivo no es el de alta.

