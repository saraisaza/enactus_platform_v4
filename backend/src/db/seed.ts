import { drizzle } from 'drizzle-orm/postgres-js';

import { hashPassword } from '../lib/password';
import { createClient, redactUrl } from './connection';
import { seedId } from './seed-ids';
import * as s from './schema';
import { databaseUrl } from '../env';

/**
 * Datos iniciales, equivalentes a `lib/services/seed_service.dart`.
 *
 * Todo sale de lo que ya existe en SeedService: los 2 super admins, el admin,
 * los 3 LXD, el mentor, el asesor, la empresa, el donante, los 4 estudiantes,
 * la estudiante de Open Learning y la alumni; los 6 laboratorios con la Ruta
 * real de `lab_ia`; los 2 proyectos y equipos; los 9 cursos; y la actividad de
 * demostración (progreso, entregas, evidencias, notificaciones, foro).
 *
 * Tres cosas se agregan porque la Fase 2 las pide explícitamente y hoy no
 * existen en el seed de Flutter — pero se arman con entidades que ya están,
 * no con datos inventados:
 *
 * 1. `lxd1` con `can_grade_enactus = true` (hoy los 3 LXD usan el default
 *    implícito `false`, así que en la app actual NINGUNO puede emitir
 *    certificados) y `lxd2` con los dos permisos en `false`.
 * 2. `est1` con la Ruta de Impacto PARCIALMENTE completa: termina el curso
 *    `crs_ia_1` entero y la lectura propia del módulo 1, con lo que ese
 *    módulo queda completo y el de mentoría pendiente → fase 1 incompleta.
 *    Hoy `est1` tiene 2 de 6 lecciones y ningún módulo completo.
 * 3. `alum1` conserva el avance original (2 lecciones), para tener un segundo
 *    estudiante en el mismo laboratorio con menos avance.
 *
 * Los ids son UUID determinísticos derivados de la clave de Hive
 * (ver `seed-ids.ts`), así que `db:reset` es reproducible.
 */

type Db = ReturnType<typeof drizzle<typeof s>>;

const ODS = [
  'Fin de la pobreza',
  'Hambre cero',
  'Salud y bienestar',
  'Educación de calidad',
  'Igualdad de género',
  'Agua limpia y saneamiento',
  'Energía asequible y no contaminante',
  'Trabajo decente y crecimiento económico',
  'Industria, innovación e infraestructura',
  'Reducción de las desigualdades',
  'Ciudades y comunidades sostenibles',
  'Producción y consumo responsables',
  'Acción por el clima',
  'Vida submarina',
  'Vida de ecosistemas terrestres',
  'Paz, justicia e instituciones sólidas',
  'Alianzas para lograr los objetivos',
];

const COMPETENCIES: [string, string][] = [
  ['leadership', 'Liderazgo'],
  ['innovation', 'Innovación'],
  ['entrepreneurship', 'Emprendimiento'],
  ['finance', 'Finanzas'],
  ['communication', 'Comunicación'],
  ['pitch', 'Pitch'],
  ['sustainability', 'Sostenibilidad'],
  ['artificial_intelligence', 'Inteligencia Artificial'],
  ['teamwork', 'Trabajo en equipo'],
  ['user_centered_design', 'Diseño Centrado en el Usuario'],
  ['project_management', 'Gestión de Proyectos'],
  ['impact_measurement', 'Medición de Impacto'],
];

const at = (iso: string) => new Date(iso);

export async function seed(db: Db): Promise<void> {
  await seedCatalogs(db);
  await seedUsers(db);
  await seedLaboratories(db);
  await seedProjectsAndGroups(db);
  await seedCourses(db);
  await seedRutaLinks(db);
  await seedAssignments(db);
  await seedDemoActivity(db);
  await seedSiteContent(db);
}

// ---------------------------------------------------------------------------
// Catálogos
// ---------------------------------------------------------------------------

async function seedCatalogs(db: Db) {
  await db.insert(s.odsGoals).values(
    ODS.map((title, i) => ({ code: `ods_${i + 1}`, number: i + 1, title })),
  );
  await db
    .insert(s.competencies)
    .values(COMPETENCIES.map(([code, name]) => ({ code, name })));
}

// ---------------------------------------------------------------------------
// Usuarios
// ---------------------------------------------------------------------------

async function seedUsers(db: Db) {
  // Las contraseñas son las mismas del seed de Flutter: son credenciales de
  // demostración, no secretos. En un entorno real se rotan al desplegar.
  const pw = {
    super1: await hashPassword('Super123'),
    super2: await hashPassword('Super456'),
    admin: await hashPassword('Admin123'),
    lxd: await hashPassword('Lxd123'),
    mentor: await hashPassword('Mentor123'),
    advisor: await hashPassword('Asesor123'),
    company: await hashPassword('Empresa123'),
    donor: await hashPassword('Donante123'),
    student: await hashPassword('Est123'),
    alumni: await hashPassword('Alumni123'),
  };

  // La empresa y el donante van primero: otros usuarios los referencian.
  await db.insert(s.users).values([
    {
      id: seedId('emp1'),
      name: 'Bancolombia',
      email: 'empresa@bancolombia.com',
      passwordHash: pw.company,
      role: 'company',
      companyName: 'Bancolombia',
      joinedAt: at('2021-09-01'),
    },
    {
      id: seedId('don1'),
      name: 'Fundación Impacto',
      email: 'donante@gmail.com',
      passwordHash: pw.donor,
      role: 'donor',
      impactCode: 'ENACTUS-2026-4589',
      joinedAt: at('2022-03-01'),
    },
  ]);

  await db.insert(s.users).values([
    {
      id: seedId('sa1'),
      name: 'Super Admin 1',
      email: 'superadmin1@enactus.co',
      passwordHash: pw.super1,
      role: 'superadmin',
      joinedAt: at('2021-03-01'),
    },
    {
      id: seedId('sa2'),
      name: 'Super Admin 2',
      email: 'superadmin2@enactus.co',
      passwordHash: pw.super2,
      role: 'superadmin',
      joinedAt: at('2021-03-01'),
    },
    {
      id: seedId('adm1'),
      name: 'Laura Gómez',
      email: 'admin@enactus.co',
      passwordHash: pw.admin,
      role: 'admin',
      phone: '3001234567',
      joinedAt: at('2021-06-01'),
    },
    {
      id: seedId('lxd1'),
      name: 'Carlos Rodríguez',
      email: 'lxd.ia@enactus.co',
      passwordHash: pw.lxd,
      role: 'lxd',
      phone: '3109876543',
      companyId: seedId('emp1'),
      // El LXD que SÍ puede calificar en los dos contextos y emitir
      // certificados (requisito de la Fase 2).
      canGradeOpenLearning: true,
      canGradeEnactus: true,
      profile: {
        company: 'Bancolombia',
        position: 'Líder de Ciencia de Datos',
        specialty: 'Inteligencia Artificial',
        languages: 'Español, Inglés',
        availability: 'Martes y jueves 6-8 pm',
        experience: '10 años en analítica y ML',
        interests: 'Educación, impacto social, tecnología',
      },
      joinedAt: at('2023-08-01'),
    },
    {
      id: seedId('lxd2'),
      name: 'Ana María Torres',
      email: 'lxd.agua@enactus.co',
      passwordHash: pw.lxd,
      role: 'lxd',
      // El LXD que NO puede calificar en ninguno de los dos contextos.
      canGradeOpenLearning: false,
      canGradeEnactus: false,
      profile: {
        company: 'EPM',
        position: 'Ingeniera Ambiental Senior',
        specialty: 'Gestión hídrica',
        languages: 'Español',
        availability: 'Lunes 5-7 pm',
        experience: '8 años en proyectos de saneamiento',
        interests: 'Sostenibilidad, comunidades rurales',
      },
      joinedAt: at('2024-02-01'),
    },
    {
      id: seedId('lxd3'),
      name: 'Sofía Ramírez',
      email: 'lxd.impacto@enactus.co',
      passwordHash: pw.lxd,
      role: 'lxd',
      companyId: seedId('emp1'),
      profile: {
        company: 'Bancolombia',
        position: 'Especialista en Medición de Impacto',
        specialty: 'Teoría de cambio e indicadores sociales',
        languages: 'Español, Inglés',
        availability: 'Miércoles 4-6 pm',
        experience: '6 años en evaluación de impacto social',
        interests: 'Medición de impacto, datos para el desarrollo',
      },
      joinedAt: at('2024-04-01'),
    },
    {
      id: seedId('ment1'),
      name: 'Daniela Herrera',
      email: 'mentor.ia@enactus.co',
      passwordHash: pw.mentor,
      role: 'mentor',
      companyId: seedId('emp1'),
      profile: { company: 'Bancolombia' },
      joinedAt: at('2024-05-01'),
    },
    {
      id: seedId('adv1'),
      name: 'Dr. Jorge Martínez',
      email: 'asesor@uniandes.edu.co',
      passwordHash: pw.advisor,
      role: 'advisor',
      university: 'Universidad de los Andes',
      joinedAt: at('2022-01-15'),
    },
    {
      id: seedId('est1'),
      name: 'Sara Nieto',
      email: 'estudiante1@uniandes.edu.co',
      passwordHash: pw.student,
      role: 'student',
      studentType: 'enactus',
      cedula: '1010101010',
      phone: '3151112233',
      university: 'Universidad de los Andes',
      career: 'Ingeniería Industrial',
      companyId: seedId('emp1'),
      donorId: seedId('don1'),
      joinedAt: at('2025-01-20'),
    },
    {
      id: seedId('est2'),
      name: 'Mateo Ruiz',
      email: 'estudiante2@uniandes.edu.co',
      passwordHash: pw.student,
      role: 'student',
      studentType: 'enactus',
      cedula: '1020202020',
      phone: '3162223344',
      university: 'Universidad de los Andes',
      career: 'Administración',
      companyId: seedId('emp1'),
      joinedAt: at('2025-01-20'),
    },
    {
      id: seedId('est3'),
      name: 'Valentina López',
      email: 'estudiante3@unal.edu.co',
      passwordHash: pw.student,
      role: 'student',
      studentType: 'enactus',
      cedula: '1030303030',
      phone: '3173334455',
      university: 'Universidad Nacional',
      career: 'Ingeniería Ambiental',
      donorId: seedId('don1'),
      joinedAt: at('2025-02-01'),
    },
    {
      id: seedId('est4'),
      name: 'Andrés Castro',
      email: 'estudiante4@unal.edu.co',
      passwordHash: pw.student,
      role: 'student',
      studentType: 'enactus',
      cedula: '1040404040',
      phone: '3184445566',
      university: 'Universidad Nacional',
      career: 'Ingeniería Eléctrica',
      joinedAt: at('2025-02-01'),
    },
    {
      id: seedId('est_ol1'),
      name: 'Camila Rivas',
      email: 'camila.rivas@gmail.com',
      passwordHash: pw.student,
      role: 'student',
      studentType: 'open_learning',
      joinedAt: at('2026-05-01'),
    },
    {
      id: seedId('alum1'),
      name: 'Juliana Restrepo',
      email: 'alumni1@uniandes.edu.co',
      passwordHash: pw.alumni,
      role: 'alumni',
      studentType: 'enactus',
      cedula: '1050505050',
      phone: '3195556677',
      university: 'Universidad de los Andes',
      career: 'Ingeniería Industrial',
      companyId: seedId('emp1'),
      donorId: seedId('don1'),
      joinedAt: at('2023-01-15'),
    },
  ]);
}

// ---------------------------------------------------------------------------
// Laboratorios, fases y módulos de la Ruta de Impacto
// ---------------------------------------------------------------------------

const LABS: [string, string, string, string][] = [
  [
    'lab_ia',
    'Laboratorio IA y Tecnología',
    'Inteligencia artificial y desarrollo tecnológico aplicado a impacto social.',
    'Formar en fundamentos de IA, datos y desarrollo de soluciones digitales.',
  ],
  [
    'lab_agua',
    'Laboratorio Agua',
    'Gestión hídrica, saneamiento y acceso a agua potable.',
    'Diseñar soluciones de acceso y calidad de agua para comunidades.',
  ],
  [
    'lab_energia',
    'Laboratorio Energía',
    'Energías renovables y eficiencia energética.',
    'Prototipar soluciones de energía limpia y asequible.',
  ],
  [
    'lab_impacto',
    'Laboratorio Impacto',
    'Medición y gestión de impacto social.',
    'Aprender metodologías de medición de impacto (teoría de cambio, indicadores).',
  ],
  [
    'lab_emprendimiento',
    'Laboratorio Emprendimiento',
    'Modelos de negocio y emprendimiento social.',
    'Construir y validar modelos de negocio sostenibles.',
  ],
  [
    'lab_agricultura',
    'Laboratorio Agricultura',
    'Agricultura sostenible y seguridad alimentaria.',
    'Desarrollar proyectos agro con enfoque regenerativo.',
  ],
];

async function seedLaboratories(db: Db) {
  await db.insert(s.laboratories).values(
    LABS.map(([key, name, description, objectives]) => ({
      id: seedId(key),
      name,
      description,
      objectives,
      sponsorCompanyId: key === 'lab_ia' ? seedId('emp1') : null,
    })),
  );

  await db.insert(s.laboratoryMentors).values({
    laboratoryId: seedId('lab_ia'),
    userId: seedId('ment1'),
  });

  // Los 6 laboratorios tienen siempre 3 fases (`Laboratory._defaultPhases`).
  // Solo `lab_ia` trae contenido; los otros 5 quedan con las fases vacías.
  const phases: (typeof s.phases.$inferInsert)[] = [];
  for (const [key] of LABS) {
    for (const order of [1, 2, 3]) {
      const isIa = key === 'lab_ia';
      phases.push({
        id: seedId(`${key}_fase${order}`),
        laboratoryId: seedId(key),
        orderIndex: order,
        title: isIa && order === 1 ? 'Fase 1: Fundamentos' : `Fase ${order}`,
        description:
          isIa && order === 1
            ? 'Introducción a la inteligencia artificial y su aplicación a proyectos sociales.'
            : '',
        // Fechas de demostración del seed original: la fase 1 ya vencida y la
        // fase 2 dentro de la ventana de aviso, para ver las dos alertas.
        deadline: isIa && order === 1 ? '2026-07-01' : isIa && order === 2 ? '2026-08-02' : null,
      });
    }
  }
  await db.insert(s.phases).values(phases);

  await db.insert(s.objectives).values([
    {
      id: seedId('lab_ia_fase1_obj1'),
      phaseId: seedId('lab_ia_fase1'),
      category: 'entrepreneurship',
      text: 'Identificar oportunidades de IA en proyectos sociales',
      orderIndex: 0,
    },
    {
      id: seedId('lab_ia_fase1_obj2'),
      phaseId: seedId('lab_ia_fase1'),
      category: 'business',
      text: 'Comprender los fundamentos de la IA y el aprendizaje automático',
      orderIndex: 1,
    },
  ]);

  await db.insert(s.rutaModules).values([
    {
      id: seedId('lab_ia_fase1_mod1'),
      phaseId: seedId('lab_ia_fase1'),
      orderIndex: 1,
      title: 'Módulo 1: Introducción a la IA',
      isMentorshipModule: false,
    },
    {
      // El último módulo de cada fase es siempre el de mentoría.
      id: seedId('lab_ia_fase1_mod2'),
      phaseId: seedId('lab_ia_fase1'),
      orderIndex: 2,
      title: 'Módulo 2: Mentoría',
      isMentorshipModule: true,
    },
  ]);

  await db.insert(s.lessons).values([
    {
      id: seedId('lab_ia_fase1_mod1_lect1'),
      rutaModuleId: seedId('lab_ia_fase1_mod1'),
      orderIndex: 1,
      title: 'Guía de la Fase 1',
      type: 'pdf',
      resourceS3Key: 'lab_ia_tecnologia/ruta_impacto/guia_fase1.pdf',
      resourceFileName: 'guia_fase1.pdf',
      resourceContentType: 'application/pdf',
    },
    {
      // Un módulo necesita al menos un elemento propio para poder completarse:
      // esta es la confirmación de asistencia a la reunión de mentoría.
      id: seedId('lab_ia_fase1_mod2_asistencia'),
      rutaModuleId: seedId('lab_ia_fase1_mod2'),
      orderIndex: 1,
      title: 'Confirmar asistencia a la reunión',
      type: 'activity',
      description:
        'Después de tu reunión con el Mentor, confirma aquí que asististe.',
    },
  ]);
}

// ---------------------------------------------------------------------------
// Proyectos, equipos y checklist Expo
// ---------------------------------------------------------------------------

async function seedProjectsAndGroups(db: Db) {
  await db.insert(s.projects).values([
    {
      id: seedId('prj1'),
      name: 'AquaVida',
      description: 'Filtros de agua de bajo costo para comunidades rurales.',
      problem: 'Comunidades de la Guajira sin acceso a agua potable.',
      solution:
        'Filtros cerámicos producidos localmente con capacitación comunitaria.',
      community: 'Comunidades wayúu, La Guajira',
      stage: 'pilot',
      impactIndicators: '320 familias con acceso a agua · 15 líderes capacitados',
      expoEnabled: true,
    },
    {
      id: seedId('prj2'),
      name: 'SolAndino',
      description: 'Micro-redes solares para escuelas rurales.',
      problem: 'Escuelas rurales de Boyacá sin electricidad confiable.',
      solution:
        'Paneles solares con baterías gestionadas por la comunidad educativa.',
      community: 'Escuelas rurales, Boyacá',
      stage: 'validation',
      impactIndicators: '4 escuelas · 260 estudiantes beneficiados',
      expoEnabled: true,
    },
  ]);

  await db.insert(s.projectOds).values([
    { projectId: seedId('prj1'), odsCode: 'ods_6' },
    { projectId: seedId('prj1'), odsCode: 'ods_3' },
    { projectId: seedId('prj2'), odsCode: 'ods_7' },
    { projectId: seedId('prj2'), odsCode: 'ods_4' },
  ]);

  await db.insert(s.groups).values([
    {
      id: seedId('grp1'),
      name: 'Equipo AquaVida',
      projectId: seedId('prj1'),
      university: 'Universidad de los Andes',
      advisorId: seedId('adv1'),
    },
    {
      id: seedId('grp2'),
      name: 'Equipo SolAndino',
      projectId: seedId('prj2'),
      university: 'Universidad Nacional',
      advisorId: seedId('adv1'),
    },
  ]);

  // `role_in_project` es la columna que faltaba en el modelo de Flutter
  // (BLOQUEOS.md § 2): allá `Group.studentIds` es solo una lista de ids.
  await db.insert(s.groupMembers).values([
    { groupId: seedId('grp1'), userId: seedId('est1'), roleInProject: 'leader' },
    { groupId: seedId('grp1'), userId: seedId('est2'), roleInProject: 'finance' },
    { groupId: seedId('grp1'), userId: seedId('alum1'), roleInProject: 'research' },
    { groupId: seedId('grp2'), userId: seedId('est3'), roleInProject: 'leader' },
    {
      groupId: seedId('grp2'),
      userId: seedId('est4'),
      roleInProject: 'operations',
    },
  ]);

  const checklist = [
    'Inscripción del equipo confirmada',
    'Annual Report entregado',
    'Impact Page publicada',
    'Pitch Deck versión final',
    'Video del proyecto grabado',
    'Simulación de pitch realizada',
    'Documentación de viaje completa',
  ];
  await db.insert(s.expoChecklistItems).values(
    ['grp1', 'grp2'].flatMap((g) =>
      checklist.map((label, i) => ({
        groupId: seedId(g),
        orderIndex: i,
        label,
        done: i === 0,
      })),
    ),
  );
}

// ---------------------------------------------------------------------------
// Cursos, módulos y lecciones
// ---------------------------------------------------------------------------

/** Lección de video propia (archivo en S3, servido por CloudFront). */
function uploadedVideo(
  key: string,
  moduleKey: string,
  order: number,
  title: string,
  path: string,
  durationMin = 0,
): typeof s.lessons.$inferInsert {
  return {
    id: seedId(key),
    courseModuleId: seedId(moduleKey),
    orderIndex: order,
    title,
    type: 'video',
    durationMin,
    videoType: 'uploaded',
    videoS3Key: path,
    videoMimeType: 'video/mp4',
  };
}

function pdfLesson(
  key: string,
  moduleKey: string,
  order: number,
  title: string,
  path: string,
): typeof s.lessons.$inferInsert {
  return {
    id: seedId(key),
    courseModuleId: seedId(moduleKey),
    orderIndex: order,
    title,
    type: 'pdf',
    resourceS3Key: path,
    resourceFileName: path.split('/').pop() ?? path,
    resourceContentType: 'application/pdf',
  };
}

async function seedCourses(db: Db) {
  await db.insert(s.courses).values([
    {
      id: seedId('crs_expo_p1'),
      name: 'RUTA NATIONAL EXPO — AquaVida',
      description:
        'Preparación colaborativa del equipo AquaVida para National Expo: entrenamientos, entregables y simulaciones.',
      isRutaExpo: true,
      legacyProjectId: seedId('prj1'),
    },
    {
      id: seedId('crs_expo_p2'),
      name: 'RUTA NATIONAL EXPO — SolAndino',
      description:
        'Preparación colaborativa del equipo SolAndino para National Expo.',
      isRutaExpo: true,
      legacyProjectId: seedId('prj2'),
    },
    {
      id: seedId('crs_ia_1'),
      name: 'Introducción a la Inteligencia Artificial',
      subtitle: 'IA aplicada al impacto social, desde cero',
      description: 'Fundamentos de IA aplicados a proyectos sociales.',
      fullDescription:
        'Aprende los fundamentos de la inteligencia artificial y cómo aplicarla a proyectos de impacto social: datos, modelos y casos reales de comunidades colombianas.',
      laboratoryId: seedId('lab_ia'),
      creatorId: seedId('lxd1'),
      level: 'intermediate',
      estimatedHours: 8,
      generatesCertificate: true,
      certifiedHours: 8,
    },
    {
      id: seedId('crs_agua_1'),
      name: 'Gestión Hídrica Comunitaria',
      description: 'Acceso, calidad y gobernanza del agua.',
      laboratoryId: seedId('lab_agua'),
      creatorId: seedId('lxd2'),
    },
    {
      id: seedId('crs_energia_1'),
      name: 'Energías Renovables Aplicadas',
      description: 'Solar, eólica y micro-redes para comunidades.',
      laboratoryId: seedId('lab_energia'),
    },
    {
      id: seedId('crs_impacto_1'),
      name: 'Medición de Impacto Social',
      description: 'Teoría de cambio e indicadores de impacto.',
      laboratoryId: seedId('lab_impacto'),
      creatorId: seedId('lxd3'),
    },
    {
      id: seedId('crs_emprend_1'),
      name: 'Modelo de Negocio Social',
      description: 'Canvas social y validación de mercado.',
      laboratoryId: seedId('lab_emprendimiento'),
    },
    {
      id: seedId('crs_agri_1'),
      name: 'Agricultura Sostenible',
      description: 'Técnicas regenerativas y seguridad alimentaria.',
      laboratoryId: seedId('lab_agricultura'),
    },
    {
      id: seedId('crs_ol_marketing'),
      name: 'Marketing Digital para Emprendedores',
      description:
        'Fundamentos de marketing digital aplicado a negocios sociales.',
      creatorId: seedId('lxd1'),
      isOpenLearning: true,
      level: 'basic',
      estimatedHours: 6,
    },
  ]);

  await db.insert(s.courseOds).values([
    { courseId: seedId('crs_ia_1'), odsCode: 'ods_4' },
    { courseId: seedId('crs_ia_1'), odsCode: 'ods_9' },
  ]);
  await db.insert(s.courseTags).values([
    { courseId: seedId('crs_ia_1'), tag: 'IA' },
    { courseId: seedId('crs_ia_1'), tag: 'Innovación' },
    { courseId: seedId('crs_ia_1'), tag: 'Tecnología' },
  ]);
  await db.insert(s.courseCompetencies).values([
    { courseId: seedId('crs_ia_1'), competencyCode: 'artificial_intelligence' },
    { courseId: seedId('crs_ia_1'), competencyCode: 'innovation' },
  ]);
  await db.insert(s.courseObjectives).values([
    {
      courseId: seedId('crs_ia_1'),
      category: 'business',
      text: 'Comprender los fundamentos de la IA y el aprendizaje automático',
      orderIndex: 0,
    },
    {
      courseId: seedId('crs_ia_1'),
      category: 'entrepreneurship',
      text: 'Identificar oportunidades de IA en proyectos sociales',
      orderIndex: 1,
    },
  ]);
  await db.insert(s.courseLearningOutcomes).values({
    courseId: seedId('crs_ia_1'),
    text: 'Propone una solución de IA para un problema comunitario real',
    orderIndex: 0,
  });

  const modules: [string, string, number, string][] = [
    ['mexpo1', 'crs_expo_p1', 1, 'Entrenamientos'],
    ['mexpo2', 'crs_expo_p2', 1, 'Entrenamientos'],
    ['mia1', 'crs_ia_1', 1, 'Módulo 1: Fundamentos'],
    ['mia2', 'crs_ia_1', 2, 'Módulo 2: Evaluación'],
    ['mag1', 'crs_agua_1', 1, 'Módulo 1: Diagnóstico'],
    ['men_1', 'crs_energia_1', 1, 'Módulo 1: Solar'],
    ['mim1', 'crs_impacto_1', 1, 'Módulo 1: Teoría de cambio'],
    ['mem1', 'crs_emprend_1', 1, 'Módulo 1: Canvas'],
    ['magr1', 'crs_agri_1', 1, 'Módulo 1: Suelos'],
    ['mol1', 'crs_ol_marketing', 1, 'Módulo 1: Fundamentos'],
  ];
  await db.insert(s.courseModules).values(
    modules.map(([key, courseKey, order, title]) => ({
      id: seedId(key),
      courseId: seedId(courseKey),
      orderIndex: order,
      title,
    })),
  );

  await db.insert(s.lessons).values([
    uploadedVideo('lexpo1', 'mexpo1', 1, 'Entrenamiento de pitch', 'ruta_national_expo/entrenamiento_pitch.mp4'),
    pdfLesson('lexpo2', 'mexpo1', 2, 'Guía del Annual Report', 'ruta_national_expo/annual_report_guia.pdf'),
    uploadedVideo('lexpo3', 'mexpo2', 1, 'Entrenamiento de pitch', 'ruta_national_expo/entrenamiento_pitch.mp4'),
    pdfLesson('lexpo4', 'mexpo2', 2, 'Guía del Annual Report', 'ruta_national_expo/annual_report_guia.pdf'),

    uploadedVideo('lia1', 'mia1', 1, '¿Qué es la IA?', 'lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4', 15),
    uploadedVideo('lia2', 'mia1', 2, 'Datos y modelos', 'lab_ia_tecnologia/curso_intro_ia/leccion_2.mp4', 20),
    pdfLesson('lia3', 'mia1', 3, 'Material de apoyo', 'lab_ia_tecnologia/curso_intro_ia/material.pdf'),
    {
      id: seedId('lia4'),
      courseModuleId: seedId('mia2'),
      orderIndex: 1,
      title: 'Quiz: conceptos básicos',
      type: 'quiz',
    },
    {
      id: seedId('lia5'),
      courseModuleId: seedId('mia2'),
      orderIndex: 2,
      title: 'Proyecto: IA para tu comunidad',
      type: 'activity',
    },
    {
      id: seedId('lia6'),
      courseModuleId: seedId('mia2'),
      orderIndex: 3,
      title: 'Encuesta de satisfacción del curso',
      type: 'survey',
    },

    uploadedVideo('lag1', 'mag1', 1, 'Diagnóstico hídrico local', 'lab_agua/curso_gestion_hidrica/leccion_1.mp4'),
    uploadedVideo('lag2', 'mag1', 2, 'Soluciones de filtración', 'lab_agua/curso_gestion_hidrica/leccion_2.mp4'),
    pdfLesson('lag3', 'mag1', 3, 'Manual técnico', 'lab_agua/curso_gestion_hidrica/material.pdf'),

    uploadedVideo('len1', 'men_1', 1, 'Fundamentos fotovoltaicos', 'lab_energia/curso_energias_renovables/leccion_1.mp4'),
    uploadedVideo('len2', 'men_1', 2, 'Dimensionamiento de sistemas', 'lab_energia/curso_energias_renovables/leccion_2.mp4'),

    uploadedVideo('lim1', 'mim1', 1, 'Construyendo la teoría de cambio', 'lab_impacto/curso_medicion_impacto/leccion_1.mp4'),
    pdfLesson('lim2', 'mim1', 2, 'Plantilla de indicadores', 'lab_impacto/curso_medicion_impacto/material.pdf'),

    uploadedVideo('lem1', 'mem1', 1, 'Canvas de negocio social', 'lab_emprendimiento/curso_modelo_negocio/leccion_1.mp4'),
    uploadedVideo('lem2', 'mem1', 2, 'Validación con clientes', 'lab_emprendimiento/curso_modelo_negocio/leccion_2.mp4'),

    uploadedVideo('lagr1', 'magr1', 1, 'Salud del suelo', 'lab_agricultura/curso_agricultura_sostenible/leccion_1.mp4'),
    uploadedVideo('lagr2', 'magr1', 2, 'Compostaje comunitario', 'lab_agricultura/curso_agricultura_sostenible/leccion_2.mp4'),

    uploadedVideo('lol1', 'mol1', 1, 'Introducción al marketing digital', 'open_learning/marketing_digital/leccion_1.mp4'),
    pdfLesson('lol2', 'mol1', 2, 'Plantilla de plan de marketing', 'open_learning/marketing_digital/plantilla.pdf'),
  ]);

  // Quiz del curso demo: los 4 tipos de pregunta que soporta el constructor.
  await db.insert(s.quizQuestions).values([
    {
      id: seedId('q_lia4_1'),
      lessonId: seedId('lia4'),
      orderIndex: 0,
      kind: 'multiple',
      question: '¿Qué es el aprendizaje supervisado?',
      answerIndex: 0,
    },
    {
      id: seedId('q_lia4_2'),
      lessonId: seedId('lia4'),
      orderIndex: 1,
      kind: 'truefalse',
      question: 'La IA puede ayudar a predecir la deserción escolar.',
      answerIndex: 0,
    },
    {
      id: seedId('q_lia4_3'),
      lessonId: seedId('lia4'),
      orderIndex: 2,
      kind: 'short',
      question: '¿Cómo se llaman los datos usados para entrenar un modelo?',
      answerText: 'datos de entrenamiento',
    },
    {
      id: seedId('q_lia4_4'),
      lessonId: seedId('lia4'),
      orderIndex: 3,
      kind: 'order',
      question: 'Ordena las etapas de un proyecto de IA:',
    },
    {
      id: seedId('q_lia6_1'),
      lessonId: seedId('lia6'),
      orderIndex: 0,
      kind: 'short',
      question: '¿Qué fue lo que más te gustó del curso?',
    },
    {
      id: seedId('q_lia6_2'),
      lessonId: seedId('lia6'),
      orderIndex: 1,
      kind: 'short',
      question: '¿Qué mejorarías?',
    },
  ]);

  await db.insert(s.quizQuestionOptions).values([
    { quizQuestionId: seedId('q_lia4_1'), orderIndex: 0, text: 'Modelos entrenados con datos etiquetados' },
    { quizQuestionId: seedId('q_lia4_1'), orderIndex: 1, text: 'Modelos sin datos' },
    { quizQuestionId: seedId('q_lia4_1'), orderIndex: 2, text: 'Un tipo de hardware' },
    // En las preguntas de tipo `order`, el orden guardado ES la respuesta.
    { quizQuestionId: seedId('q_lia4_4'), orderIndex: 0, text: 'Recolectar datos' },
    { quizQuestionId: seedId('q_lia4_4'), orderIndex: 1, text: 'Entrenar el modelo' },
    { quizQuestionId: seedId('q_lia4_4'), orderIndex: 2, text: 'Evaluar resultados' },
    { quizQuestionId: seedId('q_lia4_4'), orderIndex: 3, text: 'Desplegar la solución' },
  ]);

  await db.insert(s.lessonActivities).values({
    lessonId: seedId('lia5'),
    description:
      'Propón una solución de IA para un problema real de tu comunidad. Incluye el problema, los datos necesarios y el impacto esperado.',
    requiresFile: true,
    requiresText: true,
    maxFiles: 2,
    gradingMode: 'points100',
  });
  await db.insert(s.activityAllowedTypes).values([
    { lessonId: seedId('lia5'), fileType: 'pdf' },
    { lessonId: seedId('lia5'), fileType: 'document' },
  ]);
  await db.insert(s.activityRubricItems).values(
    ['Contenido', 'Presentación', 'Investigación', 'Creatividad', 'Impacto'].map(
      (criterion, i) => ({
        lessonId: seedId('lia5'),
        orderIndex: i,
        criterion,
        points: 20,
      }),
    ),
  );

  // El módulo de mentoría también necesita su configuración de actividad.
  await db.insert(s.lessonActivities).values({
    lessonId: seedId('lab_ia_fase1_mod2_asistencia'),
    description:
      'Después de tu reunión con el Mentor, confirma aquí que asististe.',
    requiresFile: false,
    requiresText: true,
    maxFiles: 1,
    gradingMode: 'review',
  });
}

// ---------------------------------------------------------------------------
// Vinculación curso → módulo de Ruta / objetivo
// ---------------------------------------------------------------------------

async function seedRutaLinks(db: Db) {
  await db.insert(s.rutaModuleCourses).values({
    rutaModuleId: seedId('lab_ia_fase1_mod1'),
    courseId: seedId('crs_ia_1'),
  });
  await db.insert(s.objectiveCourses).values([
    { objectiveId: seedId('lab_ia_fase1_obj1'), courseId: seedId('crs_ia_1') },
    { objectiveId: seedId('lab_ia_fase1_obj2'), courseId: seedId('crs_ia_1') },
  ]);
}

// ---------------------------------------------------------------------------
// Asignaciones (antes `extra.labIds` / `extra.courseIds` / `reviewCourseIds`)
// ---------------------------------------------------------------------------

async function seedAssignments(db: Db) {
  await db.insert(s.studentLaboratories).values([
    { studentId: seedId('est1'), laboratoryId: seedId('lab_ia') },
    { studentId: seedId('est1'), laboratoryId: seedId('lab_impacto') },
    { studentId: seedId('est2'), laboratoryId: seedId('lab_emprendimiento') },
    { studentId: seedId('est3'), laboratoryId: seedId('lab_agua') },
    { studentId: seedId('est3'), laboratoryId: seedId('lab_agricultura') },
    { studentId: seedId('est4'), laboratoryId: seedId('lab_energia') },
    { studentId: seedId('alum1'), laboratoryId: seedId('lab_ia') },
    { studentId: seedId('alum1'), laboratoryId: seedId('lab_impacto') },
  ]);

  // Solo Open Learning usa asignación directa de cursos: para un Enactus el
  // acceso sale del laboratorio (`studentHasCourse`).
  await db.insert(s.studentCourses).values({
    studentId: seedId('est_ol1'),
    courseId: seedId('crs_ol_marketing'),
  });
}

// ---------------------------------------------------------------------------
// Actividad de demostración
// ---------------------------------------------------------------------------

async function seedDemoActivity(db: Db) {
  /** Crea la fila de progreso de curso y marca las lecciones indicadas. */
  async function courseProgress(
    studentKey: string,
    courseKey: string,
    lessonKeys: string[],
  ) {
    const [row] = await db
      .insert(s.progress)
      .values({ studentId: seedId(studentKey), courseId: seedId(courseKey) })
      .returning({ id: s.progress.id });
    if (!row || lessonKeys.length === 0) return;
    await db
      .insert(s.progressLessons)
      .values(
        lessonKeys.map((k) => ({ progressId: row.id, lessonId: seedId(k) })),
      );
  }

  /** Marca lecturas/entregas propias de módulos de la Ruta. */
  async function rutaProgress(
    studentKey: string,
    labKey: string,
    lessonKeys: string[],
  ) {
    const [row] = await db
      .insert(s.rutaProgress)
      .values({ studentId: seedId(studentKey), laboratoryId: seedId(labKey) })
      .returning({ id: s.rutaProgress.id });
    if (!row || lessonKeys.length === 0) return;
    await db
      .insert(s.rutaProgressLessons)
      .values(
        lessonKeys.map((k) => ({ rutaProgressId: row.id, lessonId: seedId(k) })),
      );
  }

  // `est1`: Ruta de Impacto PARCIALMENTE completa (requisito de la Fase 2).
  // Termina el curso entero y la lectura propia del módulo 1 → ese módulo
  // queda completo; el módulo de mentoría no → la fase 1 sigue incompleta.
  await courseProgress('est1', 'crs_ia_1', ['lia1', 'lia2', 'lia3', 'lia4', 'lia5', 'lia6']);
  await rutaProgress('est1', 'lab_ia', ['lab_ia_fase1_mod1_lect1']);
  await courseProgress('est1', 'crs_impacto_1', ['lim1']);

  await courseProgress('est2', 'crs_emprend_1', ['lem1']);
  await courseProgress('est3', 'crs_agua_1', ['lag1', 'lag2', 'lag3']);
  await courseProgress('est4', 'crs_energia_1', []);
  // `alum1` conserva el avance original del seed de Flutter: menos que est1.
  await courseProgress('alum1', 'crs_ia_1', ['lia1', 'lia2']);
  await courseProgress('alum1', 'crs_impacto_1', ['lim1']);

  await db.insert(s.submissions).values([
    {
      id: seedId('sub1'),
      courseId: seedId('crs_ia_1'),
      studentId: seedId('est1'),
      taskName: 'Ensayo: IA para el bien social',
      comment: 'Adjunto mi ensayo sobre aplicaciones de IA en salud rural.',
      grade: '4.50',
      // El seed de Flutter guarda la nota 4.5 sin decir en qué escala ni
      // quién la puso. La escala es `scale5` (entrega libre, sin actividad
      // asociada) y quien pudo calificarla es el LXD dueño del curso.
      gradingMode: 'scale5',
      gradedBy: seedId('lxd1'),
      gradedAt: at('2026-06-20'),
      feedback: 'Excelente análisis. Profundiza en la parte de datos.',
      submittedAt: at('2026-06-20'),
    },
    {
      id: seedId('sub2'),
      courseId: seedId('crs_agua_1'),
      studentId: seedId('est3'),
      taskName: 'Diagnóstico hídrico de mi comunidad',
      comment: 'Diagnóstico realizado en el municipio de Sesquilé.',
      submittedAt: at('2026-07-01'),
    },
    {
      id: seedId('sub3'),
      courseId: seedId('crs_expo_p1'),
      groupId: seedId('grp1'),
      taskName: 'Annual Report (borrador)',
      comment: 'Primera versión del Annual Report del equipo.',
      submittedAt: at('2026-06-28'),
    },
  ]);

  // `project_id` es la columna que faltaba (BLOQUEOS.md § 2). Se asigna según
  // lo que la propia evidencia dice: dos hablan de AquaVida, la tercera es un
  // reporte trimestral general y queda sin proyecto.
  await db.insert(s.evidences).values([
    {
      id: seedId('ev1'),
      donorId: seedId('don1'),
      projectId: seedId('prj1'),
      type: 'story',
      title: 'La historia de Sara',
      description:
        'Gracias a tu aporte, Sara lidera el proyecto AquaVida que hoy lleva agua potable a 320 familias en La Guajira.',
      evidenceDate: at('2026-05-15'),
    },
    {
      id: seedId('ev2'),
      donorId: seedId('don1'),
      type: 'report',
      title: 'Reporte de impacto Q2 2026',
      description:
        'Resumen trimestral de resultados de los proyectos apoyados.',
      evidenceDate: at('2026-06-30'),
    },
    {
      id: seedId('ev3'),
      donorId: seedId('don1'),
      projectId: seedId('prj1'),
      type: 'testimonial',
      title: 'Testimonio de la comunidad',
      description:
        '"El filtro cambió la salud de nuestros niños" — Líder comunitaria wayúu.',
      evidenceDate: at('2026-06-10'),
    },
  ]);

  await db.insert(s.notifications).values([
    {
      id: seedId('not1'),
      userId: seedId('est1'),
      title: 'Entrega calificada',
      body: 'Tu ensayo de IA fue calificado con 4.5. ¡Revisa la retroalimentación!',
      createdAt: at('2026-06-21'),
    },
    {
      id: seedId('not2'),
      userId: seedId('lxd1'),
      title: 'Nueva entrega pendiente',
      body: 'Valentina López envió "Diagnóstico hídrico de mi comunidad".',
      createdAt: at('2026-07-01'),
    },
  ]);

  await db.insert(s.forumPosts).values([
    {
      id: seedId('post1'),
      authorId: seedId('adm1'),
      body: '¡Bienvenidos al foro de la comunidad eduXaction Colombia! 💛 Este es el espacio para compartir avances, hacer preguntas entre laboratorios y celebrar los logros de todos los equipos, sin importar tu universidad o laboratorio.',
      category: 'announcement',
      pinned: true,
      createdAt: at('2026-06-02T09:00:00Z'),
    },
    {
      id: seedId('post2'),
      authorId: seedId('adv1'),
      body: 'Muy orgulloso del equipo AquaVida de la Universidad de los Andes: pasaron a etapa Piloto esta semana. Si algún otro equipo está trabajando temas de agua, con gusto conectamos experiencias 🚰',
      category: 'progress',
      createdAt: at('2026-06-15T14:30:00Z'),
    },
    {
      id: seedId('post3'),
      authorId: seedId('est1'),
      body: '¿Alguien ha usado modelos de IA para predecir deserción escolar? Estamos empezando esa parte del proyecto en el Laboratorio de IA y Tecnología y nos vendría bien aprender de otros equipos.',
      category: 'question',
      createdAt: at('2026-07-10T11:15:00Z'),
    },
    {
      id: seedId('post4'),
      authorId: seedId('est3'),
      body: 'Compartiendo un logro del Laboratorio Agua: instalamos el primer filtro comunitario piloto en La Guajira. ¡Gracias a todos los que nos dieron ideas en este foro! 🎉',
      category: 'progress',
      createdAt: at('2026-07-22T16:45:00Z'),
    },
  ]);
}

async function seedSiteContent(db: Db) {
  await db.insert(s.siteContent).values({
    id: 1,
    heroTitle: 'eduXaction Colombia',
    heroSubtitle:
      'Formamos líderes que transforman comunidades a través del emprendimiento social.',
    bannerText: 'Convocatoria National Expo 2026 abierta',
    aboutText:
      'Conectamos estudiantes, mentores, universidades, empresas y donantes para crear proyectos de impacto social en toda Colombia.',
    meetingLink: 'https://meet.google.com/eduxaction-mentoria',
    statStudents: 6,
    statProjects: 2,
    statLabs: 6,
    statUniversities: 2,
  });
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

async function main() {
  const sql = createClient(databaseUrl);
  const db = drizzle(sql, { schema: s, casing: 'snake_case' });
  try {
    console.log(`Sembrando ${redactUrl(databaseUrl)}…`);
    await seed(db);
    console.log('Seed completo.');
  } finally {
    await sql.end();
  }
}

// Solo corre como script; al importarlo desde un test no hace nada.
if (process.argv[1]?.endsWith('seed.ts')) {
  main().catch((error: unknown) => {
    console.error('Falló el seed:', error);
    process.exit(1);
  });
}
