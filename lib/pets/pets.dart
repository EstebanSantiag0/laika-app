// Las 3 mascotas originales de Laika, estilo "gótico-kawaii":
// perrita de cara blanca, capucha negra con orejas caídas, una lunita rosa
// en la frente (por la Laika del espacio) y colores de la paleta Cristal.
// Diseño propio: no copia a ningún personaje existente.
//
//  • cabeza  — solo la cabeza: cabecea al dormirse y luego se ladea.
//  • chibi   — cuerpo completo sentada: duerme sentada y luego se acuesta.
//  • cachorro — perrita en cuatro patas: se sienta a dormir y luego se hace bolita.

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pet.dart';

enum PetKind {
  head('Cabeza', 'Solo la cabeza'),
  chibi('Chibi', 'Cuerpo completo, sentada'),
  puppy('Cachorro', 'Cuerpo completo, en cuatro patas');

  const PetKind(this.label, this.description);
  final String label;
  final String description;
}

const kInk = Color(0xFF2B2440); // casi negro, morado
const kHood = Color(0xFF1F1A2E);
const kFace = Colors.white;
const kLavender = Color(0xFFC4B5FD);
const kPink = Color(0xFFF9A8D4);
const kMint = Color(0xFFA7F3D0);

/// Qué tan dormida está: 0 despierta, 1 dormida sentada, 2 acostada.
int sleepLevel(PetController c) => c.state != PetState.asleep ? 0 : (c.sleepPose == SleepPose.seated ? 1 : 2);

class GothPetPainter extends CustomPainter {
  GothPetPainter({required this.kind, required this.state, required this.pose, required this.t, required this.bell});

  final PetKind kind;
  final PetState state;
  final SleepPose pose;
  final double t;
  final bool bell;

  bool get asleep => state == PetState.asleep;
  bool get lying => asleep && pose == SleepPose.lying;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case PetKind.head:
        _paintHeadOnly(canvas, size);
      case PetKind.chibi:
        _paintChibi(canvas, size);
      case PetKind.puppy:
        _paintPuppy(canvas, size);
    }
    if (asleep) _zzz(canvas, size);
    if (state == PetState.thinking) _thinking(canvas, size);
    if (bell) _bell(canvas, size);
  }

  // ── Cabeza (compartida por las tres) ──────────────────────────────────────

  /// Dibuja la cabeza centrada en [c] con radio [r]. [tilt] en radianes.
  void head(Canvas canvas, Offset c, double r, {double tilt = 0, double earSwing = 0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);

    // Orejas caídas (largas, de perrita), detrás de la cara.
    for (final s in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(s * r * 0.78, -r * 0.42);
      canvas.rotate(s * (0.18 + earSwing) + (asleep ? s * 0.12 : 0));
      final ear = Path()
        ..moveTo(-r * 0.2, 0)
        ..cubicTo(-r * 0.32, r * 0.55, -r * 0.2, r * 1.15, r * 0.02, r * 1.2)
        ..cubicTo(r * 0.24, r * 1.15, r * 0.3, r * 0.5, r * 0.2, 0)
        ..close();
      canvas.drawPath(ear, Paint()..color = kHood);
      final inner = Path()
        ..moveTo(-r * 0.08, r * 0.15)
        ..cubicTo(-r * 0.16, r * 0.55, -r * 0.08, r * 0.95, r * 0.02, r * 0.98)
        ..cubicTo(r * 0.12, r * 0.95, r * 0.14, r * 0.5, r * 0.08, r * 0.15)
        ..close();
      canvas.drawPath(inner, Paint()..color = kLavender.withValues(alpha: 0.85));
      canvas.restore();
    }

    // Capucha.
    final hood = Path()
      ..addOval(Rect.fromCenter(center: Offset(0, -r * 0.08), width: r * 2.08, height: r * 1.95));
    canvas.drawPath(hood, Paint()..color = kHood);
    // Cara.
    final face = Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 1.62, height: r * 1.42);
    canvas.drawOval(face, Paint()..color = kFace);
    // Borde de la capucha sobre la frente.
    final brim = Path()
      ..moveTo(-r * 0.86, -r * 0.05)
      ..quadraticBezierTo(0, -r * 0.62, r * 0.86, -r * 0.05)
      ..quadraticBezierTo(0, -r * 0.82, -r * 0.86, -r * 0.05)
      ..close();
    canvas.drawPath(brim, Paint()..color = kHood);

    // Lunita en la frente de la capucha.
    final mc = Offset(0, -r * 0.62);
    canvas.drawCircle(mc, r * 0.16, Paint()..color = kPink);
    canvas.drawCircle(mc + Offset(r * 0.07, -r * 0.04), r * 0.14, Paint()..color = kHood);
    _star(canvas, mc + Offset(r * 0.2, -r * 0.1), r * 0.05, kPink);

    // Ojos.
    final level = asleep ? 1 : 0;
    final blink = !asleep && (t % 4.0) > 3.86;
    for (final s in [-1.0, 1.0]) {
      final e = Offset(s * r * 0.36, r * 0.1);
      if (level > 0 || blink) {
        canvas.drawArc(
          Rect.fromCenter(center: e, width: r * 0.32, height: r * 0.2),
          0.15,
          pi - 0.3,
          false,
          Paint()
            ..color = kInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.6, r * 0.06)
            ..strokeCap = StrokeCap.round,
        );
      } else if (state == PetState.waking) {
        canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.26, height: r * 0.12), Paint()..color = kInk);
      } else {
        final look = state == PetState.thinking ? Offset(r * 0.05, -r * 0.07) : Offset.zero;
        canvas.drawOval(Rect.fromCenter(center: e + look, width: r * 0.26, height: r * 0.34), Paint()..color = kInk);
        canvas.drawCircle(e + look + Offset(-r * 0.05, -r * 0.08), r * 0.06, Paint()..color = Colors.white);
        canvas.drawCircle(e + look + Offset(r * 0.05, r * 0.06), r * 0.03, Paint()..color = kLavender);
      }
      // Mejillas.
      canvas.drawOval(Rect.fromCenter(center: Offset(s * r * 0.56, r * 0.36), width: r * 0.24, height: r * 0.12),
          Paint()..color = kPink.withValues(alpha: 0.6));
    }
    // Nariz y boca con colmillito.
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.32), width: r * 0.16, height: r * 0.1), Paint()..color = kInk);
    final mouth = Paint()
      ..color = kInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.3, r * 0.045)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(-r * 0.07, r * 0.42), width: r * 0.14, height: r * 0.12), 0, pi, false, mouth);
    canvas.drawArc(Rect.fromCenter(center: Offset(r * 0.07, r * 0.42), width: r * 0.14, height: r * 0.12), 0, pi, false, mouth);
    if (!asleep) {
      final fang = Path()
        ..moveTo(r * 0.09, r * 0.47)
        ..lineTo(r * 0.13, r * 0.47)
        ..lineTo(r * 0.11, r * 0.53)
        ..close();
      canvas.drawPath(fang, Paint()..color = Colors.white);
      canvas.drawPath(fang, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = kInk);
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final o = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  // ── 1. Solo cabeza ────────────────────────────────────────────────────────

  void _paintHeadOnly(Canvas canvas, Size size) {
    final r = size.width * 0.3;
    var c = size.center(Offset.zero) + Offset(0, r * 0.05);
    double tilt = 0;
    if (!asleep) {
      c += Offset(0, sin(t * 2.4) * r * 0.04);
      tilt = sin(t * 0.9) * 0.05;
    } else if (!lying) {
      // Cabeceando.
      c += Offset(0, r * 0.06 + max(0, sin(t * 1.3)) * r * 0.08);
      tilt = sin(t * 1.3) * 0.04;
    } else {
      // Ladeada y más abajo.
      c += Offset(-r * 0.05, r * 0.22);
      tilt = -0.42 + sin(t * 1.1) * 0.02;
    }
    _shadow(canvas, Offset(size.width / 2, size.height * 0.9), r * 1.2);
    head(canvas, c, r, tilt: tilt, earSwing: asleep ? 0 : sin(t * 2.4) * 0.05);
  }

  // ── 2. Chibi sentada ──────────────────────────────────────────────────────

  void _paintChibi(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.2; // radio de la cabeza
    final ground = size.height * 0.9;
    _shadow(canvas, Offset(w / 2, ground), lying ? r * 2.2 : r * 1.4);

    if (lying) {
      // Acostada: cuerpo horizontal, cabeza sobre las patitas, cola enroscada.
      final breath = sin(t * 1.4) * r * 0.03;
      final body = Rect.fromCenter(center: Offset(w * 0.56, ground - r * 0.55 - breath / 2), width: r * 2.6, height: r * 1.1 + breath);
      _tail(canvas, Offset(body.right - r * 0.15, body.center.dy), r, curled: true);
      canvas.drawOval(body, Paint()..color = kHood);
      canvas.drawOval(Rect.fromCenter(center: body.center + Offset(-r * 0.1, r * 0.2), width: r * 1.6, height: r * 0.55),
          Paint()..color = kLavender.withValues(alpha: 0.9));
      for (final dx in [-0.25, 0.15]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.24 + dx * r, ground - r * 0.16), width: r * 0.7, height: r * 0.34),
            Paint()..color = kFace);
      }
      head(canvas, Offset(w * 0.3, ground - r * 0.72), r * 0.95, tilt: -0.28);
      return;
    }

    final nod = asleep ? max(0.0, sin(t * 1.3)) * r * 0.1 : 0.0;
    final bounce = asleep ? 0.0 : max(0.0, sin(t * 3)) * r * 0.08;
    final bodyC = Offset(w / 2, ground - r * 0.95 - bounce);
    _tail(canvas, bodyC + Offset(r * 0.8, r * 0.4), r, wag: asleep ? 0 : sin(t * 7) * 0.35);
    // Cuerpo (sudadera negra) y pancita lavanda.
    canvas.drawOval(Rect.fromCenter(center: bodyC, width: r * 1.8, height: r * 1.9), Paint()..color = kHood);
    canvas.drawOval(Rect.fromCenter(center: bodyC + Offset(0, r * 0.15), width: r * 1.0, height: r * 1.1),
        Paint()..color = kLavender.withValues(alpha: 0.9));
    // Patitas traseras y delanteras.
    for (final s in [-1.0, 1.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(w / 2 + s * r * 0.62, ground - r * 0.2), width: r * 0.75, height: r * 0.42),
          Paint()..color = kFace);
      canvas.drawOval(Rect.fromCenter(center: Offset(w / 2 + s * r * 0.26, ground - r * 0.3 - bounce), width: r * 0.42, height: r * 0.5),
          Paint()..color = kFace);
    }
    head(canvas, bodyC + Offset(0, -r * 1.25 + nod), r, tilt: asleep ? sin(t * 1.3) * 0.05 : sin(t * 0.9) * 0.05);
  }

  // ── 3. Cachorro en cuatro patas ───────────────────────────────────────────

  void _paintPuppy(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.17;
    final ground = size.height * 0.9;
    _shadow(canvas, Offset(w / 2, ground), r * 2.3);
    final legPaint = Paint()..color = kHood;
    final paw = Paint()..color = kFace;

    if (lying) {
      // Bolita: cuerpo redondo, cola alrededor, cabeza recargada.
      final breath = sin(t * 1.4) * r * 0.04;
      final body = Rect.fromCenter(center: Offset(w * 0.55, ground - r * 0.7), width: r * 3.0, height: r * 1.4 + breath);
      canvas.drawOval(body, Paint()..color = kHood);
      _tail(canvas, Offset(body.right - r * 0.3, body.bottom - r * 0.3), r, curled: true);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.3, ground - r * 0.15), width: r * 1.1, height: r * 0.35), paw);
      head(canvas, Offset(w * 0.32, ground - r * 0.8), r * 1.05, tilt: -0.35);
      return;
    }

    if (asleep) {
      // Sentada, cabeceando: patas delanteras rectas, trasera doblada.
      final bodyC = Offset(w * 0.55, ground - r * 1.25);
      _tail(canvas, Offset(bodyC.dx + r * 0.9, ground - r * 0.25), r, curled: true);
      canvas.save();
      canvas.translate(bodyC.dx, bodyC.dy);
      canvas.rotate(-0.55);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.5, height: r * 1.4), Paint()..color = kHood);
      canvas.restore();
      canvas.drawOval(Rect.fromCenter(center: Offset(bodyC.dx + r * 0.55, ground - r * 0.45), width: r * 1.3, height: r * 0.9), legPaint);
      for (final dx in [-0.55, -0.2]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(bodyC.dx + dx * r - r * 0.17, bodyC.dy, r * 0.34, ground - bodyC.dy), Radius.circular(r * 0.17)),
            legPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(bodyC.dx + dx * r, ground - r * 0.06), width: r * 0.48, height: r * 0.26), paw);
      }
      final nod = max(0.0, sin(t * 1.3)) * r * 0.12;
      head(canvas, Offset(bodyC.dx - r * 0.5, bodyC.dy - r * 1.1 + nod), r, tilt: sin(t * 1.3) * 0.05);
      return;
    }

    // De pie, despierta: camina en su lugar y mueve la cola.
    final step = sin(t * 6);
    final bodyC = Offset(w * 0.55, ground - r * 1.15 - step.abs() * r * 0.05);
    _tail(canvas, bodyC + Offset(r * 1.35, -r * 0.3), r, wag: sin(t * 8) * 0.45, up: true);
    final legs = [(-0.9, step), (-0.45, -step), (0.6, -step), (1.0, step)];
    for (final (dx, ph) in legs) {
      final x = bodyC.dx + dx * r;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - r * 0.16 + ph * r * 0.06, bodyC.dy, r * 0.32, ground - bodyC.dy - r * 0.05),
              Radius.circular(r * 0.16)),
          legPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + ph * r * 0.06, ground - r * 0.06), width: r * 0.46, height: r * 0.24), paw);
    }
    canvas.drawOval(Rect.fromCenter(center: bodyC, width: r * 3.0, height: r * 1.35), Paint()..color = kHood);
    canvas.drawOval(Rect.fromCenter(center: bodyC + Offset(-r * 0.6, r * 0.2), width: r * 1.2, height: r * 0.7),
        Paint()..color = kLavender.withValues(alpha: 0.9));
    head(canvas, Offset(bodyC.dx - r * 1.2, bodyC.dy - r * 0.95), r, tilt: sin(t * 0.9) * 0.06, earSwing: step * 0.04);
  }

  // ── Detalles ──────────────────────────────────────────────────────────────

  void _tail(Canvas canvas, Offset base, double r, {double wag = 0, bool curled = false, bool up = false}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(wag + (up ? -0.6 : 0));
    final p = Path()..moveTo(0, 0);
    if (curled) {
      p.cubicTo(r * 0.7, r * 0.1, r * 0.8, -r * 0.6, r * 0.25, -r * 0.55);
    } else {
      p.cubicTo(r * 0.5, -r * 0.1, r * 0.75, -r * 0.6, r * 0.6, -r * 1.0);
    }
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round
      ..color = kHood);
    final tip = curled ? Offset(r * 0.25, -r * 0.55) : Offset(r * 0.6, -r * 1.0);
    _star(canvas, tip, r * 0.22, kPink);
    canvas.restore();
  }

  void _shadow(Canvas canvas, Offset c, double w) {
    canvas.drawOval(Rect.fromCenter(center: c, width: w, height: w * 0.16), Paint()..color = kInk.withValues(alpha: 0.12));
  }

  void _zzz(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final ph = (t * 0.45 + i / 3) % 1;
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontFamily: 'Hack',
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B7CF6).withValues(alpha: 1 - ph),
            fontSize: 11 + ph * 9 + (lying ? 3 : 0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * 0.72 + ph * 16, size.height * (lying ? 0.45 : 0.22) - ph * 34));
    }
  }

  void _thinking(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final ph = (t * 0.9 + i / 3) % 1;
      canvas.drawCircle(Offset(size.width * 0.78 + i * 5, size.height * 0.18 - ph * 16), 3.2 - i * 0.6,
          Paint()..color = const Color(0xFF8B7CF6).withValues(alpha: 1 - ph));
    }
  }

  void _bell(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.16, size.height * 0.16);
    canvas.drawCircle(c, 13, Paint()..color = kPink.withValues(alpha: 0.35));
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFFEC4899));
  }

  @override
  bool shouldRepaint(covariant GothPetPainter old) => true;
}
