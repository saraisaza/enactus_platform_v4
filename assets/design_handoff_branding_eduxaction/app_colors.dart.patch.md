# Parche de `lib/utils/app_theme.dart`

Cambios de color. **El único acento pasa de naranja #FA6A1E a ámbar #FFC107.**
No hay cambios de tipografía ni de layout.

## `AppColors`

```dart
// Marca / UI
static const gold = Color(0xFFFFC107);        // antes 0xFFFA6A1E
static const goldBright = Color(0xFFFFCF3D);  // antes 0xFFFF8647
static const ink = Color(0xFF21120A);         // sin cambios

// El `slate` cálido sale de la landing: se reemplaza por grises neutros.
static const slate = Color(0xFF26262A);       // antes 0xFF453027
static const slateLight = Color(0xFF2C2B30);  // antes 0xFF573D31
static const slateDark = Color(0xFF17171A);   // antes 0xFF392720

// Superficies
static const background = Color(0xFF35343A);  // antes 0xFF08080A
static const backgroundDeep = Color(0xFF0B0B0D); // NUEVO: destino de los degradados
static const surface = Color(0xFF17171A);     // antes 0xFF0B0B0D
static const surfaceAlt = Color(0xFF26262A);  // antes 0xFF121214
static const border = Color(0x14FFFFFF);      // rgba(255,255,255,.08)

// Texto
static const textPrimary = Color(0xFFF2F2F5); // antes 0xFFE9E9EE
static const textSecondary = Color(0xFFAEABB0); // antes 0xFF8A8A93
static const textMuted = Color(0xFF8F8C92);   // antes 0xFF8C817C (ya no es cálido)

// Partículas del hero: sin el naranja saturado
static const heroParticleColors = [
  Color(0xFFFFC107),
  Color(0xFFFFD98A),
  Color(0xFFFFFFFF),
  Color(0xFFBABABA),
];
```

`labColors` era una rampa cálida naranja/marrón derivada del acento viejo. Rampa
equivalente sobre el gris nuevo (mantiene seis tonos distinguibles y legibles):

```dart
static const labColors = {
  'lab_ia':             Color(0xFFFFC107),
  'lab_agua':           Color(0xFF4FB3C4),
  'lab_energia':        Color(0xFFE8A93D),
  'lab_impacto':        Color(0xFF9085E9),
  'lab_emprendimiento': Color(0xFFE07A5F),
  'lab_agricultura':    Color(0xFF7FA34A),
};
```

## `ContentColors.dark`

```dart
bg: Color(0xFF35343A),
surface: Color(0xFF17171A),
surface2: Color(0xFF26262A),
border: Color(0x14FFFFFF),
text: Color(0xFFF2F2F5),
text2: Color(0xFFAEABB0),
text3: Color(0xFF8F8C92),
goldInk: AppColors.gold,              // #FFC107
goldSoft: Color(0x29FFC107),          // rgba(255,193,7,.16)
alertInk: Color(0xFFFF8A9B),          // sin cambios
```

## `ContentColors.light`

El ámbar sobre blanco da ~1.7:1, peor que el naranja anterior: el token de texto
tiene que oscurecerse más.

```dart
bg: Color(0xFFF4F2EF),      // antes 0xFFF7F1EC (era cálido/rosado)
surface2: Color(0xFFE9E7E3), // antes 0xFFF0E7E0
border: Color(0xFFD8D4CE),   // antes 0xFFE2D5CB
text: Color(0xFF1B1A1E),
text2: Color(0xFF55535A),
goldInk: Color(0xFF8A6A00),  // antes 0xFFB03D06 — nunca usar #FFC107 como texto en claro
goldSoft: Color(0x3DFFC107),
```

## Degradados que hay que cambiar en las vistas

| Sitio | Antes | Ahora |
| --- | --- | --- |
| `_Hero` (landing_view.dart) | `[background, slate]` | `[background, backgroundDeep]` |
| Banda "¿Listo para sumarte?" | `[gold .14, slate]` | `[Colors.white .04, backgroundDeep]`, borde `border` |
| Contadores `_AnimatedCounter` | `slate.withValues(alpha: .4)` | radial `rgba(255,255,255,.05)` → `rgba(11,11,13,.72)` |
| Tarjeta "Sobre nosotros" | `slate` | `surface` |
| Tarjetas de laboratorio | `surface` | `Colors.white.withValues(alpha: .045)` sobre banda `[#2C2B30, backgroundDeep]` |
