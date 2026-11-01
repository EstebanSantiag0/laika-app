// Configuración local de Laika: ~/.config/laika/config.json
//
//   {
//     "server":  "https://tu-servidor.tu-tailnet.ts.net",   // sin esto: servidor simulado
//     "skin":    "circulo",                                 // o el nombre de una carpeta de skins
//     "petSize": 150                                        // tamaño de Laika en el escritorio (px)
//   }
//
// Este archivo NO va en el repositorio (tiene la dirección de tu servidor).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class LaikaConfig {
  const LaikaConfig({this.server, this.skin = defaultSkin, this.petSize = 150});

  static const defaultSkin = 'circulo';

  final String? server;
  final String skin;
  final double petSize;

  LaikaConfig copyWith({String? server, bool clearServer = false, String? skin, double? petSize}) => LaikaConfig(
        server: clearServer ? null : (server ?? this.server),
        skin: skin ?? this.skin,
        petSize: petSize ?? this.petSize,
      );

  factory LaikaConfig.fromJson(Map<String, dynamic> j) {
    final server = j['server'];
    final skin = j['skin'];
    final size = j['petSize'];
    return LaikaConfig(
      server: server is String && server.trim().isNotEmpty ? server.trim() : null,
      skin: skin is String && skin.isNotEmpty ? skin : defaultSkin,
      petSize: size is num ? size.toDouble().clamp(80, 400) : 150,
    );
  }

  Map<String, dynamic> toJson() => {
        if (server != null) 'server': server,
        'skin': skin,
        'petSize': petSize,
      };

  @override
  bool operator ==(Object other) =>
      other is LaikaConfig && other.server == server && other.skin == skin && other.petSize == petSize;

  @override
  int get hashCode => Object.hash(server, skin, petSize);

  // ── Archivo ──────────────────────────────────────────────────────────────

  /// ~/.config/laika (o $XDG_CONFIG_HOME/laika).
  static String? dir() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) return '$xdg/laika';
    final home = Platform.environment['HOME'];
    return home == null ? null : '$home/.config/laika';
  }

  static File? _file() {
    final d = dir();
    return d == null ? null : File('$d/config.json');
  }

  static LaikaConfig load() {
    final f = _file();
    if (f == null || !f.existsSync()) return const LaikaConfig();
    try {
      final j = jsonDecode(f.readAsStringSync());
      return j is Map<String, dynamic> ? LaikaConfig.fromJson(j) : const LaikaConfig();
    } catch (_) {
      return const LaikaConfig();
    }
  }

  /// Guarda sin perder claves que esta versión no conozca.
  Future<void> save() async {
    final f = _file();
    if (f == null) return;
    Map<String, dynamic> old = {};
    try {
      if (f.existsSync()) old = (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
    } catch (_) {}
    old
      ..remove('server')
      ..addAll(toJson());
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(old));
    await tmp.rename(f.path);
  }
}

/// La configuración actual, compartida por toda la app. [watchConfig] la
/// mantiene al día si otro proceso (la app abierta con --app) la cambia.
final config = ValueNotifier<LaikaConfig>(LaikaConfig.load());

/// Vigila ~/.config/laika con inotify (sin sondeo) y recarga al cambiar.
StreamSubscription<FileSystemEvent>? watchConfig() {
  final d = LaikaConfig.dir();
  if (d == null) return null;
  try {
    Directory(d).createSync(recursive: true);
    return Directory(d).watch().listen((e) {
      if (!e.path.endsWith('config.json')) return;
      final next = LaikaConfig.load();
      if (next != config.value) config.value = next;
    });
  } catch (_) {
    return null;
  }
}

/// Guarda y avisa a toda la app.
Future<void> updateConfig(LaikaConfig next) async {
  config.value = next;
  await next.save();
}
