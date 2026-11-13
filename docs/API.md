# Contrato con el servidor (vista desde la app)

La referencia completa la mantiene el servidor en
[`EstebanSantiag0/laika` → `docs/API.md`](https://github.com/EstebanSantiag0/laika/blob/main/docs/API.md).
Aquí está lo que la app usa y cómo lo implementa `MockLaika`.

**Base:** `https://cc-server.<tailnet>.ts.net` (solo dentro de Tailscale).
**Autenticación:** la pone `tailscale serve` (cabecera `tailscale-user-login`).
Sin ella: `403` (WebSocket: cierre `4403`). `/health` es abierto.

## GET /health

```json
{"ok": true, "llm": true, "telegram": true}
```

La mascota despierta solo si `ok && llm`. Timeout en la app: 4 s.

## GET /api/graph?scope=active|all

```json
{
  "generated_at": "ISO", "scope": "all",
  "areas": [{"id": "study", "name": "Estudios", "color": "#5B8DEF"}],
  "nodes": [{
    "id": "fact:93", "kind": "area|entity|fact|episode|reminder",
    "label": "≤ 60 caracteres", "text": "completo",
    "areas": ["projects"],
    "time_scope": "permanent|stage|dated|reminder|archived",
    "valid_from": null, "valid_to": null, "due_at": null,
    "importance": 0.4, "created_at": "ISO",
    "subkind": "goal", "sensitive": false, "status": null
  }],
  "edges": [{"source": "fact:93", "target": "entity:12",
             "kind": "about|related|in_area|in_episode|similar", "weight": 0.8}]
}
```

- `subkind`: entidades `person|place|thing|topic|work`; datos `identity|habit|opinion|event|goal|preference|relationship|language|worry|us|laika_self`.
- `sensitive`: la app los oculta por defecto ("🔒 privado").
- `status`: solo recordatorios.
- `review_after` (`"YYYY-MM-DD"`): solo datos de *etapa actual*; desde ese día Laika pregunta si sigue siendo cierto.
- **Áreas:** vienen de `config.yaml` del servidor (los `id` son estables; nombre y color se pueden cambiar).
  Hay un nodo `kind: "area"` por área (`id: "area:<id>"`) y aristas `in_area` hacia él. La app **no** los
  dibuja como recuerdos: cada diseño muestra las áreas a su manera (zonas, rebanadas, cuartos).
- Datos: hasta 2 áreas. Entidades y conversaciones: las 2 áreas más comunes de sus datos. Algunos nodos traen `[]`.
- `scope=active` no incluye lo archivado; la app pide `all` y filtra con el botón "Ver archivados".

## GET /api/reminders?status=pending|all

`pending` = todo lo no hecho (pending, delivered, snoozed), ordenado por `due_at`.

```json
[{"id": 1, "text": "Pagar la renta", "due_at": "2026-11-06T17:00:00-06:00",
  "status": "pending|delivered|snoozed|done", "areas": [],
  "source_message_id": 788, "time_defaulted": false,
  "created_at": "ISO", "delivered_at": null, "done_at": null, "snoozes": 0}]
```

- `POST /api/reminders/{id}/done` → Reminder
- `POST /api/reminders/{id}/snooze` `{"minutes": 60}` (1–43200) → Reminder
- No hay POST para crear: los recordatorios nacen en el chat ("recuérdame…").

## WebSocket /ws

Servidor → app (los que usa la app):

| type | Uso en la app |
|---|---|
| `message` | `{"message": {id, ts, role, channel, text, lang, audio_path, batch_id, status, meta, episode_id}}`. Cada burbuja de Laika es un `message` aparte con `role: "companion"`; las correcciones llegan con `role: "correction"` y `meta.corrections[{original, better, why}]`; los avisos de recordatorio, como `role: "system"` con `meta.reminder.id`; tu propio mensaje vuelve como eco (`role: "user"`, `meta.client_id`); `update: true` = reemplaza un mensaje ya mostrado |
| `typing` / `typing_stop` | `typing` antes de cada burbuja; `typing_stop` cierra la tanda de respuestas |
| `reminder` | `{"reminder": {...}}` al crear, avisar (`status: delivered`), hecho y pospuesto |
| `error` | `{"text": "..."}` |

También existen `read`, `recording`, `audio`, `audio_failed`, `file`, `settings`.

App → servidor:

```json
{"type": "message", "text": "…", "client_id": "uuid"}
{"type": "typing", "active": true, "draft": true, "recording": false}
```

> Laika **no responde mientras la app diga que estás escribiendo**: al enviar
> o al salir de la caja de texto hay que mandar `{"type":"typing","active":false}`.

- **Sin repetición al reconectar:** lo que llegó mientras no había conexión se
  pide con `GET /api/history?limit=50&before=<id>`.
- **Autenticación:** la cabecera `tailscale-user-login` que añade `tailscale serve`.
  Sin ella: HTTP 403 y el WebSocket se cierra con código 4403. `/health` es abierto.

## Correspondencia en el código

| API | Dart |
|---|---|
| `/health` | `LaikaApi.health()` → `Health` |
| `/api/graph` | `LaikaApi.graph()` → `MemoryGraph` |
| `/api/reminders` | `LaikaApi.reminders()` → `List<Reminder>` |
| done / snooze | `LaikaApi.markDone()` / `snooze()` |
| `/ws` | `LaikaApi.events` (`BubbleEvent`, `TypingEvent`, `ReminderEvent`, `MemoryEvent`, `LibraryEvent`, `ItemEvent`) y `send()` |
| `/api/resurface` | `LaikaApi.resurface()` → `List<Item>` (segundo cerebro, plan SB7; acepta `[...]` o `{items: [...]}`; si falla, lista vacía) |

Segundo cerebro (en vivo desde SB7/SB7b; probado con `tool/live_test.dart`, ver abajo):
- `{"type": "item", "item": {...}}` por `/ws` → `ItemEvent`. Un `kind` desconocido se lee como `saved`.
- Los avisos de la biblioteca (`role: "system"`, texto que empieza con `📚`) → `LibraryEvent` (Laika come).

| Endpoint | En la app |
|---|---|
| `GET /api/items` (`kind`, `status`, `tag`, `before`, `limit`) | `items()` → `ItemPage` (`next_before` para paginar) |
| `GET/PATCH /api/items/{id}` | `item()` / `patchItem()` (`base_updated_at` se manda tal cual llegó; si cambió → 409) |
| `POST /api/items` `{text}` o `{url}` | `createItem()` → `(Item, SaveResult)` |
| `POST /api/items/upload` (multipart, campo `file`) | `uploadItem()` → `(Item, SaveResult)` |
| `POST /api/items/{id}/resurface` | `resurfaceAction()` (`done`, `later`, …) |
| `GET /api/items/{id}/page/{n}.png`, `/file` | `pageImage()`, `fileUrl()` |
| `GET /api/search?q=` | `search()` → `List<SearchHit>` (con páginas: "p. 3–4") |
| `GET /api/tags`, `GET/PATCH /api/likes` | `tags()`, `likes()`, `patchLike()` |
| `PATCH/DELETE /api/nodes/{id}`, `POST …/restore` | `patchNode()`, `deleteNode(withFacts, dryRun)`, `restoreNode()` |
| `POST/PATCH/DELETE /api/edges`, `…/restore` | `createEdge()`, `patchEdge()`, `deleteEdge()`, `restoreEdge()` |
| `GET /api/trash` | `trash()` → `Trash` |

Desde la caja de la mascota:
| Endpoint | En la app |
|---|---|
| `GET/PUT /api/settings` | `settings()` / `updateSettings({practice_lang})`: chip de idioma (en, ru, zh). UNA lectura al abrir la caja tras despertar; el evento WS `settings` lo mantiene al día |
| `POST /api/voice` (multipart `file`, ≤ 20 MB) | `sendVoice()`: nota de voz `voz.ogg` (Opus); se transcribe y entra al chat; la respuesta llega por `/ws` |
| `{"type":"typing","recording":true}` | `recording(true)` cada ~2 s mientras grabas (Laika no contesta mientras) |
| `POST /api/items` con `comment=true` | `uploadItem(…, comment: true)`: archivos y capturas desde la mascota. Se guarda igual (201/200/restored) y, aparte, entra al chat "📎 <título>" y Laika lo comenta (texto OCR de una imagen; resumen o inicio de un documento). Servidor d61edda |

`SaveResult` al guardar:
- `201` → `created` ("Guardado como …").
- `200 {duplicate: true}` → `duplicate` ("Ya lo tenías guardado").
- `201 {restored: true}` → `restored`: el mismo archivo o URL estaba en la papelera y **volvió** con el mismo id
  ("Estaba en la papelera: «…» volvió"; en el chat llega "📚 «…» was in the trash: it's back").

Errores: `{error, field?, max_mb?, node_id?}` → `LaikaApiError` (404, 409 conflicto, 413 archivo grande, 422 campo).
`base_updated_at` se compara como instante (cualquier zona horaria); si no es una fecha → 422 `field=base_updated_at`.

## Tarjetas (acordado con cc-server el 2026-11-13; en vivo desde las 12:31)

Fuente de verdad: `docs/API.md` → "Flashcards" del servidor. Probado con `tool/cards_live_test.dart` (fase 1: 11/11).
Sin servidor configurado, la app usa el simulado (`lib/core/mock_cards.dart`). **Solo la app**: la mascota ignora
el evento `card` y las líneas 🃏 del chat (decisión de Esteban).

Una tarjeta = un carácter chino en una lectura (`kind: "hanzi"`), agendada con FSRS (py-fsrs). Reglas:
- `note` es solo de Esteban; Laika nunca la escribe.
- Lo que Esteban manda en PATCH queda en `locked`: Laika ya no lo cambia, solo lo **sugiere** (Edit `op: "suggest"`,
  `status: pending|applied|dismissed`, `after` = lo propuesto; `{"deleted": true}` = propone borrarla).
- Toda escritura devuelve `{card, edit_id}` (para "Deshacer").

| Endpoint | En la app |
|---|---|
| `GET /api/cards?filter=all\|due\|new\|his\|hers\|hard\|trash&q=&before=&limit=` (≤ 500) | `cards()` → `CardPage` (`cards`, `next_before`, `counts`). La app pide todo de una vez y busca aquí |
| `GET /api/cards/{id}` → `{card, history: [Edit]}` | `card()` |
| `POST /api/cards {front, reading?, word?, meaning_es?, meaning_en?, note?}` | `createCard()`; el servidor llena lo que falta. 409 `{error, card_id}` si ya existe (si estaba en la papelera, vuelve) |
| `PATCH /api/cards/{id} {campos de editable, base_updated_at?, unlock?: [campos]}` | `patchCard()`; 409 si cambió o si la lectura ya existe (`card_id`); 422 lectura que el carácter no tiene. Cambiar la lectura conserva la agenda |
| `DELETE /api/cards/{id}`, `POST …/restore` | `deleteCard()`, `restoreCard()` (papelera de 30 días) |
| `GET /api/cards/due?limit=` → `{cards (con preview 1–4), now, counts}` | `dueCards()`: repasos + nuevas hasta `cards.new_per_day` (10) |
| `POST /api/cards/{id}/review {rating 1–4, client_id, duration_ms?, reviewed_at?}` | `reviewCard()`; idempotente por `client_id`; el repaso es un Edit `op: "review"` (se deshace) |
| `POST /api/cards/edits/{id}/undo` | `undoCardEdit()`; 409 si un cambio posterior tocó lo mismo |
| `POST /api/cards/suggestions/{id} {apply}` | `answerSuggestion()` (Aplicar / No) |
| `GET /api/cards/edits?who=&op=&pending=true&before=&limit=` | `cardEdits()` → `CardEditPage`; cada Edit trae `card: {id, front, reading, word}` |
| `GET /api/cards/{id}/audio` (ogg/opus; 202 `{retry_after}` si se está generando) | `cardAudio()` → archivo temporal; se oye con `pw-play` (o `ffplay`) |
| `GET /api/trash` | `Trash.cards` |
| `{"type":"card", op, who, card, edit_id?, counts}` por `/ws` | `CardEvent` (solo la pestaña Tarjetas) |

`Card`: `id, kind, front, word, reading, tone (1–5), meaning_es, meaning_en, note, known_words [{word, reading,
gloss_es, gloss_en}], parts, audio, source (him|laika|book:<id>), created_by, updated_by, created_at, updated_at,
locked, suspended, deleted_at, editable, schedule {due_at, state new|learning|review|relearning, stability,
difficulty, last_review_at}, suggestions [edit ids pendientes], flags (["check_meaning"])` y, solo en `/due`,
`preview {"1".."4": due_at}`. `counts`: `total, due, new, learning, suspended, trash, new_left_today, suggestions`.

Detalles del servidor en vivo: `POST /api/cards` siempre contesta 201 (también si recuperó una de la papelera) y
puede tardar unos segundos (el modelo escribe los significados; la app espera hasta 90 s). `reading` acepta "háng"
o "hang2". `note` nunca se bloquea. Un PATCH sin cambios → `edit_id: null`. Deshacer una edición también quita su
bloqueo. El repaso es un Edit con `after = {fsrs, rating}`; `client_id` es obligatorio (422 sin él). Todos los 409
traen `card_id`. Las líneas del chat empiezan con 🃏 (nunca 📚, así la mascota no las muestra). Una sugerencia
nueva llega por el WS como `op: "edited"` con el `edit_id` de la sugerencia.
