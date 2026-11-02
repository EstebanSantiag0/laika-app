// Grabar notas de voz, sacar capturas y elegir archivos desde la mascota.
//
// En Linux usa lo que ya trae el escritorio: `pw-record` (PipeWire) para el
// micrófono, `ffmpeg` para pasarlo a Opus (9× más chico; si no está, se manda
// WAV) y `spectacle -r` (KDE) para que elijas un rectángulo de la pantalla.
// En otras plataformas [Media.supported] es false y la caja lo dice.

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

class Media {
  const Media();

  bool get supported => Platform.isLinux;

  VoiceRecorder recorder() => VoiceRecorder();

  static Directory _tmp() => Directory.systemTemp.createTempSync('laika_');

  /// Abre el selector de archivos. null = cancelaste.
  Future<String?> pickFile() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(
          label: 'Documentos e imágenes',
          extensions: ['pdf', 'epub', 'fb2', 'docx', 'txt', 'md', 'html', 'png', 'jpg', 'jpeg', 'webp']),
    ]);
    return f?.path;
  }

  /// Captura de un rectángulo que eliges con el mouse (Spectacle). null = la cancelaste.
  Future<String?> screenshotRegion() async {
    final out = '${_tmp().path}/captura-${_stamp()}.png';
    try {
      final r = await Process.run('spectacle', ['-b', '-n', '-r', '-o', out]);
      if (r.exitCode != 0) return null;
    } on ProcessException {
      throw const MediaError('Para capturas hace falta Spectacle (KDE).');
    }
    final f = File(out);
    return f.existsSync() && f.lengthSync() > 0 ? out : null;
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}

/// Graba el micrófono hasta que llames a [stop] (o [cancel]).
class VoiceRecorder {
  Process? _p;
  String? _wav;

  bool get active => _p != null;

  Future<void> start() async {
    if (_p != null) return;
    _wav = '${Media._tmp().path}/voz.wav';
    try {
      _p = await Process.start('pw-record', ['--rate', '16000', '--channels', '1', _wav!]);
    } on ProcessException {
      _p = null;
      throw const MediaError('Para grabar hace falta pw-record (PipeWire).');
    }
    // Si pw-record termina solo (sin micrófono), se nota al parar: no habrá archivo.
    _p!.stdout.drain<void>();
    _p!.stderr.drain<void>();
  }

  /// Termina la grabación y devuelve el archivo listo para mandar (.ogg o .wav).
  /// null si no se grabó nada.
  Future<String?> stop() async {
    final p = _p, wav = _wav;
    _p = null;
    if (p == null || wav == null) return null;
    p.kill(ProcessSignal.sigint); // así pw-record cierra bien el WAV
    await p.exitCode.timeout(const Duration(seconds: 3), onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -1;
    });
    final f = File(wav);
    if (!f.existsSync() || f.lengthSync() < 3200) return null; // < 0.1 s
    final ogg = wav.replaceAll(RegExp(r'\.wav$'), '.ogg');
    try {
      final r = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libopus', '-b:a', '24k', ogg]);
      if (r.exitCode == 0 && File(ogg).existsSync()) {
        f.deleteSync();
        return ogg;
      }
    } on ProcessException {
      // Sin ffmpeg: se manda el WAV (el servidor también lo entiende).
    }
    return wav;
  }

  Future<void> cancel() async {
    final p = _p, wav = _wav;
    _p = null;
    if (p == null) return;
    p.kill(ProcessSignal.sigint);
    await p.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1);
    if (wav != null && File(wav).existsSync()) File(wav).deleteSync();
  }
}

class MediaError implements Exception {
  const MediaError(this.message);
  final String message;
  @override
  String toString() => message;
}
