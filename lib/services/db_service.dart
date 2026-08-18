import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'data_store.dart';

/// Capa de persistencia local sobre Hive. Implementa [DataStore] — ver ahí
/// la nota completa sobre cómo migrar a AWS (S3 + RDS/PostgreSQL) sin
/// tocar Providers ni Vistas.
///
/// Cada entidad vive en su propia "box" (equivalente a una tabla) y se
/// almacena como JSON.
class DbService implements DataStore {
  static const boxNames = [
    'users',
    'projects',
    'groups',
    'labs',
    'courses',
    'progress',
    'submissions',
    'certificates',
    'expo_checklists',
    'evidences',
    'comm_resources',
    'notifications',
    'content',
    'session',
    'mentor_notes',
    'ruta_progress',
    'forum_posts',
    'calendar_events',
  ];

  static Future<void> init() async {
    await Hive.initFlutter('enactus_db');
    for (final name in boxNames) {
      await Hive.openBox<String>(name);
    }
  }

  Box<String> _box(String name) => Hive.box<String>(name);

  @override
  List<Map<String, dynamic>> getAll(String boxName) => _box(boxName)
      .values
      .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
      .toList();

  @override
  Map<String, dynamic>? get(String boxName, String id) {
    final raw = _box(boxName).get(id);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> put(String boxName, String id, Map<String, dynamic> json) =>
      _box(boxName).put(id, jsonEncode(json));

  @override
  Future<void> delete(String boxName, String id) => _box(boxName).delete(id);

  @override
  bool get isEmpty => _box('users').isEmpty;

  /// Exporta TODA la base de datos como un solo mapa JSON
  /// (caja → {id → registro}). Sirve como copia de seguridad portátil.
  @override
  Map<String, dynamic> exportAll() => {
        for (final name in boxNames)
          name: {
            for (final key in _box(name).keys)
              key.toString(): jsonDecode(_box(name).get(key)!),
          },
      };

  /// Restaura una copia de seguridad completa: reemplaza el contenido
  /// de todas las cajas por el del respaldo.
  @override
  Future<void> importAll(Map<String, dynamic> backup) async {
    for (final name in boxNames) {
      final box = _box(name);
      await box.clear();
      final entries =
          Map<String, dynamic>.from(backup[name] as Map? ?? {});
      for (final e in entries.entries) {
        await box.put(e.key, jsonEncode(e.value));
      }
    }
  }
}
