import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../services/contact_service.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Formulario "Contáctenos" del botón "Quiero unirme" en el landing.
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
      showSuccessCheck(context, tr.contactoEnviado);
    } else {
      showAppSnack(context,
          tr.contactoError,
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr.contactoTitulo, style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.contactoTexto,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: tr.comunNombre),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? tr.comunRequerido : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration:
                    InputDecoration(labelText: tr.ingresoCorreo),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return tr.comunRequerido;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return tr.comunCorreoInvalido;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _message,
                maxLines: 4,
                decoration: InputDecoration(
                    labelText: tr.contactoMensaje,
                    hintText:
                        tr.contactoMensajePista),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? tr.comunRequerido : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(tr.comunCancelar),
        ),
        ElevatedButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.ink),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_sending ? tr.comunEnviando : tr.contactoEnviar),
        ),
      ],
    );
  }
}
