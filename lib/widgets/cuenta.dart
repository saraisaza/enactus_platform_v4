import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/textos.dart';
import '../providers/auth_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'common.dart';
import 'normas_comunidad.dart';
import 'social_button.dart';
import 'social_icons.dart';
import 'visor_pdf.dart';

/// Lo que App Store y Google Play exigen encontrar en «Mi cuenta»: eliminar
/// la cuenta, la política de privacidad y una forma de contactar al equipo.

/// Abre la política de privacidad en el navegador integrado.
Future<void> abrirPoliticaDePrivacidad(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final abierta = await abrirRecurso(context, LegalLinks.privacidad,
      titulo: tr.comunPoliticaPrivacidad);
  if (!abierta) {
    messenger?.showSnackBar(SnackBar(
      content: Text(tr.cuentaPrivacidadError),
    ));
  }
}

// ---------------------------------------------------------------------------
// Eliminar mi cuenta
// ---------------------------------------------------------------------------

/// «Eliminar mi cuenta» (App Store, guía 5.1.1(v); Google Play).
///
/// Pide la contraseña —un teléfono prestado o desbloqueado no basta— y nada
/// más: la guía de Apple admite confirmar, pero no poner obstáculos. Al
/// terminar, la sesión ya está cerrada y se vuelve al inicio.
Future<void> mostrarEliminarCuenta(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const EliminarCuentaDialog(),
  );
}

class EliminarCuentaDialog extends StatefulWidget {
  const EliminarCuentaDialog({super.key});

  @override
  State<EliminarCuentaDialog> createState() => _EliminarCuentaDialogState();
}

class _EliminarCuentaDialogState extends State<EliminarCuentaDialog> {
  final _password = TextEditingController();
  bool _enviando = false;
  bool _verPassword = false;
  String? _error;

  /// Con valor, la solicitud ya se recibió: es el plazo en días.
  int? _dias;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    if (_password.text.isEmpty) {
      setState(() => _error = tr.cuentaEscribaContrasena);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final dias = await context
          .read<AuthProvider>()
          .requestAccountDeletion(_password.text);
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _dias = dias;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.message;
      });
    }
  }

  /// La sesión ya se cerró: se vuelve al inicio, como al cerrar sesión.
  void _terminar() {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    if (dias != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _terminar();
        },
        child: AlertDialog(
          title: Text(tr.cuentaSolicitudRecibida,
              style: TextStyle(fontSize: 18)),
          content: Text(
            tr.cuentaDesactivada(dias),
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: _terminar,
              child: Text(tr.comunEntendido),
            ),
          ],
        ),
      );
    }

    return AdaptiveFormShell(
      title: tr.cuentaEliminar,
      saving: _enviando,
      dirty: _password.text.isNotEmpty,
      saveLabel: tr.cuentaEliminar,
      savingLabel: tr.cuentaEliminando,
      onCancel: () => Navigator.pop(context),
      onSave: _eliminar,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.cuentaQuePasa,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _Punto(tr.cuentaPunto1),
          _Punto(tr.cuentaPunto2),
          _Punto(tr.cuentaPunto3),
          _Punto(tr.cuentaPunto4),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: !_verPassword,
            enabled: !_enviando,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _eliminar(),
            decoration: InputDecoration(
              labelText: tr.ingresoContrasena,
              helperText: tr.cuentaParaConfirmar,
              errorText: _error,
              suffixIcon: IconButton(
                tooltip:
                    _verPassword ? tr.ingresoOcultarContrasena : tr.ingresoMostrarContrasena,
                icon: Icon(_verPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _verPassword = !_verPassword),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  final String texto;
  const _Punto(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.textMuted),
          ),
          Expanded(child: Text(texto, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Acerca de eduXaction
// ---------------------------------------------------------------------------

/// Lo que en la web está en el pie de página —redes, créditos— más lo que
/// las tiendas piden tener a mano: privacidad, normas, contacto y licencias.
/// En la app no hay pie de página (ver `AppFooter`).
Future<void> mostrarAcercaDe(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('eduXaction', style: TextStyle(fontSize: 20)),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tr.cuentaAcercaTexto(InstitutionalInfo.footerText),
                  style: TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  children: [
                    construirBotonSocial(
                      icono: (c) => Icon(Icons.facebook, size: 18, color: c),
                      label: 'Facebook',
                      url: SocialLinks.facebook,
                    ),
                    construirBotonSocial(
                      icono: (c) => InstagramIcon(color: c),
                      label: 'Instagram',
                      url: SocialLinks.instagram,
                    ),
                    construirBotonSocial(
                      icono: (c) => LinkedInIcon(color: c),
                      label: 'LinkedIn',
                      url: SocialLinks.linkedin,
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(tr.comunPoliticaPrivacidad),
                onTap: () => abrirPoliticaDePrivacidad(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(tr.cuentaNormas),
                onTap: () => mostrarNormasDeLaComunidad(ctx),
              ),
              if (ContactInfo.correoSoporte.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(tr.cuentaEscribanos),
                  subtitle: const Text(ContactInfo.correoSoporte),
                  onTap: () => launchUrl(
                    Uri(scheme: 'mailto', path: ContactInfo.correoSoporte),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(tr.cuentaLicencias),
                onTap: () => showLicensePage(
                  context: ctx,
                  applicationName: 'eduXaction',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  tr.cuentaDerechos(DateTime.now().year),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr.comunCerrar),
        ),
      ],
    ),
  );
}
