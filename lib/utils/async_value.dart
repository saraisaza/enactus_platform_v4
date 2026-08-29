import 'package:flutter/foundation.dart';

import '../services/api_errors.dart';

/// Estado de un dato que viene de la red: `idle`, `loading`, `data` o `error`.
///
/// Es el único patrón de carga de la app. Los getters de `DataProvider` siguen
/// siendo SÍNCRONOS —devuelven este estado, no un `Future`— por una razón
/// concreta: un `FutureBuilder` dentro de `build()` se vuelve a disparar en
/// cada reconstrucción salvo que se cachee el future a mano, y con ~300 puntos
/// de lectura eso son 300 oportunidades de meter un bucle de peticiones.
///
/// Acá el provider hace el fetch una vez, guarda el resultado y notifica; la
/// vista solo lee estado.
///
/// ```dart
/// data.courses.when(
///   loading: () => const CardGridSkeleton(),
///   error: (e) => ErrorState(e, onRetry: data.reloadCourses),
///   data: (courses) => CourseGrid(courses),
/// )
/// ```
@immutable
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Todavía nadie pidió este dato. El provider lo dispara al primer acceso.
  const factory AsyncValue.idle() = AsyncIdle<T>;

  /// Pedido en curso. [previous] conserva lo que ya había, para poder
  /// recargar sin que la pantalla parpadee a vacío.
  const factory AsyncValue.loading({T? previous}) = AsyncLoading<T>;

  const factory AsyncValue.data(T value) = AsyncData<T>;

  const factory AsyncValue.error(ApiException error, {T? previous}) =
      AsyncError<T>;

  /// El valor actual si lo hay — incluso mientras recarga o tras un error.
  T? get valueOrNull => switch (this) {
        AsyncData<T>(:final value) => value,
        AsyncLoading<T>(:final previous) => previous,
        AsyncError<T>(:final previous) => previous,
        AsyncIdle<T>() => null,
      };

  bool get isLoading => this is AsyncLoading<T> || this is AsyncIdle<T>;
  bool get hasValue => valueOrNull != null;
  ApiException? get errorOrNull =>
      this is AsyncError<T> ? (this as AsyncError<T>).error : null;

  /// Ramas obligatorias: no se puede olvidar el error ni el vacío.
  ///
  /// [loading] cubre también `idle` a propósito: para quien mira la pantalla,
  /// "todavía no lo pedimos" y "lo estamos pidiendo" son lo mismo.
  R when<R>({
    required R Function() loading,
    required R Function(ApiException error) error,
    required R Function(T value) data,
  }) =>
      switch (this) {
        AsyncIdle<T>() => loading(),
        AsyncLoading<T>() => loading(),
        AsyncError<T>(:final error) => error(this.error),
        AsyncData<T>(:final value) => data(value),
      };

  /// Igual que [when], pero mientras recarga sigue mostrando lo anterior en
  /// vez de volver al esqueleto. Para refrescos, no para la primera carga.
  R whenKeepingPrevious<R>({
    required R Function() loading,
    required R Function(ApiException error) error,
    required R Function(T value) data,
  }) {
    final previous = valueOrNull;
    if (previous != null && this is! AsyncError<T>) return data(previous);
    return when(loading: loading, error: error, data: data);
  }

  /// Transforma el valor conservando el estado.
  AsyncValue<R> map<R>(R Function(T value) transform) => switch (this) {
        AsyncIdle<T>() => AsyncValue<R>.idle(),
        AsyncLoading<T>(:final previous) => AsyncValue<R>.loading(
            previous: previous == null ? null : transform(previous)),
        AsyncError<T>(:final error, :final previous) => AsyncValue<R>.error(
            error,
            previous: previous == null ? null : transform(previous)),
        AsyncData<T>(:final value) => AsyncValue<R>.data(transform(value)),
      };
}

final class AsyncIdle<T> extends AsyncValue<T> {
  const AsyncIdle();
}

final class AsyncLoading<T> extends AsyncValue<T> {
  final T? previous;
  const AsyncLoading({this.previous});
}

final class AsyncData<T> extends AsyncValue<T> {
  final T value;
  const AsyncData(this.value);
}

final class AsyncError<T> extends AsyncValue<T> {
  final ApiException error;
  final T? previous;
  const AsyncError(this.error, {this.previous});
}

/// Combina dos estados: carga si alguno carga, error con el primero que falle.
/// Evita anidar dos `when` cuando una pantalla necesita dos fuentes.
AsyncValue<(A, B)> combine2<A, B>(AsyncValue<A> a, AsyncValue<B> b) {
  final errorA = a.errorOrNull;
  if (errorA != null) return AsyncValue.error(errorA);
  final errorB = b.errorOrNull;
  if (errorB != null) return AsyncValue.error(errorB);

  final valueA = a is AsyncData<A> ? a.value : null;
  final valueB = b is AsyncData<B> ? b.value : null;
  if (valueA == null || valueB == null) return const AsyncValue.loading();
  return AsyncValue.data((valueA, valueB));
}

AsyncValue<(A, B, C)> combine3<A, B, C>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
) {
  final pair = combine2(a, b);
  final errorPair = pair.errorOrNull;
  if (errorPair != null) return AsyncValue.error(errorPair);
  final errorC = c.errorOrNull;
  if (errorC != null) return AsyncValue.error(errorC);

  final valuePair = pair is AsyncData<(A, B)> ? pair.value : null;
  final valueC = c is AsyncData<C> ? c.value : null;
  if (valuePair == null || valueC == null) return const AsyncValue.loading();
  return AsyncValue.data((valuePair.$1, valuePair.$2, valueC));
}
