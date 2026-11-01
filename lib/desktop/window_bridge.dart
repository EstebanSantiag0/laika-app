// Puente con la ventana nativa de Linux (linux/runner/my_application.cc).
//
// En modo mascota (--pet) la ventana cubre toda la pantalla pero es
// transparente; aquí le decimos qué rectángulos (Laika, su chat) deben recibir
// clics. Todo lo demás pasa a las ventanas de abajo.

import 'package:flutter/services.dart';

class WindowBridge {
  static const _ch = MethodChannel('laika/window');

  /// true si la ventana nativa se abrió como capa transparente (Wayland + gtk-layer-shell).
  static Future<bool> isPetMode() async {
    try {
      return await _ch.invokeMethod<bool>('isPetMode') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> setInputRegion(List<Rect> rects) async {
    try {
      await _ch.invokeMethod('setInputRegion', [
        for (final r in rects) [r.left, r.top, r.width, r.height],
      ]);
    } on MissingPluginException {
      // Fuera de Linux (o en pruebas) no hay nada que recortar.
    } on PlatformException {
      // Ídem.
    }
  }
}
