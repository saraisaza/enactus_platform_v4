import '../models/models.dart';
import 'db_service.dart';

/// Datos iniciales de la plataforma (solo se cargan si la BD está vacía).
///
/// Incluye los 2 Super Admins por defecto, los 6 laboratorios, usuarios de
/// ejemplo por cada rol, proyectos, grupos, cursos con lecciones apuntando a
/// `course_resources/` y datos de demostración (entregas, progreso,
/// evidencias, notificaciones).
class SeedService {
  final DbService db;
  SeedService(this.db);

  Future<void> seedIfEmpty() async {
    if (!db.isEmpty) {
      // BD existente: actualiza el curso demo de IA a la versión LMS
      // (solo si el usuario no lo ha personalizado).
      await _upgradeDemoCourse();
      return;
    }
    await _seedUsersAndLabs();
    await _seedProjectsAndGroups();
    await _seedCourses();
    await _seedDemoActivity();
  }

  /// Si el curso demo de IA sigue en su versión antigua (sin subtítulo,
  /// competencias ni certificado), lo reemplaza por la versión LMS completa
  /// para que las nuevas funciones sean visibles con datos ya guardados.
  Future<void> _upgradeDemoCourse() async {
    final j = db.get('courses', 'crs_ia_1');
    if (j == null) return;
    final existing = Course.fromJson(j);
    final untouched = existing.subtitle.isEmpty &&
        existing.competencies.isEmpty &&
        !existing.generatesCertificate;
    if (untouched) {
      await db.put('courses', 'crs_ia_1', _demoIaCourse().toJson());
    }
  }

  Future<void> _seedUsersAndLabs() async {
    final users = <AppUser>[
      // --- Super Admins (fijos, no se crean más desde la interfaz) ---
      AppUser(
        id: 'sa1',
        name: 'Super Admin 1',
        email: 'superadmin1@enactus.co',
        password: 'Super123',
        role: 'superadmin',
        extra: {'joinedAt': '2021-03-01T00:00:00.000'},
      ),
      AppUser(
        id: 'sa2',
        name: 'Super Admin 2',
        email: 'superadmin2@enactus.co',
        password: 'Super456',
        role: 'superadmin',
        extra: {'joinedAt': '2021-03-01T00:00:00.000'},
      ),
      // --- Admin ---
      AppUser(
        id: 'adm1',
        name: 'Laura Gómez',
        email: 'admin@enactus.co',
        password: 'Admin123',
        role: 'admin',
        phone: '3001234567',
        extra: {'joinedAt': '2021-06-01T00:00:00.000'},
      ),
      // --- LXD (antes "Mentor"): crean y son dueños de los cursos ---
      AppUser(
        id: 'lxd1',
        name: 'Carlos Rodríguez',
        email: 'lxd.ia@enactus.co',
        password: 'Lxd123',
        role: 'lxd',
        phone: '3109876543',
        extra: {
          'company': 'Bancolombia',
          'companyId': 'emp1',
          'position': 'Líder de Ciencia de Datos',
          'specialty': 'Inteligencia Artificial',
          'languages': 'Español, Inglés',
          'availability': 'Martes y jueves 6-8 pm',
          'experience': '10 años en analítica y ML',
          'interests': 'Educación, impacto social, tecnología',
          'joinedAt': '2023-08-01T00:00:00.000',
        },
      ),
      AppUser(
        id: 'lxd2',
        name: 'Ana María Torres',
        email: 'lxd.agua@enactus.co',
        password: 'Lxd123',
        role: 'lxd',
        extra: {
          'company': 'EPM',
          'position': 'Ingeniera Ambiental Senior',
          'specialty': 'Gestión hídrica',
          'languages': 'Español',
          'availability': 'Lunes 5-7 pm',
          'experience': '8 años en proyectos de saneamiento',
          'interests': 'Sostenibilidad, comunidades rurales',
          'joinedAt': '2024-02-01T00:00:00.000',
        },
      ),
      // Segundo LXD de Bancolombia: una empresa puede tener varios LXD
      // creando cursos en laboratorios distintos a la vez (no solo uno).
      AppUser(
        id: 'lxd3',
        name: 'Sofía Ramírez',
        email: 'lxd.impacto@enactus.co',
        password: 'Lxd123',
        role: 'lxd',
        extra: {
          'companyId': 'emp1',
          'company': 'Bancolombia',
          'position': 'Especialista en Medición de Impacto',
          'specialty': 'Teoría de cambio e indicadores sociales',
          'languages': 'Español, Inglés',
          'availability': 'Miércoles 4-6 pm',
          'experience': '6 años en evaluación de impacto social',
          'interests': 'Medición de impacto, datos para el desarrollo',
          'joinedAt': '2024-04-01T00:00:00.000',
        },
      ),
      // --- Mentor (rol nuevo): revisa Ruta de Impacto y entregas ---
      AppUser(
        id: 'ment1',
        name: 'Daniela Herrera',
        email: 'mentor.ia@enactus.co',
        password: 'Mentor123',
        role: 'mentor',
        extra: {
          'companyId': 'emp1',
          'company': 'Bancolombia',
          'joinedAt': '2024-05-01T00:00:00.000',
        },
      ),
      // --- Asesor académico ---
      AppUser(
        id: 'adv1',
        name: 'Dr. Jorge Martínez',
        email: 'asesor@uniandes.edu.co',
        password: 'Asesor123',
        role: 'advisor',
        extra: {
          'university': 'Universidad de los Andes',
          'joinedAt': '2022-01-15T00:00:00.000',
        },
      ),
      // --- Empresa ---
      AppUser(
        id: 'emp1',
        name: 'Bancolombia',
        email: 'empresa@bancolombia.com',
        password: 'Empresa123',
        role: 'company',
        extra: {
          'companyName': 'Bancolombia',
          'joinedAt': '2021-09-01T00:00:00.000',
        },
      ),
      // --- Donante ---
      AppUser(
        id: 'don1',
        name: 'Fundación Impacto',
        email: 'donante@gmail.com',
        password: 'Donante123',
        role: 'donor',
        extra: {
          'impactCode': 'ENACTUS-2026-4589',
          'joinedAt': '2022-03-01T00:00:00.000',
        },
      ),
      // --- Estudiantes ---
      AppUser(
        id: 'est1',
        name: 'Sara Nieto',
        email: 'estudiante1@uniandes.edu.co',
        password: 'Est123',
        role: 'student',
        cedula: '1010101010',
        phone: '3151112233',
        extra: {
          'university': 'Universidad de los Andes',
          'career': 'Ingeniería Industrial',
          'groupId': 'grp1',
          'courseIds': ['crs_expo_p1', 'crs_ia_1', 'crs_impacto_1'],
          'companyId': 'emp1',
          'donorId': 'don1',
          // Varios laboratorios: cada uno con su propia Ruta de Impacto,
          // y sus cursos se ven automáticamente (no hace falta asignarlos
          // aparte).
          'labIds': ['lab_ia', 'lab_impacto'],
          'joinedAt': '2025-01-20T00:00:00.000',
        },
      ),
      AppUser(
        id: 'est2',
        name: 'Mateo Ruiz',
        email: 'estudiante2@uniandes.edu.co',
        password: 'Est123',
        role: 'student',
        cedula: '1020202020',
        phone: '3162223344',
        extra: {
          'university': 'Universidad de los Andes',
          'career': 'Administración',
          'groupId': 'grp1',
          'courseIds': ['crs_expo_p1', 'crs_emprend_1'],
          'companyId': 'emp1',
          'labIds': ['lab_emprendimiento'],
          'joinedAt': '2025-01-20T00:00:00.000',
        },
      ),
      AppUser(
        id: 'est3',
        name: 'Valentina López',
        email: 'estudiante3@unal.edu.co',
        password: 'Est123',
        role: 'student',
        cedula: '1030303030',
        phone: '3173334455',
        extra: {
          'university': 'Universidad Nacional',
          'career': 'Ingeniería Ambiental',
          'groupId': 'grp2',
          'courseIds': ['crs_expo_p2', 'crs_agua_1', 'crs_agri_1'],
          'donorId': 'don1',
          'labIds': ['lab_agua', 'lab_agricultura'],
          'joinedAt': '2025-02-01T00:00:00.000',
        },
      ),
      AppUser(
        id: 'est4',
        name: 'Andrés Castro',
        email: 'estudiante4@unal.edu.co',
        password: 'Est123',
        role: 'student',
        cedula: '1040404040',
        phone: '3184445566',
        extra: {
          'university': 'Universidad Nacional',
          'career': 'Ingeniería Eléctrica',
          'groupId': 'grp2',
          'courseIds': ['crs_expo_p2', 'crs_energia_1'],
          'labIds': ['lab_energia'],
          'joinedAt': '2025-02-01T00:00:00.000',
        },
      ),
      // --- Estudiante de Open Learning (externo, pagó el curso) ---
      AppUser(
        id: 'est_ol1',
        name: 'Camila Rivas',
        email: 'camila.rivas@gmail.com',
        password: 'Est123',
        role: 'student',
        extra: {
          'studentType': StudentType.openLearning,
          'courseIds': ['crs_ol_marketing'],
          'joinedAt': '2026-05-01T00:00:00.000',
        },
      ),
      // --- Alumni (egresada Enactus): mismo acceso que un estudiante, ver
      // Roles.isStudentLike. Mismos laboratorios/empresa/donante que est1
      // para poder comparar lado a lado que se ve igual en cada portal.
      AppUser(
        id: 'alum1',
        name: 'Juliana Restrepo',
        email: 'alumni1@uniandes.edu.co',
        password: 'Alumni123',
        role: 'alumni',
        cedula: '1050505050',
        phone: '3195556677',
        extra: {
          'university': 'Universidad de los Andes',
          'career': 'Ingeniería Industrial',
          'studentType': StudentType.enactus,
          'groupId': 'grp1',
          'courseIds': ['crs_expo_p1', 'crs_ia_1', 'crs_impacto_1'],
          'companyId': 'emp1',
          'donorId': 'don1',
          'labIds': ['lab_ia', 'lab_impacto'],
          'joinedAt': '2023-01-15T00:00:00.000',
        },
      ),
    ];
    for (final u in users) {
      await db.put('users', u.id, u.toJson());
    }

    final labs = <Laboratory>[
      Laboratory(
        id: 'lab_ia',
        name: 'Laboratorio IA y Tecnología',
        description: 'Inteligencia artificial y desarrollo tecnológico aplicado a impacto social.',
        objectives: 'Formar en fundamentos de IA, datos y desarrollo de soluciones digitales.',
        mentorIds: ['ment1'],
        sponsorCompanyId: 'emp1',
        phases: [
          Phase(
            id: 'lab_ia_fase1',
            order: 1,
            title: 'Fase 1: Fundamentos',
            description:
                'Introducción a la inteligencia artificial y su aplicación a proyectos sociales.',
            // Demo: fecha ya vencida, para que se vea la alerta de "vencida"
            // en vivo sin tener que esperar semanas.
            deadline: '2026-07-01',
            objectives: [
              Objective(
                id: 'lab_ia_fase1_obj1',
                category: ObjectiveCategory.entrepreneurship,
                text: 'Identificar oportunidades de IA en proyectos sociales',
                sourceCourseIds: ['crs_ia_1'],
              ),
              Objective(
                id: 'lab_ia_fase1_obj2',
                category: ObjectiveCategory.business,
                text:
                    'Comprender los fundamentos de la IA y el aprendizaje automático',
                sourceCourseIds: ['crs_ia_1'],
              ),
            ],
            modules: [
              RutaModule(
                id: 'lab_ia_fase1_mod1',
                order: 1,
                title: 'Módulo 1: Introducción a la IA',
                courseIds: ['crs_ia_1'],
                ownLessons: [
                  Lesson(
                    id: 'lab_ia_fase1_mod1_lect1',
                    title: 'Guía de la Fase 1',
                    type: LessonType.pdf,
                    resourcePath:
                        'lab_ia_tecnologia/ruta_impacto/guia_fase1.pdf',
                  ),
                ],
              ),
              RutaModule(
                id: 'lab_ia_fase1_mod2',
                order: 2,
                title: 'Módulo 2: Mentoría',
                isMentorshipModule: true,
                // El módulo de mentoría necesita al menos un elemento propio
                // para poder completarse (un módulo vacío nunca cuenta como
                // completo) — esta es la confirmación de asistencia.
                ownLessons: [
                  Lesson(
                    id: 'lab_ia_fase1_mod2_asistencia',
                    title: 'Confirmar asistencia a la reunión',
                    type: LessonType.activity,
                    description:
                        'Después de tu reunión con el Mentor, confirma aquí que asististe.',
                  ),
                ],
              ),
            ],
          ),
          // Demo: fecha próxima a vencer (dentro de la ventana de aviso),
          // para que se vea la alerta de "próxima a vencer" en vivo.
          Phase(
              id: 'lab_ia_fase2',
              order: 2,
              title: 'Fase 2',
              deadline: '2026-08-02'),
          Phase(id: 'lab_ia_fase3', order: 3, title: 'Fase 3'),
        ],
      ),
      Laboratory(
        id: 'lab_agua',
        name: 'Laboratorio Agua',
        description: 'Gestión hídrica, saneamiento y acceso a agua potable.',
        objectives: 'Diseñar soluciones de acceso y calidad de agua para comunidades.',
      ),
      Laboratory(
        id: 'lab_energia',
        name: 'Laboratorio Energía',
        description: 'Energías renovables y eficiencia energética.',
        objectives: 'Prototipar soluciones de energía limpia y asequible.',
      ),
      Laboratory(
        id: 'lab_impacto',
        name: 'Laboratorio Impacto',
        description: 'Medición y gestión de impacto social.',
        objectives: 'Aprender metodologías de medición de impacto (teoría de cambio, indicadores).',
      ),
      Laboratory(
        id: 'lab_emprendimiento',
        name: 'Laboratorio Emprendimiento',
        description: 'Modelos de negocio y emprendimiento social.',
        objectives: 'Construir y validar modelos de negocio sostenibles.',
      ),
      Laboratory(
        id: 'lab_agricultura',
        name: 'Laboratorio Agricultura',
        description: 'Agricultura sostenible y seguridad alimentaria.',
        objectives: 'Desarrollar proyectos agro con enfoque regenerativo.',
      ),
    ];
    for (final l in labs) {
      await db.put('labs', l.id, l.toJson());
    }
  }

  Future<void> _seedProjectsAndGroups() async {
    final projects = [
      Project(
        id: 'prj1',
        name: 'AquaVida',
        description: 'Filtros de agua de bajo costo para comunidades rurales.',
        problem: 'Comunidades de la Guajira sin acceso a agua potable.',
        solution: 'Filtros cerámicos producidos localmente con capacitación comunitaria.',
        community: 'Comunidades wayúu, La Guajira',
        ods: ['ODS 6: Agua limpia y saneamiento', 'ODS 3: Salud y bienestar'],
        stage: 'Piloto',
        impactIndicators: '320 familias con acceso a agua · 15 líderes capacitados',
        expoEnabled: true,
      ),
      Project(
        id: 'prj2',
        name: 'SolAndino',
        description: 'Micro-redes solares para escuelas rurales.',
        problem: 'Escuelas rurales de Boyacá sin electricidad confiable.',
        solution: 'Paneles solares con baterías gestionadas por la comunidad educativa.',
        community: 'Escuelas rurales, Boyacá',
        ods: [
          'ODS 7: Energía asequible y no contaminante',
          'ODS 4: Educación de calidad'
        ],
        stage: 'Validación',
        impactIndicators: '4 escuelas · 260 estudiantes beneficiados',
        expoEnabled: true,
      ),
    ];
    for (final p in projects) {
      await db.put('projects', p.id, p.toJson());
    }

    final groups = [
      Group(
        id: 'grp1',
        name: 'Equipo AquaVida',
        projectId: 'prj1',
        university: 'Universidad de los Andes',
        advisorId: 'adv1',
        // alum1 (Alumni) queda en su equipo original: mismo acceso que
        // cualquier estudiante del grupo (ver Roles.isStudentLike).
        studentIds: ['est1', 'est2', 'alum1'],
      ),
      Group(
        id: 'grp2',
        name: 'Equipo SolAndino',
        projectId: 'prj2',
        university: 'Universidad Nacional',
        advisorId: 'adv1',
        studentIds: ['est3', 'est4'],
      ),
    ];
    for (final g in groups) {
      await db.put('groups', g.id, g.toJson());
    }

    // Checklist RUTA NATIONAL EXPO por grupo
    for (final g in groups) {
      final checklist = ExpoChecklist(groupId: g.id, items: [
        {'label': 'Inscripción del equipo confirmada', 'done': true},
        {'label': 'Annual Report entregado', 'done': false},
        {'label': 'Impact Page publicada', 'done': false},
        {'label': 'Pitch Deck versión final', 'done': false},
        {'label': 'Video del proyecto grabado', 'done': false},
        {'label': 'Simulación de pitch realizada', 'done': false},
        {'label': 'Documentación de viaje completa', 'done': false},
      ]);
      await db.put('expo_checklists', g.id, checklist.toJson());
    }
  }

  Future<void> _seedCourses() async {
    Lesson video(String id, String title, String path) =>
        Lesson(id: id, title: title, type: LessonType.video, resourcePath: path);
    Lesson pdf(String id, String title, String path) =>
        Lesson(id: id, title: title, type: LessonType.pdf, resourcePath: path);

    final courses = <Course>[
      // --- RUTA NATIONAL EXPO (uno por proyecto) ---
      Course(
        id: 'crs_expo_p1',
        name: 'RUTA NATIONAL EXPO — AquaVida',
        description:
            'Preparación colaborativa del equipo AquaVida para National Expo: '
            'entrenamientos, entregables y simulaciones.',
        isRutaExpo: true,
        projectId: 'prj1',
        modules: [
          CourseModule(id: 'mexpo1', title: 'Entrenamientos', lessons: [
            video('lexpo1', 'Entrenamiento de pitch',
                'ruta_national_expo/entrenamiento_pitch.mp4'),
            pdf('lexpo2', 'Guía del Annual Report',
                'ruta_national_expo/annual_report_guia.pdf'),
          ]),
        ],
      ),
      Course(
        id: 'crs_expo_p2',
        name: 'RUTA NATIONAL EXPO — SolAndino',
        description:
            'Preparación colaborativa del equipo SolAndino para National Expo.',
        isRutaExpo: true,
        projectId: 'prj2',
        modules: [
          CourseModule(id: 'mexpo2', title: 'Entrenamientos', lessons: [
            video('lexpo3', 'Entrenamiento de pitch',
                'ruta_national_expo/entrenamiento_pitch.mp4'),
            pdf('lexpo4', 'Guía del Annual Report',
                'ruta_national_expo/annual_report_guia.pdf'),
          ]),
        ],
      ),
      // --- Cursos de laboratorios ---
      _demoIaCourse(),
      Course(
        id: 'crs_agua_1',
        name: 'Gestión Hídrica Comunitaria',
        description: 'Acceso, calidad y gobernanza del agua.',
        labId: 'lab_agua',
        creatorId: 'lxd2',
        modules: [
          CourseModule(id: 'mag1', title: 'Módulo 1: Diagnóstico', lessons: [
            video('lag1', 'Diagnóstico hídrico local',
                'lab_agua/curso_gestion_hidrica/leccion_1.mp4'),
            video('lag2', 'Soluciones de filtración',
                'lab_agua/curso_gestion_hidrica/leccion_2.mp4'),
            pdf('lag3', 'Manual técnico',
                'lab_agua/curso_gestion_hidrica/material.pdf'),
          ]),
        ],
      ),
      Course(
        id: 'crs_energia_1',
        name: 'Energías Renovables Aplicadas',
        description: 'Solar, eólica y micro-redes para comunidades.',
        labId: 'lab_energia',
        modules: [
          CourseModule(id: 'men_1', title: 'Módulo 1: Solar', lessons: [
            video('len1', 'Fundamentos fotovoltaicos',
                'lab_energia/curso_energias_renovables/leccion_1.mp4'),
            video('len2', 'Dimensionamiento de sistemas',
                'lab_energia/curso_energias_renovables/leccion_2.mp4'),
          ]),
        ],
      ),
      Course(
        id: 'crs_impacto_1',
        name: 'Medición de Impacto Social',
        description: 'Teoría de cambio e indicadores de impacto.',
        labId: 'lab_impacto',
        creatorId: 'lxd3',
        modules: [
          CourseModule(id: 'mim1', title: 'Módulo 1: Teoría de cambio', lessons: [
            video('lim1', 'Construyendo la teoría de cambio',
                'lab_impacto/curso_medicion_impacto/leccion_1.mp4'),
            pdf('lim2', 'Plantilla de indicadores',
                'lab_impacto/curso_medicion_impacto/material.pdf'),
          ]),
        ],
      ),
      Course(
        id: 'crs_emprend_1',
        name: 'Modelo de Negocio Social',
        description: 'Canvas social y validación de mercado.',
        labId: 'lab_emprendimiento',
        modules: [
          CourseModule(id: 'mem1', title: 'Módulo 1: Canvas', lessons: [
            video('lem1', 'Canvas de negocio social',
                'lab_emprendimiento/curso_modelo_negocio/leccion_1.mp4'),
            video('lem2', 'Validación con clientes',
                'lab_emprendimiento/curso_modelo_negocio/leccion_2.mp4'),
          ]),
        ],
      ),
      Course(
        id: 'crs_agri_1',
        name: 'Agricultura Sostenible',
        description: 'Técnicas regenerativas y seguridad alimentaria.',
        labId: 'lab_agricultura',
        modules: [
          CourseModule(id: 'magr1', title: 'Módulo 1: Suelos', lessons: [
            video('lagr1', 'Salud del suelo',
                'lab_agricultura/curso_agricultura_sostenible/leccion_1.mp4'),
            video('lagr2', 'Compostaje comunitario',
                'lab_agricultura/curso_agricultura_sostenible/leccion_2.mp4'),
          ]),
        ],
      ),
      // --- Open Learning (externo, sin laboratorio ni Ruta de Impacto) ---
      Course(
        id: 'crs_ol_marketing',
        name: 'Marketing Digital para Emprendedores',
        description: 'Fundamentos de marketing digital aplicado a negocios sociales.',
        creatorId: 'lxd1',
        isOpenLearning: true,
        level: 'Básico',
        estimatedHours: 6,
        modules: [
          CourseModule(id: 'mol1', title: 'Módulo 1: Fundamentos', lessons: [
            video('lol1', 'Introducción al marketing digital',
                'open_learning/marketing_digital/leccion_1.mp4'),
            pdf('lol2', 'Plantilla de plan de marketing',
                'open_learning/marketing_digital/plantilla.pdf'),
          ]),
        ],
      ),
    ];
    for (final c in courses) {
      await db.put('courses', c.id, c.toJson());
    }
  }

  /// Curso demo con TODAS las capacidades del constructor LMS:
  /// metadatos completos, quiz de varios tipos, actividad con rúbrica,
  /// encuesta y certificado configurado.
  Course _demoIaCourse() {
    return Course(
      id: 'crs_ia_1',
      name: 'Introducción a la Inteligencia Artificial',
      subtitle: 'IA aplicada al impacto social, desde cero',
      description: 'Fundamentos de IA aplicados a proyectos sociales.',
      fullDescription:
          'Aprende los fundamentos de la inteligencia artificial y cómo '
          'aplicarla a proyectos de impacto social: datos, modelos y '
          'casos reales de comunidades colombianas.',
      labId: 'lab_ia',
      creatorId: 'lxd1',
      level: 'Intermedio',
      estimatedHours: 8,
      tags: ['IA', 'Innovación', 'Tecnología'],
      objectives: [
        'Comprender los fundamentos de la IA y el aprendizaje automático',
        'Identificar oportunidades de IA en proyectos sociales',
      ],
      competencies: ['Inteligencia Artificial', 'Innovación'],
      learningOutcomes: [
        'Propone una solución de IA para un problema comunitario real',
      ],
      ods: [
        'ODS 4: Educación de calidad',
        'ODS 9: Industria, innovación e infraestructura',
      ],
      generatesCertificate: true,
      certifiedHours: 8,
      modules: [
        CourseModule(id: 'mia1', title: 'Módulo 1: Fundamentos', lessons: [
          Lesson(
              id: 'lia1',
              title: '¿Qué es la IA?',
              type: LessonType.video,
              durationMin: 15,
              resourcePath:
                  'lab_ia_tecnologia/curso_intro_ia/leccion_1.mp4'),
          Lesson(
              id: 'lia2',
              title: 'Datos y modelos',
              type: LessonType.video,
              durationMin: 20,
              resourcePath:
                  'lab_ia_tecnologia/curso_intro_ia/leccion_2.mp4'),
          Lesson(
              id: 'lia3',
              title: 'Material de apoyo',
              type: LessonType.pdf,
              resourcePath:
                  'lab_ia_tecnologia/curso_intro_ia/material.pdf'),
        ]),
        CourseModule(id: 'mia2', title: 'Módulo 2: Evaluación', lessons: [
          Lesson(
            id: 'lia4',
            title: 'Quiz: conceptos básicos',
            type: LessonType.quiz,
            quiz: [
              QuizQuestion(
                kind: 'multiple',
                question: '¿Qué es el aprendizaje supervisado?',
                options: [
                  'Modelos entrenados con datos etiquetados',
                  'Modelos sin datos',
                  'Un tipo de hardware',
                ],
                answerIndex: 0,
              ),
              QuizQuestion(
                kind: 'truefalse',
                question:
                    'La IA puede ayudar a predecir la deserción escolar.',
                answerIndex: 0, // Verdadero
              ),
              QuizQuestion(
                kind: 'short',
                question:
                    '¿Cómo se llaman los datos usados para entrenar un modelo?',
                answerText: 'datos de entrenamiento',
              ),
              QuizQuestion(
                kind: 'order',
                question: 'Ordena las etapas de un proyecto de IA:',
                options: [
                  'Recolectar datos',
                  'Entrenar el modelo',
                  'Evaluar resultados',
                  'Desplegar la solución',
                ],
              ),
            ],
          ),
          Lesson(
            id: 'lia5',
            title: 'Proyecto: IA para tu comunidad',
            type: LessonType.activity,
            activity: ActivityConfig(
              description:
                  'Propón una solución de IA para un problema real de tu '
                  'comunidad. Incluye el problema, los datos necesarios y '
                  'el impacto esperado.',
              requiresFile: true,
              requiresText: true,
              maxFiles: 2,
              allowedTypes: ['PDF', 'Documento'],
              gradingMode: 'points100',
              rubric: [
                {'criterion': 'Contenido', 'points': 20},
                {'criterion': 'Presentación', 'points': 20},
                {'criterion': 'Investigación', 'points': 20},
                {'criterion': 'Creatividad', 'points': 20},
                {'criterion': 'Impacto', 'points': 20},
              ],
            ),
          ),
          Lesson(
            id: 'lia6',
            title: 'Encuesta de satisfacción del curso',
            type: LessonType.survey,
            quiz: [
              QuizQuestion(
                  kind: 'short',
                  question: '¿Qué fue lo que más te gustó del curso?'),
              QuizQuestion(kind: 'short', question: '¿Qué mejorarías?'),
            ],
          ),
        ]),
      ],
    );
  }

  Future<void> _seedDemoActivity() async {
    // Progreso de demostración
    final progress = [
      Progress(studentId: 'est1', courseId: 'crs_ia_1', completedLessonIds: ['lia1', 'lia2']),
      Progress(studentId: 'est1', courseId: 'crs_impacto_1', completedLessonIds: ['lim1']),
      Progress(studentId: 'est2', courseId: 'crs_emprend_1', completedLessonIds: ['lem1']),
      Progress(studentId: 'est3', courseId: 'crs_agua_1', completedLessonIds: ['lag1', 'lag2', 'lag3']),
      Progress(studentId: 'est4', courseId: 'crs_energia_1', completedLessonIds: []),
      // alum1 (Alumni) con el mismo avance que est1 en sus mismos
      // laboratorios, para verificar que se ve y se cuenta igual.
      Progress(studentId: 'alum1', courseId: 'crs_ia_1', completedLessonIds: ['lia1', 'lia2']),
      Progress(studentId: 'alum1', courseId: 'crs_impacto_1', completedLessonIds: ['lim1']),
    ];
    for (final p in progress) {
      await db.put('progress', p.id, p.toJson());
    }

    // Entregas de demostración
    final submissions = [
      Submission(
        id: 'sub1',
        courseId: 'crs_ia_1',
        studentId: 'est1',
        taskName: 'Ensayo: IA para el bien social',
        comment: 'Adjunto mi ensayo sobre aplicaciones de IA en salud rural.',
        grade: 4.5,
        feedback: 'Excelente análisis. Profundiza en la parte de datos.',
        date: DateTime(2026, 6, 20),
      ),
      Submission(
        id: 'sub2',
        courseId: 'crs_agua_1',
        studentId: 'est3',
        taskName: 'Diagnóstico hídrico de mi comunidad',
        comment: 'Diagnóstico realizado en el municipio de Sesquilé.',
        date: DateTime(2026, 7, 1),
      ),
      Submission(
        id: 'sub3',
        courseId: 'crs_expo_p1',
        groupId: 'grp1',
        taskName: 'Annual Report (borrador)',
        comment: 'Primera versión del Annual Report del equipo.',
        date: DateTime(2026, 6, 28),
      ),
    ];
    for (final s in submissions) {
      await db.put('submissions', s.id, s.toJson());
    }

    // Evidencias para el donante
    final evidences = [
      Evidence(
        id: 'ev1',
        donorId: 'don1',
        type: 'historia',
        title: 'La historia de Sara',
        description:
            'Gracias a tu aporte, Sara lidera el proyecto AquaVida que hoy '
            'lleva agua potable a 320 familias en La Guajira.',
        date: DateTime(2026, 5, 15),
      ),
      Evidence(
        id: 'ev2',
        donorId: 'don1',
        type: 'reporte',
        title: 'Reporte de impacto Q2 2026',
        description: 'Resumen trimestral de resultados de los proyectos apoyados.',
        date: DateTime(2026, 6, 30),
      ),
      Evidence(
        id: 'ev3',
        donorId: 'don1',
        type: 'testimonio',
        title: 'Testimonio de la comunidad',
        description:
            '"El filtro cambió la salud de nuestros niños" — Líder comunitaria wayúu.',
        date: DateTime(2026, 6, 10),
      ),
    ];
    for (final e in evidences) {
      await db.put('evidences', e.id, e.toJson());
    }

    // Notificaciones de demostración
    final notifications = [
      AppNotification(
        id: 'not1',
        userId: 'est1',
        title: 'Entrega calificada',
        body: 'Tu ensayo de IA fue calificado con 4.5. ¡Revisa la retroalimentación!',
        date: DateTime(2026, 6, 21),
      ),
      AppNotification(
        id: 'not2',
        userId: 'lxd1',
        title: 'Nueva entrega pendiente',
        body: 'Valentina López envió "Diagnóstico hídrico de mi comunidad".',
        date: DateTime(2026, 7, 1),
      ),
    ];
    for (final n in notifications) {
      await db.put('notifications', n.id, n.toJson());
    }

    // Foro de la comunidad: publicaciones de demostración de distintos
    // roles (Admin, Asesor, estudiantes de universidades y laboratorios
    // distintos), para que el espacio no se sienta vacío la primera vez.
    final forumPosts = [
      ForumPost(
        id: 'post1',
        authorId: 'adm1',
        body:
            '¡Bienvenidos al foro de la comunidad Enactus Colombia! 💛 Este es el espacio para compartir avances, hacer preguntas entre laboratorios y celebrar los logros de todos los equipos, sin importar tu universidad o laboratorio.',
        date: DateTime(2026, 6, 2, 9, 0),
        category: ForumCategory.anuncio,
        pinned: true,
      ),
      ForumPost(
        id: 'post2',
        authorId: 'adv1',
        body:
            'Muy orgulloso del equipo AquaVida de la Universidad de los Andes: pasaron a etapa Piloto esta semana. Si algún otro equipo está trabajando temas de agua, con gusto conectamos experiencias 🚰',
        date: DateTime(2026, 6, 15, 14, 30),
        category: ForumCategory.avance,
      ),
      ForumPost(
        id: 'post3',
        authorId: 'est1',
        body:
            '¿Alguien ha usado modelos de IA para predecir deserción escolar? Estamos empezando esa parte del proyecto en el Laboratorio de IA y Tecnología y nos vendría bien aprender de otros equipos.',
        date: DateTime(2026, 7, 10, 11, 15),
        category: ForumCategory.pregunta,
      ),
      ForumPost(
        id: 'post4',
        authorId: 'est3',
        body:
            'Compartiendo un logro del Laboratorio Agua: instalamos el primer filtro comunitario piloto en La Guajira. ¡Gracias a todos los que nos dieron ideas en este foro! 🎉',
        date: DateTime(2026, 7, 22, 16, 45),
        category: ForumCategory.avance,
      ),
    ];
    for (final p in forumPosts) {
      await db.put('forum_posts', p.id, p.toJson());
    }

    // Contenido de la página principal
    await db.put('content', 'site', SiteContent().toJson());
  }
}
