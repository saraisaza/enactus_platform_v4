import 'package:flutter/material.dart';

import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Los tres estados que toda pantalla necesita ahora que los datos vienen de
/// la red: cargando, error con reintentar, y vacío.
///
/// Un solo juego de widgets para toda la app: si cada pantalla inventara el
/// suyo, un 403 se vería distinto en cada portal y algunos terminarían
/// mostrando una lista vacía en vez del error.

/// Indicador de carga con la marca. Se usa en pantallas completas.
class BrandLoader extends StatelessWidget {
  final String? message;
  const BrandLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      ],
    );
  }
}

/// Bloque gris que ocupa el lugar del contenido mientras carga.
///
/// Un esqueleto en vez de una ruedita: la pantalla no salta de tamaño cuando
/// llegan los datos, que es lo que hace que una carga se sienta lenta aunque
/// tarde lo mismo.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se respeta la preferencia de reducir movimiento del sistema: con ella
    // activa el bloque queda quieto, sin latido.
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.surfaceAlt,
            AppColors.border,
            _controller.value,
          ),
          borderRadius: widget.radius ?? BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// Esqueleto con forma de tarjeta, para listados.
class CardSkeleton extends StatelessWidget {
  final double height;
  const CardSkeleton({super.key, this.height = 132});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 150, height: 18),
          const SizedBox(height: 12),
          const Skeleton(height: 12),
          const SizedBox(height: 8),
          const Skeleton(width: 220, height: 12),
          const Spacer(),
          Row(
            children: const [
              Skeleton(width: 70, height: 22, radius: null),
              SizedBox(width: 8),
              Skeleton(width: 54, height: 22),
            ],
          ),
        ],
      ),
    );
  }
}

/// Varias tarjetas de esqueleto, como se verá el listado real.
class CardListSkeleton extends StatelessWidget {
  final int count;
  final double height;
  const CardListSkeleton({super.key, this.count = 3, this.height = 132});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : 12),
            child: CardSkeleton(height: height),
          ),
      ],
    );
  }
}

/// Error con su motivo y un botón de reintentar.
///
/// El mensaje sale del servidor cuando lo hay: "Tu cuenta es de Open Learning"
/// dice mucho más que "algo salió mal". Y el botón de reintentar solo aparece
/// cuando reintentar puede servir de algo — ante un 403 no sirve nunca.
class ErrorState extends StatelessWidget {
  final ApiException error;
  final Future<void> Function()? onRetry;

  /// Para incrustarlo dentro de una tarjeta en vez de ocupar la pantalla.
  final bool compact;

  const ErrorState(this.error, {super.key, this.onRetry, this.compact = false});

  /// Reintentar solo tiene sentido si el problema puede ser pasajero.
  bool get _canRetry =>
      onRetry != null && (error is NetworkError || error is ServerError);

  IconData get _icon => switch (error) {
        NetworkError() => Icons.wifi_off_outlined,
        ForbiddenError() => Icons.lock_outline,
        NotFoundError() => Icons.search_off_outlined,
        AuthError() => Icons.person_off_outlined,
        _ => Icons.error_outline,
      };

  Color get _color => switch (error) {
        ForbiddenError() => AppColors.statusWarning,
        NotFoundError() => AppColors.textMuted,
        _ => AppColors.statusCritical,
      };

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(_icon, size: compact ? 28 : 44, color: _color),
        SizedBox(height: compact ? 10 : 16),
        Text(
          error.message,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: compact ? 13 : 14.5,
            height: 1.5,
          ),
        ),
        if (_canRetry) ...[
          SizedBox(height: compact ? 12 : 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            onPressed: () => onRetry?.call(),
          ),
        ],
      ],
    );

    if (compact) return Padding(padding: const EdgeInsets.all(16), child: content);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: const EdgeInsets.all(32), child: content),
      ),
    );
  }
}

/// Franja discreta para avisar de un error que NO impide usar la pantalla
/// (por ejemplo, no se pudieron cargar las notificaciones pero el resto sí).
class ErrorBanner extends StatelessWidget {
  final ApiException error;
  final Future<void> Function()? onRetry;

  const ErrorBanner(this.error, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusCritical.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.statusCritical.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: AppColors.statusCritical),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () => onRetry?.call(),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}

/// Envuelve el patrón completo: carga → error → vacío → contenido.
///
/// Existe para que ninguna pantalla se olvide del caso vacío, que es el que
/// más fácil se pasa por alto cuando uno solo piensa en "cargando o listo".
class AsyncListView<T> extends StatelessWidget {
  final List<T>? items;
  final bool isLoading;
  final ApiException? error;
  final Future<void> Function()? onRetry;
  final Widget Function(List<T> items) builder;
  final Widget emptyState;
  final Widget? loadingState;

  const AsyncListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.error,
    required this.builder,
    required this.emptyState,
    this.onRetry,
    this.loadingState,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) return ErrorState(error!, onRetry: onRetry);
    if (items == null || isLoading && items!.isEmpty) {
      return loadingState ?? const CardListSkeleton();
    }
    if (items!.isEmpty) return emptyState;
    return builder(items!);
  }
}
