import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../widgets/animated_logo.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/selector_idioma.dart';

/// Verificación pública de un certificado: lo que abre su QR.
///
/// Sin sesión. Quien recibe un certificado —una empresa que contrata, por
/// ejemplo— comprueba aquí que es real y qué dice. Se muestra solo lo que el
/// certificado ya trae impreso.
class VerificarCertificadoView extends StatefulWidget {
  final String? id;
  const VerificarCertificadoView({super.key, this.id});

  @override
  State<VerificarCertificadoView> createState() =>
      _VerificarCertificadoViewState();
}

class _VerificarCertificadoViewState extends State<VerificarCertificadoView> {
  Future<CertificadoVerificado>? _carga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final id = widget.id;
    if (id == null || id.isEmpty) return;
    _carga = context.read<DataProvider>().verificarCertificado(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                const SafeArea(bottom: false, child: BarraIdioma()),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AnimatedLogo(height: 90),
                            const SizedBox(height: 28),
                            _carga == null
                                ? _NoEncontrado()
                                : FutureBuilder<CertificadoVerificado>(
                                    future: _carga,
                                    builder: (context, snap) {
                                      final error = snap.error;
                                      if (error is NotFoundError) {
                                        return _NoEncontrado();
                                      }
                                      if (error != null) {
                                        return ErrorState(
                                          error is ApiException
                                              ? error
                                              : NetworkError(),
                                          onRetry: () async =>
                                              setState(_cargar),
                                        );
                                      }
                                      final cert = snap.data;
                                      if (cert == null) {
                                        return const CardListSkeleton(
                                            count: 1, height: 220);
                                      }
                                      return _Valido(cert: cert);
                                    },
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

class _Valido extends StatelessWidget {
  final CertificadoVerificado cert;
  const _Valido({required this.cert});

  @override
  Widget build(BuildContext context) {
    Widget dato(String rotulo, String valor) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 124,
                child: Text(rotulo,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ),
              Expanded(
                child: Text(valor,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ),
            ],
          ),
        );

    return HoverCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppColors.statusGood, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr.verificarValido,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: AppWeights.uiSemibold,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(cert.studentName,
              style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 28,
                  color: AppColors.gold)),
          const SizedBox(height: 6),
          Text(
            cert.esDeCurso
                ? tr.verificarCompletoCurso(cert.titulo)
                : tr.verificarCompletoRuta(cert.titulo),
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (cert.hours > 0) dato(tr.verificarHoras, '${cert.hours}'),
          dato(tr.verificarEmitidoPor, cert.issuer),
          dato(tr.verificarFecha, fechaLarga(cert.issuedAt)),
          dato(tr.verificarCodigo, cert.code),
        ],
      ),
    );
  }
}

class _NoEncontrado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.gpp_bad_outlined,
            color: AppColors.statusCritical, size: 40),
        const SizedBox(height: 12),
        Text(tr.verificarNoEncontrado,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: AppWeights.uiSemibold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(tr.verificarNoEncontradoTexto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.home_outlined, size: 18),
          label: Text(tr.comunVolverAlInicio),
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false),
        ),
      ],
    );
  }
}
