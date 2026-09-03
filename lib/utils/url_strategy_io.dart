/// Fuera de la web no hay barra de direcciones que configurar.
///
/// Existe para que `main.dart` pueda llamar a `configurarRutas()` sin
/// preguntarse en qué plataforma corre — y sobre todo para que la app siga
/// compilando para iOS, Android y macOS, que es a donde va después.
void configurarRutas() {}
