/// Catálogo de ciudades colombianas con coordenadas reales, usado por el
/// selector de ciudad del estudiante (Admin) y por el Mapa de Estudiantes
/// (`design_handoff_mapa_estudiantes/README.md`). Ciudades y coordenadas
/// tomadas del prototipo del handoff — son reales y reutilizables tal
/// cual. Lo que NO se reutiliza del prototipo son sus conteos de
/// estudiantes ni sus listas de universidades por ciudad: eso sale de los
/// datos reales (`DataProvider`), nunca de aquí.
class ColombiaCity {
  final String name;
  final String department;
  final double lat;
  final double lon;
  const ColombiaCity(
      {required this.name,
      required this.department,
      required this.lat,
      required this.lon});
}

const List<ColombiaCity> colombiaCities = [
  ColombiaCity(name: 'Bogotá', department: 'Cundinamarca', lat: 4.711, lon: -74.072),
  ColombiaCity(name: 'Medellín', department: 'Antioquia', lat: 6.244, lon: -75.581),
  ColombiaCity(name: 'Cali', department: 'Valle del Cauca', lat: 3.452, lon: -76.532),
  ColombiaCity(name: 'Barranquilla', department: 'Atlántico', lat: 10.968, lon: -74.781),
  ColombiaCity(name: 'Bucaramanga', department: 'Santander', lat: 7.119, lon: -73.123),
  ColombiaCity(name: 'Cartagena', department: 'Bolívar', lat: 10.391, lon: -75.479),
  ColombiaCity(name: 'Pereira', department: 'Risaralda', lat: 4.809, lon: -75.691),
  ColombiaCity(name: 'Manizales', department: 'Caldas', lat: 5.069, lon: -75.517),
  ColombiaCity(name: 'Santa Marta', department: 'Magdalena', lat: 11.240, lon: -74.211),
  ColombiaCity(name: 'Cúcuta', department: 'N. de Santander', lat: 7.894, lon: -72.508),
  ColombiaCity(name: 'Popayán', department: 'Cauca', lat: 2.445, lon: -76.615),
  ColombiaCity(name: 'Tunja', department: 'Boyacá', lat: 5.535, lon: -73.368),
  ColombiaCity(name: 'Ibagué', department: 'Tolima', lat: 4.439, lon: -75.232),
  ColombiaCity(name: 'Neiva', department: 'Huila', lat: 2.927, lon: -75.282),
  ColombiaCity(name: 'Pasto', department: 'Nariño', lat: 1.214, lon: -77.281),
  ColombiaCity(name: 'Villavicencio', department: 'Meta', lat: 4.142, lon: -73.627),
  ColombiaCity(name: 'Montería', department: 'Córdoba', lat: 8.748, lon: -75.881),
  ColombiaCity(name: 'Riohacha', department: 'La Guajira', lat: 11.544, lon: -72.907),
  ColombiaCity(name: 'Armenia', department: 'Quindío', lat: 4.534, lon: -75.681),
];

/// `null` si `name` no está en el catálogo — pasa siempre por aquí en vez
/// de comparar strings sueltos, para que un typo no rompa el mapa en
/// silencio (la ciudad simplemente no aparece, en vez de reventar).
ColombiaCity? colombiaCityByName(String name) {
  for (final c in colombiaCities) {
    if (c.name == name) return c;
  }
  return null;
}
