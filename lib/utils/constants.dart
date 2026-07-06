/// Constantes globales de la plataforma Enactus Colombia.
library;

class Roles {
  static const superAdmin = 'superadmin';
  static const admin = 'admin';
  static const student = 'student';
  static const mentor = 'mentor';
  static const advisor = 'advisor';
  static const company = 'company';
  static const donor = 'donor';

  static const all = [superAdmin, admin, student, mentor, advisor, company, donor];

  static String label(String role) => switch (role) {
        superAdmin => 'Super Admin',
        admin => 'Administrador',
        student => 'Estudiante',
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
  static const mentor = '/mentor';
  static const admin = '/admin';
  static const superAdmin = '/superadmin';
  static const advisor = '/advisor';
  static const company = '/company';
  static const donor = '/donor';

  static String forRole(String role) => switch (role) {
        Roles.superAdmin => superAdmin,
        Roles.admin => admin,
        Roles.student => student,
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

/// Objetivos de Desarrollo Sostenible (ONU) para asociar a proyectos.
const List<String> odsList = [
  'ODS 1: Fin de la pobreza',
  'ODS 2: Hambre cero',
  'ODS 3: Salud y bienestar',
  'ODS 4: Educación de calidad',
  'ODS 5: Igualdad de género',
  'ODS 6: Agua limpia y saneamiento',
  'ODS 7: Energía asequible y no contaminante',
  'ODS 8: Trabajo decente y crecimiento económico',
  'ODS 9: Industria, innovación e infraestructura',
  'ODS 10: Reducción de las desigualdades',
  'ODS 11: Ciudades y comunidades sostenibles',
  'ODS 12: Producción y consumo responsables',
  'ODS 13: Acción por el clima',
  'ODS 14: Vida submarina',
  'ODS 15: Vida de ecosistemas terrestres',
  'ODS 16: Paz, justicia e instituciones sólidas',
  'ODS 17: Alianzas para lograr los objetivos',
];

/// Etapas posibles de un proyecto Enactus.
const List<String> projectStages = [
  'Ideación',
  'Validación',
  'Prototipo',
  'Piloto',
  'Escalamiento',
  'National Expo',
];

/// Ruta local (relativa al directorio del repositorio) donde viven los
/// recursos de los cursos. En producción se reemplaza por URLs de AWS S3.
const String courseResourcesPath = '../course_resources';

// ---------------------------------------------------------------------------
// Catálogos del constructor de cursos (LMS)
// ---------------------------------------------------------------------------

const List<String> courseLevels = ['Básico', 'Intermedio', 'Avanzado'];

const List<String> courseLanguages = ['Español', 'Inglés', 'Portugués'];

const List<String> courseStatuses = ['Borrador', 'Publicado', 'Archivado'];

/// Etiquetas sugeridas para categorizar cursos.
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

/// Competencias Enactus que un curso puede desarrollar. Alimentan las
/// métricas de impacto formativo (horas por competencia).
const List<String> enactusCompetencies = [
  'Liderazgo',
  'Innovación',
  'Emprendimiento',
  'Finanzas',
  'Comunicación',
  'Pitch',
  'Sostenibilidad',
  'Inteligencia Artificial',
  'Trabajo en equipo',
  'Diseño Centrado en el Usuario',
  'Gestión de Proyectos',
  'Medición de Impacto',
];

/// Tipos de archivo aceptables en entregables de actividades.
const List<String> deliverableTypes = [
  'PDF',
  'Video',
  'Documento',
  'Imagen',
  'ZIP',
];
