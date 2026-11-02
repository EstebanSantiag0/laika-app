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

  Future<Object?> _request(String method, String path,
      {Map<String, String>? query, Object? body, Duration timeout = const Duration(seconds: 20)}) async {
    final HttpClientResponse res;
    final String text;
    try {
      final uri = base.replace(path: '${base.path}$path', queryParameters: query == null || query.isEmpty ? null : query);
      final req = await _http.openUrl(method, uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      res = await req.close().timeout(timeout);
      text = await res.transform(utf8.decoder).join();
    } catch (e) {
      throw LaikaOffline('El servidor de Laika no responde ($e)');
    }
    _check(res.statusCode, text);
    return text.isEmpty ? null : jsonDecode(text);
  }

  /// Convierte {"error", "field"?, "max_mb"?, "node_id"?} en [LaikaApiError].
  void _check(int status, String text) {
    if (status < 400) return;
    if (status == 403) throw const LaikaApiError(403, 'El servidor rechazó la conexión (¿estás en Tailscale?)');
    Map? j;
    try {
      final d = jsonDecode(text);
      if (d is Map) j = d;
    } catch (_) {}
    throw LaikaApiError(status, (j?['error'] ?? j?['detail'] ?? 'Error $status del servidor').toString(),
        field: j?['field'] as String?, maxMb: (j?['max_mb'] as num?)?.toInt(), nodeId: j?['node_id'] as String?);
  }

  /// Un id del grafo dentro de una ruta ("fact:12" → "fact%3A12").
  static String _seg(String id) => Uri.encodeComponent(id);

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

  @override
  Future<List<Item>> resurface() async {
    final j = await _request('GET', '/api/resurface');
    final list = j is Map ? j['items'] : j;
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().map(Item.fromJson).toList();
  }

  // ── Segundo cerebro ─────────────────────────────────────────────────────

  static Item _item(Object? j) => Item.fromJson((j as Map<String, dynamic>)['item'] as Map<String, dynamic>);

  @override
  Future<ItemPage> items({String? kind, String? area, String? tag, String? status, String? q, int? before, int limit = 30}) async {
    final j = await _request('GET', '/api/items', query: {
      'kind': ?kind,
      'area': ?area,
      'tag': ?tag,
      'status': ?status,
      if (q != null && q.isNotEmpty) 'q': q,
      if (before != null) 'before': '$before',
      'limit': '$limit',
    }) as Map<String, dynamic>;
    return ItemPage([for (final e in j['items'] as List) Item.fromJson(e as Map<String, dynamic>)],
        (j['next_before'] as num?)?.toInt());
  }

  @override
  Future<Item> item(int id) async => _item(await _request('GET', '/api/items/$id'));

  @override
  Future<(Item, bool)> createItem({String? text, String? url, String? kind, List<String>? areas, List<String>? tags, String? note}) async {
    final j = await _request('POST', '/api/items',
        body: {
          'url': ?url,
          'text': ?text,
          'kind': ?kind,
          'areas': ?areas,
          'tags': ?tags,
          if (note != null && note.isNotEmpty) 'note': note,
        },
        timeout: const Duration(seconds: 60)) as Map<String, dynamic>; // sin kind, Laika lo clasifica (una llamada al modelo)
    return (_item(j), j['duplicate'] == true);
  }

  @override
  Future<(Item, bool)> uploadItem(String path, {String? kind, List<String>? areas, List<String>? tags, String? note}) async {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;
    final boundary = 'laika-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    String field(String k, String v) => '--$boundary\r\nContent-Disposition: form-data; name="$k"\r\n\r\n$v\r\n';
    final head = StringBuffer()
      ..write(kind != null ? field('kind', kind) : '')
      ..write(areas != null && areas.isNotEmpty ? field('areas', areas.join(',')) : '')
      ..write(tags != null && tags.isNotEmpty ? field('tags', tags.join(',')) : '')
      ..write(note != null && note.isNotEmpty ? field('note', note) : '')
      ..write('--$boundary\r\nContent-Disposition: form-data; name="file"; filename="${name.replaceAll('"', '')}"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n');
    final headBytes = utf8.encode(head.toString());
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    final HttpClientResponse res;
    final String text;
    try {
      final req = await _http.postUrl(base.replace(path: '${base.path}/api/items')).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      req.contentLength = headBytes.length + await file.length() + tail.length;
      req.add(headBytes);
      await req.addStream(file.openRead()); // en partes: un PDF de 100 MB no se carga entero en memoria
      req.add(tail);
      res = await req.close().timeout(const Duration(minutes: 10));
      text = await res.transform(utf8.decoder).join();
    } catch (e) {
      throw LaikaOffline('No se pudo subir el archivo ($e)');
    }
    _check(res.statusCode, text);
    final j = jsonDecode(text) as Map<String, dynamic>;
    return (_item(j), j['duplicate'] == true);
  }

  @override
  Future<Item> patchItem(int id, Map<String, Object?> fields) async =>
      _item(await _request('PATCH', '/api/items/$id', body: fields));

  @override
  Future<Item> resurfaceAction(int id, String action) async =>
      _item(await _request('POST', '/api/items/$id/resurface', body: {'action': action}));

  @override
  Uri? pageImage(int id, int page, {int width = 1200}) =>
      base.replace(path: '${base.path}/api/items/$id/pages/$page.png', queryParameters: {'w': '${width.clamp(200, 2000)}'});

  @override
  Uri? fileUrl(int id) => base.replace(path: '${base.path}/api/items/$id/file');

  @override
  Future<List<SearchHit>> search(String q, {int limit = 20}) async {
    final j = await _request('GET', '/api/search', query: {'q': q, 'limit': '$limit'}) as Map<String, dynamic>;
    return [for (final e in j['results'] as List) SearchHit.fromJson(e as Map<String, dynamic>)];
  }

  @override
  Future<List<(String, int)>> tags() async {
    final j = await _request('GET', '/api/tags') as List;
    return [for (final e in j.cast<Map<String, dynamic>>()) (e['tag'] as String, (e['count'] as num?)?.toInt() ?? 0)];
  }

  @override
  Future<(List<Fact>, List<Fact>)> likes() async {
    final j = await _request('GET', '/api/likes') as Map<String, dynamic>;
    List<Fact> list(String k, String pol) =>
        [for (final e in (j[k] as List? ?? const [])) Fact.fromJson(e as Map<String, dynamic>, polarity: pol)];
    return (list('likes', 'like'), list('dislikes', 'dislike'));
  }

  @override
  Future<Fact> patchLike(Fact fact, Map<String, Object?> fields) async {
    final j = await _request('PATCH', '/api/likes/${fact.number}', body: fields) as Map<String, dynamic>;
    return Fact.fromJson(j['node'] is Map ? j['node'] as Map<String, dynamic> : j);
  }

  @override
  Future<NodeUpdate> patchNode(String nodeId, Map<String, Object?> fields, {DateTime? baseUpdatedAt}) async {
    final j = await _request('PATCH', '/api/nodes/${_seg(nodeId)}', body: {
      ...fields,
      if (baseUpdatedAt != null) 'base_updated_at': baseUpdatedAt.toIso8601String(),
    }) as Map<String, dynamic>;
    return NodeUpdate(MemoryNode.fromJson(j['node'] as Map<String, dynamic>),
        [for (final e in (j['edges'] as List? ?? const [])) MemoryEdge.fromJson(e as Map<String, dynamic>)]);
  }

  @override
  Future<(String?, int)> tagRenamePreview(String nodeId, String name) async {
    final j = await _request('PATCH', '/api/nodes/${_seg(nodeId)}', query: {'dry_run': 'true'}, body: {'name': name})
        as Map<String, dynamic>;
    return (j['merges_into'] as String?, (j['nodes_affected'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<TrashResult> deleteNode(String nodeId, {bool withFacts = false, bool dryRun = false}) async {
    final j = await _request('DELETE', '/api/nodes/${_seg(nodeId)}', query: {
      if (withFacts) 'with_facts': 'true',
      if (dryRun) 'dry_run': 'true',
    }) as Map<String, dynamic>;
    return TrashResult.fromJson(j);
  }

  @override
  Future<void> restoreNode(String nodeId) => _request('POST', '/api/trash/${_seg(nodeId)}/restore');

  @override
  Future<MemoryEdge> createEdge(String source, String target, {String? label}) async {
    final j = await _request('POST', '/api/edges', body: {'source': source, 'target': target, 'label': ?label})
        as Map<String, dynamic>;
    return MemoryEdge.fromJson(j['edge'] as Map<String, dynamic>);
  }

  @override
  Future<MemoryEdge> patchEdge(String edgeId, String label) async {
    final j = await _request('PATCH', '/api/edges/${_seg(edgeId)}', body: {'label': label}) as Map<String, dynamic>;
    return MemoryEdge.fromJson(j['edge'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteEdge(String edgeId) => _request('DELETE', '/api/edges/${_seg(edgeId)}');

  @override
  Future<void> restoreEdge(String edgeId) => _request('POST', '/api/trash/edges/${_seg(edgeId)}/restore');

  @override
  Future<Trash> trash() async => Trash.fromJson(await _request('GET', '/api/trash') as Map<String, dynamic>);

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
      case 'item':
        final it = j['item'];
        if (it is Map<String, dynamic>) _events.add(ItemEvent(Item.fromJson(it)));
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
          case 'system' when text.startsWith('📚'):
            // Avisos de su biblioteca: le llegó un PDF/libro (come) o no pudo leerlo.
            _events.add(LibraryEvent(text));
          // 'user' es el eco de lo que mandaste; los demás 'system' (⏰) ya llegan como evento "reminder".
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
