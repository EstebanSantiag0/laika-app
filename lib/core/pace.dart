// Reloj lento para las animaciones que nunca terminan: Laika respirando, el
// fondo de la app, la esfera del cerebro que gira, las caritas de Emociones.
//
// Un AnimationController en repeat() pide un cuadro en cada refresco de la
// pantalla (144 por segundo en la laptop de Esteban) aunque casi nada se mueva,
// y cada cuadro redibuja la ventana completa: la mascota dormida se comía ~20 %
// de un núcleo y la app abierta ~60 %. Pace avisa solo [fps] veces por segundo
// y se puede pausar. [t] (segundos) solo avanza mientras corre, así que al
// seguir no hay saltos.

import 'dart:async';

import 'package:flutter/widgets.dart';

class Pace extends ChangeNotifier with WidgetsBindingObserver {
  /// [whenFocused]: además se detiene cuando la ventana no está al frente
  /// (en Linux, Flutter avisa `inactive` al perder el foco y `hidden` al
  /// minimizar). No sirve para la mascota: su ventana nunca tiene el foco.
  Pace({this._fps = 30, this.whenFocused = false}) {
    if (whenFocused) {
      WidgetsBinding.instance.addObserver(this);
      _front = _isFront(WidgetsBinding.instance.lifecycleState);
    }
    _update();
  }

  final bool whenFocused;
  final _watch = Stopwatch();
  Timer? _timer;
  int _fps;
  int _timerFps = 0;
  bool _on = true, _front = true;

  /// Segundos que lleva corriendo (para animar).
  double get t => _watch.elapsedMicroseconds / 1e6;

  bool get running => _watch.isRunning;

  int get fps => _fps;
  set fps(int v) {
    if (v == _fps) return;
    _fps = v;
    _update();
  }

  /// Pausa o sigue por decisión de quien lo usa (p. ej. la esfera dejó de girar).
  bool get on => _on;
  set on(bool v) {
    if (v == _on) return;
    _on = v;
    _update();
  }

  static bool _isFront(AppLifecycleState? s) => s == null || s == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _front = _isFront(state);
    _update();
  }

  void _update() {
    final run = _on && _front && _fps > 0;
    if (run && !_watch.isRunning) _watch.start();
    if (!run && _watch.isRunning) _watch.stop();
    if (run && _timer != null && _timerFps == _fps) return;
    _timer?.cancel();
    _timer = null;
    if (!run) return;
    _timerFps = _fps;
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ _fps), (_) => notifyListeners());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (whenFocused) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
