# Arquitectura de la app

## Visión general

```
┌──────────────────────── tu laptop (Linux) / tu teléfono (Android) ────────────────────────┐
│                                                                                            │
│   variants/*.dart  ── estilo (cómo se ve)                                                  │
│        │  usa                                                                              │
│   core/stage.dart  core/pet.dart  core/brain.dart  ── comportamiento (igual en todos)      │
│        │  habla con                                                                        │
│   core/api.dart (LaikaApi)                                                                 │
│        ├── MockLaika   (hoy: servidor simulado, sin red)                                   │
│        └── HttpLaika   (siguiente paso: HTTPS + WebSocket)                                 │
└───────────────────────────────────────────┬────────────────────────────────────────────────┘
                                            │ Tailscale (red privada)
                              https://cc-server.<tailnet>.ts.net
                                            │
┌───────────────────────────────────────────┴──────── cc-server ─────────────────────────────┐
│  app (FastAPI) · llm (Gemma 4 en llama.cpp) · embed · voice      repo: EstebanSantiag0/laika │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

La app **no guarda memoria propia**: todo vive en el servidor. La app solo
muestra y envía.

## Capas

| Capa | Archivos | Responsabilidad |
|---|---|---|
| Datos | `core/models.dart` | Clases que reflejan el JSON de la API (`MemoryGraph`, `MemoryNode`, `Reminder`, `Health`, eventos). |
| Acceso | `core/api.dart`, `core/mock_backend.dart` | `LaikaApi` es la única puerta al servidor. `MockLaika` la imita con datos ficticios de `sample_data.dart`. |
| Comportamiento | `core/pet.dart`, `core/stage.dart`, `core/brain.dart` | Reglas de la mascota, posición de burbujas, filtros del cerebro, agenda. |
| Acomodo | `core/layouts.dart` | Algoritmos para colocar nodos: esfera de Fibonacci, radial, fuerzas (Fruchterman–Reingold), cuartos, órbitas. Todos deterministas. |
| Estilo | `variants/*.dart` | Cada diseño implementa `PetSkin` (mascota, burbujas, caja de texto) y sus propias pantallas de Cerebro y Agenda. |

## La mascota (`PetController`)

```
           hover/tap                      /health ok && llm
 ┌────────┐ ───────► ┌────────┐ ─────────────────────────► ┌───────┐  envías  ┌──────────┐
 │ asleep │          │ waking │                            │ awake │ ───────► │ thinking │
 └────────┘ ◄─────── └────────┘                            └───────┘ ◄─────── └──────────┘
     ▲     sin respuesta / timeout 4 s                         │   respuesta lista
     └──────────────────────── 15 s sin interacción ───────────┘
```

- Cualquier interacción (mouse encima, escribir, recibir burbuja) reinicia los 15 s.
- Cada burbuja se queda su **tiempo de lectura** (`readingTime`: 3 s por palabra; cada carácter chino
  2 s + 3 s por palabra en pinyin o inglés; mínimo 3 s) y se desvanece en 1.5 s. El desvanecimiento es por
  tiempo, no por posición (lo pone `PetStage`, igual en todas las variantes).
- No se duerme hasta 15 s **después de que se desvanece la última burbuja** (Esteban, 2026-11-02).
- Al despertar, después del saludo, UNA petición a `/api/resurface`: si hay algo guardado que recordarte,
  lo dice con cara `impressed` (máximo uno al día). Si la ruta no existe, no pasa nada.
- No se duerme mientras espera una respuesta.
- Si el servidor deja de responder a media plática, se duerme.

### Emociones (`Mood`)

`PetController.mood` dice qué cara pone Laika. La skin en uso (`pets/skins.dart`,
elegida en Ajustes) la dibuja: por defecto `pets/circle_face.dart` (`CustomPainter`
en una caja de 100×100), o una imagen por emoción (formato en `docs/SKINS.md`).

### Ajustes (`core/config.dart`)

`~/.config/laika/config.json` → `{server, skin, petSize}`. La pestaña Ajustes lo
escribe (archivo temporal + rename); `--pet` y `--app` vigilan la carpeta con
inotify (`Directory.watch`, sin sondeo) y se actualizan al instante.

| Estado / evento | Cara |
|---|---|
| dormida (15 s) → acostada en su cojín (30 s) | `sleeping` |
| preguntando a `/health` | `waking` |
| despierta sin nada que hacer | `neutral` |
| esperando su respuesta / ella escribe | `thinking` |
| despierta bien | `greeting` (3.5 s) |
| llega una burbuja | `Mood.forText(texto)`: `laughing`, `inLove`, `crying`, `cheeky`, `doubting`, `impressed`, `scheming`, `greeting` o `happy` |
| corrección (`✏️`) / error (`⚠️`) | `cheeky` / `ashamed` |
| suena un recordatorio | `surprised` |
| se crea un recordatorio | `scheming` |
| aprendió algo (evento de memoria) | `impressed` |
| te recuerda algo guardado (`/api/resurface`) | `impressed` (5 s) |
| le llega un PDF, link o archivo (evento `item` nuevo o aviso `📚` de la biblioteca) | `eating` (4 s); si no pudo leerlo, `ashamed` |

Las reacciones duran 3.5 s y luego vuelve a `neutral`.

## El escritorio (`PetStage`)

- En los prototipos y en `--app` el "escritorio" se simula dentro de la ventana;
  con `--pet` es tu escritorio real (ver abajo).
- Regla de lado: `petOnRight = centroX(Laika) > anchoPantalla / 2`. Si es
  verdadero, la columna de chat (burbujas + caja de texto) se dibuja a la
  izquierda de Laika; si no, a la derecha.
- Si Laika está muy arriba, la columna se ancla hacia abajo desde su borde
  superior; si no, crece hacia arriba desde su borde inferior.

### Escritorio real en Linux (`--pet`) ✅

```
laika_app --pet
  └─ my_application.cc: ¿Wayland + gtk_layer_is_supported()?
       sí → capa TOP "laika-pet", anclada a los 4 bordes, zona exclusiva 0,
            teclado ON_DEMAND, fondo RGBA transparente, sin barra de título.
            Región de entrada vacía hasta que Dart diga otra cosa.
       no → ventana normal (LaikaApp con el escritorio simulado)
  └─ Dart: PetOverlay → PetStage(onRegions) → WindowBridge.setInputRegion
       Tras cada cuadro se miden (GlobalKey) Laika, la columna de chat y el
       estado; si cambiaron, se mandan por el canal `laika/window`
       (`setInputRegion([[x,y,w,h],…])`). Solo esas zonas reciben clics.
  └─ 2 clics → Process.start(laika_app --app) en otro proceso (ventana normal).
```

- Mientras arrastras a Laika, Wayland mantiene el puntero "agarrado", así que
  no se pierde aunque salgas un instante de la región.
- La caja de texto avisa al servidor que estás escribiendo
  (`PetController.composing`), y deja de avisar al vaciarla o al salir de ella.

### Cliente real (`HttpLaika`)

- HTTP con `HttpClient` de `dart:io` (sin dependencias extra); la identidad la pone `tailscale serve`.
- El WebSocket se abre **solo cuando Laika despierta** (después de un `/health` correcto).
  Si se corta, **no** se reconecta solo: se reabre en el siguiente despertar
  (regla de Esteban: nada de tráfico en segundo plano).
- Burbujas: cada `message` con `role: "companion"` es una burbuja; las
  correcciones (`role: "correction"`) se muestran como `✏️ original → mejor`.
- URL del servidor: `--dart-define=LAIKA_SERVER`, variable `LAIKA_SERVER` o
  `~/.config/laika/config.json`; si no hay, servidor simulado.

### Pendiente

| Plataforma | Cómo | Nota |
|---|---|---|
| Android | servicio con permiso "mostrar sobre otras apps" (burbuja flotante) | el usuario concede el permiso una vez |

## Datos de ejemplo

`sample_data.dart` es **ficticio** (el repositorio es público). Las fechas se
calculan desde "ahora" para que la agenda siempre se vea con "hoy/mañana".

## Pruebas

- `test/smoke_test.dart`: por cada diseño, despertar con mouse, enviar mensaje,
  comprobar el lado de las burbujas, dormirse a los 15 s, servidor caído, y
  dibujar Cerebro y Agenda sin errores. Más: lado izquierdo y recordatorio al despertar.
- `tool/screenshots_test.dart`: genera `docs/screenshots/` con fuentes reales.
