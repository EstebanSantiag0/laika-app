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

  /// Convierte {"error", "field"?, "max_mb"?, "node_id"?, "card_id"?} en [LaikaApiError].
  void _check(int status, String text) {
    if (status < 400) return;
    if (status == 403) throw const LaikaApiError(403, 'El servidor rechazó la conexión (¿estás en Tailscale?)');
    Map? j;
    try {
      final d = jsonDecode(text);
      if (d is Map) j = d;
    } catch (_) {}
    throw LaikaApiError(status, (j?['error'] ?? j?['detail'] ?? 'Error $status del servidor').toString(),
        field: j?['field'] as String?,
        maxMb: (j?['max_mb'] as num?)?.toInt(),
        nodeId: j?['node_id'] as String?,
        cardId: (j?['card_id'] as num?)?.toInt());
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

  static SaveResult _saved(Map<String, dynamic> j) => j['restored'] == true
      ? SaveResult.restored
      : (j['duplicate'] == true ? SaveResult.duplicate : SaveResult.created);

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
  Future<(Item, SaveResult)> createItem({String? text, String? url, String? kind, List<String>? areas, List<String>? tags, String? note}) async {
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
    return (_item(j), _saved(j));
  }

  @override
  Future<(Item, SaveResult)> uploadItem(String path,
      {String? kind, List<String>? areas, List<String>? tags, String? note, bool comment = false}) async {
    final j = await _multipart('/api/items', path, {
      'kind': ?kind,
      if (areas != null && areas.isNotEmpty) 'areas': areas.join(','),
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (note != null && note.isNotEmpty) 'note': note,
      if (comment) 'comment': 'true',
    }) as Map<String, dynamic>;
    return (_item(j), _saved(j));
  }

  /// POST multipart con un archivo (campo `file`), mandado en partes: un PDF de
  /// 100 MB no se carga entero en memoria.
  Future<Object?> _multipart(String route, String path, Map<String, String> fields,
      {Duration timeout = const Duration(minutes: 10)}) async {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;
    final boundary = 'laika-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final head = StringBuffer();
    fields.forEach((k, v) => head.write('--$boundary\r\nContent-Disposition: form-data; name="$k"\r\n\r\n$v\r\n'));
    head.write('--$boundary\r\nContent-Disposition: form-data; name="file"; filename="${name.replaceAll('"', '')}"\r\n'
        'Content-Type: application/octet-stream\r\n\r\n');
    final headBytes = utf8.encode(head.toString());
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    final HttpClientResponse res;
    final String text;
    try {
      final req = await _http.postUrl(base.replace(path: '${base.path}$route')).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      req.contentLength = headBytes.length + await file.length() + tail.length;
      req.add(headBytes);
      await req.addStream(file.openRead());
      req.add(tail);
      res = await req.close().timeout(timeout);
      text = await res.transform(utf8.decoder).join();
    } catch (e) {
      throw LaikaOffline('No se pudo subir el archivo ($e)');
    }
    _check(res.statusCode, text);
    return text.isEmpty ? null : jsonDecode(text);
  }

  @override
  Future<Map<String, dynamic>> settings() async => (await _request('GET', '/api/settings')) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> updateSettings(Map<String, Object?> changes) async =>
      (await _request('PUT', '/api/settings', body: changes)) as Map<String, dynamic>;

  @override
  Future<void> sendVoice(String path) async {
    await _socket(); // la respuesta llega por el chat en vivo
    _turn = Completer<void>();
    await _multipart('/api/voice', path, const {}, timeout: const Duration(minutes: 2));
    await _turn!.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  @override
  void recording(bool active) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) {
      if (active) _socket().ignore();
      return;
    }
    ws.add(jsonEncode({'type': 'typing', 'active': active, 'draft': false, 'recording': active}));
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
  Future<NodeUpdate> patchNode(String nodeId, Map<String, Object?> fields, {String? baseUpdatedAt}) async {
    final j = await _request('PATCH', '/api/nodes/${_seg(nodeId)}', body: {
      ...fields,
      'base_updated_at': ?baseUpdatedAt,
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

  // ── Tarjetas ──────────────────────────────────────────────────────────────

  static CardWrite _cardWrite(Object? j) => CardWrite.fromJson(j as Map<String, dynamic>);

  @override
  Future<CardPage> cards({String filter = 'all', String? q, int? before, int limit = 500}) async =>
      CardPage.fromJson(await _request('GET', '/api/cards', query: {
        'filter': filter,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (before != null) 'before': '$before',
        'limit': '$limit',
      }) as Map<String, dynamic>);

  @override
  Future<(Flashcard, List<CardEdit>)> card(int id) async {
    final j = await _request('GET', '/api/cards/$id') as Map<String, dynamic>;
    return (
      Flashcard.fromJson(j['card'] as Map<String, dynamic>),
      [for (final e in (j['history'] as List? ?? const []).whereType<Map<String, dynamic>>()) CardEdit.fromJson(e)],
    );
  }

  @override
  Future<CardWrite> createCard(
          {required String front, String? reading, String? word, String? meaningEs, String? meaningEn, String? note}) async =>
      _cardWrite(await _request('POST', '/api/cards', body: {
        'front': front,
        'reading': ?reading,
        'word': ?word,
        'meaning_es': ?meaningEs,
        'meaning_en': ?meaningEn,
        'note': ?note,
      }));

  @override
  Future<CardWrite> patchCard(int id, Map<String, Object?> fields, {String? baseUpdatedAt, List<String>? unlock}) async =>
      _cardWrite(await _request('PATCH', '/api/cards/$id', body: {
        ...fields,
        'base_updated_at': ?baseUpdatedAt,
        if (unlock != null && unlock.isNotEmpty) 'unlock': unlock,
      }));

  @override
  Future<CardWrite> deleteCard(int id) async => _cardWrite(await _request('DELETE', '/api/cards/$id'));

  @override
  Future<CardWrite> restoreCard(int id) async => _cardWrite(await _request('POST', '/api/cards/$id/restore'));

  @override
  Future<DueCards> dueCards({int limit = 20}) async =>
      DueCards.fromJson(await _request('GET', '/api/cards/due', query: {'limit': '$limit'}) as Map<String, dynamic>);

  @override
  Future<CardWrite> reviewCard(int id, int rating, {required String clientId, int? durationMs, DateTime? reviewedAt}) async =>
      _cardWrite(await _request('POST', '/api/cards/$id/review', body: {
        'rating': rating,
        'client_id': clientId,
        'duration_ms': ?durationMs,
        if (reviewedAt != null) 'reviewed_at': reviewedAt.toUtc().toIso8601String(),
      }));

  @override
  Future<CardWrite> undoCardEdit(int editId) async => _cardWrite(await _request('POST', '/api/cards/edits/$editId/undo'));

  @override
  Future<CardWrite> answerSuggestion(int editId, {required bool apply}) async =>
      _cardWrite(await _request('POST', '/api/cards/suggestions/$editId', body: {'apply': apply}));

  @override
  Future<CardEditPage> cardEdits({String? who, String? op, bool pending = false, int? before, int limit = 50}) async =>
      CardEditPage.fromJson(await _request('GET', '/api/cards/edits', query: {
        'who': ?who,
        'op': ?op,
        if (pending) 'pending': 'true',
        if (before != null) 'before': '$before',
        'limit': '$limit',
      }) as Map<String, dynamic>);

  /// Baja el audio (ogg/opus) a un archivo temporal. El servidor lo genera la
  /// primera vez: si contesta 202 {retry_after}, se espera y se vuelve a pedir.
  @override
  Future<String?> cardAudio(int id) async {
    final uri = base.replace(path: '${base.path}/api/cards/$id/audio');
    for (var attempt = 0; attempt < 3; attempt++) {
      final HttpClientResponse res;
      final List<int> bytes;
      try {
        final req = await _http.getUrl(uri).timeout(const Duration(seconds: 8));
        res = await req.close().timeout(const Duration(seconds: 20));
        bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      } catch (e) {
        throw LaikaOffline('El servidor de Laika no responde ($e)');
      }
      if (res.statusCode == 202) {
        Object? j;
        try {
          j = jsonDecode(utf8.decode(bytes));
        } catch (_) {}
        final wait = ((j is Map ? j['retry_after'] : null) as num?)?.toDouble() ?? 3;
        await Future<void>.delayed(Duration(milliseconds: (wait.clamp(1, 10) * 1000).round()));
        continue;
      }
      if (res.statusCode == 404) return null;
      _check(res.statusCode, utf8.decode(bytes, allowMalformed: true));
      final dir = await Directory.systemTemp.createTemp('laika_card_');
      final f = File('${dir.path}/card-$id.ogg');
      await f.writeAsBytes(bytes);
      return f.path;
    }
    throw const LaikaApiError(504, 'El audio todavía no está listo; inténtalo en un momento');
  }

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
      case 'settings':
        final st = j['settings'];
        if (st is Map<String, dynamic>) _events.add(SettingsEvent(st));
      case 'item':
        final it = j['item'];
        if (it is Map<String, dynamic>) _events.add(ItemEvent(Item.fromJson(it)));
      case 'card':
        // Solo para la pestaña Tarjetas; la mascota los ignora.
        if (j['card'] is Map<String, dynamic>) _events.add(CardEvent.fromJson(j));
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
