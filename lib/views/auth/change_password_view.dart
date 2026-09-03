import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_logo.dart';

/// Cambio obligatorio de contraseña al primer ingreso.
///
/// Aparece cuando la cuenta trae `mustChangePassword`, que el servidor pone en
/// los dos únicos casos en que alguien recibe una contraseña que no eligió:
/// las cuentas que crea `seed:prod` y los restablecimientos que hace
/// administración.
///
/// **No es una pantalla que se pueda saltar**, y no porque acá se lo impida:
/// mientras la bandera esté puesta, la API responde 403
/// `password_change_required` a todo lo demás. Si esta pantalla no existiera,
/// la persona entraría a un portal que no contesta nada. De ahí que tampoco
/// tenga botón de "más tarde" — sí uno de cerrar sesión, para que nadie quede
/// encerrado sin salida.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _enviando = false;

  /// El mismo piso que exige el servidor. Se valida acá además de allá para
  /// que el mensaje llegue al escribir y no después de un viaje de red — pero
  /// la regla que manda es la del servidor.
  static const minimo = 12;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  /// El motivo por el que todavía no se puede enviar, o `null` si se puede.
  String? get _problema {
    if (_actual.text.isEmpty) return 'Escribí tu contraseña actual.';
    if (_nueva.text.length < minimo) {
      return 'La contraseña nueva necesita al menos $minimo caracteres.';
    }
    if (_nueva.text == _actual.text) {
      return 'La nueva tiene que ser distinta de la actual.';
    }
    if (_repetida.text != _nueva.text) return 'Las dos contraseñas no coinciden.';
    return null;
  }

  Future<void> _enviar() async {
    final problema = _problema;
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }

    setState(() {
      _error = null;
      _enviando = true;
    });

    final auth = context.read<AuthProvider>();
    final fallo = await auth.changePassword(
      currentPassword: _actual.text,
      newPassword: _nueva.text,
    );
    if (!mounted) return;

    setState(() => _enviando = false);
    if (fallo != null) {
      // El mensaje sale del servidor: distingue "tu contraseña actual no es
      // correcta" de un problema de red, que son dos cosas distintas con dos
      // soluciones distintas.
      setState(() => _error = fallo.message);
      return;
    }

    // El usuario en memoria ya viene sin la obligación, así que el guardia de
    // rol deja pasar. Se navega al portal en vez de esperar a que el guardia
    // reaccione, para que el cambio de pantalla sea inmediato.
    final rol = auth.currentUser?.role;
    if (rol == null) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.forRole(rol), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.watch<AuthProvider>().currentUser?.name ?? '';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AnimatedLogo(height: 72)),
                  const SizedBox(height: 20),
                  Text('Cambia tu contraseña'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: displayHeading(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    nombre.isEmpty
                        ? 'Estás usando la contraseña que te entregaron. '
                            'Elige una propia para continuar. La debes recordar'
                        : '$nombre, estás usando la contraseña que te '
                            'entregaron. Elige una propia para continuar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _actual,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nueva,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña nueva',
                      helperText: 'Al menos $minimo caracteres',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20),
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _repetida,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Repetí la contraseña nueva',
                      prefixIcon: Icon(Icons.check_circle_outline, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _enviar(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.statusCritical, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.statusCritical,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    // Deshabilitado mientras falte algo: así el motivo se ve
                    // al escribir, sin gastar un viaje de red para que el
                    // servidor diga lo mismo.
                    onPressed: (_enviando || _problema != null) ? null : _enviar,
                    child: Text(_enviando ? 'Guardando…' : 'Guardar y continuar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    // Sin botón de "más tarde" —no hay más tarde: la API no
                    // responde nada hasta el cambio— pero sí una salida, para
                    // que nadie quede encerrado.
                    onPressed: _enviando
                        ? null
                        : () async {
                            await context.read<AuthProvider>().logout();
                            if (!context.mounted) return;
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.landing, (_) => false);
                          },
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
