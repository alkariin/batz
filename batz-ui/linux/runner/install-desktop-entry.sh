#!/bin/sh
# Adds batz to the applications of the desktop, with its icon: writes
# dev.batz.app.desktop, pointing at this folder, in the applications of the
# user. Run it again after moving the folder; delete that file to undo.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$target"
cat > "$target/dev.batz.app.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=batz
Comment=Comptabilité personnelle
Exec="$here/batz"
Icon=$here/batz.png
Terminal=false
Categories=Office;Finance;
StartupWMClass=dev.batz.app
ENTRY
echo "Written: $target/dev.batz.app.desktop"
