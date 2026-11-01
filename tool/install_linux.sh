#!/usr/bin/env bash
# Instala Laika para tu usuario (sin sudo):
#   ~/.local/share/laika-app/         el programa compilado
#   ~/.local/share/applications/      lanzadores "Laika" y "Laika (mascota)"
#   ~/.config/autostart/              solo con --autostart: la mascota al iniciar sesión
#
# Uso:  flutter build linux --release && tool/install_linux.sh [--autostart]
# Quitar: tool/install_linux.sh --uninstall
# Si la mascota se porta mal:  pkill laika_app
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="$HOME/.local/share/laika-app"
APPS="$HOME/.local/share/applications"
AUTO="$HOME/.config/autostart"
ID="io.github.estebansantiag0.laika_app"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$DEST"
  rm -f "$APPS/laika.desktop" "$APPS/laika-pet.desktop" "$AUTO/laika-pet.desktop"
  echo "Laika desinstalada (tu ~/.config/laika/config.json no se tocó)."
  exit 0
fi

BUNDLE="build/linux/x64/release/bundle"
[[ -x "$BUNDLE/laika_app" ]] || { echo "Primero: flutter build linux --release" >&2; exit 1; }

mkdir -p "$DEST" "$APPS"
rm -rf "$DEST.new" && cp -r "$BUNDLE" "$DEST.new" && rm -rf "$DEST" && mv "$DEST.new" "$DEST"

desktop() { # nombre, args, comentario
  cat <<EOD
[Desktop Entry]
Type=Application
Name=$1
Comment=$3
Exec=$DEST/laika_app $2
Icon=face-smile
Terminal=false
Categories=Education;
StartupWMClass=$ID
EOD
}
desktop "Laika" "--app" "Cerebro, agenda y mascota" > "$APPS/laika.desktop"
desktop "Laika (mascota)" "--pet" "Laika sobre tu escritorio" > "$APPS/laika-pet.desktop"

if [[ "${1:-}" == "--autostart" ]]; then
  mkdir -p "$AUTO"
  desktop "Laika (mascota)" "--pet" "Laika sobre tu escritorio" > "$AUTO/laika-pet.desktop"
  echo "La mascota arrancará al iniciar sesión."
fi

[[ -f "$HOME/.config/laika/config.json" ]] || cat <<'EOM'
Aviso: no hay ~/.config/laika/config.json, así que Laika usará el servidor simulado.
Para el real crea ese archivo con:  {"server": "https://tu-servidor.tu-tailnet.ts.net"}
EOM
echo "Instalada en $DEST"
