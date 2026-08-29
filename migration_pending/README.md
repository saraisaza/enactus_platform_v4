# Portales pendientes de migrar a la API

Estos archivos **no se compilan**: viven fuera de `lib/` a propósito.

## Por qué no están simplemente parcheados para compilar

La migración de Hive a la API cambia la forma de los datos, no solo de dónde
vienen: `AppUser.extra` desapareció, la completitud ya no se calcula en el
cliente, y cada lectura pasó a tener estados de carga y error. Dejar estos
portales "compilando" sin recorrerlos de verdad produciría siete portales a
medias en vez de unos pocos terminados — y en producción, un portal que
muestra datos incompletos o que revienta ante un 403 es peor que uno que
todavía no está.

Mientras tanto, sus rutas muestran una pantalla honesta de "disponible
próximamente" (`lib/views/public/pending_portal_view.dart`).

## Cómo se migra uno

1. `git mv migration_pending/views/<portal>/... lib/views/<portal>/...`
2. Reemplazar cada lectura de datos por su `AsyncValue` correspondiente:
   `data.courses.when(loading:, error:, data:)`.
3. Quitar del enrutador la entrada a `PendingPortalView` y devolverle su
   portal real.
4. Cerrar el ciclo completo: `flutter analyze` → `flutter test` →
   `flutter build web --release` → recorrido real con clics contra el backend
   → actualizar `MIGRACION_FRONT.md` → commit.

## Qué NO hacer

No volver a conectarlos a Hive ni a ninguna copia local de los datos. Se
eliminó a propósito: dos fuentes de verdad hacen que un LXD cree un curso por
la API y el Mentor, leyendo la copia, no lo vea.
