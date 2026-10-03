import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Un WebView falso para el reproductor de YouTube.
///
/// `flutter test` no tiene WebView ni navegador, así que sin esto el
/// reproductor no se puede ni construir. Pero **no reemplaza al reproductor**:
/// el `YoutubePlayerController`, su manejador de eventos y el `YoutubePlayer`
/// son los del paquete, de verdad. Lo único falso es la página de adentro, y
/// habla el mismo protocolo que la real — los mensajes JSON que el
/// `player.html` del paquete le manda a Flutter (`Ready`, `StateChange`,
/// `VideoState`). Así, lo que se prueba es nuestro cableado contra el paquete,
/// no un doble que se porta como uno quisiera.
class FakeYoutubeWebView extends WebViewPlatform {
  final List<FakeYoutubePage> pages = [];

  /// La última página creada: la del reproductor que está en pantalla.
  FakeYoutubePage get page => pages.last;

  /// Lo instala como plataforma de WebView y lo devuelve. Llamar en `setUp`.
  static FakeYoutubeWebView install() {
    // El paquete lee su `player.html` con `rootBundle`, que guarda el Future
    // en caché. Ese Future quedó atado al tiempo falso de la prueba anterior y
    // en la siguiente no se resuelve nunca: el reproductor no carga y la
    // prueba falla por algo que no es suyo. Comprobado, no supuesto.
    rootBundle.clear();
    final fake = FakeYoutubeWebView();
    WebViewPlatform.instance = fake;
    return fake;
  }

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final page = FakeYoutubePage(params);
    pages.add(page);
    return page;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakeWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _FakeNavigationDelegate(params);
}

/// La página del reproductor: recibe órdenes y manda eventos.
class FakeYoutubePage extends PlatformWebViewController {
  FakeYoutubePage(super.params) : super.implementation();

  JavaScriptChannelParams? _channel;

  /// El HTML que el paquete cargó (su `player.html`, ya completado).
  String? html;

  /// El canal de mensajes que abrió el controlador; se llama como su
  /// `playerId`.
  String? get channelName => _channel?.name;

  /// Cada orden que el controlador le dio al reproductor (`player.cueVideoById(…)`).
  final List<String> commands = [];

  /// Lo que contesta `getDuration`, en segundos.
  double durationSec = 212;

  /// El id que contesta `getVideoData`.
  String videoId = '';

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    this.html = html;
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    commands.add(javaScript);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    commands.add(javaScript);
    if (javaScript.contains('getDuration')) return '$durationSec';
    if (javaScript.contains('getVideoData')) {
      return jsonEncode({'video_id': videoId, 'author': '', 'title': ''});
    }
    return '';
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    _channel = params;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  /// Un evento como los que manda el `player.html` real.
  void send(String event, Object data) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('El reproductor todavía no abrió su canal.');
    }
    channel.onMessageReceived(JavaScriptMessage(
      message: jsonEncode({event: data, 'playerId': channel.name}),
    ));
  }

  /// El reproductor terminó de cargar la API de YouTube.
  void ready() => send('Ready', {});

  /// Cambio de estado, con los códigos de la API de YouTube.
  void state(int code) => send('StateChange', code);

  /// La posición, como la informa el reproductor mientras reproduce.
  void position(double seconds) => send(
        'VideoState',
        jsonEncode({'currentTime': seconds, 'loadedFraction': 0.5}),
      );
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-youtube-webview'));
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {}

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {}
}
