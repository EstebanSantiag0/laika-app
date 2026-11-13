// Cerrar Laika del todo (Ajustes → Cerrar Laika): la mascota del escritorio
// y la app. Pensado para cuando Esteban viaja.
//
// La mascota corre aparte (`laika_app --pet`, normalmente el servicio de
// inicio de sesión, con Restart=no), así que la app la busca en /proc y le
// manda SIGTERM. Vuelve al iniciar sesión o con «Laika (mascota)» del menú.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';

/// Los procesos `laika_app --pet` que hay corriendo, menos este.
/// [proc] solo cambia en las pruebas.
List<int> petPids({String proc = '/proc'}) {
  final found = <int>[];
  final List<FileSystemEntity> dirs;
  try {
    dirs = Directory(proc).listSync(followLinks: false);
  } on FileSystemException {
    return found;
  }
  for (final d in dirs) {
    final id = int.tryParse(d.path.split('/').last);
    if (id == null || id == pid) continue;
    try {
      final args = utf8.decode(File('${d.path}/cmdline').readAsBytesSync(), allowMalformed: true).split('\x00');
      if (args.first.split('/').last == 'laika_app' && args.contains('--pet')) found.add(id);
    } on FileSystemException {
      // Ya terminó, o no se puede leer: no es nuestra.
    }
  }
  return found;
}

/// Cierra las mascotas y luego esta ventana.
Future<void> quitLaika() async {
  for (final p in petPids()) {
    Process.killPid(p); // SIGTERM; si falla (no es nuestra), no pasa nada
  }
  await ServicesBinding.instance.exitApplication(AppExitType.required);
}
