# CLAUDE.md — Laika app

Cliente Flutter (Linux + Android) de **Laika**, la compañera de idiomas con IA de
Esteban. El servidor vive en cc-server (`/root/docker/laika`, repo
`EstebanSantiag0/laika`) y lo maneja otra sesión de Claude (Remote Control
`cc-server-giggly-star`). Este repo es público: `EstebanSantiag0/laika-app`.

## Reglas
- Llama al usuario **Esteban**. Docs y textos de la app en **español**.
- **Retomar aquí:** `docs/PROGRESS.md`. Actualízalo y haz commit **en cada paso**.
- Repo público: **nunca** datos reales de Laika (recuerdos, nombres, tailnet). `sample_data.dart` es ficticio.
- Comportamiento de la mascota = decisiones de Esteban (no cambiarlas sin preguntar):
  dormir 15 s después de que se desvanece su última burbuja (cada una dura 3 s/palabra; chino 2 s/carácter
  + 3 s/palabra); al hover hace UNA petición a `/health` y despierta solo si `ok && llm` (y luego UNA a
  `/api/resurface`);
  sin sondeo en segundo plano; chat = solo caja de texto; burbujas al lado contrario del borde.
- El README termina con la sección **Autoría** (idea y dirección de Esteban; ser exacto sobre la ayuda de Claude).
- `sudo`: dar a Esteban el comando como `! sudo ...`.

## Comandos
```bash
flutter analyze && flutter test
flutter run -d linux [--dart-define=VARIANT=cosmos|papel|pixel|brutal|cristal]
flutter test tool/screenshots_test.dart --update-goldens   # regenera docs/screenshots
flutter build linux --release
build/linux/x64/release/bundle/laika_app --pet   # mascota sobre el escritorio (Wayland); salir: pkill laika_app
build/linux/x64/release/bundle/laika_app --app   # app en ventana normal
tool/install_linux.sh [--autostart|--uninstall]   # preguntar a Esteban antes de --autostart
```
- Ajustes: `~/.config/laika/config.json` `{"server", "skin", "petSize"}` (fuera del repo). Sin server → simulado.
- Skins de imágenes: `./skins/` y `~/.config/laika/skins/` (en `.gitignore`; imágenes personales,
  **nunca** subirlas). Formato: `docs/SKINS.md`. No dibujar personajes con dueño en el repo.

## Docs
- `docs/architecture.md` — capas, máquina de estados de la mascota, plan de escritorio real.
- `docs/API.md` — contrato con el servidor (fuente de verdad: docs/API.md del repo del servidor).
- `docs/VARIANTES.md` — los 5 diseños.
- `docs/SKINS.md` — skins de imágenes y `tool/make_skin.py`.
- `docs/PROGRESS.md` — estado y siguiente paso.
