// Comportamiento de la mascota (igual en las 5 variantes; solo cambia el estilo).
//
// Reglas de Esteban:
//  • Tras 15 s sin interacción, Laika se duerme.
//  • Al pasar el mouse (o tocarla en Android) estando dormida, hace UNA
//    petición a GET /health. Si el servidor responde, despierta; si no,
//    sigue dormida.
//  • No hay sondeo en segundo plano: solo se pregunta al servidor cuando tú
//    la buscas.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

enum PetState {
  /// Dormida. Nadie ha preguntado al servidor.
  asleep,

  /// Preguntando a /health…
  waking,

  /// Despierta y lista para platicar.
  awake,

  /// Esperando su respuesta.
  thinking,
}

/// Cómo duerme: primero sentada (cabeceando) y, 15 s después, acostada.
enum SleepPose { seated, lying }

/// La cara y la postura de Laika. Las de "reacción" duran unos segundos.
enum Mood {
  neutral('Tranquila', 'despierta, sin nada que hacer'),
  happy('Contenta', 'cuando te contesta'),
  greeting('Saludando', 'al despertar o cuando dice "hola"'),
  laughing('Muerta de risa', 'jaja, lol, 😂'),
  inLove('Enamorada', '❤️, te quiero'),
  surprised('Sorprendida', 'cuando suena un recordatorio'),
  impressed('Impresionada', 'cuando aprende algo nuevo, wow, increíble'),
  doubting('Dudando', '🤔, hmm, no estoy segura'),
  ashamed('Apenada', 'cuando algo le sale mal'),
  crying('Llorando', '😭, qué triste'),
  scheming('Tramando algo', 'cuando anota un recordatorio, 😈'),
  cheeky('Traviesa', 'cuando te corrige, 😜'),
  thinking('Pensando', 'mientras escribe su respuesta'),
  waking('Despertando', 'preguntando a /health'),
  sleeping('Dormida', 'tras 15 s sentada; 15 s después, acostada');

  const Mood(this.label, this.when);
  final String label;
  final String when;

  /// Reacción a un mensaje de Laika (por palabras y emojis).
  static Mood forText(String text) {
    final s = text.toLowerCase();
    bool has(String pattern) => RegExp(pattern, unicode: true).hasMatch(s);
    if (s.startsWith('⚠️')) return Mood.ashamed;
    if (s.startsWith('✏️')) return Mood.cheeky;
    if (s.startsWith('⏰')) return Mood.surprised;
    if (has(r'😈|😏|muaha|fufu')) return Mood.scheming;
    if (has(r'😂|🤣|😆|\b(ja){2,}|\b(ha){2,}|\blol\b|\bxd\b|哈哈|ахах')) return Mood.laughing;
    if (has(r'❤|💕|💖|🥰|😍|te quiero|te amo|love you')) return Mood.inLove;
    if (has(r'😭|😢|🥺|qué triste|que triste|so sad')) return Mood.crying;
    if (has(r'😜|😛|😝|:p\b')) return Mood.cheeky;
    if (has(r'🤔|\bhmm+|no estoy segura|not sure')) return Mood.doubting;
    if (has(r'😮|😲|🤩|\bwow\b|increíble|impresionante|amazing|bien hecho|well done')) return Mood.impressed;
    if (has(r'^(¡?hola|hi\b|hey\b|hello|buen(os|as) (días|tardes|noches)|привет|你好)')) return Mood.greeting;
    return Mood.happy;
  }
}

class Bubble {
  Bubble(this.text) : at = DateTime.now(), id = _n++;
  static int _n = 0;
  final String text;
  final DateTime at;
  final int id;
}

class PetController extends ChangeNotifier {
  PetController(
    this.api, {
    this.idle = const Duration(seconds: 15),
    this.healthTimeout = const Duration(seconds: 4),
  }) {
    _sub = api.events.listen(_onEvent);
  }

  final LaikaApi api;

  /// Tiempo sin interacción antes de dormirse.
  final Duration idle;

  /// Si /health tarda más que esto, se considera que no respondió.
  final Duration healthTimeout;

  PetState _state = PetState.asleep;
  PetState get state => _state;
  bool get isAwake => _state == PetState.awake || _state == PetState.thinking;

  /// Postura mientras duerme. Al arrancar la app ya está acostada.
  SleepPose sleepPose = SleepPose.lying;

  /// La caja de texto está abierta (se abre con UN clic sobre Laika).
  bool chatOpen = false;
  bool _openAfterWake = false;

  /// Burbujas de Laika (las más recientes al final). Máximo [maxBubbles].
  final List<Bubble> bubbles = [];
  static const maxBubbles = 4;

  /// Tu último mensaje (se muestra discreto junto a la caja de texto).
  String? lastMine;

  /// Laika está escribiendo.
  bool typing = false;

  /// El último intento de despertar falló (servidor caído). Se muestra un
  /// aviso breve y Laika sigue dormida.
  bool wakeFailed = false;

  /// Recordatorios que llegaron mientras dormía: se muestran con una
  /// campanita y los dice al despertar.
  final List<Reminder> pendingReminders = [];

  /// Algo que Laika acaba de guardar en su memoria (aviso breve).
  MemoryNode? justLearned;

  Mood? _reaction;
  Timer? _reactionTimer;

  /// Cómo se ve ahora (ver [Mood]).
  Mood get mood => switch (_state) {
        PetState.asleep => Mood.sleeping,
        PetState.waking => Mood.waking,
        PetState.thinking => _reaction ?? Mood.thinking,
        PetState.awake => _reaction ?? (typing ? Mood.thinking : Mood.neutral),
      };

  /// Pone una cara unos segundos (luego vuelve a la normal).
  void react(Mood m, [Duration d = const Duration(milliseconds: 3500)]) {
    if (!isAwake) return;
    _reaction = m;
    _reactionTimer?.cancel();
    _reactionTimer = Timer(d, () {
      _reaction = null;
      _notify();
    });
    _notify();
  }

  late final StreamSubscription<LaikaEvent> _sub;
  Timer? _idleTimer;
  Timer? _deepTimer;
  Timer? _flashTimer;
  bool _checking = false;
  bool _disposed = false;

  /// El mouse entró sobre Laika.
  void hover() {
    if (_state == PetState.asleep) {
      _tryWake();
    } else {
      touch();
    }
  }

  /// Un clic sobre Laika: abre la caja de texto (si está dormida, primero
  /// intenta despertarla y la abre solo si el servidor responde).
  void poke() {
    if (_state == PetState.asleep) {
      _openAfterWake = true;
      _tryWake();
    } else {
      openChat();
    }
  }

  void openChat() {
    if (!isAwake) return;
    chatOpen = true;
    touch();
    _notify();
  }

  void closeChat() {
    chatOpen = false;
    _notify();
  }

  /// Cualquier interacción: reinicia la cuenta de 15 s.
  void touch() {
    if (!isAwake) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idle, _onIdle);
  }

  void _onIdle() {
    // No se duerme a media respuesta.
    if (_state == PetState.thinking || typing) {
      touch();
      return;
    }
    sleep();
  }

  void sleep() {
    _idleTimer?.cancel();
    _deepTimer?.cancel();
    _state = PetState.asleep;
    sleepPose = SleepPose.seated;
    chatOpen = false;
    // Otros 15 s sin interacción: se acuesta.
    _deepTimer = Timer(idle, () {
      if (_state != PetState.asleep) return;
      sleepPose = SleepPose.lying;
      _notify();
    });
    bubbles.clear();
    lastMine = null;
    typing = false;
    _reaction = null;
    _reactionTimer?.cancel();
    _notify();
  }

  Future<void> _tryWake() async {
    if (_checking) return;
    _checking = true;
    _state = PetState.waking;
    wakeFailed = false;
    _notify();
    bool ok;
    try {
      final h = await api.health().timeout(healthTimeout);
      ok = h.canWake;
    } catch (_) {
      ok = false;
    }
    _checking = false;
    if (_disposed) return;
    if (ok) {
      _deepTimer?.cancel();
      _state = PetState.awake;
      if (_openAfterWake) chatOpen = true;
      for (final r in pendingReminders) {
        _addBubble('⏰ Recordatorio: ${r.text}');
      }
      pendingReminders.clear();
      touch();
      react(Mood.greeting);
    } else {
      _state = PetState.asleep;
      wakeFailed = true;
      _flash(() => wakeFailed = false);
    }
    _openAfterWake = false;
    _notify();
  }

  bool _composing = false;

  /// La caja de texto tiene algo escrito (o se vació).
  void composing(bool active) {
    if (active == _composing) return;
    _composing = active;
    api.composing(active);
    if (active) touch();
  }

  Future<void> send(String text) async {
    composing(false);
    text = text.trim();
    if (text.isEmpty || !isAwake) return;
    lastMine = text;
    _state = PetState.thinking;
    touch();
    _notify();
    try {
      await api.send(text);
      if (_state == PetState.thinking) _state = PetState.awake;
    } catch (_) {
      // El servidor dejó de contestar a media plática: se duerme.
      sleep();
      wakeFailed = true;
      _flash(() => wakeFailed = false);
    }
    touch();
    _notify();
  }

  void _onEvent(LaikaEvent e) {
    switch (e) {
      case TypingEvent(:final typing):
        this.typing = typing;
      case BubbleEvent(:final text):
        if (isAwake) {
          _addBubble(text);
          react(Mood.forText(text));
        }
      case ReminderEvent(:final reminder) when !e.isDue:
        // Creado, hecho o pospuesto: no hay que avisar nada.
        pendingReminders.removeWhere((r) => r.id == reminder.id);
        if (reminder.status == ReminderStatus.pending && reminder.snoozes == 0) react(Mood.scheming);
      case ReminderEvent(:final reminder):
        if (isAwake) {
          _addBubble('⏰ Recordatorio: ${reminder.text}');
          react(Mood.surprised);
        } else {
          pendingReminders.add(reminder);
        }
      case MemoryEvent(:final node):
        justLearned = node;
        _flash(() => justLearned = null, const Duration(seconds: 4));
        react(Mood.impressed);
    }
    touch();
    _notify();
  }

  void _addBubble(String text) {
    bubbles.add(Bubble(text));
    while (bubbles.length > maxBubbles) {
      bubbles.removeAt(0);
    }
  }

  void _flash(VoidCallback clear, [Duration d = const Duration(seconds: 3)]) {
    _flashTimer?.cancel();
    _flashTimer = Timer(d, () {
      clear();
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _deepTimer?.cancel();
    _flashTimer?.cancel();
    _reactionTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }
}
