import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';

/// Login único: identifica el rol del usuario y lo lleva a su portal.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _obscure = true;

  void _submit() {
    final user = context
        .read<AuthProvider>()
        .login(_email.text, _password.text);
    if (user == null) {
      setState(() => _error = 'Correo o contraseña incorrectos.');
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.forRole(user.role), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Footer dentro del scroll: solo aparece al desplazarse al final.
    return Scaffold(
      body: CustomScrollView(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AnimatedLogo(height: 84)),
                        const SizedBox(height: 20),
                        const Text('Bienvenido de nuevo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text(
                          'Ingresa con la cuenta creada por tu administrador',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
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
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
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
                          onPressed: _submit,
                          child: const Text('Ingresar'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context, AppRoutes.landing, (_) => false),
                          child: const Text('← Volver al inicio'),
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
