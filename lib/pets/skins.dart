// Apariencias ("skins") de Laika.
//
//  • "circulo" (por defecto): la cara-círculo dibujada con código.
//  • Skins de imágenes: una carpeta con una imagen por emoción. Se buscan en
//      ~/.config/laika/skins/<nombre>/
//      ./skins/<nombre>/          (junto al proyecto; esta carpeta no se sube a git)
//    Formato completo: docs/SKINS.md.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/pet.dart';
import 'circle_face.dart';

/// Nombre de archivo (sin extensión) para cada emoción.
String moodFileName(Mood m, {bool lying = false}) => m == Mood.sleeping && lying ? 'sleepingLying' : m.name;

/// Si falta una imagen, qué otras probar (en orden).
const _fallbacks = <String, List<String>>{
  'thinking': ['doubting'],
  'waking': ['sleeping', 'sleepingLying'],
  'sleeping': ['sleepingLying'],
  'sleepingLying': ['sleeping'],
  'greeting': ['happy'],
  'laughing': ['happy'],
  'impressed': ['surprised'],
  'surprised': ['impressed'],
  'scheming': ['cheeky'],
  'eating': ['happy'],
  'cheeky': ['happy'],
  'crying': ['ashamed'],
  'ashamed': ['crying'],
};

const _exts = ['png', 'webp', 'gif', 'jpg', 'jpeg'];

abstract class PetSkinLook {
  String get id;
  String get name;

  /// Dibuja a Laika con esa emoción. [t] = segundos (para animar).
  Widget build(Mood mood, {bool lying = false, required double t, bool bell = false});
}

class CircleLook implements PetSkinLook {
  const CircleLook();
  @override
  String get id => LaikaConfig.defaultSkin;
  @override
  String get name => 'Círculo';
  @override
  Widget build(Mood mood, {bool lying = false, required double t, bool bell = false}) =>
      CustomPaint(painter: CircleFacePainter(mood: mood, lying: lying, t: t, bell: bell));
}

/// Skin hecha de imágenes en una carpeta.
class ImageLook implements PetSkinLook {
  ImageLook._(this.id, this.name, this.dir, this.files);

  @override
  final String id;
  @override
  final String name;
  final Directory dir;

  /// emoción → archivo.
  final Map<String, File> files;

  /// Lee la carpeta. null si no hay ninguna imagen usable.
  static ImageLook? fromDir(Directory dir) {
    final id = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    var name = id;
    final files = <String, File>{};
    // 1) skin.json opcional: {"name": "...", "moods": {"happy": "feliz.png"}}
    final manifest = File('${dir.path}/skin.json');
    if (manifest.existsSync()) {
      try {
        final j = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
        if (j['name'] is String) name = j['name'] as String;
        final moods = j['moods'];
        if (moods is Map) {
          for (final e in moods.entries) {
            final f = File('${dir.path}/${e.value}');
            if (f.existsSync()) files['${e.key}'] = f;
          }
        }
      } catch (_) {}
    }
    // 2) archivos con el nombre de la emoción: happy.png, sleepingLying.webp…
    final keys = {...Mood.values.map((m) => m.name), 'sleepingLying'};
    for (final k in keys) {
      if (files.containsKey(k)) continue;
      for (final ext in _exts) {
        final f = File('${dir.path}/$k.$ext');
        if (f.existsSync()) {
          files[k] = f;
          break;
        }
      }
    }
    return files.isEmpty ? null : ImageLook._(id, name, dir, files);
  }

  File? fileFor(Mood mood, {bool lying = false}) {
    final key = moodFileName(mood, lying: lying);
    for (final k in [key, ...?_fallbacks[key], 'neutral']) {
      final f = files[k];
      if (f != null) return f;
    }
    return files.values.first;
  }

  @override
  Widget build(Mood mood, {bool lying = false, required double t, bool bell = false}) {
    final f = fileFor(mood, lying: lying);
    // Movimiento suave para que no se vea como una foto fija.
    final dy = switch (mood) {
      Mood.happy || Mood.greeting || Mood.laughing => -sin(t * 7).abs() * 4,
      Mood.sleeping => sin(t * 1.4) * 1.5,
      Mood.eating => (sin(t * 11) + 1) * 0.9,
      _ => sin(t * 2.2) * 1.2,
    };
    final dx = mood == Mood.crying ? sin(t * 18) * 1.5 : 0.0;
    return Stack(fit: StackFit.expand, children: [
      Transform.translate(
        offset: Offset(dx, dy),
        child: f == null
            ? const SizedBox.shrink()
            : Image.file(f, fit: BoxFit.contain, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
      CustomPaint(painter: _OverlayPainter(mood: mood, t: t, bell: bell)),
    ]);
  }
}

/// Encima de las skins de imágenes: solo "zzz", "…" y la campanita.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.mood, required this.t, required this.bell});
  final Mood mood;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    const ink = Color(0xFF231B2E);
    if (mood == Mood.thinking) {
      for (var i = 0; i < 3; i++) {
        final on = ((t * 2.5).floor() % 4) > i;
        canvas.drawCircle(Offset(80 + i * 7.0, 8), 2.6, Paint()..color = on ? ink : ink.withValues(alpha: 0.2));
      }
    }
    if (mood == Mood.sleeping) {
      for (var i = 0; i < 3; i++) {
        final f = (t * 0.35 + i / 3) % 1;
        final tp = TextPainter(
          text: TextSpan(
              text: 'z',
              style: TextStyle(
                  fontFamily: 'Adwaita Sans',
                  fontSize: 8 + f * 7,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFB9A3F0).withValues(alpha: 1 - f))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(84 + f * 5, 18 - f * 20));
      }
    }
    if (bell) {
      canvas.drawCircle(const Offset(90, 88), 6, Paint()..color = const Color(0xFFFFD66B));
      canvas.drawCircle(const Offset(90, 88), 6, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => true;
}

/// Carpetas donde se buscan skins.
List<Directory> skinDirs() => [
      if (LaikaConfig.dir() != null) Directory('${LaikaConfig.dir()}/skins'),
      Directory('${Directory.current.path}/skins'),
    ];

/// Todas las apariencias disponibles (la de círculo siempre va primero).
List<PetSkinLook> availableSkins() {
  final out = <PetSkinLook>[const CircleLook()];
  final seen = <String>{LaikaConfig.defaultSkin};
  for (final d in skinDirs()) {
    if (!d.existsSync()) continue;
    final subs = d.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final sub in subs) {
      final look = ImageLook.fromDir(sub);
      if (look != null && seen.add(look.id)) out.add(look);
    }
  }
  return out;
}

/// La apariencia que pide la configuración (o el círculo si no existe).
PetSkinLook skinFor(String id) {
  if (id == LaikaConfig.defaultSkin) return const CircleLook();
  for (final s in availableSkins()) {
    if (s.id == id) return s;
  }
  return const CircleLook();
}

/// La apariencia en uso; sigue a `config.skin` (también si cambia desde otra ventana).
final currentLook = () {
  final n = ValueNotifier<PetSkinLook>(skinFor(config.value.skin));
  config.addListener(() {
    if (n.value.id != config.value.skin) n.value = skinFor(config.value.skin);
  });
  return n;
}();
