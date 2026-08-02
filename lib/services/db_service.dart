import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Capa de persistencia local sobre Hive.
///
/// Cada entidad vive en su propia "box" (equivalente a una tabla) y se
/// almacena como JSON. Para migrar a AWS RDS/PostgreSQL basta con
/// reimplementar esta clase contra una API REST manteniendo la misma
/// interfaz (getAll / get / put / delete).
class DbService {
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
    'notifications',
    'content',
    'session',
    'mentor_notes',
    'ruta_progress',
    'forum_posts',
  ];

  static Future<void> init() async {
    await Hive.initFlutter('enactus_db');
    for (final name in boxNames) {
      await Hive.openBox<String>(name);
    }
  }

  Box<String> _box(String name) => Hive.box<String>(name);

  List<Map<String, dynamic>> getAll(String boxName) => _box(boxName)
      .values
      .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
      .toList();

  Map<String, dynamic>? get(String boxName, String id) {
    final raw = _box(boxName).get(id);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> put(String boxName, String id, Map<String, dynamic> json) =>
      _box(boxName).put(id, jsonEncode(json));

  Future<void> delete(String boxName, String id) => _box(boxName).delete(id);

  bool get isEmpty => _box('users').isEmpty;

  /// Exporta TODA la base de datos como un solo mapa JSON
  /// (caja → {id → registro}). Sirve como copia de seguridad portátil.
  Map<String, dynamic> exportAll() => {
        for (final name in boxNames)
          name: {
            for (final key in _box(name).keys)
              key.toString(): jsonDecode(_box(name).get(key)!),
          },
      };

  /// Restaura una copia de seguridad completa: reemplaza el contenido
  /// de todas las cajas por el del respaldo.
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
