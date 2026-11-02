// Corre antes de cada archivo de pruebas: los ajustes van a una carpeta
// temporal, así ninguna prueba cambia ~/.config/laika/config.json de Esteban.
import 'dart:async';
import 'dart:io';

import 'package:laika_app/core/config.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LaikaConfig.dirForTests = Directory.systemTemp.createTempSync('laika_test_config_').path;
  await testMain();
}
