// Cliente real del servidor de Laika: HTTPS + WebSocket a través de Tailscale.
//
// La autenticación la pone `tailscale serve` (cabecera tailscale-user-login),
// así que aquí no hay contraseñas ni tokens. Protocolo: docs/API.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'api.dart';
import 'config.dart';
import 'models.dart';

class HttpLaika implements LaikaApi {
  HttpLaika(String baseUrl) : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);

  final Uri base;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  final _events = StreamController<LaikaEvent>.broadcast();
  WebSocket? _ws;
  Future<WebSocket>? _connecting;
  Completer<void>? _turn; // se completa con typing_stop / error
  bool _disposed = false;
  final _rng = Random();

  @override
  Stream<LaikaEvent> get events => _events.stream;

  // ── HTTP ──────────────────────────────────────────────────────────────────

  Future<Object?> _request(String method, String path, {Map<String, String>? query, Object? body}) async {
    try {
      final uri = base.replace(path: '${base.path}$path', queryParameters: query);
      final req = await _http.openUrl(method, uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == 403) throw const LaikaOffline('El servidor rechazó la conexión (¿estás en Tailscale?)');
      if (res.statusCode >= 400) throw LaikaOffline('Error ${res.statusCode} del servidor');
      return text.isEmpty ? null : jsonDecode(text);
    } on LaikaOffline {
      rethrow;
    } catch (e) {
      throw LaikaOffline('El servidor de Laika no responde ($e)');
    }
  }

  @override
  Future<Health> health() async {
    final h = Health.fromJson((await _request('GET', '/health')) as Map<String, dynamic>);
    // Despertó: abre el chat en vivo (mensajes y recordatorios) mientras la app siga abierta.
    if (h.canWake) _socket().ignore();
    return h;
  }

  @override
  Future<MemoryGraph> graph({bool all = true}) async =>
      MemoryGraph.fromJson((await _request('GET', '/api/graph', query: {'scope': all ? 'all' : 'active'})) as Map<String, dynamic>);

  @override
  Future<List<Reminder>> reminders({bool all = true}) async {
    final j = await _request('GET', '/api/reminders', query: {'status': all ? 'all' : 'pending'});
    return (j as List).map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markDone(int id) => _request('POST', '/api/reminders/$id/done');

  @override
  Future<void> snooze(int id, {int minutes = 60}) => _request('POST', '/api/reminders/$id/snooze', body: {'minutes': minutes});

  // ── WebSocket ─────────────────────────────────────────────────────────────

  Future<WebSocket> _socket() {
    if (_disposed) return Future.error(const LaikaOffline());
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) return Future.value(ws);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<WebSocket> _connect() async {
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final uri = base.replace(scheme: scheme, path: '${base.path}/ws');
    try {
      final ws = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 8));
      ws.pingInterval = const Duration(seconds: 25);
      _ws = ws;
      ws.listen(_onFrame, onDone: _onClosed, onError: (_) => _onClosed(), cancelOnError: true);
      return ws;
    } catch (e) {
      throw LaikaOffline('No se pudo abrir el chat ($e)');
    }
  }

  void _onClosed() {
    _ws = null;
    _events.add(const TypingEvent(false));
    final t = _turn;
    if (t != null && !t.isCompleted) t.completeError(const LaikaOffline('Se cortó la conexión con Laika'));
    _turn = null;
    // Sin reconexión automática: Esteban no quiere tráfico en segundo plano.
    // El chat se vuelve a abrir la próxima vez que Laika despierta.
  }

  void _endTurn() {
    final t = _turn;
    if (t != null && !t.isCompleted) t.complete();
    _turn = null;
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (j['type']) {
      case 'typing':
        _events.add(const TypingEvent(true));
      case 'typing_stop':
        _events.add(const TypingEvent(false));
        _endTurn();
      case 'error':
        _events.add(BubbleEvent('⚠️ ${j['text'] ?? 'Laika no pudo contestar.'}'));
        _events.add(const TypingEvent(false));
        _endTurn();
      case 'reminder':
        final r = j['reminder'];
        if (r is Map<String, dynamic>) _events.add(ReminderEvent(Reminder.fromJson(r)));
      case 'message':
        if (j['update'] == true) return; // ediciones: la mascota solo muestra lo nuevo
        final m = j['message'];
        if (m is! Map<String, dynamic>) return;
        final text = (m['text'] as String?)?.trim() ?? '';
        switch (m['role']) {
          case 'companion':
            if (text.isNotEmpty) _events.add(BubbleEvent(text));
          case 'correction':
            final list = (m['meta'] as Map?)?['corrections'];
            if (list is List && list.isNotEmpty) {
              final lines = [
                for (final c in list.whereType<Map>()) '✏️ ${c['original']} → ${c['better']}',
              ];
              _events.add(BubbleEvent(lines.join('\n')));
            }
          // 'user' es el eco de lo que mandaste; 'system' (⏰) ya llega como evento "reminder".
        }
    }
  }

  @override
  Future<void> send(String text) async {
    final ws = await _socket();
    final id = 'pet-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rng.nextInt(1 << 20).toRadixString(36)}';
    _turn = Completer<void>();
    ws.add(jsonEncode({'type': 'typing', 'active': false, 'draft': false, 'recording': false}));
    ws.add(jsonEncode({'type': 'message', 'text': text, 'client_id': id}));
    // Gemma puede tardar; si no avisa que terminó, no se considera error.
    await _turn!.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  @override
  void composing(bool active) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) {
      if (active) _socket().ignore();
      return;
    }
    ws.add(jsonEncode({'type': 'typing', 'active': active, 'draft': active, 'recording': false}));
  }

  @override
  void dispose() {
    _disposed = true;
    _ws?.close();
    _http.close(force: true);
    _events.close();
  }
}

/// Dónde está el servidor. Orden: --dart-define=LAIKA_SERVER=…, variable de
/// entorno LAIKA_SERVER, o "server" en ~/.config/laika/config.json (se puede
/// poner desde Ajustes). Si no hay nada, la app usa el servidor simulado.
String? laikaServerUrl() {
  const fromBuild = String.fromEnvironment('LAIKA_SERVER');
  if (fromBuild.isNotEmpty) return fromBuild;
  final env = Platform.environment['LAIKA_SERVER'];
  if (env != null && env.isNotEmpty) return env;
  return LaikaConfig.load().server;
}
