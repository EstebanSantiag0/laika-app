// Laika — la mascota (diseño original).
//
// Esteban pidió el estilo y las emociones de sus referencias (personaje
// chibi gótico-kawaii con muchas caras). Como el repo es público y esos
// personajes tienen dueño, Laika es un diseño propio con su propia silueta:
//   • capucha oscura con orejas de murciélago (borde festoneado),
//   • luna creciente rosa en la frente (Laika, la perrita del espacio),
//   • nariz de perrito y boca "ω", patitas con almohadillas rosas,
//   • gorguera lila con un corazón colgando y cola con punta de corazón.
// Lo que sí se toma de las referencias es la lista de emociones y posturas.
//
// Todo se dibuja con código en una caja de 100×100 (se escala sola).

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pet.dart';

const _ink = Color(0xFF231B2E);
const _hood = Color(0xFF2E2440);
const _hoodHi = Color(0xFF4F3F6B);
const _pink = Color(0xFFF7A8C8);
const _pinkDeep = Color(0xFFE8679E);
const _lilac = Color(0xFFCDB8F5);
const _blush = Color(0xFFF58BB4);
const _mouthIn = Color(0xFF5A2440);
const _tear = Color(0xFF8FD3FF);
const _cushion = Color(0xFFF9C6DB);

enum _Body { stand, sit }

enum _Arms { down, up, wave, chest, fingers, mouth, chin, belly }

enum _Eye { open, happy, closed, heart, squeeze, wide, sparkle, sad, angry, half, lookUp, sleepy }

enum _Brow { none, angry, worried, raised }

enum _Mouth { w, open, big, o, smirk, wavy, flat, tongue }

class LaikaPainter extends CustomPainter {
  LaikaPainter({required this.mood, this.lying = false, required this.t, this.bell = false});

  final Mood mood;

  /// Solo cuenta si [mood] es [Mood.sleeping]: acostada sobre su cojín.
  final bool lying;
  final double t;

  /// Hay recordatorios esperando (campanita).
  final bool bell;

  Paint _stroke([double w = 2.2, Color c = _ink]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = c
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _fs(Canvas c, Path p, Color fill, [double w = 2.2]) {
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, _stroke(w));
  }

  Path _oval(Offset center, double rx, double ry) => Path()..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));

  static Path heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.5)
    ..cubicTo(c.dx - s * 1.0, c.dy - s * 0.05, c.dx - s * 0.5, c.dy - s * 0.78, c.dx, c.dy - s * 0.3)
    ..cubicTo(c.dx + s * 0.5, c.dy - s * 0.78, c.dx + s * 1.0, c.dy - s * 0.05, c.dx, c.dy + s * 0.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    if (mood == Mood.sleeping && lying) {
      _paintLying(canvas);
    } else {
      _paintUpright(canvas);
    }
    if (bell) _bell(canvas);
    canvas.restore();
  }

  // ── Cuerpo completo ───────────────────────────────────────────────────────

  void _paintUpright(Canvas c) {
    final (body, arms, eyes, brow, mouth, blush) = switch (mood) {
      Mood.neutral => (_Body.sit, _Arms.down, (_Eye.open, _Eye.open), _Brow.none, _Mouth.w, 0.55),
      Mood.happy => (_Body.stand, _Arms.up, (_Eye.happy, _Eye.happy), _Brow.none, _Mouth.open, 1.0),
      Mood.greeting => (_Body.stand, _Arms.wave, (_Eye.happy, _Eye.happy), _Brow.none, _Mouth.open, 1.0),
      Mood.laughing => (_Body.sit, _Arms.belly, (_Eye.happy, _Eye.happy), _Brow.none, _Mouth.big, 1.0),
      Mood.inLove => (_Body.stand, _Arms.chest, (_Eye.heart, _Eye.heart), _Brow.none, _Mouth.open, 1.0),
      Mood.surprised => (_Body.stand, _Arms.mouth, (_Eye.wide, _Eye.wide), _Brow.none, _Mouth.o, 0.4),
      Mood.impressed => (_Body.stand, _Arms.mouth, (_Eye.sparkle, _Eye.sparkle), _Brow.none, _Mouth.o, 0.9),
      Mood.doubting => (_Body.stand, _Arms.chin, (_Eye.half, _Eye.open), _Brow.raised, _Mouth.flat, 0.3),
      Mood.ashamed => (_Body.sit, _Arms.fingers, (_Eye.sad, _Eye.sad), _Brow.worried, _Mouth.wavy, 1.0),
      Mood.crying => (_Body.sit, _Arms.up, (_Eye.squeeze, _Eye.squeeze), _Brow.worried, _Mouth.big, 0.8),
      Mood.scheming => (_Body.stand, _Arms.chest, (_Eye.angry, _Eye.angry), _Brow.angry, _Mouth.smirk, 0.3),
      Mood.cheeky => (_Body.sit, _Arms.chin, (_Eye.happy, _Eye.open), _Brow.none, _Mouth.tongue, 0.8),
      Mood.thinking => (_Body.sit, _Arms.down, (_Eye.lookUp, _Eye.lookUp), _Brow.none, _Mouth.o, 0.5),
      Mood.waking => (_Body.sit, _Arms.down, (_Eye.sleepy, _Eye.sleepy), _Brow.none, _Mouth.o, 0.5),
      Mood.sleeping => (_Body.sit, _Arms.down, (_Eye.closed, _Eye.closed), _Brow.none, _Mouth.w, 0.6),
    };
    final sit = body == _Body.sit;
    final bob = mood == Mood.sleeping ? sin(t * 1.4) * 1.1 : sin(t * 2.2) * 0.7;

    // Sombra en el piso.
    c.drawOval(Rect.fromCenter(center: const Offset(50, 95.5), width: sit ? 50 : 38, height: 5),
        Paint()..color = _ink.withValues(alpha: 0.10));

    c.save();
    if (mood == Mood.laughing) {
      // Se va de espaldas de la risa.
      c.translate(50, 92);
      c.rotate(-0.26 + sin(t * 16) * 0.03);
      c.translate(-50, -92);
    }
    if (mood == Mood.crying) c.translate(sin(t * 18) * 0.7, 0);

    final headC = Offset(50, (sit ? 41 : 38) + bob);
    final shoulderL = Offset(sit ? 38.5 : 40.5, (sit ? 72 : 68) + bob * 0.5);
    final shoulderR = Offset(100 - shoulderL.dx, shoulderL.dy);

    // Cola (detrás de todo).
    final sway = sin(t * 2.6) * 1.8;
    final tail = sit
        ? (Path()
          ..moveTo(62, 86)
          ..cubicTo(78, 90, 84, 78, 81 + sway, 69))
        : (Path()
          ..moveTo(60, 86)
          ..cubicTo(72, 93, 83, 90, 83 + sway, 80));
    c.drawPath(tail, _stroke(5.6));
    c.drawPath(tail, _stroke(2.6, _hood));
    final tip = sit ? Offset(81 + sway, 66) : Offset(83 + sway, 77);
    _fs(c, heart(tip, 8), _hood, 1.8);

    // Brazos de atrás (los que salen hacia los lados).
    final (handL, handR, front) = _hands(arms, shoulderL, shoulderR);
    if (!front.$1) _arm(c, shoulderL, handL);
    if (!front.$2) _arm(c, shoulderR, handR);

    // Cuerpo.
    if (sit) {
      _fs(c, _oval(Offset(50, 79 + bob * 0.3), 16, 12.5), Colors.white);
      for (final x in [39.0, 61.0]) {
        if (mood == Mood.laughing) {
          _paw(c, Offset(x, 88), kick: sin(t * 16 + x) * 1.5);
        } else {
          _paw(c, Offset(x, 89.5));
        }
      }
    } else {
      _fs(c, _oval(Offset(50, 76 + bob * 0.3), 13.5, 14.5), Colors.white);
      for (final x in [43.5, 56.5]) {
        _fs(c, _oval(Offset(x, 91), 6, 4), Colors.white);
      }
    }

    // Cabeza.
    c.save();
    c.translate(headC.dx, headC.dy);
    if (mood == Mood.sleeping) c.rotate(0.12 + sin(t * 1.4) * 0.05);
    if (mood == Mood.doubting) c.rotate(-0.08);
    if (mood == Mood.cheeky) c.rotate(0.07);
    _head(c, eyes, brow, mouth, blush);
    c.restore();

    // Brazos de enfrente.
    if (front.$1) _arm(c, shoulderL, handL);
    if (front.$2) _arm(c, shoulderR, handR);

    c.restore();
    _effects(c, headC);
  }

  /// Manos según la postura de brazos; también dice cuál brazo va enfrente.
  (Offset, Offset, (bool, bool)) _hands(_Arms a, Offset l, Offset r) {
    Offset both(Offset s, double dx, double dy, {required bool left}) => s + Offset(left ? dx : -dx, dy);
    switch (a) {
      case _Arms.down:
        return (both(l, -6, 11, left: true), both(r, -6, 11, left: false), (false, false));
      case _Arms.up:
        final wob = sin(t * 7) * 1.2;
        return (both(l, -13, -10 + wob, left: true), both(r, -13, -10 - wob, left: false), (false, false));
      case _Arms.wave:
        final ang = sin(t * 8) * 0.35;
        final d = Offset(13 * cos(ang) + 10 * sin(ang), -10 * cos(ang) + 13 * sin(ang) * 0.3);
        return (both(l, -6, 11, left: true), r + d, (false, false));
      case _Arms.chest:
        final rub = mood == Mood.scheming ? sin(t * 10) * 1.2 : 0.0;
        return (both(l, 6 + rub, 2, left: true), both(r, 6 - rub, 2, left: false), (true, true));
      case _Arms.fingers:
        final tap = sin(t * 6) * 0.8;
        return (both(l, 7.2 + tap, 0, left: true), both(r, 7.2 + tap, 0, left: false), (true, true));
      case _Arms.mouth:
        return (both(l, 5.5, -5, left: true), both(r, 5.5, -5, left: false), (true, true));
      case _Arms.chin:
        return (both(l, -6, 11, left: true), both(r, 2, -7.5, left: false), (false, true));
      case _Arms.belly:
        return (both(l, 6, 7, left: true), both(r, 6, 7, left: false), (true, true));
    }
  }

  void _arm(Canvas c, Offset from, Offset to) {
    c.drawLine(from, to, _stroke(10));
    c.drawLine(from, to, _stroke(6.2, Colors.white));
  }

  /// Patita vista de frente, con almohadillas rosas.
  void _paw(Canvas c, Offset p, {double kick = 0}) {
    final o = p + Offset(0, kick);
    _fs(c, _oval(o, 7, 5.6), Colors.white);
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 1.2), width: 5.6, height: 4), Paint()..color = _pink);
    for (final dx in [-2.6, 0.0, 2.6]) {
      c.drawCircle(o + Offset(dx, -2.6 + (dx == 0 ? -0.5 : 0)), 1.05, Paint()..color = _pink);
    }
  }

  // ── Cabeza (origen = centro de la capucha) ────────────────────────────────

  void _head(Canvas c, (_Eye, _Eye) eyes, _Brow brow, _Mouth mouth, double blush) {
    final droop = switch (mood) {
      Mood.sleeping => 0.42,
      Mood.waking => 0.3,
      Mood.ashamed || Mood.crying => 0.32,
      Mood.surprised || Mood.impressed => -0.12,
      _ => 0.0,
    };
    final flap = sin(t * 1.7) * 0.04 + droop;

    // Gorguera con corazón colgando (va detrás de la cabeza).
    for (var i = -2; i <= 2; i++) {
      final x = i * 6.0;
      final p = Offset(x, 25.5 - x.abs() * 0.18);
      _fs(c, _oval(p, 3.7, 3.4), _lilac, 1.5);
    }
    _fs(c, heart(const Offset(0, 31.5), 4.2), _pink, 1.3);

    // Orejas de murciélago.
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.scale(side, 1);
      c.translate(-15, -15);
      c.rotate(-flap);
      c.translate(15, 15);
      final ear = Path()
        ..moveTo(-8, -23)
        ..quadraticBezierTo(-21, -36, -37, -37)
        ..quadraticBezierTo(-28.5, -29, -31.5, -19.5)
        ..quadraticBezierTo(-24, -17.5, -21, -7.5)
        ..close();
      _fs(c, ear, _hood);
      final inner = Path()
        ..moveTo(-12, -21.5)
        ..quadraticBezierTo(-21, -31, -31, -33)
        ..quadraticBezierTo(-25.5, -27, -27.5, -21)
        ..quadraticBezierTo(-22, -19.5, -19.5, -13)
        ..close();
      c.drawPath(inner, Paint()..color = _hoodHi);
      c.restore();
    }

    // Capucha.
    _fs(c, _oval(Offset.zero, 28, 25), _hood);
    c.drawArc(Rect.fromCenter(center: Offset.zero, width: 48, height: 42), pi * 1.08, 0.75,
        false, _stroke(2.4, _hoodHi.withValues(alpha: 0.9)));

    // Luna creciente y estrellita.
    final moon = Path.combine(
      PathOperation.difference,
      _oval(const Offset(0, -14.5), 5.4, 5.4),
      _oval(const Offset(2.6, -16.2), 4.5, 4.5),
    );
    c.drawPath(moon, Paint()..color = _pink);
    _star(c, const Offset(4.6, -12.2), 1.9, _pink);

    // Cara.
    final face = _oval(const Offset(0, 6), 21, 16.5);
    c.drawPath(face, Paint()..color = Colors.white);
    c.drawPath(face, _stroke(1.6));

    // Cachetes.
    for (final x in [-14.5, 14.5]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, 12.5), width: 7.6, height: 4.4),
          Paint()..color = _blush.withValues(alpha: 0.55 * blush));
      if (mood == Mood.ashamed || mood == Mood.inLove) {
        for (final dx in [-1.6, 0.0, 1.6]) {
          c.drawLine(Offset(x + dx + 0.6, 11.2), Offset(x + dx - 0.6, 13.6), _stroke(0.8, _pinkDeep));
        }
      }
    }

    final blink = (eyes.$1 == _Eye.open || eyes.$2 == _Eye.open) && (t % 4.3) > 4.17;
    _eye(c, const Offset(-9, 5.5), blink && eyes.$1 == _Eye.open ? _Eye.closed : eyes.$1, left: true);
    _eye(c, const Offset(9, 5.5), blink && eyes.$2 == _Eye.open ? _Eye.closed : eyes.$2, left: false);
    _brows(c, brow);

    // Nariz de perrito.
    final nose = Path()
      ..moveTo(-2.2, 10.1)
      ..quadraticBezierTo(0, 9.2, 2.2, 10.1)
      ..quadraticBezierTo(1.3, 12.5, 0, 12.7)
      ..quadraticBezierTo(-1.3, 12.5, -2.2, 10.1)
      ..close();
    c.drawPath(nose, Paint()..color = _ink);
    c.drawCircle(const Offset(-0.7, 10.3), 0.45, Paint()..color = Colors.white);

    _mouth(c, mouth);

    // Efectos pegados a la cara.
    if (mood == Mood.ashamed) {
      final drop = Path()
        ..moveTo(19, -9)
        ..quadraticBezierTo(22.5, -3.5, 19, -2)
        ..quadraticBezierTo(15.5, -3.5, 19, -9)
        ..close();
      _fs(c, drop, _tear, 1.2);
    }
    if (mood == Mood.crying) {
      for (final x in [-9.0, 9.0]) {
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.6 + (x > 0 ? 1 : -1), 8.5, 3.2, 13), const Radius.circular(1.6));
        c.drawRRect(r, Paint()..color = _tear.withValues(alpha: 0.9));
        final f = (t * 1.6 + (x > 0 ? 0.5 : 0)) % 1;
        c.drawCircle(Offset(x + (x > 0 ? 3 : -3) * f * 2, 21 + f * 9), 1.5 * (1 - f * 0.5), Paint()..color = _tear);
      }
    }
  }

  void _eye(Canvas c, Offset e, _Eye kind, {required bool left}) {
    final outer = left ? -1.0 : 1.0;
    void openEye({double dx = 0, double dy = 0, double scale = 1}) {
      final o = e + Offset(dx, dy);
      c.drawOval(Rect.fromCenter(center: o, width: 6.8 * scale, height: 8.8 * scale), Paint()..color = _ink);
      c.drawCircle(o + Offset(1.1 * scale, -1.7 * scale), 1.3 * scale, Paint()..color = Colors.white);
      c.drawCircle(o + Offset(-1.0 * scale, 1.7 * scale), 0.6 * scale, Paint()..color = Colors.white);
    }

    void lash() => c.drawLine(e + Offset(outer * 2.8, -3.4), e + Offset(outer * 5, -5.2), _stroke(1.3));

    void lidded({required double innerY, required double outerY, double dy = 0}) {
      // Párpado: recorta el ojo por encima de una línea.
      final pIn = e + Offset(-outer * 4.4, innerY);
      final pOut = e + Offset(outer * 4.4, outerY);
      c.save();
      c.clipPath(Path()
        ..moveTo(pIn.dx, pIn.dy)
        ..lineTo(pOut.dx, pOut.dy)
        ..lineTo(pOut.dx, e.dy + 8)
        ..lineTo(pIn.dx, e.dy + 8)
        ..close());
      openEye(dy: dy);
      c.restore();
      c.drawLine(pIn, pOut, _stroke(1.8));
    }

    switch (kind) {
      case _Eye.open:
        openEye();
        lash();
      case _Eye.lookUp:
        openEye(dx: outer * 0.4, dy: -0.9);
        lash();
      case _Eye.happy:
        c.drawPath(
            Path()
              ..moveTo(e.dx - 3.8, e.dy + 1.4)
              ..quadraticBezierTo(e.dx, e.dy - 4.2, e.dx + 3.8, e.dy + 1.4),
            _stroke(2.1));
        lash();
      case _Eye.closed:
        c.drawPath(
            Path()
              ..moveTo(e.dx - 3.8, e.dy - 0.2)
              ..quadraticBezierTo(e.dx, e.dy + 3.6, e.dx + 3.8, e.dy - 0.2),
            _stroke(1.9));
        c.drawLine(e + Offset(outer * 3.6, 0.2), e + Offset(outer * 5.2, -1.2), _stroke(1.2));
      case _Eye.heart:
        final h = heart(e + const Offset(0, 0.4), 9.5);
        _fs(c, h, _pinkDeep, 1.4);
        c.drawCircle(e + const Offset(-1.6, -1.2), 0.9, Paint()..color = Colors.white);
      case _Eye.squeeze:
        c.drawPath(
            Path()
              ..moveTo(e.dx - outer * 3.2, e.dy - 3)
              ..lineTo(e.dx + outer * 2.4, e.dy)
              ..lineTo(e.dx - outer * 3.2, e.dy + 3),
            _stroke(2.1));
      case _Eye.wide:
        c.drawOval(Rect.fromCenter(center: e, width: 8, height: 9.6), Paint()..color = Colors.white);
        c.drawOval(Rect.fromCenter(center: e, width: 8, height: 9.6), _stroke(1.5));
        c.drawCircle(e + const Offset(0, 0.6), 2.1, Paint()..color = _ink);
        c.drawCircle(e + const Offset(0.6, -0.1), 0.6, Paint()..color = Colors.white);
      case _Eye.sparkle:
        c.drawOval(Rect.fromCenter(center: e, width: 7.6, height: 9.8), Paint()..color = _ink);
        _star(c, e + const Offset(0.6, -1.2), 2.6, Colors.white);
        c.drawCircle(e + const Offset(-1.3, 2.3), 0.7, Paint()..color = Colors.white);
        lash();
      case _Eye.sad:
        lidded(innerY: -2.2, outerY: 0.2, dy: 1);
      case _Eye.angry:
        lidded(innerY: 0.4, outerY: -2.6);
        lash();
      case _Eye.half:
        lidded(innerY: -0.6, outerY: -0.6);
      case _Eye.sleepy:
        lidded(innerY: 0.6, outerY: 0.9, dy: 0.6);
    }
  }

  void _brows(Canvas c, _Brow b) {
    final p = _stroke(1.7);
    switch (b) {
      case _Brow.none:
        return;
      case _Brow.angry:
        c.drawLine(const Offset(-13.5, -2.6), const Offset(-5.5, -0.6), p);
        c.drawLine(const Offset(13.5, -2.6), const Offset(5.5, -0.6), p);
      case _Brow.worried:
        c.drawLine(const Offset(-13, -0.8), const Offset(-6, -3.2), p);
        c.drawLine(const Offset(13, -0.8), const Offset(6, -3.2), p);
      case _Brow.raised:
        c.drawLine(const Offset(-12.5, 0.4), const Offset(-5.5, 0.8), p);
        c.drawPath(
            Path()
              ..moveTo(5.5, -2.6)
              ..quadraticBezierTo(9, -5.6, 12.8, -3.2),
            p);
    }
  }

  void _mouth(Canvas c, _Mouth m) {
    void opened(double w, double depth) {
      final path = Path()
        ..moveTo(-w, 14.2)
        ..quadraticBezierTo(0, 13.4, w, 14.2)
        ..cubicTo(w * 0.95, 14.2 + depth, -w * 0.95, 14.2 + depth, -w, 14.2)
        ..close();
      c.drawPath(path, Paint()..color = _mouthIn);
      c.save();
      c.clipPath(path);
      c.drawOval(Rect.fromCenter(center: Offset(0, 14.2 + depth * 0.82), width: w * 1.5, height: depth * 0.75),
          Paint()..color = _blush);
      c.restore();
      c.drawPath(path, _stroke(1.5));
    }

    switch (m) {
      case _Mouth.w:
        c.drawPath(
            Path()
              ..moveTo(-3.6, 13.8)
              ..quadraticBezierTo(-1.8, 16.4, 0, 13.9)
              ..quadraticBezierTo(1.8, 16.4, 3.6, 13.8),
            _stroke(1.4));
      case _Mouth.open:
        opened(4.6, 8);
      case _Mouth.big:
        opened(6.8, 11 + sin(t * 14) * 0.8);
      case _Mouth.o:
        c.drawOval(Rect.fromCenter(center: const Offset(0, 16), width: 3.6, height: 4.2), Paint()..color = _mouthIn);
        c.drawOval(Rect.fromCenter(center: const Offset(0, 16), width: 3.6, height: 4.2), _stroke(1.2));
      case _Mouth.smirk:
        c.drawPath(
            Path()
              ..moveTo(-3.6, 15.4)
              ..quadraticBezierTo(0.6, 17.6, 4.2, 13.6),
            _stroke(1.5));
        final fang = Path()
          ..moveTo(0.9, 16.5)
          ..lineTo(2.9, 15.6)
          ..lineTo(2.2, 18.2)
          ..close();
        _fs(c, fang, Colors.white, 1.0);
      case _Mouth.wavy:
        c.drawPath(
            Path()
              ..moveTo(-3.6, 15.6)
              ..quadraticBezierTo(-1.8, 14.2, 0, 15.6)
              ..quadraticBezierTo(1.8, 17, 3.6, 15.6),
            _stroke(1.4));
      case _Mouth.flat:
        c.drawLine(const Offset(-2.8, 15.8), const Offset(3, 15.1), _stroke(1.5));
      case _Mouth.tongue:
        final tongue = Path()
          ..moveTo(-1.6, 14.6)
          ..lineTo(3.2, 14.6)
          ..cubicTo(3.4, 20.4, -1.8, 20.4, -1.6, 14.6)
          ..close();
        _fs(c, tongue, _blush, 1.2);
        c.drawLine(const Offset(0.8, 15.2), const Offset(0.8, 17.4), _stroke(0.8, _pinkDeep));
        c.drawPath(
            Path()
              ..moveTo(-3.6, 13.8)
              ..quadraticBezierTo(-1.8, 16.2, 0, 14.4)
              ..quadraticBezierTo(1.8, 15.4, 3.8, 13.2),
            _stroke(1.4));
    }
  }

  // ── Dormida sobre su cojín ────────────────────────────────────────────────

  void _paintLying(Canvas c) {
    final breathe = sin(t * 1.3);
    _fs(c, _oval(const Offset(50, 85), 45, 12), _cushion);
    c.drawOval(Rect.fromCenter(center: const Offset(50, 81), width: 64, height: 9), Paint()..color = Colors.white.withValues(alpha: 0.45));
    for (final x in [8.0, 92.0]) {
      c.drawCircle(Offset(x, 84), 2.4, Paint()..color = _pink);
    }

    final tail = Path()
      ..moveTo(78, 75)
      ..cubicTo(90, 76, 94, 66, 90 + breathe * 0.8, 60);
    c.drawPath(tail, _stroke(5.6));
    c.drawPath(tail, _stroke(2.6, _hood));
    _fs(c, heart(Offset(90 + breathe * 0.8, 57.5), 7.5), _hood, 1.8);

    _fs(c, _oval(Offset(62, 73 - breathe * 0.5), 21, 10 + breathe * 0.5), Colors.white);
    _fs(c, _oval(const Offset(80, 80), 5.5, 3.6), Colors.white);

    c.save();
    c.translate(35, 60.5 + breathe * 0.4);
    c.scale(0.9);
    c.rotate(-0.12);
    _head(c, (_Eye.closed, _Eye.closed), _Brow.none, _Mouth.w, 0.7);
    c.restore();

    for (final x in [42.0, 51.0]) {
      _fs(c, _oval(Offset(x, 80), 5, 3.4), Colors.white, 2);
    }
    _zzz(c, const Offset(64, 50));
  }

  // ── Efectos alrededor ─────────────────────────────────────────────────────

  void _effects(Canvas c, Offset head) {
    switch (mood) {
      case Mood.sleeping:
        _zzz(c, const Offset(87, 44));
      case Mood.greeting:
        for (final (i, x) in [(0, 32.0), (1, 50.0), (2, 68.0)]) {
          final y = 4 + sin(t * 3 + i) * 1.2;
          c.drawLine(Offset(x + (i - 1) * 2.5, y + 7), Offset(x + (i - 1) * 4.5, y + 12), _stroke(1.3));
          _fs(c, heart(Offset(x, y), 7), _pink, 1.3);
        }
      case Mood.inLove:
        for (var i = 0; i < 3; i++) {
          final f = (t * 0.45 + i / 3) % 1;
          final p = Offset(18 + i * 30 + sin(t * 2 + i) * 3, 30 - f * 28);
          c.save();
          c.translate(p.dx, p.dy);
          c.scale(0.6 + f * 0.5);
          _fs(c, heart(Offset.zero, 8), _pinkDeep.withValues(alpha: 1 - f * 0.7), 1.2);
          c.restore();
        }
      case Mood.surprised:
        _text(c, '!', Offset(89, 38 + sin(t * 12) * 0.6), 17, _pinkDeep);
      case Mood.impressed:
        for (var i = 0; i < 4; i++) {
          final tw = (sin(t * 4 + i * 1.7) + 1) / 2;
          final p = [const Offset(16, 18), const Offset(84, 14), const Offset(12, 46), const Offset(88, 44)][i];
          _star(c, p, 2.4 + tw * 2.2, Color.lerp(_lilac, _pinkDeep, tw)!);
        }
      case Mood.doubting:
        _text(c, '?', Offset(89, 36 + sin(t * 3) * 1), 17, _lilac);
      case Mood.scheming:
        for (var i = 0; i < 3; i++) {
          final f = (t * 0.6 + i / 3) % 1;
          final x = 24.0 + i * 26;
          c.drawPath(
              Path()
                ..moveTo(x, 18 - f * 10)
                ..quadraticBezierTo(x + 3, 13 - f * 10, x, 8 - f * 10)
                ..quadraticBezierTo(x - 3, 3 - f * 10, x, -2 - f * 10),
              _stroke(1.6, _hoodHi.withValues(alpha: 1 - f)));
        }
      case Mood.laughing:
        _text(c, 'jaja', Offset(84, 40 + sin(t * 14) * 0.8), 9, _pinkDeep);
      case Mood.thinking:
        for (var i = 0; i < 3; i++) {
          final on = ((t * 2.5).floor() % 4) > i;
          c.drawCircle(Offset(83 + i * 5.5, 44), 1.9, Paint()..color = on ? _hoodHi : _hoodHi.withValues(alpha: 0.25));
        }
      case Mood.cheeky:
        _star(c, Offset(82, 22 + sin(t * 4) * 1), 3, _pink);
      case Mood.neutral || Mood.happy || Mood.ashamed || Mood.crying || Mood.waking:
        break;
    }
  }

  void _zzz(Canvas c, Offset at) {
    for (var i = 0; i < 3; i++) {
      final f = (t * 0.35 + i / 3) % 1;
      _text(c, 'z', at + Offset(f * 5, -f * 20), 7 + f * 7, _lilac.withValues(alpha: 1 - f));
    }
  }

  void _bell(Canvas c) {
    final swing = sin(t * 6) * 0.25;
    c.save();
    c.translate(86, 50);
    c.rotate(swing);
    final body = Path()
      ..moveTo(-5, 4)
      ..quadraticBezierTo(-5, -5, 0, -5.5)
      ..quadraticBezierTo(5, -5, 5, 4)
      ..lineTo(6.5, 6)
      ..lineTo(-6.5, 6)
      ..close();
    _fs(c, body, const Color(0xFFFFD66B), 1.5);
    c.drawCircle(const Offset(0, 7.4), 1.6, Paint()..color = _ink);
    c.restore();
  }

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 2;
      final rr = i.isEven ? r : r * 0.38;
      final q = p + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _text(Canvas c, String s, Offset at, double size, Color color) {
    TextPainter tp(Paint? fg, Color? col) => TextPainter(
          text: TextSpan(
              text: s,
              style: TextStyle(
                  fontFamily: 'Adwaita Sans',
                  fontFamilyFallback: const ['Liberation Sans', 'sans-serif'],
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  foreground: fg,
                  color: fg == null ? col : null)),
          textDirection: TextDirection.ltr,
        )..layout();
    final o = tp(_stroke(2.4), null);
    o.paint(c, at - Offset(o.width / 2, o.height / 2));
    final f = tp(null, color);
    f.paint(c, at - Offset(f.width / 2, f.height / 2));
  }

  @override
  bool shouldRepaint(covariant LaikaPainter old) => true;
}
