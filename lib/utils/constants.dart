/// Constantes globales de la plataforma Enactus Colombia.
library;

import '../models/models.dart';

class Roles {
  static const superAdmin = 'superadmin';
  static const admin = 'admin';
  static const student = 'student';

  /// Egresado Enactus: cuenta idéntica a la de estudiante en accesos y
  /// permisos (mismo portal, mismos datos, mismas pestañas) — solo cambia
  /// la etiqueta visible ("Alumni" en vez de "Estudiante"). Ver
  /// [isStudentLike], que es la forma correcta de preguntar "¿esto es un
  /// estudiante (o su equivalente egresado)?" en el resto del código.
  static const alumni = 'alumni';

  /// LXD (Learning Experience Designer): antes se llamaba "mentor". Crea
  /// cursos completos (Enactus y Open Learning) y los asigna opcionalmente
  /// a un laboratorio. Las cuentas que antes tenían el rol "mentor" se
  /// migraron automáticamente a "lxd" (ver migration_service.dart).
  static const lxd = 'lxd';

  /// Mentor: rol nuevo, sin relación con el "mentor" anterior (ahora LXD).
  /// No crea cursos: revisa la Ruta de Impacto y las entregas de sus
  /// estudiantes/laboratorio, y se une a la reunión del módulo de
  /// mentoría. Las cuentas las crea el Admin manualmente.
  static const mentor = 'mentor';

  static const advisor = 'advisor';
  static const company = 'company';
  static const donor = 'donor';

  static const all = [
    superAdmin,
    admin,
    lxd,
    advisor,
    company,
    donor,
    student,
    alumni,
    mentor,
  ];

  /// Un Alumni tiene exactamente los mismos accesos y permisos que un
  /// estudiante (mismo portal, mismas consultas de laboratorios/cursos/
  /// entregas/certificados/foro/BuscaTalento): en cualquier lugar del
  /// código donde antes solo importaba `role == Roles.student`, debe
  /// preguntarse esto en su lugar.
  static bool isStudentLike(String role) => role == student || role == alumni;

  static String label(String role) => switch (role) {
        superAdmin => 'Super Admin',
        admin => 'Administrador',
        student => 'Estudiante',
        alumni => 'Alumni',
        lxd => 'LXD',
        mentor => 'Mentor',
        advisor => 'Asesor Académico',
        company => 'Empresa',
        donor => 'Donante',
        _ => role,
      };
}

class AppRoutes {
  static const landing = '/';
  static const login = '/login';
  static const student = '/student';
  static const alumni = '/alumni';
  static const lxd = '/lxd';
  static const mentor = '/mentor';
  static const admin = '/admin';
  static const superAdmin = '/superadmin';
  static const advisor = '/advisor';
  static const company = '/company';
  static const donor = '/donor';
  static const projects = '/proyectos';
  static const courses = '/cursos';

  /// Perfil de un usuario (cualquier rol) — ver `UserDetailView`. Antes
  /// solo existía `StudentDetailView`, alcanzable con `Navigator.push` pero
  /// sin URL con nombre.
  static const users = '/usuarios';

  /// Detalle de laboratorio, sin depender de un estudiante puntual — ver
  /// `LabDetailView`. Antes solo existía la vista embebida del propio
  /// portal Estudiante (`/student/lab/:id`, ligada siempre al usuario con
  /// sesión) y el perfil de una persona (progreso de UN estudiante puntual).
  static const labs = '/laboratorios';

  static String forRole(String role) => switch (role) {
        Roles.superAdmin => superAdmin,
        Roles.admin => admin,
        Roles.student => student,
        Roles.alumni => alumni,
        Roles.lxd => lxd,
        Roles.mentor => mentor,
        Roles.advisor => advisor,
        Roles.company => company,
        Roles.donor => donor,
        _ => landing,
      };
}

class SocialLinks {
  static const facebook = 'https://www.facebook.com/enactuscolombia/';
  static const instagram = 'https://www.instagram.com/enactuscolombia/';
  static const linkedin = 'http://linkedin.com/company/enactuscolombia/';
}

class InstitutionalInfo {
  static const footerText =
      'Entidad sin ánimo de lucro. Fundada en 2021. Bogotá D. C., Colombia.';
}

// Los ODS y las competencias Enactus **ya no viven acá**: los sirve
// `GET /catalogs` desde las tablas `ods_goals` y `competencies`.
//
// Estaban duplicados —una lista en Dart y otra en PostgreSQL— y las dos se
// iban separando en silencio: una competencia agregada en la base no aparecía
// en el editor, y la etiqueta larga de Dart ("ODS 6: Agua limpia y
// saneamiento") no es el código que acepta la API (`ods_6`), así que guardarla
// habría fallado recién contra la clave ajena.

/// Etapas de un proyecto, **en identificadores de la API** (`ideation`,
/// `validation`, …), en su orden real.
///
/// Antes esta lista tenía las etiquetas en español y se comparaba directo
/// contra `Project.stage`. Con la API eso deja de coincidir: el servidor
/// guarda el identificador, así que el filtro por etapa no encontraría nunca
/// nada y el riel de etapas quedaría siempre en la primera — sin que nada
/// falle ni se vea un error. Para mostrar, se usa `ProjectStage.label`.
const List<String> projectStages = ProjectStage.all;

/// Ruta local (relativa al directorio del repositorio) donde viven los
/// recursos de los cursos. En producción se reemplaza por URLs de AWS S3.
const String courseResourcesPath = '../course_resources';

// ---------------------------------------------------------------------------
// Catálogos del constructor de cursos (LMS)
// ---------------------------------------------------------------------------

// El nivel, el idioma, el estado y los tipos de entregable son
// identificadores de la API con etiqueta aparte: `CourseLevel`,
// `CourseLanguage`, `CourseStatus` y `DeliverableType` en `models.dart`.
// Antes eran listas en español que se mandaban tal cual al servidor.

/// Etiquetas sugeridas para categorizar cursos.
///
/// Estas SÍ son texto libre: `course_tags.tag` guarda lo que se escriba, sin
/// catálogo detrás. El LXD puede agregar las suyas.
const List<String> courseTags = [
  'IA',
  'Finanzas',
  'Pitch',
  'Marketing',
  'Innovación',
  'ODS',
  'Liderazgo',
  'Sostenibilidad',
  'Tecnología',
  'Comunidad',
];

