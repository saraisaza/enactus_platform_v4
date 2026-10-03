import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/cuenta.dart';

/// Login único: identifica el rol del usuario y lo lleva a su portal.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    // Un toque más mientras se espera la respuesta no manda otro intento.
    if (auth.isLoggingIn) return;
    setState(() => _error = null);

    final user = await auth.login(_email.text.trim(), _password.text);
    if (!mounted) return;

    if (user == null) {
      // El mensaje sale del servidor: distingue "credenciales incorrectas" de
      // "demasiados intentos" o "sin conexión", que para quien lo usa son tres
      // problemas distintos con tres soluciones distintas.
      setState(() => _error =
          auth.loginError?.message ?? 'Correo o contraseña incorrectos.');
      return;
    }
    // El Llavero de iOS y Google ofrecen guardar la contraseña recién cuando
    // el formulario de ingreso se da por terminado.
    TextInput.finishAutofillContext();
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.forRole(user.role), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final enviando = context.watch<AuthProvider>().isLoggingIn;
    // Footer dentro del scroll: solo aparece al desplazarse al final.
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    // Scrollable: si el contenido no cabe en el alto
                    // disponible (pantallas bajas, error visible, cambios de
                    // fuente) se desplaza en vez de desbordar.
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AnimatedLogo(height: 84)),
                        const SizedBox(height: 20),
                        Text('Bienvenido de nuevo'.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: displayHeading(fontSize: 26)),
                        const SizedBox(height: 6),
                        const Text(
                          'Ingrese con la cuenta creada por su administrador',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        // Autocompletar del Llavero de iOS y de Google: los
                        // dos campos juntos y marcados como correo y
                        // contraseña.
                        AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                enabled: !enviando,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon:
                                      Icon(Icons.mail_outline, size: 20),
                                ),
                                // "Siguiente" pasa a la contraseña. Antes
                                // enviaba el formulario con la contraseña
                                // vacía.
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                enabled: !enviando,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20),
                                    tooltip: _obscure
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                          ),
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
                          onPressed: enviando ? null : _submit,
                          child: enviando
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Ingresar'),
                        ),
                        // La portada es el sitio de presentación de la web:
                        // en la app no hay "inicio" al cual volver.
                        if (kIsWeb) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.landing, (_) => false),
                            child: const Text('← Volver al inicio'),
                          ),
                        ],
                        // Las tiendas piden la política de privacidad a la
                        // vista también ANTES de entrar. La web no pasa por
                        // una tienda; ahí se enlaza cuando el texto esté
                        // aprobado (docs/movil/DATOS_Y_PRIVACIDAD.md).
                        if (!kIsWeb) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => abrirPoliticaDePrivacidad(context),
                            child: const Text('Política de privacidad'),
                          ),
                        ],
                      ],
                    ),
                    ),
                  ),
                    ),
                  ),
                ),
                if (kIsWeb) const AppFooter(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
