# Plataforma Educativa Enactus Colombia


Es una **página web Flutter** (Flutter Web). Hoy corre 100 % local; más
adelante se desplegará en AWS y también se distribuirá como app.

## Cómo ejecutar

```bash
cd enactus_platform
flutter pub get
flutter run -d chrome        # página web local (principal)
flutter run -d macos         # opcional: la misma plataforma como app de escritorio
```

Para publicar la versión web estática: `flutter build web` (queda en
`build/web/`, lista para S3 + CloudFront).

> **Videos**: en web se sirven desde `web/course_resources/`; en escritorio se
> leen de `../course_resources/`. Los archivos actuales son *dummies*:
> reemplázalos por `.mp4` reales con el mismo nombre para verlos en el
> reproductor (en web, cópialos también a `web/course_resources/`).

## Credenciales de prueba (seed)

| Rol | Correo | Contraseña |
|---|---|---|
| Super Admin 1 | `superadmin1@enactus.co` | `Super123` |
| Super Admin 2 | `superadmin2@enactus.co` | `Super456` |
| Admin | `admin@enactus.co` | `Admin123` |
| Mentor (IA) | `mentor.ia@enactus.co` | `Mentor123` |
| Mentor (Agua) | `mentor.agua@enactus.co` | `Mentor123` |
| Asesor académico | `asesor@uniandes.edu.co` | `Asesor123` |
| Empresa | `empresa@bancolombia.com` | `Empresa123` |
| Donante | `donante@gmail.com` | `Donante123` |
| Estudiante 1 | `estudiante1@uniandes.edu.co` | `Est123` |
| Estudiantes 2–4 | `estudiante2..4@...` | `Est123` |

No hay registro público: **todas las cuentas las crean los administradores**.
Los 2 Super Admins son fijos y no pueden crearse ni eliminarse desde la UI.

## Estructura

```
ENACTUS V2/
├── media_resources/          # logo, favicon (fuente original)
├── course_resources/         # videos y PDFs de cursos (→ AWS S3 en el futuro)
│   ├── ruta_national_expo/
│   └── lab_<area>/curso_<nombre>/
└── enactus_platform/         # proyecto Flutter
    ├── assets/media/         # copia empaquetada del logo/favicon
    └── lib/
        ├── models/           # entidades (JSON ↔ objetos; contrato para RDS)
        ├── services/         # db (Hive), seed, PDF de certificados
        ├── providers/        # estado global (Provider): auth + datos
        ├── views/            # un directorio por portal/rol
        │   ├── public/ auth/ student/ mentor/ admin/ advisor/ company/ donor/
        ├── widgets/          # header, footer, shell, charts, video player
        └── utils/            # tema oscuro + constantes
```

## Roles y portales

- **Super Admin** — todo lo del admin + gestión de laboratorios y de admins.
- **Admin** — usuarios, proyectos (ODS, etapa, indicadores), grupos
  (universidad + asesor), asignación de cursos/patrocinadores/donantes,
  evidencias para donantes y contenido de la página principal.
- **Estudiante** — dashboard de progreso, cursos con videos locales, quizzes
  y entregas; RUTA NATIONAL EXPO colaborativa (checklist y entregas grupales);
  certificados en PDF.
- **Mentor** — tabla de estudiantes (proyecto/etapa/necesidad/institución),
  creación de cursos/módulos/lecciones de su laboratorio, calificación de
  entregas y emisión de certificados PDF.
- **Asesor académico** — dashboard de su universidad y seguimiento con
  alertas de riesgo de abandono. Solo ve estudiantes de su universidad.
- **Empresa** — indicadores de impacto, laboratorio patrocinado y
  estudiantes patrocinados.
- **Donante** — código de impacto único (p. ej. `ENACTUS-2026-4589`),
  resumen visual del aporte y galería de evidencias.

## Decisiones técnicas

- **Persistencia**: Hive (cajas por entidad, valores JSON). `DbService`
  expone `getAll/get/put/delete`: para migrar a PostgreSQL/AWS RDS basta con
  reimplementar esa clase contra una API REST — las vistas no cambian.
- **Estado**: `Provider` (`DataProvider` para datos, `AuthProvider` para sesión).
- **Videos**: `video_player` sobre archivos locales, con placeholder
  elegante si el archivo es dummy. En AWS pasará a URLs firmadas de S3.
- **Certificados**: paquete `pdf` + `printing` (vista previa e impresión),
  con logo, código de verificación, fecha y firma del mentor.
- **Gráficos**: `fl_chart` con paleta categórica validada para fondo oscuro
  (contraste ≥ 3:1 y separación para daltonismo ΔE ≥ 12):
  `#C98500, #3987E5, #E66767, #9085E9, #199E70`. El amarillo de marca
  (`#F4C430`) se reserva para la UI (botones, títulos, acentos).

## Próximos pasos para migrar a AWS

1. **S3** — subir `course_resources/` a un bucket; cambiar
   `Lesson.resourcePath` de rutas locales a keys de S3 y servir URLs firmadas
   (CloudFront opcional para streaming).
2. **RDS (PostgreSQL)** — cada modelo de `lib/models/` equivale a una tabla;
   crear una API (Lambda + API Gateway o un backend en ECS) y reimplementar
   `DbService` contra ella.
3. **Cognito** — reemplazar el login local por autenticación gestionada
   (los roles pasan a grupos de Cognito).
4. **Despliegue** — compilar `flutter build web` y servir desde S3 +
   CloudFront, o distribuir la app de escritorio.
5. **Seguridad** — antes de producción: hashear contraseñas (bcrypt),
   HTTPS en todas las llamadas y validación en servidor.
