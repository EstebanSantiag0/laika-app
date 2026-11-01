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
- No se duerme mientras espera una respuesta.
- Si el servidor deja de responder a media plática, se duerme.

## El escritorio (`PetStage`)

- Hoy el "escritorio" se simula dentro de la ventana.
- Regla de lado: `petOnRight = centroX(Laika) > anchoPantalla / 2`. Si es
  verdadero, la columna de chat (burbujas + caja de texto) se dibuja a la
  izquierda de Laika; si no, a la derecha.
- Si Laika está muy arriba, la columna se ancla hacia abajo desde su borde
  superior; si no, crece hacia arriba desde su borde inferior.

### Plan para el escritorio real

| Plataforma | Cómo | Nota |
|---|---|---|
| Linux (KDE/Wayland) | ventana sin marco y transparente con `gtk-layer-shell` (capa *overlay*), región de entrada solo sobre Laika y el chat | requiere `sudo pacman -S gtk-layer-shell` |
| Android | servicio con permiso "mostrar sobre otras apps" (burbuja flotante) | el usuario concede el permiso una vez |

## Datos de ejemplo

`sample_data.dart` es **ficticio** (el repositorio es público). Las fechas se
calculan desde "ahora" para que la agenda siempre se vea con "hoy/mañana".

## Pruebas

- `test/smoke_test.dart`: por cada diseño, despertar con mouse, enviar mensaje,
  comprobar el lado de las burbujas, dormirse a los 15 s, servidor caído, y
  dibujar Cerebro y Agenda sin errores. Más: lado izquierdo y recordatorio al despertar.
- `tool/screenshots_test.dart`: genera `docs/screenshots/` con fuentes reales.
