// «No abrir Laika al iniciar sesión» (Ajustes → Cerrar Laika), para los viajes.
//
// La mascota arranca sola por ~/.config/autostart/laika-pet.desktop (lo crea
// tool/install_linux.sh --autostart). Apagarlo le agrega `Hidden=true`, como
// hace Plasma en Preferencias → Inicio automático, y systemd ya no crea el
// servicio al iniciar sesión (comprobado con su generador). Prenderlo quita esa
// línea. El instalador la conserva al reinstalar.

import 'dart:io';

class Autostart {
  /// [path] solo cambia en las pruebas.
  Autostart([String? path]) : path = path ?? _defaultPath();
  final String path;

  static String _defaultPath() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    final base = xdg != null && xdg.isNotEmpty ? xdg : '${Platform.environment['HOME'] ?? ''}/.config';
    return '$base/autostart/laika-pet.desktop';
  }

  static bool _isHidden(String line) {
    final i = line.indexOf('=');
    return i > 0 && line.substring(0, i).trim() == 'Hidden';
  }

  /// ¿La mascota se abre al iniciar sesión?
  bool get enabled {
    final f = File(path);
    if (!f.existsSync()) return false;
    return !f.readAsLinesSync().any((l) => _isHidden(l) && l.split('=').last.trim() == 'true');
  }

  Future<void> setEnabled(bool on) async {
    final f = File(path);
    final List<String> lines;
    if (f.existsSync()) {
      lines = (await f.readAsLines()).where((l) => !_isHidden(l)).toList();
    } else {
      if (!on) return; // sin archivo ya no se abre
      lines = entryFor(Platform.resolvedExecutable);
      await f.parent.create(recursive: true);
    }
    if (!on) {
      final i = lines.indexWhere((l) => l.trim() == '[Desktop Entry]');
      if (i < 0) {
        lines.insertAll(0, ['[Desktop Entry]', 'Hidden=true']);
      } else {
        lines.insert(i + 1, 'Hidden=true');
      }
    }
    final tmp = File('$path.tmp');
    await tmp.writeAsString('${lines.join('\n')}\n');
    await tmp.rename(path);
  }

  /// La misma entrada que escribe tool/install_linux.sh.
  static List<String> entryFor(String exe) => [
        '[Desktop Entry]',
        'Type=Application',
        'Name=Laika (mascota)',
        'Comment=Laika sobre tu escritorio',
        'Exec=${exe.contains(' ') ? '"$exe"' : exe} --pet',
        'Icon=face-smile',
        'Terminal=false',
        'Categories=Education;',
        'StartupWMClass=io.github.estebansantiag0.laika_app',
      ];
}
