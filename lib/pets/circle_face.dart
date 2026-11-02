// La cara de Laika por defecto: un círculo blanco estilo "Brutal" (borde
// grueso, sombra dura) que cambia de expresión según su emoción.
//
// Se dibuja con código en una caja de 100×100 (se escala sola). Otras
// apariencias se pueden cargar como imágenes: ver lib/pets/skins.dart.

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pet.dart';

const _ink = Color(0xFF231B2E);
const _pink = Color(0xFFF7A8C8);
const _pinkDeep = Color(0xFFE8679E);
const _lilac = Color(0xFFB9A3F0);
const _blush = Color(0xFFF58BB4);
const _mouthIn = Color(0xFF5A2440);
const _tear = Color(0xFF8FD3FF);
const _pillow = Color(0xFFE9D5FF);

enum _Eye { open, happy, closed, heart, squeeze, wide, sparkle, sad, angry, half, lookUp, sleepy }

enum _Brow { none, angry, worried, raised }

enum _Mouth { w, open, big, o, smirk, wavy, flat, tongue, chew }

class CircleFacePainter extends CustomPainter {
  CircleFacePainter({required this.mood, this.lying = false, required this.t, this.bell = false});

  final Mood mood;

  /// Solo cuenta si [mood] es [Mood.sleeping]: acostada en su almohada.
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
    _paintFace(canvas);
    _effects(canvas);
    if (bell) _bell(canvas);
    canvas.restore();
  }

  void _paintFace(Canvas c) {
    final (eyes, brow, mouth, blush) = switch (mood) {
      Mood.neutral => ((_Eye.open, _Eye.open), _Brow.none, _Mouth.w, 0.55),
      Mood.happy => ((_Eye.happy, _Eye.happy), _Brow.none, _Mouth.open, 1.0),
      Mood.greeting => ((_Eye.happy, _Eye.happy), _Brow.none, _Mouth.open, 1.0),
      Mood.laughing => ((_Eye.happy, _Eye.happy), _Brow.none, _Mouth.big, 1.0),
      Mood.inLove => ((_Eye.heart, _Eye.heart), _Brow.none, _Mouth.open, 1.0),
      Mood.surprised => ((_Eye.wide, _Eye.wide), _Brow.none, _Mouth.o, 0.4),
      Mood.impressed => ((_Eye.sparkle, _Eye.sparkle), _Brow.none, _Mouth.o, 0.9),
      Mood.doubting => ((_Eye.half, _Eye.open), _Brow.raised, _Mouth.flat, 0.3),
      Mood.ashamed => ((_Eye.sad, _Eye.sad), _Brow.worried, _Mouth.wavy, 1.0),
      Mood.crying => ((_Eye.squeeze, _Eye.squeeze), _Brow.worried, _Mouth.big, 0.8),
      Mood.scheming => ((_Eye.angry, _Eye.angry), _Brow.angry, _Mouth.smirk, 0.3),
      Mood.eating => ((_Eye.happy, _Eye.happy), _Brow.none, _Mouth.chew, 0.9),
      Mood.cheeky => ((_Eye.happy, _Eye.open), _Brow.none, _Mouth.tongue, 0.8),
      Mood.thinking => ((_Eye.lookUp, _Eye.lookUp), _Brow.none, _Mouth.o, 0.5),
      Mood.waking => ((_Eye.sleepy, _Eye.sleepy), _Brow.none, _Mouth.o, 0.5),
      Mood.sleeping => ((_Eye.closed, _Eye.closed), _Brow.none, _Mouth.w, 0.6),
    };

    // Movimiento del círculo completo según la emoción.
    var center = const Offset(50, 54);
    var rot = 0.0;
    var sx = 1.0, sy = 1.0;
    final sleepingLying = mood == Mood.sleeping && lying;
    switch (mood) {
      case Mood.happy || Mood.greeting:
        final b = (sin(t * 7)).abs();
        center += Offset(0, -b * 4);
        sy = 1 - (1 - b) * 0.04;
      case Mood.laughing:
        rot = -0.18 + sin(t * 16) * 0.05;
        center += Offset(0, sin(t * 16).abs() * -2);
      case Mood.crying:
        center += Offset(sin(t * 18) * 1.2, 0);
      case Mood.surprised:
        sx = sy = 1.04;
        center += const Offset(0, -3);
      case Mood.ashamed:
        rot = 0.12;
        sx = sy = 0.94;
        center += const Offset(0, 3);
      case Mood.doubting:
        rot = -0.1;
      case Mood.cheeky:
        rot = 0.1;
      case Mood.scheming:
        sx = 1 + sin(t * 10) * 0.012;
      case Mood.eating:
        // Mastica: el círculo se aplasta un poquito a cada mordida.
        final chew = (sin(t * 11) + 1) / 2;
        sy = 1 - chew * 0.03;
        sx = 1 + chew * 0.015;
        center += Offset(0, chew * 0.8);
      case Mood.sleeping when !sleepingLying:
        rot = 0.14 + sin(t * 1.4) * 0.05;
        sy = 1 - (sin(t * 1.4) + 1) * 0.015;
      default:
        sy = 1 + sin(t * 2.2) * 0.012;
    }
    const r = 36.0;

    if (sleepingLying) {
      // Almohada "brutal" y el círculo aplastado encima.
      final pillow = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 74, 84, 16), const Radius.circular(6));
      c.drawRRect(pillow.shift(const Offset(4, 4)), Paint()..color = _ink);
      c.drawRRect(pillow, Paint()..color = _pillow);
      c.drawRRect(pillow, _stroke(3));
      final breathe = sin(t * 1.3) * 0.02;
      center = const Offset(50, 56);
      sx = 1.14 + breathe;
      sy = 0.78 - breathe;
      rot = -0.06;
    }

    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);
    c.scale(sx, sy);

    // Sombra dura + círculo blanco con borde grueso.
    c.drawCircle(const Offset(5, 5), r, Paint()..color = _ink);
    c.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    c.drawCircle(Offset.zero, r, _stroke(3.4));

    // Rasgos (en las coordenadas de siempre, agrandados).
    c.save();
    c.scale(1.6);
    c.translate(0, -9);
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
    _mouth(c, mouth);
    if (mood == Mood.ashamed) {
      final drop = Path()
        ..moveTo(17, -4)
        ..quadraticBezierTo(20.5, 1.5, 17, 3)
        ..quadraticBezierTo(13.5, 1.5, 17, -4)
        ..close();
      _fs(c, drop, _tear, 1.2);
    }
    if (mood == Mood.crying) {
      for (final x in [-9.0, 9.0]) {
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.6 + (x > 0 ? 1 : -1), 8.5, 3.2, 11), const Radius.circular(1.6));
        c.drawRRect(rr, Paint()..color = _tear.withValues(alpha: 0.9));
      }
    }
    c.restore();
    c.restore();

    if (mood == Mood.crying) {
      for (final x in [30.0, 70.0]) {
        final f = (t * 1.6 + (x > 50 ? 0.5 : 0)) % 1;
        c.drawCircle(Offset(x + (x > 50 ? 6 : -6) * f, 80 + f * 14), 2.2 * (1 - f * 0.5), Paint()..color = _tear);
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
      case _Mouth.chew:
        opened(4.4, 1.6 + (sin(t * 11) + 1) / 2 * 5.6);
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


  // ── Efectos alrededor ─────────────────────────────────────────────────────

  void _effects(Canvas c) {
    switch (mood) {
      case Mood.sleeping:
        _zzz(c, lying ? const Offset(84, 46) : const Offset(86, 22));
      case Mood.greeting:
        for (final (i, x) in [(0, 26.0), (1, 50.0), (2, 74.0)]) {
          final y = 6 + sin(t * 3 + i) * 1.2;
          _fs(c, heart(Offset(x, y), 8), _pink, 1.6);
        }
      case Mood.inLove:
        for (var i = 0; i < 3; i++) {
          final f = (t * 0.45 + i / 3) % 1;
          final p = Offset(14 + i * 36 + sin(t * 2 + i) * 3, 26 - f * 24);
          c.save();
          c.translate(p.dx, p.dy);
          c.scale(0.6 + f * 0.5);
          _fs(c, heart(Offset.zero, 9), _pinkDeep.withValues(alpha: 1 - f * 0.7), 1.4);
          c.restore();
        }
      case Mood.surprised:
        _text(c, '!', Offset(90, 14 + sin(t * 12) * 0.6), 20, _pinkDeep);
      case Mood.impressed:
        for (var i = 0; i < 4; i++) {
          final tw = (sin(t * 4 + i * 1.7) + 1) / 2;
          final p = [const Offset(10, 14), const Offset(90, 12), const Offset(8, 60), const Offset(93, 58)][i];
          _star(c, p, 2.6 + tw * 2.4, Color.lerp(_lilac, _pinkDeep, tw)!);
        }
      case Mood.doubting:
        _text(c, '?', Offset(90, 14 + sin(t * 3) * 1), 20, _lilac);
      case Mood.scheming:
        for (var i = 0; i < 3; i++) {
          final f = (t * 0.6 + i / 3) % 1;
          final x = 30.0 + i * 20;
          c.drawPath(
              Path()
                ..moveTo(x, 16 - f * 8)
                ..quadraticBezierTo(x + 3, 11 - f * 8, x, 6 - f * 8)
                ..quadraticBezierTo(x - 3, 1 - f * 8, x, -4 - f * 8),
              _stroke(2, _lilac.withValues(alpha: 1 - f)));
        }
      case Mood.laughing:
        _text(c, 'jaja', Offset(86, 12 + sin(t * 14) * 0.8), 11, _pinkDeep);
      case Mood.thinking:
        for (var i = 0; i < 3; i++) {
          final on = ((t * 2.5).floor() % 4) > i;
          c.drawCircle(Offset(78 + i * 7.0, 12), 2.6, Paint()..color = on ? _ink : _ink.withValues(alpha: 0.2));
        }
      case Mood.cheeky:
        _star(c, Offset(88, 16 + sin(t * 4) * 1), 3.4, _pinkDeep);
      case Mood.eating:
        _page(c);
      case Mood.neutral || Mood.happy || Mood.ashamed || Mood.crying || Mood.waking:
        break;
    }
  }

  /// Una hojita (el PDF, el link…) que vuela hacia su boca y desaparece.
  void _page(Canvas c) {
    final f = (t * 0.7) % 1;
    final p = Offset.lerp(const Offset(86, 58), const Offset(56, 66), Curves.easeIn.transform(f))!;
    final alpha = f < 0.8 ? 1.0 : (1 - f) / 0.2;
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(-0.35 + f * 0.5);
    c.scale(1 - f * 0.55);
    const rect = Rect.fromLTWH(-6, -7.5, 12, 15);
    c.drawRect(rect.shift(const Offset(2, 2)), Paint()..color = _ink.withValues(alpha: alpha));
    c.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: alpha));
    c.drawRect(rect, _stroke(1.6, _ink.withValues(alpha: alpha)));
    for (var i = 0; i < 3; i++) {
      final y = -3.5 + i * 3.5;
      c.drawLine(Offset(-3.5, y), Offset(i == 2 ? 1 : 3.5, y), _stroke(1.1, _lilac.withValues(alpha: alpha)));
    }
    c.restore();
    // Migajas al morder.
    if (f > 0.75) {
      final g = (f - 0.75) / 0.25;
      for (final (dx, dy) in [(-1.0, 0.6), (1.0, 1.0), (0.3, 1.4)]) {
        c.drawRect(Rect.fromCenter(center: Offset(52 + dx * 9 * g, 70 + dy * 8 * g), width: 2, height: 2),
            Paint()..color = _ink.withValues(alpha: 1 - g));
      }
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
    c.translate(88, 78);
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
  bool shouldRepaint(covariant CircleFacePainter old) => true;
}
