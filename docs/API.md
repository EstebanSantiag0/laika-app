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

Segundo cerebro (contrato propuesto en `docs/PLAN-second-brain.md` §5 del servidor, aún no en vivo):
- `{"type": "item", "item": {...}}` por `/ws` → `ItemEvent`. Un `kind` desconocido se lee como `saved`.
- Los avisos de la biblioteca (`role: "system"`, texto que empieza con `📚`) → `LibraryEvent` (Laika come).
