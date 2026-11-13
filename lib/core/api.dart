// Interfaz con el servidor de Laika.
//
// Las interfaces (variantes) solo hablan con esta clase abstracta. Hoy la
// implementa MockLaika (backend simulado); después se añadirá HttpLaika, que
// hablará con el servidor real por HTTPS + WebSocket a través de Tailscale.

import 'cards.dart';
import 'models.dart';

export 'cards.dart';

abstract class LaikaApi {
  /// GET /health — se llama al pasar el mouse sobre Laika dormida.
  Future<Health> health();

  /// Eventos en vivo del servidor: burbujas, "escribiendo", recordatorios...
  Stream<LaikaEvent> get events;

  /// Envía un mensaje tuyo. Las respuestas llegan por [events].
  Future<void> send(String text);

  /// GET /api/graph — el "cerebro" completo. [all] incluye lo archivado.
  Future<MemoryGraph> graph({bool all = true});

  /// GET /api/reminders
  Future<List<Reminder>> reminders({bool all = true});

  /// POST /api/reminders/{id}/done
  Future<void> markDone(int id);

  /// POST /api/reminders/{id}/snooze
  Future<void> snooze(int id, {int minutes = 60});

  /// GET /api/resurface — lo guardado que conviene recordarte hoy (máx. 3).
  /// La mascota lo pide UNA vez, justo después de despertar.
  Future<List<Item>> resurface();

  // ── Segundo cerebro ─────────────────────────────────────────────────────

  /// GET /api/items (de la más nueva a la más vieja; [before] = id para la siguiente página).
  Future<ItemPage> items({String? kind, String? area, String? tag, String? status, String? q, int? before, int limit = 30});

  /// GET /api/items/{id}
  Future<Item> item(int id);

  /// POST /api/items con {text} o {url}. Devuelve el item y si es nuevo, ya existía o volvió de la papelera.
  Future<(Item, SaveResult)> createItem({String? text, String? url, String? kind, List<String>? areas, List<String>? tags, String? note});

  /// POST /api/items multipart (un archivo: PDF, libro, imagen…).
  ///
  /// [comment]: además, Laika lo comenta en el chat (lo que se manda desde la mascota).
  Future<(Item, SaveResult)> uploadItem(String path, {String? kind, List<String>? areas, List<String>? tags, String? note, bool comment = false});

  /// PATCH /api/items/{id}: kind/areas/tags/note/title/status.
  Future<Item> patchItem(int id, Map<String, Object?> fields);

  /// POST /api/items/{id}/resurface {action: dismiss|done|later}
  Future<Item> resurfaceAction(int id, String action);

  /// URL de una página del PDF como imagen (GET /api/items/{id}/pages/{n}.png?w=), o null sin servidor.
  Uri? pageImage(int id, int page, {int width = 1200});

  /// URL del archivo original (GET /api/items/{id}/file), o null sin servidor.
  Uri? fileUrl(int id);

  /// GET /api/search
  Future<List<SearchHit>> search(String q, {int limit = 20});

  /// GET /api/tags → [(nombre, cuántos)]
  Future<List<(String, int)>> tags();

  /// GET /api/likes
  Future<(List<Fact>, List<Fact>)> likes();

  /// PATCH /api/likes/{n}: {polarity: like|dislike|null} o {status: "archived"}.
  Future<Fact> patchLike(Fact fact, Map<String, Object?> fields);

  // ── Editar el grafo ─────────────────────────────────────────────────────

  /// PATCH /api/nodes/{node_id}. Con [baseUpdatedAt], 409 si alguien lo cambió antes.
  Future<NodeUpdate> patchNode(String nodeId, Map<String, Object?> fields, {String? baseUpdatedAt});

  /// PATCH de una etiqueta con dry_run: (con cuál se fusionaría o null, cuántos nodos cambian).
  Future<(String?, int)> tagRenamePreview(String nodeId, String name);

  /// DELETE /api/nodes/{node_id} (a la papelera 30 días). [dryRun]: solo dice qué se llevaría.
  Future<TrashResult> deleteNode(String nodeId, {bool withFacts = false, bool dryRun = false});

  /// POST /api/trash/{node_id}/restore
  Future<void> restoreNode(String nodeId);

  /// POST /api/edges: una conexión tuya.
  Future<MemoryEdge> createEdge(String source, String target, {String? label});

  /// PATCH /api/edges/{id} {label} (solo las guardadas: link/about).
  Future<MemoryEdge> patchEdge(String edgeId, String label);

  /// DELETE /api/edges/{id}: borra una tuya u oculta una de Laika.
  Future<void> deleteEdge(String edgeId);

  /// POST /api/trash/edges/{id}/restore
  Future<void> restoreEdge(String edgeId);

  /// GET /api/trash
  Future<Trash> trash();

  // ── Tarjetas (hanzi + FSRS). Solo la app: la mascota no las muestra. ──────

  /// GET /api/cards (filter: all|due|new|his|hers|hard|trash). El mazo es chico
  /// (decenas a cientos), así que se pide todo de una vez y se busca aquí.
  Future<CardPage> cards({String filter = 'all', String? q, int? before, int limit = 500});

  /// GET /api/cards/{id}: la tarjeta y su historial.
  Future<(Flashcard, List<CardEdit>)> card(int id);

  /// POST /api/cards. El servidor llena lo que falte (pinyin, significados).
  /// 409 con [LaikaApiError.cardId] si ese carácter con esa lectura ya existe.
  Future<CardWrite> createCard({required String front, String? reading, String? word, String? meaningEs, String? meaningEn, String? note});

  /// PATCH /api/cards/{id}: los campos que mandas quedan bloqueados para Laika;
  /// [unlock] se los devuelve. 409 si cambió desde [baseUpdatedAt].
  Future<CardWrite> patchCard(int id, Map<String, Object?> fields, {String? baseUpdatedAt, List<String>? unlock});

  /// DELETE /api/cards/{id}: a la papelera (30 días).
  Future<CardWrite> deleteCard(int id);

  /// POST /api/cards/{id}/restore
  Future<CardWrite> restoreCard(int id);

  /// GET /api/cards/due: repasos que tocan + nuevas hasta el tope del día, con `preview` y `now`.
  Future<DueCards> dueCards({int limit = 20});

  /// POST /api/cards/{id}/review (1 Otra vez · 2 Difícil · 3 Bien · 4 Fácil).
  /// [clientId] hace que repetirlo (sin red, reintento) no cuente dos veces.
  Future<CardWrite> reviewCard(int id, int rating, {required String clientId, int? durationMs, DateTime? reviewedAt});

  /// POST /api/cards/edits/{id}/undo. 409 si un cambio posterior tocó lo mismo.
  Future<CardWrite> undoCardEdit(int editId);

  /// POST /api/cards/suggestions/{id}: Aplicar (true) o No (false).
  Future<CardWrite> answerSuggestion(int editId, {required bool apply});

  /// GET /api/cards/edits: los cambios y sugerencias (de Laika, tuyos o de ambos).
  Future<CardEditPage> cardEdits({String? who, String? op, bool pending = false, int? before, int limit = 50});

  /// GET /api/cards/{id}/audio bajado a un archivo (ogg/opus), o null si no hay audio.
  Future<String?> cardAudio(int id);

  /// GET /api/settings: idioma de práctica (`practice_lang`), correcciones, voz…
  Future<Map<String, dynamic>> settings();

  /// PUT /api/settings (parcial). Devuelve los ajustes completos.
  Future<Map<String, dynamic>> updateSettings(Map<String, Object?> changes);

  /// POST /api/voice: una nota de voz (se transcribe y entra al chat como si la
  /// hubieras escrito). Las respuestas llegan por [events].
  Future<void> sendVoice(String path);

  /// Estás grabando una nota de voz ({"type":"typing","recording":true} cada ~2 s).
  void recording(bool active);

  /// Avisa si estás escribiendo en la caja de texto. Laika no contesta
  /// mientras estás escribiendo ({"type":"typing","active":…}).
  void composing(bool active);

  void dispose();
}

/// El servidor contestó con un error ({"error", "field"?, "max_mb"?, "node_id"?}).
class LaikaApiError extends LaikaOffline {
  const LaikaApiError(this.status, super.message, {this.field, this.maxMb, this.nodeId, this.cardId});
  final int status;

  /// 422: qué campo está mal.
  final String? field;

  /// 413: el límite de tamaño.
  final int? maxMb;

  /// 409: el nodo que cambió mientras lo editabas.
  final String? nodeId;

  /// 409 al crear o cambiar la lectura: la tarjeta que ya existe.
  final int? cardId;

  bool get conflict => status == 409;
}

/// Error cuando el servidor no contesta.
class LaikaOffline implements Exception {
  const LaikaOffline([this.message = 'El servidor de Laika no responde']);
  final String message;
  @override
  String toString() => message;
}
