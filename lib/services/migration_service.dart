import 'db_service.dart';

/// Migraciones de datos que se ejecutan UNA sola vez por instalación local
/// (por navegador/dispositivo), la primera vez que se abre la app con una
/// versión más nueva del modelo de datos. Cada migración se registra en la
/// caja 'content' bajo el id 'migrations' para no volver a aplicarse.
///
/// Ese guard es crítico: sin él, esta migración volvería a convertir en
/// LXD a las cuentas de Mentor NUEVAS creadas por el Admin después de
/// migrar (el rol "mentor" se reutiliza con un significado distinto).
class MigrationService {
  final DbService db;
  MigrationService(this.db);

  static const _migrationsKey = 'migrations';

  Future<void> runAll() async {
    final done = _doneMigrations();
    if (!done.contains('role_mentor_to_lxd_v1')) {
      await _migrateMentorToLxd();
      await _markDone('role_mentor_to_lxd_v1');
    }
  }

  Set<String> _doneMigrations() {
    final j = db.get('content', _migrationsKey);
    if (j == null) return {};
    return Set<String>.from(j['done'] as List? ?? const []);
  }

  Future<void> _markDone(String name) async {
    final current = _doneMigrations()..add(name);
    await db.put('content', _migrationsKey, {'done': current.toList()});
  }

  /// Las cuentas que tenían el rol "mentor" (dueño de la herramienta de
  /// cursos) pasan a "lxd", conservando id, historial, cursos creados y
  /// laboratorios asignados: solo cambia el string de rol. El rol "mentor"
  /// queda libre para las cuentas nuevas que el Admin cree manualmente
  /// (rol redefinido, sin relación con el anterior).
  ///
  /// El permiso de calificar del LXD y los `mentorIds` (lista) de
  /// Laboratory no necesitan backfill aquí: [AppUser.canGradeOpenLearning]
  /// / [AppUser.canGradeEnactus] y [Laboratory.fromJson] ya devuelven los
  /// valores por defecto/compatibles cuando el campo no existe todavía.
  Future<void> _migrateMentorToLxd() async {
    for (final j in db.getAll('users')) {
      if (j['role'] == 'mentor') {
        await db.put('users', j['id'] as String, {...j, 'role': 'lxd'});
      }
    }
  }
}
