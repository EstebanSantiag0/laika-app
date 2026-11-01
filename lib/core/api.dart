// Interfaz con el servidor de Laika.
//
// Las interfaces (variantes) solo hablan con esta clase abstracta. Hoy la
// implementa MockLaika (backend simulado); después se añadirá HttpLaika, que
// hablará con el servidor real por HTTPS + WebSocket a través de Tailscale.

import 'models.dart';

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

  /// Avisa si estás escribiendo en la caja de texto. Laika no contesta
  /// mientras estás escribiendo ({"type":"typing","active":…}).
  void composing(bool active);

  void dispose();
}

/// Error cuando el servidor no contesta.
class LaikaOffline implements Exception {
  const LaikaOffline([this.message = 'El servidor de Laika no responde']);
  final String message;
  @override
  String toString() => message;
}
