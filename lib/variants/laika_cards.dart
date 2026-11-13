// Diseño Laika — Tarjetas: hanzi con su lectura, agendados con FSRS.
// Mismo estilo que Guardados: cajas Brutal con colores Cristal; el pinyin y
// el carácter llevan el color de su tono.
//
// Solo la app: la mascota no muestra nada de tarjetas (decisión de Esteban).
// Lo que Laika cambia o sugiere aparece arriba, en la caja "Laika".

part of 'laika.dart';

const _cjk = 'Noto Sans CJK SC';
const _cjkFallback = ['Noto Sans CJK TC', 'Noto Sans CJK JP', 'Droid Sans Fallback'];

/// Tono 1–4 y neutro (5): color del texto y relleno pastel.
const _toneInk = {1: Color(0xFFD93636), 2: Color(0xFFC77700), 3: Color(0xFF168A4E), 4: Color(0xFF2F5FD0), 5: lSoft};
const _toneFill = {1: Color(0xFFFFE1E1), 2: Color(0xFFFFEFD2), 3: Color(0xFFD7F5E5), 4: Color(0xFFDDE7FF), 5: Color(0xFFF1EEF8)};

TextStyle _hz(double size, {Color color = lInk, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: _cjk, fontFamilyFallback: _cjkFallback, fontSize: size, fontWeight: w, color: color, height: 1.15);

const _ratingColor = {1: lPeach, 2: lLavender, 3: lMint, 4: lSky};

String _val(Object? v) => switch (v) {
      null => '—',
      true => 'sí',
      false => 'no',
      '' => '—',
      _ => '$v',
    };

String _label(String field) => Flashcard.fieldLabels[field] ?? field;

/// "1 nueva", "4 nuevas".
String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _when(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final diff = DateTime.now().difference(l);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return '${l.day}/${l.month}/${l.year}';
}

/// Cuándo toca: "para hoy", "en 3 d", "nueva", "pausada".
String _dueLabel(Flashcard c) {
  if (c.inTrash) return 'en la papelera';
  if (c.suspended) return 'pausada';
  if (c.schedule.isNew) return 'nueva';
  final due = c.schedule.dueAt;
  if (due == null || !due.isAfter(DateTime.now())) return 'para hoy';
  return 'en ${dueIn(due, DateTime.now())}';
}

/// Mensaje legible para errores de tarjetas.
String _cardWhy(Object e) => switch (e) {
      LaikaApiError(status: 404) => 'El servidor todavía no tiene tarjetas (o esa ya no existe)',
      LaikaApiError(status: 409, :final message) => message,
      LaikaApiError(status: 422, :final message, :final field?) => '$message (${_label(field)})',
      _ => _why(e),
    };

/// "cambió Significado: «a» → «b»" de un Edit.
List<String> _changeLines(CardEdit e) {
  if (e.proposesDeletion) return ['borrar la tarjeta'];
  if (e.op == 'review') return ['calificó: ${ratingLabels[e.after['rating']] ?? '?'}'];
  return [for (final f in e.fields) '${_label(f)}: ${_val(e.before[f])} → ${_val(e.after[f])}'];
}

Widget _hanziChip(CardRef? r, {double size = 22}) => r == null
    ? const SizedBox.shrink()
    : Text.rich(TextSpan(children: [
        TextSpan(text: r.front, style: _hz(size, w: FontWeight.w700)),
        TextSpan(text: ' ${r.reading}', style: _t(13, w: FontWeight.w700, color: _toneInk[toneOf(r.reading)]!)),
      ]));

// ── Pestaña ───────────────────────────────────────────────────────────────────

class LaikaCards extends StatefulWidget {
  const LaikaCards({super.key, required this.deck, this.media = const Media()});
  final DeckController deck;
  final Media media;
  @override
  State<LaikaCards> createState() => _LaikaCardsState();
}

class _LaikaCardsState extends State<LaikaCards> {
  final _front = TextEditingController();
  final _reading = TextEditingController();
  final _search = TextEditingController();
  bool _busy = false;

  DeckController get d => widget.deck;

  @override
  void initState() {
    super.initState();
    d.load();
  }

  @override
  void dispose() {
    _front.dispose();
    _reading.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) _toast(context, _cardWhy(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _undoToast(String text, int? editId) => _toast(context, text,
      action: editId == null ? null : 'Deshacer',
      onAction: editId == null ? null : () => _run(() async => d.undo(editId)));

  Future<void> _add() async {
    final front = _front.text.trim();
    if (front.isEmpty) return;
    final reading = _reading.text.trim();
    setState(() => _busy = true);
    try {
      final w = await d.create(front: front, reading: reading.isEmpty ? null : reading);
      _front.clear();
      _reading.clear();
      if (mounted) _undoToast('Agregada: ${w.card.front} ${w.card.reading} · ${w.card.meaning}', w.editId);
    } on LaikaApiError catch (e) {
      if (!mounted) return;
      final id = e.cardId;
      if (e.status == 409 && id != null) {
        _toast(context, 'Ya la tienes: $front${reading.isEmpty ? '' : ' $reading'}', action: 'Abrir', onAction: () => _open(id));
      } else {
        _toast(context, _cardWhy(e));
      }
    } catch (e) {
      if (mounted) _toast(context, _cardWhy(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(int id) => _showCard(context, d, id, media: widget.media);

  Future<void> _review() async {
    await showDialog<void>(
        context: context, barrierDismissible: false, builder: (_) => _ReviewDialog(deck: d, media: widget.media));
    await d.reviewed();
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [d],
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Tarjetas', style: _t(44, w: FontWeight.w900)),
          Text('Hanzi con su lectura. Laika los agenda; lo que tú corriges, ella ya no lo cambia: solo te lo sugiere.',
              style: _t(13, color: lSoft)),
          const SizedBox(height: 18),
          _studyBar(),
          if (d.suggestions.isNotEmpty || d.laikaChanges.isNotEmpty) ...[const SizedBox(height: 18), _laikaBox()],
          const SizedBox(height: 18),
          _addBox(),
          const SizedBox(height: 18),
          _searchBox(),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 14),
          ..._grid(),
        ],
      ),
    );
  }

  Widget _studyBar() {
    final n = d.counts;
    final study = n.toStudy;
    return Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      GestureDetector(
        onTap: study == 0 ? null : _review,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: brutalBox(study == 0 ? Colors.white : lMint),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(study == 0 ? Icons.celebration_rounded : Icons.style_rounded, color: lInk),
            const SizedBox(width: 10),
            Text(study == 0 ? 'Nada que repasar por ahora' : 'Repasar · $study', style: _t(18, w: FontWeight.w900)),
          ]),
        ),
      ),
      Text(
        '${n.due} para hoy · ${_n(n.newCards, 'nueva', 'nuevas')} (caben ${n.newLeftToday} hoy) · ${n.total} en total'
        '${n.suspended > 0 ? ' · ${_n(n.suspended, 'pausada', 'pausadas')}' : ''}',
        style: _t(13, w: FontWeight.w700, color: lSoft),
      ),
    ]);
  }

  Widget _laikaBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: brutalBox(lLavender),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Laika', style: _t(16, w: FontWeight.w900)),
          for (final s in d.suggestions) _feedRow(s, suggestion: true),
          for (final e in d.laikaChanges) _feedRow(e, suggestion: false),
        ]),
      );

  Widget _feedRow(CardEdit e, {required bool suggestion}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => _open(e.cardId), child: _hanziChip(e.card)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(suggestion ? 'Sugiere (es tuyo, decides tú):' : 'Cambió ${_when(e.at)}:', style: _t(12.5, w: FontWeight.w800)),
              for (final l in _changeLines(e)) Text(l, style: _t(13.5)),
              if (e.reason != null) Text('«${e.reason}»', style: _t(12, color: lSoft)),
            ]),
          ),
          const SizedBox(width: 8),
          if (suggestion) ...[
            _action('Aplicar', lMint, _busy ? null : () => _run(() async => d.answer(e, apply: true)), icon: Icons.check_rounded),
            const SizedBox(width: 6),
            _action('No', lPeach, _busy ? null : () => _run(() async => d.answer(e, apply: false))),
          ] else
            _action('Deshacer', Colors.white, _busy ? null : () => _run(() async => d.undo(e.id)), icon: Icons.undo_rounded),
        ]),
      );

  Widget _addBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: brutalBox(Colors.white),
        child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 72,
            child: TextField(
              controller: _front,
              style: _hz(30, w: FontWeight.w700),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: '爱', hintStyle: _hz(30, color: lSoft.withValues(alpha: 0.5))),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _reading,
              style: _t(15),
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                  isDense: true, border: const OutlineInputBorder(), labelText: 'Lectura (opcional)', hintText: 'ài', hintStyle: _t(14, color: lSoft)),
            ),
          ),
          _action(_busy ? 'Agregando…' : 'Agregar', lLavender, _busy ? null : _add, icon: Icons.add_rounded),
          Text('Escribe un carácter: Laika llena el pinyin y el significado.', style: _t(12.5, color: lSoft)),
        ]),
      );

  Widget _searchBox() => Container(
        decoration: brutalBox(Colors.white, shadow: 3),
        child: TextField(
          controller: _search,
          style: _t(14),
          onChanged: d.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(11),
            prefixIcon: const Icon(Icons.search_rounded, color: lInk),
            hintText: 'Buscar: 行, hang, banco, bank…',
            hintStyle: _t(14, color: lSoft),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: lInk),
                    onPressed: () {
                      _search.clear();
                      d.search('');
                    }),
          ),
        ),
      );

  Widget _filters() {
    final n = d.counts;
    String withCount(String f, String label) => switch (f) {
          'due' => '$label · ${n.due}',
          'new' => '$label · ${n.newCards}',
          'trash' => n.trash > 0 ? '$label · ${n.trash}' : label,
          'check' => (d.toCheck ?? n.suggestions) > 0 ? '$label · ${d.toCheck ?? n.suggestions}' : label,
          _ => label,
        };
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final MapEntry(key: f, value: label) in DeckController.filters.entries)
        _chip(withCount(f, label), f == 'trash' ? lPeach : (f == 'check' ? lPink : lLavender), d.filter == f, () => d.setFilter(f)),
    ]);
  }

  List<Widget> _grid() {
    if (d.loading && d.cards.isEmpty) return [const Center(child: CircularProgressIndicator())];
    final err = d.error;
    final list = d.visible;
    return [
      if (err != null) Text(err.contains('404') ? 'El servidor todavía no tiene tarjetas.' : err, style: _t(13, color: Colors.red.shade700)),
      if (list.isEmpty && err == null)
        Text(d.query.isEmpty ? 'Nada aquí.' : 'Nada con «${d.query}».', style: _t(13, w: FontWeight.w700, color: lSoft)),
      Wrap(spacing: 14, runSpacing: 14, children: [for (final c in list) _tile(c)]),
    ];
  }

  Widget _tile(Flashcard c) {
    final ink = _toneInk[c.tone]!;
    return GestureDetector(
      onTap: () => _open(c.id),
      child: Container(
        width: 196,
        padding: const EdgeInsets.all(12),
        decoration: brutalBox(c.suspended || c.inTrash ? Colors.white : _toneFill[c.tone]!, shadow: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.front, style: _hz(42, color: ink, w: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.reading, style: _t(17, w: FontWeight.w800, color: ink)),
                if (c.word != null) Text(c.word!, style: _hz(15)),
              ]),
            ),
            Column(children: [
              if (c.suggestions.isNotEmpty) const Tooltip(message: 'Laika sugiere un cambio', child: Text('💡')),
              if (c.checkMeaning) const Tooltip(message: 'Revisa el significado en inglés', child: Text('⚠️')),
              if (c.locked.isNotEmpty) Tooltip(
                  message: 'Tuyo: ${c.locked.map(_label).join(', ')}', child: const Icon(Icons.lock_rounded, size: 15, color: lInk)),
            ]),
          ]),
          const SizedBox(height: 6),
          Text(c.meaning, style: _t(13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: brutalBox(Colors.white, shadow: 0, border: 1.5),
                child: Text(_dueLabel(c), style: _t(11.5, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const Spacer(),
            if (c.byLaika)
              Flexible(
                flex: 2,
                child: Text('de Laika',
                    style: _t(11.5, w: FontWeight.w700, color: lAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ── Una tarjeta: ver, editar, historial ─────────────────────────────────────

Future<Flashcard?> _showCard(BuildContext context, DeckController deck, int id, {Media media = const Media()}) =>
    showDialog<Flashcard>(context: context, builder: (_) => _CardDialog(deck: deck, id: id, media: media));

class _CardDialog extends StatefulWidget {
  const _CardDialog({required this.deck, required this.id, required this.media});
  final DeckController deck;
  final int id;
  final Media media;
  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  static const _textFields = ['word', 'reading', 'meaning_es', 'meaning_en', 'note'];

  Flashcard? _card;
  List<CardEdit> _history = [];
  final Map<String, TextEditingController> _ctl = {};
  final Set<String> _unlock = {};
  bool _suspended = false;
  bool _busy = false;
  String? _error;

  DeckController get d => widget.deck;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({String? error}) async {
    try {
      final (c, h) = await d.api.card(widget.id);
      if (!mounted) return;
      setState(() {
        _card = c;
        _history = h;
        _suspended = c.suspended;
        _unlock.clear();
        for (final f in _textFields) {
          (_ctl[f] ??= TextEditingController()).text = _val(c.field(f)) == '—' ? '' : '${c.field(f)}';
        }
        _error = error;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _cardWhy(e));
    }
  }

  Map<String, Object?> _changes(Flashcard c) => {
        for (final f in _textFields)
          if (c.editable.contains(f) && _ctl[f]!.text.trim() != (c.field(f) ?? '').toString())
            f: f == 'word' && _ctl[f]!.text.trim().isEmpty ? null : _ctl[f]!.text.trim(),
        if (c.editable.contains('suspended') && _suspended != c.suspended) 'suspended': _suspended,
      };

  Future<void> _save() async {
    final c = _card!;
    setState(() => _busy = true);
    try {
      final w = await d.save(c, _changes(c), unlock: _unlock.toList());
      if (!mounted) return;
      Navigator.pop(context, w?.card ?? c);
      if (w?.editId != null) {
        _toast(context, 'Guardado: ${w!.card.front} ${w.card.reading}', action: 'Deshacer', onAction: () {
          d.undo(w.editId!).ignore();
        });
      }
    } on LaikaApiError catch (e) {
      if (e.status == 409 && e.cardId == c.id) {
        await _load(error: 'Cambió mientras la editabas (¿Laika?). Ya se recargó: revisa y guarda otra vez.');
      } else if (e.status == 409 && e.cardId != null) {
        setState(() => _error = 'Esa lectura ya está en otra tarjeta (${e.cardId}).');
      } else {
        setState(() => _error = _cardWhy(e));
      }
    } catch (e) {
      setState(() => _error = _cardWhy(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _do(Future<CardWrite> Function() job, {bool close = false, String? done}) async {
    setState(() => _busy = true);
    try {
      final w = await job();
      if (!mounted) return;
      if (close) {
        Navigator.pop(context, w.card);
        if (done != null) {
          _toast(context, done, action: w.editId == null ? null : 'Deshacer', onAction: () {
            d.undo(w.editId!).ignore();
          });
        }
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _cardWhy(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _play() async {
    try {
      final path = await d.api.cardAudio(widget.id);
      if (path == null) {
        if (mounted) _toast(context, 'Esta tarjeta todavía no tiene audio');
        return;
      }
      await widget.media.play(path);
    } on MediaError catch (e) {
      if (mounted) _toast(context, e.message);
    } catch (e) {
      if (mounted) _toast(context, _cardWhy(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 660,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(20),
        decoration: brutalBox(Colors.white, shadow: 8),
        child: c == null
            ? SizedBox(
                height: 160,
                child: Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!, style: _t(14))))
            : SingleChildScrollView(child: _body(c)),
      ),
    );
  }

  Widget _field(Flashcard c, String f, {int maxLines = 1}) {
    final locked = c.isLocked(f) && !_unlock.contains(f);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            controller: _ctl[f],
            enabled: c.editable.contains(f) && !_busy,
            minLines: 1,
            maxLines: maxLines,
            style: f == 'word' ? _hz(18) : _t(15),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: f == 'note' ? 'Tu nota (Laika no la toca)' : _label(f),
              suffixIcon: locked ? const Tooltip(message: 'Tuyo: Laika ya no lo cambia', child: Icon(Icons.lock_rounded, size: 18)) : null,
            ),
          ),
        ),
        if (c.isLocked(f)) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _action(_unlock.contains(f) ? 'Mejor no' : 'Devolver a Laika', Colors.white,
                _busy ? null : () => setState(() => _unlock.contains(f) ? _unlock.remove(f) : _unlock.add(f))),
          ),
        ],
      ]),
    );
  }

  Widget _body(Flashcard c) {
    final ink = _toneInk[c.tone]!;
    final mine = d.suggestions.where((s) => s.cardId == c.id).toList();
    final s = c.schedule;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 104,
          height: 104,
          alignment: Alignment.center,
          decoration: brutalBox(_toneFill[c.tone]!, shadow: 4),
          child: Text(c.front, style: _hz(68, color: ink, w: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.reading, style: _t(28, w: FontWeight.w900, color: ink)),
            if (c.word != null) Text(c.word!, style: _hz(20)),
            if (c.parts.isNotEmpty) Text('Partes: ${c.parts.join(' ')}', style: _hz(14, color: lSoft)),
            const SizedBox(height: 4),
            Text('${s.label} · ${_dueLabel(c)}${s.difficulty != null ? ' · dificultad ${s.difficulty!.toStringAsFixed(1)}' : ''}',
                style: _t(12.5, w: FontWeight.w700, color: lSoft)),
            Text('${c.createdBy == CardWho.him ? 'La agregaste tú' : 'La agregó Laika'}${c.source.startsWith('book:') ? ' (de un libro)' : ''}',
                style: _t(12, color: lSoft)),
          ]),
        ),
        IconButton(tooltip: 'Escuchar', onPressed: _play, icon: const Icon(Icons.volume_up_rounded)),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
      ]),
      if (c.checkMeaning)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(10),
          decoration: brutalBox(lPeach, shadow: 2, border: 1.8),
          child: Text('⚠️ El significado en inglés que puso Laika no coincide con el diccionario. Revísalo y guárdalo: así queda tuyo.',
              style: _t(13)),
        ),
      for (final sug in mine)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(10),
          decoration: brutalBox(lLavender, shadow: 2, border: 1.8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💡 Laika sugiere:', style: _t(13, w: FontWeight.w800)),
                for (final l in _changeLines(sug)) Text(l, style: _t(13.5)),
                if (sug.reason != null) Text('«${sug.reason}»', style: _t(12, color: lSoft)),
              ]),
            ),
            _action('Aplicar', lMint, _busy ? null : () => _do(() => d.answer(sug, apply: true), close: sug.proposesDeletion)),
            const SizedBox(width: 6),
            _action('No', lPeach, _busy ? null : () => _do(() => d.answer(sug, apply: false))),
          ]),
        ),
      if (c.knownWords.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final w in c.knownWords)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: brutalBox(Colors.white, shadow: 0, border: 1.5),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: w.word, style: _hz(15, w: FontWeight.w700)),
                TextSpan(text: ' ${w.reading} · ${w.gloss}', style: _t(12.5)),
              ])),
            ),
        ]),
      ],
      const Divider(height: 28),
      if (c.inTrash) ...[
        Text('Está en la papelera (se borra sola a los 30 días).', style: _t(13, w: FontWeight.w700)),
        const SizedBox(height: 10),
        _action('Recuperar', lMint, _busy ? null : () => _do(() => d.restore(c)), icon: Icons.restore_rounded),
      ] else ...[
        Text('Editar', style: _t(14, w: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final f in ['reading', 'word', 'meaning_es', 'meaning_en']) _field(c, f),
        _field(c, 'note', maxLines: 4),
        if (c.editable.contains('suspended'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Switch(value: _suspended, onChanged: _busy ? null : (v) => setState(() => _suspended = v)),
              const SizedBox(width: 8),
              Text('Pausada (no sale en el repaso)', style: _t(14)),
            ]),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: _t(13, color: Colors.red.shade700))),
        Row(children: [
          _action(_busy ? 'Guardando…' : 'Guardar', lLavender, _busy ? null : _save, icon: Icons.check_rounded),
          const Spacer(),
          _action('A la papelera', lPeach, _busy ? null : () => _do(() => d.remove(c), close: true, done: 'A la papelera: ${c.front} ${c.reading}'),
              icon: Icons.delete_outline_rounded),
        ]),
      ],
      if (_history.isNotEmpty) ...[
        const Divider(height: 28),
        Text('Historial', style: _t(14, w: FontWeight.w900)),
        for (final e in _history.where((e) => e.op != 'review' || e.undoable).take(30))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e.who.label} ${e.opLabel} · ${_when(e.at)}'
                      '${e.undoneAt != null ? ' · deshecho' : ''}${e.status == 'dismissed' ? ' · no la aceptaste' : ''}'
                      '${e.status == 'applied' ? ' · la aceptaste' : ''}',
                      style: _t(12.5, w: FontWeight.w800, color: e.undoneAt != null ? lSoft : lInk)),
                  if (e.op != 'create') for (final l in _changeLines(e)) Text(l, style: _t(13)),
                  if (e.reason != null) Text('«${e.reason}»', style: _t(12, color: lSoft)),
                ]),
              ),
              // Deshacer "creó" = mandarla a la papelera: para eso está el botón de arriba.
              if (e.undoable && e.op != 'create')
                _action('Deshacer', Colors.white, _busy ? null : () => _do(() => d.undo(e.id)), icon: Icons.undo_rounded),
            ]),
          ),
      ],
    ]);
  }
}

// ── Repaso ─────────────────────────────────────────────────────────────────────

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.deck, required this.media});
  final DeckController deck;
  final Media media;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final ReviewSession r = ReviewSession(widget.deck.api)..start();
  final _focus = FocusNode();

  @override
  void dispose() {
    r.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      if (r.revealed) {
        r.rate(3);
      } else {
        r.reveal();
      }
      return KeyEventResult.handled;
    }
    final digits = {
      LogicalKeyboardKey.digit1: 1,
      LogicalKeyboardKey.digit2: 2,
      LogicalKeyboardKey.digit3: 3,
      LogicalKeyboardKey.digit4: 4,
    };
    if (digits[k] case final n?) {
      r.rate(n);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyU) {
      r.undoLast();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _edit(Flashcard c) async {
    final updated = await _showCard(context, widget.deck, c.id, media: widget.media);
    if (updated != null && r.current?.id == updated.id) {
      r.queue = [updated, ...r.queue.skip(1)];
      setState(() {});
    }
    _focus.requestFocus();
  }

  Future<void> _play(Flashcard c) async {
    try {
      final path = await widget.deck.api.cardAudio(c.id);
      if (path != null) await widget.media.play(path);
    } catch (_) {
      // Sin audio no pasa nada: el repaso sigue.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(22),
          decoration: brutalBox(Colors.white, shadow: 8),
          child: Watch(listenables: [r], builder: (context) => _body()),
        ),
      ),
    );
  }

  Widget _body() {
    final c = r.current;
    final header = Row(children: [
      Text('Repaso', style: _t(20, w: FontWeight.w900)),
      const SizedBox(width: 12),
      Expanded(
        child: Text('${r.done} hechas${r.queue.isEmpty ? '' : ' · faltan ${r.queue.length}'}',
            style: _t(13, w: FontWeight.w700, color: lSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      if (r.last != null)
        _action('Deshacer (U)', Colors.white, r.sending ? null : r.undoLast, icon: Icons.undo_rounded),
      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
    ]);
    if (r.loading) return Column(mainAxisSize: MainAxisSize.min, children: [header, const SizedBox(height: 40), const CircularProgressIndicator(), const SizedBox(height: 40)]);
    if (c == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        header,
        const SizedBox(height: 30),
        Text(r.error != null ? _cardWhy(r.error!) : '¡Listo por ahora! 🎉', style: _t(26, w: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(r.done == 0 ? 'No hay nada que repasar.' : 'Repasaste ${r.done}. Las que estás aprendiendo vuelven en unos minutos.',
            style: _t(14, color: lSoft)),
        const SizedBox(height: 30),
      ]);
    }
    final ink = _toneInk[c.tone]!;
    final word = c.word;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 18),
      Center(child: Text(c.front, style: _hz(120, color: r.revealed ? ink : lInk, w: FontWeight.w700))),
      if (word != null)
        Center(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'en ', style: _t(15, color: lSoft)),
            for (final ch in word.split(''))
              TextSpan(text: ch, style: _hz(24, color: ch == c.front ? lAccent : lInk, w: ch == c.front ? FontWeight.w900 : FontWeight.w500)),
          ])),
        ),
      const SizedBox(height: 16),
      if (!r.revealed)
        Center(child: _action('Mostrar (espacio)', lLavender, r.reveal, icon: Icons.visibility_rounded))
      else ...[
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(c.reading, style: _t(34, w: FontWeight.w900, color: ink)),
            IconButton(tooltip: 'Escuchar', onPressed: () => _play(c), icon: const Icon(Icons.volume_up_rounded)),
          ]),
        ),
        Center(child: Text(c.meaningEs, style: _t(18, w: FontWeight.w700), textAlign: TextAlign.center)),
        if (c.meaningEn.isNotEmpty) Center(child: Text(c.meaningEn, style: _t(14, color: lSoft), textAlign: TextAlign.center)),
        if (c.knownWords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(c.knownWords.map((w) => '${w.word} ${w.reading} · ${w.gloss}').join('   '),
                  style: _hz(14, color: lSoft), textAlign: TextAlign.center),
            ),
          ),
        if (c.note.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text('📝 ${c.note}', style: _t(13.5)))),
        const SizedBox(height: 18),
        Row(children: [
          for (final n in [1, 2, 3, 4]) ...[
            Expanded(
              child: GestureDetector(
                onTap: r.sending ? null : () => r.rate(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: brutalBox(_ratingColor[n]!, shadow: 3),
                  child: Column(children: [
                    Text('${ratingLabels[n]}', style: _t(15, w: FontWeight.w900)),
                    Text('$n · ${r.previewFor(n) ?? '—'}', style: _t(12, w: FontWeight.w700, color: lSoft)),
                  ]),
                ),
              ),
            ),
            if (n < 4) const SizedBox(width: 10),
          ],
        ]),
      ],
      if (r.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('${_cardWhy(r.error!)} — vuelve a calificarla: no se cuenta dos veces.', style: _t(13, color: Colors.red.shade700)),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('Teclas: espacio = mostrar / Bien · 1–4 = calificar · U = deshacer', style: _t(11.5, color: lSoft))),
        const SizedBox(width: 12),
        GestureDetector(onTap: () => _edit(c), child: Text('Corregir esta tarjeta', style: _t(12.5, w: FontWeight.w700, color: lAccent))),
      ]),
    ]);
  }
}
