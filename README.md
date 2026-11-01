# Laika · app (Linux y Android)

Laika es una **compañera de idiomas con IA** que vive en un servidor propio
(ver el repositorio del servidor, [`EstebanSantiag0/laika`](https://github.com/EstebanSantiag0/laika)).
Esta app es su **cuerpo**: una mascota que vive en tu escritorio (Linux) o
flotando sobre tus apps (Android), con la que platicas, y un **cerebro visible**
donde ves todo lo que Laika recuerda de ti, organizado por áreas de tu vida y
por tiempo.

> **Estado actual (nov 2026): prototipos.** Hay **5 diseños muy distintos** con
> el mismo comportamiento y un **servidor simulado**. Sirven para elegir el
> estilo antes de conectar la app al servidor real.

| Cosmos | Papel | Pixel | Brutal | Cristal |
|---|---|---|---|---|
| ![Cosmos](docs/screenshots/cosmos-1-escritorio.png) | ![Papel](docs/screenshots/papel-1-escritorio.png) | ![Pixel](docs/screenshots/pixel-1-escritorio.png) | ![Brutal](docs/screenshots/brutal-1-escritorio.png) | ![Cristal](docs/screenshots/cristal-1-escritorio.png) |
| ![](docs/screenshots/cosmos-2-cerebro.png) | ![](docs/screenshots/papel-2-cerebro.png) | ![](docs/screenshots/pixel-2-cerebro.png) | ![](docs/screenshots/brutal-2-cerebro.png) | ![](docs/screenshots/cristal-2-cerebro.png) |

Más capturas y la descripción de cada diseño: [`docs/VARIANTES.md`](docs/VARIANTES.md).

## Contenido

1. [Cómo se comporta Laika](#1-cómo-se-comporta-laika)
2. [Requisitos](#2-requisitos)
3. [Instalar y ejecutar, paso a paso](#3-instalar-y-ejecutar-paso-a-paso)
4. [Probar los prototipos](#4-probar-los-prototipos)
5. [El cerebro: áreas y tiempo](#5-el-cerebro-áreas-y-tiempo)
6. [Pruebas y capturas](#6-pruebas-y-capturas)
7. [Cómo está organizado el código](#7-cómo-está-organizado-el-código)
8. [Siguientes pasos](#8-siguientes-pasos)
9. [Problemas comunes](#9-problemas-comunes)
10. [Licencia](#10-licencia)
11. [Autoría](#11-autoría)

## 1. Cómo se comporta Laika

Las reglas son iguales en los 5 diseños:

- **Se duerme sola** después de **15 segundos** sin que interactúes con ella.
- **Para despertarla**, pasa el mouse sobre ella (en Android: tócala). En ese
  momento la app hace **una sola** petición `GET /health` al servidor:
  - si el servidor responde y el modelo está cargado → **despierta**;
  - si no responde → **sigue dormida** y muestra "el servidor no responde".
  - No hay consultas en segundo plano: solo pregunta cuando tú la buscas.
- **El chat es solo una caja de texto.** Los mensajes de Laika salen **a su lado**:
  - si Laika está en la **mitad derecha** de la pantalla, sus mensajes salen a su **izquierda**;
  - si está en la **mitad izquierda**, salen a su **derecha**.
  - Puedes arrastrarla a donde quieras.
- **Recordatorios:** si uno suena mientras duerme, aparece una campanita; al
  despertarla, te lo dice. (En el servidor real también llega por Telegram.)
- **Datos sensibles** (los que el servidor marca como `sensitive`) se muestran
  como "🔒 privado" hasta que los desbloqueas en el cerebro.

## 2. Requisitos

| Qué | Versión probada | Para qué |
|---|---|---|
| Flutter | 3.47.5 (Dart 3.13) | todo |
| Linux: `clang`, `cmake`, `ninja`, `gtk3`, `pkg-config` | Arch Linux, KDE Plasma 6.8 (Wayland) | compilar para escritorio |
| Android SDK | 36 | compilar para Android |

En Arch Linux:

```bash
sudo pacman -S clang cmake ninja gtk3 pkgconf
```

Instala Flutter siguiendo <https://docs.flutter.dev/get-started/install/linux> y
comprueba con:

```bash
flutter doctor
```

Para Android además acepta las licencias una vez:

```bash
flutter doctor --android-licenses
```

## 3. Instalar y ejecutar, paso a paso

```bash
# 1. Descargar el código
git clone https://github.com/EstebanSantiag0/laika-app.git
cd laika-app

# 2. Descargar dependencias
flutter pub get

# 3. Abrir la galería de diseños (Linux)
flutter run -d linux
```

Para abrir directo un diseño:

```bash
flutter run -d linux --dart-define=VARIANT=cosmos    # cosmos | papel | pixel | brutal | cristal
```

En Android (con el teléfono conectado por USB y la depuración activada):

```bash
flutter devices                 # busca el id de tu teléfono
flutter run -d <id-del-teléfono>
```

Para generar un ejecutable de Linux:

```bash
flutter build linux --release
./build/linux/x64/release/bundle/laika_app
```

## 4. Probar los prototipos

1. En la galería, elige un diseño.
2. **Pasa el mouse sobre Laika**: verás "preguntando al servidor…" y luego despierta.
3. Escríbele. Prueba:
   - `hola`
   - `quiero aprender a soldar` → lo guarda en su memoria como *etapa actual*
   - `recuérdame pagar la renta` → crea un recordatorio que, en la demo, suena en 1 minuto
4. No toques nada 15 s → se duerme.
5. Abre **⚙ SIM** (abajo a la izquierda):
   - apaga **Servidor en línea** y pasa el mouse sobre ella → **no despierta**;
   - sube la **latencia** para ver qué pasa con un servidor lento;
   - **Sonar recordatorio** dispara uno ya (con Laika dormida aparece la campanita).
6. Revisa las pestañas **Cerebro** y **Agenda**.
7. `←` regresa a la galería.

Cuando tengas un favorito, o quieras mezclar partes (por ejemplo, "la mascota
de Pixel con el cerebro de Cosmos"), anótalo; ver [`docs/VARIANTES.md`](docs/VARIANTES.md).

## 5. El cerebro: áreas y tiempo

Todo lo que Laika recuerda es un **nodo**:

| Tipo | Ejemplo |
|---|---|
| Entidad | "Universidad", "Flutter", "Mamá" |
| Dato | "Quieres hacer prácticas en una empresa de hardware" |
| Conversación | "Planes para el verano" |
| Recordatorio | "Pagar el internet — mañana 10:00" |

Cada nodo pertenece a una o más **áreas de tu vida** (Estudios, Proyectos,
Finanzas, Legal/trámites, Habilidades, Trabajo/prácticas, Idiomas, Salud,
Personas, Hogar/día a día) y tiene un **tiempo**:

| Tiempo | Significado | Qué pasa después |
|---|---|---|
| Permanente | siempre cierto | nada |
| Etapa actual | cierto *por ahora* | Laika te pregunta en unas semanas si sigue igual |
| Con fecha | evento o fecha límite | al pasar la fecha se archiva |
| Recordatorio | algo que te debe avisar | te avisa a la hora y se marca hecho |
| Archivado | ya no es actual | se conserva como historia, no se borra |

Cada diseño dibuja el cerebro distinto: esfera 3D (Cosmos), mapa mental
(Papel), cuartos de videojuego (Pixel), grafo de fuerzas (Brutal) y órbitas del
tiempo (Cristal).

## 6. Pruebas y capturas

```bash
flutter analyze        # revisa el código
flutter test           # 8 pruebas: despertar, burbujas a su lado, dormirse, servidor caído...
```

Las capturas de `docs/screenshots/` se generan con las fuentes de tu sistema:

```bash
flutter test tool/screenshots_test.dart --update-goldens
```

## 7. Cómo está organizado el código

```
lib/
├── main.dart              galería de diseños
├── core/                  lógica compartida (igual en todos los diseños)
│   ├── models.dart        datos: nodos, áreas, recordatorios (contrato de la API)
│   ├── api.dart           interfaz con el servidor
│   ├── mock_backend.dart  servidor simulado
│   ├── sample_data.dart   recuerdos de ejemplo (ficticios)
│   ├── pet.dart           reglas de la mascota (dormir, despertar, burbujas)
│   ├── stage.dart         el escritorio y la regla de "mensajes a su lado"
│   ├── brain.dart         filtros del cerebro y agenda
│   ├── layouts.dart       cómo se acomodan los nodos (esfera, radial, fuerzas…)
│   ├── session.dart       une todo + panel de simulación
│   └── widgets.dart       piezas reutilizables
└── variants/              los 5 diseños (solo estilo)
    ├── cosmos.dart  papel.dart  pixel.dart  brutal.dart  cristal.dart
    └── variants.dart      lista de diseños
```

Explicación completa: [`docs/architecture.md`](docs/architecture.md).
Contrato con el servidor: [`docs/API.md`](docs/API.md).

## 8. Siguientes pasos

1. Elegir diseño (o mezcla).
2. `HttpLaika`: cliente real (HTTPS + WebSocket por Tailscale) en lugar del simulado.
3. Linux: Laika como ventana transparente sobre tu escritorio real (`gtk-layer-shell`, que KDE soporta).
4. Android: burbuja flotante sobre otras apps y notificaciones de recordatorios.
5. Animaciones finales y alimentar a Laika arrastrándole PDFs o enlaces.

El avance día a día está en [`docs/PROGRESS.md`](docs/PROGRESS.md).

## 9. Problemas comunes

| Problema | Solución |
|---|---|
| `flutter run -d linux` dice que falta CMake/GTK | instala los paquetes de la sección 2 |
| Los emojis salen como cuadritos | instala una fuente de emojis (`noto-fonts-emoji` en Arch) |
| Android: "licenses not accepted" | `flutter doctor --android-licenses` |
| Las capturas salen distintas en otra computadora | es normal: dependen de las fuentes instaladas |

## 10. Licencia

[MIT](LICENSE).

## 11. Autoría

- **Idea, diseño del producto, reglas de comportamiento y dirección del proyecto:**
  Esteban Santiago ([@EstebanSantiag0](https://github.com/EstebanSantiag0)).
- **Código de los prototipos y documentación:** escritos con ayuda de Claude
  (IA de Anthropic), siguiendo las decisiones y revisiones de Esteban.
