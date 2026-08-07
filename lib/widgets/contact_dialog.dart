import 'package:flutter/material.dart';

import '../services/contact_service.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Formulario "Contáctanos" del botón "Quiero unirme" en el landing.
/// El envío real lo resuelve [ContactService.sendMessage].
Future<void> showContactDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ContactDialog(),
  );
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final ok = await ContactService.sendMessage(
      name: _name.text.trim(),
      email: _email.text.trim(),
      message: _message.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Navigator.pop(context);
      showSuccessCheck(context, '¡Mensaje enviado! Te contactaremos pronto.');
    } else {
      showAppSnack(context,
          'No pudimos enviar tu mensaje. Intenta de nuevo en un momento.',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contáctanos', style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cuéntanos quién eres y qué te gustaría hacer con nosotros.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                decoration:
                    const InputDecoration(labelText: 'Correo electrónico'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Requerido';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _message,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText:
                        '¿Cómo quieres sumarte? (estudiante, mentor, empresa, donante...)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1A1400)),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_sending ? 'Enviando…' : 'Enviar mensaje'),
        ),
      ],
    );
  }
}
