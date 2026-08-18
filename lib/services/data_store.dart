/// Contrato de persistencia que necesita [DataProvider]: leer y escribir
/// "cajas" de registros JSON por id, sin saber si el origen es Hive
/// (local, hoy) o una API REST contra AWS (S3 + RDS/PostgreSQL, cuando
/// exista el backend).
///
/// Hoy solo [DbService] lo implementa. El día que exista el backend, la
/// forma de conectarlo NO es escribir una implementación de este mismo
/// contrato que haga llamadas HTTP: `getAll`/`get` son síncronos porque
/// Hive es local — una API real es async por naturaleza, así que no se
/// puede cumplir esta misma firma con una llamada de red honesta.
///
/// Dos caminos reales al migrar (documentados con más detalle en la hoja
/// "Plan de Migración al Backend" de `assets/Arquitectura General -
/// Enactus Platform.xlsx`):
/// 1. Hive pasa a ser una CACHÉ local sincronizada en segundo plano con la
///    API — este contrato sigue tal cual, [DataProvider] y las ~40
///    pantallas que leen sus getters de forma síncrona no cambian.
/// 2. [DataProvider] se vuelve async (sus getters pasan a `Future`) y se
///    adapta cada pantalla que los consume — cambio de fondo, mucho más
///    grande.
/// Este archivo existe para dejar declarado el límite exacto entre
/// "estado de la app" (Providers/Vistas) y "de dónde vienen los datos"
/// — es el primer paso útil en cualquiera de los dos caminos.
abstract class DataStore {
  /// Todos los registros de una caja (ej. 'users', 'comm_resources').
  List<Map<String, dynamic>> getAll(String boxName);

  /// Un registro puntual por id, o `null` si no existe.
  Map<String, dynamic>? get(String boxName, String id);

  /// Crea o reemplaza un registro (upsert).
  Future<void> put(String boxName, String id, Map<String, dynamic> json);

  Future<void> delete(String boxName, String id);

  /// Si la base está completamente vacía (usado hoy por [SeedService] para
  /// decidir si cargar datos de demostración — un backend en producción
  /// probablemente ya no necesite este chequeo).
  bool get isEmpty;

  /// Toda la base como un solo mapa (caja → {id → registro}), para respaldo.
  Map<String, dynamic> exportAll();

  /// Reemplaza el contenido completo de todas las cajas por el del respaldo.
  Future<void> importAll(Map<String, dynamic> backup);
}
