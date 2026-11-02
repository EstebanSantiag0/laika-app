// El "escritorio" donde vive Laika, compartido por todas las variantes.
//
// En estos prototipos el escritorio se simula dentro de la ventana. En la
// versión final, Laika será una ventana transparente sobre tu escritorio
// real (Linux: gtk-layer-shell; Android: burbuja sobre otras apps), con la
// misma lógica.
//
// Las burbujas se desvanecen por TIEMPO (su tiempo de lectura, ver
// readingTime en pet.dart), no por qué tan arriba quedaron: la opacidad la
// pone el escenario, igual para todas las variantes.
//
// Regla de las burbujas: si Laika está en la mitad derecha de la pantalla,
// sus mensajes salen a su IZQUIERDA; si está en la mitad izquierda, salen a
// su DERECHA. La caja de texto va en el mismo lado.

import 'package:flutter/material.dart';

import 'media.dart';
import 'models.dart';
import 'pet.dart';

/// Lo que cada variante dibuja a su manera.
abstract class PetSkin {
  const PetSkin();

  double get petSize => 132;
  double get chatWidth => 300;

  /// El fondo del escritorio simulado.
  Widget backdrop(BuildContext context);

  /// Laika. [t] son segundos desde que arrancó (para animar).
  Widget pet(BuildContext context, PetController c, double t);

  /// Una burbuja de Laika. [age] 0 = la más nueva (solo para el estilo: el
  /// desvanecimiento por tiempo lo pone el escenario).
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age});

  /// "Laika está escribiendo…"
  Widget typing(BuildContext context, double t, {required bool petOnRight});

  /// Tu último mensaje, discreto.
  Widget mine(BuildContext context, String text, {required bool petOnRight});

  /// La caja de texto: lo único del chat que siempre se ve.
  Widget input(BuildContext context, TextEditingController text, FocusNode focus,
      VoidCallback onSend, {required bool petOnRight});

  /// Etiqueta pequeña sobre Laika: "zZz", "preguntando…", "sin respuesta".
  Widget? status(BuildContext context, PetController c, double t) => null;

  /// La fila para escribirle: (+) ___________ (🎤). Con texto (o grabando), el
  /// micrófono se vuelve el avioncito de enviar, como en WhatsApp.
  Widget composer(BuildContext context, Composer k, {required bool petOnRight}) => Row(children: [
        composerButton(context, Icons.add_rounded, k.onPlus, on: k.menuOpen),
        const SizedBox(width: 6),
        Expanded(
          child: k.recordingFor != null
              ? recordingBar(context, k.recordingFor!, k.onCancelRecording)
              : input(context, k.text, k.focus, k.onSend, petOnRight: petOnRight),
        ),
        const SizedBox(width: 6),
        composerButton(context, k.showSend ? Icons.send_rounded : Icons.mic_rounded, k.showSend ? k.onSend : k.onMic,
            on: k.recordingFor != null),
      ]);

  Widget composerButton(BuildContext context, IconData icon, VoidCallback? onTap, {bool on = false}) => Material(
        color: on ? Theme.of(context).colorScheme.primary : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 20, color: on ? Colors.white : Colors.black87),
          ),
        ),
      );

  /// En lugar de la caja mientras grabas: "● 0:07  Grabando…  ✕".
  Widget recordingBar(BuildContext context, Duration d, VoidCallback onCancel) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Icon(Icons.fiber_manual_record, size: 12, color: Colors.red),
          const SizedBox(width: 6),
          Text(Composer.clock(d)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Grabando…', overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onCancel, child: const Icon(Icons.close_rounded, size: 18)),
        ]),
      );

  /// Una etiqueta que se puede tocar (el idioma: "RU ▾").
  Widget chip(BuildContext context, String label, {bool selected = false, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      );

  /// El menú del (+): archivo, captura.
  Widget menu(BuildContext context, List<MenuEntry> items) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in items)
            InkWell(
              onTap: e.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [Icon(e.icon, size: 18), const SizedBox(width: 10), Text(e.label)]),
              ),
            ),
        ]),
      );
}

/// Lo que necesita [PetSkin.composer].
class Composer {
  const Composer({
    required this.text,
    required this.focus,
    required this.onSend,
    required this.onPlus,
    required this.onMic,
    required this.onCancelRecording,
    required this.hasText,
    required this.menuOpen,
    this.recordingFor,
  });
  final TextEditingController text;
  final FocusNode focus;

  /// Manda el texto, o la nota de voz si estás grabando.
  final VoidCallback onSend;
  final VoidCallback onPlus;
  final VoidCallback onMic;
  final VoidCallback onCancelRecording;
  final bool hasText;
  final bool menuOpen;

  /// Cuánto llevas grabando (null = no estás grabando).
  final Duration? recordingFor;

  bool get showSend => hasText || recordingFor != null;

  static String clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class MenuEntry {
  const MenuEntry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class PetStage extends StatefulWidget {
  const PetStage({super.key, required this.controller, required this.skin, this.onOpenApp, this.onRegions, this.media = const Media()});

  /// Micrófono, capturas y selector de archivos (en las pruebas, uno falso).
  final Media media;

  final PetController controller;
  final PetSkin skin;

  /// Doble clic sobre Laika: abre la app completa (cerebro, agenda…).
  final VoidCallback? onOpenApp;

  /// Zonas de la pantalla ocupadas por Laika y su chat. En el escritorio real
  /// solo esas zonas reciben clics; el resto pasa a las ventanas de abajo.
  final ValueChanged<List<Rect>>? onRegions;

  @override
  State<PetStage> createState() => _PetStageState();
}

class _PetStageState extends State<PetStage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final _watch = Stopwatch()..start();
  final _text = TextEditingController();
  final _focus = FocusNode();
  Offset? _pos; // esquina superior izquierda de Laika

  PetController get c => widget.controller;

  final _petKey = GlobalKey();
  final _chatKey = GlobalKey();
  final _statusKey = GlobalKey();
  List<Rect> _lastRegions = const [];

  bool _hasText = false;
  bool _menuOpen = false; // el del (+)
  bool _langOpen = false;
  late final VoiceRecorder _rec = widget.media.recorder();

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      c.composing(has);
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() {
      if (!_focus.hasFocus) c.composing(false);
    });
  }

  void _reportRegions() {
    final cb = widget.onRegions;
    if (cb == null || !mounted) return;
    final rects = <Rect>[];
    for (final k in c.hiddenForShot ? const <GlobalKey>[] : [_petKey, _chatKey, _statusKey]) {
      final box = k.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.width > 1 && box.size.height > 1) {
        rects.add((box.localToGlobal(Offset.zero) & box.size).inflate(4));
      }
    }
    // El chat solo cuenta si está visible.
    if (!c.isAwake && !c.hiddenForShot && rects.length > 1) rects.removeAt(1);
    bool same(List<Rect> a, List<Rect> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if ((a[i].topLeft - b[i].topLeft).distance > 1 || (a[i].size - b[i].size as Offset).distance > 1) return false;
      }
      return true;
    }
    if (same(rects, _lastRegions)) return;
    _lastRegions = rects;
    cb(rects);
  }

  bool _wasOpen = false;

  void _changed() {
    if (!mounted) return;
    if (c.chatOpen && !_wasOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
    _wasOpen = c.chatOpen;
    if (!c.chatOpen) _menuOpen = _langOpen = false;
    setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _rec.cancel();
    _anim.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (c.recordingVoice) {
      _sendVoice();
      return;
    }
    final t = _text.text;
    _text.clear();
    c.send(t);
    _focus.requestFocus();
  }

  Future<void> _pickFile() async {
    setState(() => _menuOpen = false);
    final path = await widget.media.pickFile();
    if (path != null) await c.attach(path);
  }

  /// Laika se esconde, eliges un rectángulo (Spectacle) y se lo da.
  Future<void> _screenshot() async {
    setState(() => _menuOpen = false);
    c.hide(true);
    await Future<void>.delayed(const Duration(milliseconds: 350)); // que ya no salga en pantalla
    String? path;
    try {
      path = await widget.media.screenshotRegion();
    } on MediaError catch (e) {
      c.notice('⚠️ ${e.message}');
    } finally {
      c.hide(false);
    }
    if (path != null) await c.attach(path, screenshot: true);
  }

  Future<void> _mic() async {
    setState(() => _menuOpen = _langOpen = false);
    if (!widget.media.supported) {
      c.notice('🎤 Las notas de voz por ahora solo funcionan en Linux.');
      return;
    }
    try {
      await _rec.start();
      c.setRecording(true);
    } on MediaError catch (e) {
      c.notice('⚠️ ${e.message}');
    }
  }

  Future<void> _sendVoice() async {
    final path = await _rec.stop();
    c.setRecording(false);
    if (path == null) {
      c.notice('🎤 No se oyó nada.');
    } else {
      await c.sendVoice(path);
    }
  }

  Future<void> _cancelRecording() async {
    await _rec.cancel();
    c.setRecording(false);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    if (widget.onRegions != null) WidgetsBinding.instance.addPostFrameCallback((_) => _reportRegions());
    return LayoutBuilder(builder: (context, box) {
      if (c.hiddenForShot) {
        if (widget.onRegions != null) WidgetsBinding.instance.addPostFrameCallback((_) => _reportRegions());
        return const SizedBox.expand();
      }
      // También al cambiar el tamaño de la ventana (en --pet arranca en 1280×800 y
      // luego cubre la pantalla): si no, la zona de clics se queda en otro lado.
      if (widget.onRegions != null) WidgetsBinding.instance.addPostFrameCallback((_) => _reportRegions());
      final w = box.maxWidth, h = box.maxHeight;
      final size = skin.petSize;
      final pos = _clamp(_pos ?? Offset(w - size - 48, h - size - 64), w, h, size);
      final petOnRight = pos.dx + size / 2 > w / 2;
      const gap = 14.0;
      final room = petOnRight ? pos.dx - gap - 8 : w - (pos.dx + size + gap) - 8;
      final chatW = room.clamp(140.0, skin.chatWidth);
      final chatLeft = petOnRight ? pos.dx - gap - chatW : pos.dx + size + gap;
      final anchorTop = pos.dy + size / 2 < h * 0.35;

      final chat = AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: c.isAwake ? 1 : 0,
        child: IgnorePointer(
          ignoring: !c.isAwake,
          child: MouseRegion(
            onHover: (_) => c.touch(),
            child: SizedBox(
              key: _chatKey,
              width: chatW,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  final t = _watch.elapsedMilliseconds / 1000;
                  final cross = petOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                  final n = c.bubbles.length;
                  final now = c.now();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: cross,
                    children: [
                      for (var i = 0; i < n; i++)
                        Padding(
                          key: ValueKey(c.bubbles[i].id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _Appear(
                            child: Opacity(
                              opacity: c.bubbles[i].opacityAt(now),
                              child: skin.bubble(context, c.bubbles[i].text,
                                  petOnRight: petOnRight, age: n - 1 - i),
                            ),
                          ),
                        ),
                      if (c.typing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: skin.typing(context, t, petOnRight: petOnRight),
                        ),
                      if (c.lastMine != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: skin.mine(context, c.lastMine!, petOnRight: petOnRight),
                        ),
                      // Un clic sobre Laika abre la caja; si no, solo se ven sus mensajes.
                      if (c.chatOpen) ...[
                        if (_langOpen)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final e in practiceLangs.entries)
                                skin.chip(context, e.value, selected: e.key == c.lang, onTap: () {
                                  setState(() => _langOpen = false);
                                  c.setLang(e.key);
                                }),
                            ]),
                          ),
                        if (_menuOpen)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: skin.menu(context, [
                              MenuEntry(Icons.description_outlined, 'Archivo', _pickFile),
                              MenuEntry(Icons.screenshot_monitor_outlined, 'Captura de pantalla', _screenshot),
                            ]),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: skin.chip(context, '${(c.lang ?? '··').toUpperCase()} ▾', selected: _langOpen,
                              onTap: () => setState(() {
                                    _langOpen = !_langOpen;
                                    _menuOpen = false;
                                    c.touch();
                                  })),
                        ),
                        skin.composer(
                          context,
                          Composer(
                            text: _text,
                            focus: _focus,
                            onSend: _send,
                            onPlus: () => setState(() {
                              _menuOpen = !_menuOpen;
                              _langOpen = false;
                              c.touch();
                            }),
                            onMic: _mic,
                            onCancelRecording: _cancelRecording,
                            hasText: _hasText,
                            menuOpen: _menuOpen,
                            recordingFor: c.recordingSince == null ? null : now.difference(c.recordingSince!),
                          ),
                          petOnRight: petOnRight,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: skin.backdrop(context)),
          Positioned(
            left: chatLeft,
            top: anchorTop ? pos.dy : null,
            bottom: anchorTop ? null : h - (pos.dy + size),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: anchorTop ? h - pos.dy - 8 : pos.dy + size - 8),
              child: SingleChildScrollView(reverse: !anchorTop, child: chat),
            ),
          ),
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: size,
            height: size,
            child: MouseRegion(
              key: _petKey,
              cursor: SystemMouseCursors.grab,
              onEnter: (_) => c.hover(),
              onHover: (_) => c.touch(),
              child: GestureDetector(
                onTap: c.poke,
                onDoubleTap: widget.onOpenApp,
                onPanUpdate: (d) => setState(() {
                  _pos = _clamp(pos + d.delta, w, h, size);
                  c.touch();
                }),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) =>
                      skin.pet(context, c, _watch.elapsedMilliseconds / 1000),
                ),
              ),
            ),
          ),
          Positioned(
            left: pos.dx - 40,
            width: size + 80,
            top: pos.dy - 34,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Center(
                  child: KeyedSubtree(
                    key: _statusKey,
                    child: skin.status(context, c, _watch.elapsedMilliseconds / 1000) ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Offset _clamp(Offset p, double w, double h, double size) => Offset(
        p.dx.clamp(8.0, (w - size - 8).clamp(8.0, double.infinity)),
        p.dy.clamp(40.0, (h - size - 8).clamp(40.0, double.infinity)),
      );
}

/// Animación de entrada de cada burbuja.
class _Appear extends StatelessWidget {
  const _Appear({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
        ),
        child: child,
      );
}

/// Texto estándar para el estado (las variantes pueden usarlo).
String? statusText(PetController c) {
  if (c.wakeFailed) return 'el servidor no responde… zZz';
  if (c.state == PetState.waking) return 'preguntando al servidor…';
  if (c.state == PetState.asleep && c.pendingReminders.isNotEmpty) {
    return '🔔 ${c.pendingReminders.length}';
  }
  if (c.justLearned != null) return '🧠 guardado';
  return null;
}
