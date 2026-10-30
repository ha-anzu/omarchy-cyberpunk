#!/bin/bash
# Jack in. Copies the theme without a .git folder so Omarchy keeps the lua.
set -euo pipefail

REPO="https://github.com/ha-anzu/omarchy-cyberpunk.git"

if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} && -d $(dirname "${BASH_SOURCE[0]}")/theme ]]; then
  SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
else
  TMP=$(mktemp -d)
  git clone --depth 1 "$REPO" "$TMP/repo"
  exec bash "$TMP/repo/install.sh"
fi

HOME_DIR=${HOME:?}
CFG="$HOME_DIR/.config"
THEME_DST="$CFG/omarchy/themes/cyberpunk-2077"
HYPR="$CFG/hypr"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Need $1. This is an Omarchy theme." >&2
    exit 1
  }
}
need git
need python3

mkdir -p "$CFG/omarchy/themes" "$CFG/omarchy/bin" "$CFG/omarchy/plugins" \
  "$CFG/omarchy/extensions" "$CFG/omarchy/hooks/post-boot.d" \
  "$HYPR/shaders" "$HOME_DIR/.local/share/icons"

rm -rf "$THEME_DST"
cp -a "$SRC/theme" "$THEME_DST"
chmod +x "$SRC/bin/"* "$SRC/hooks/"*
cp -a "$SRC/bin/." "$CFG/omarchy/bin/"
cp -a "$SRC/shader/cp2077.frag" "$HYPR/shaders/cp2077.frag"
cp -a "$SRC/hooks/cp2077-jacked-in.sh" "$CFG/omarchy/hooks/post-boot.d/cp2077-jacked-in.sh"
rm -rf "$CFG/omarchy/plugins/nightcity.workspaces"
cp -a "$SRC/plugin/nightcity.workspaces" "$CFG/omarchy/plugins/nightcity.workspaces"
rm -rf "$HOME_DIR/.local/share/icons/Nightcity"
cp -a "$SRC/icons/Nightcity" "$HOME_DIR/.local/share/icons/Nightcity"
rm -f "$HOME_DIR/.local/share/icons/Nightcity/icon-theme.cache"

menu="$CFG/omarchy/extensions/omarchy-menu.jsonc"
if [[ -f $menu && ! -f $menu.nightcity-bak ]]; then
  cp -a "$menu" "$menu.nightcity-bak"
fi
cp -a "$SRC/extras/omarchy-menu.jsonc" "$menu"

upsert() {
  local file=$1 marker=$2 snippet=$3
  python3 - "$file" "$marker" "$snippet" << 'PY'
import pathlib, sys
path, marker, snippet = sys.argv[1:]
file = pathlib.Path(path)
file.parent.mkdir(parents=True, exist_ok=True)
text = file.read_text() if file.exists() else ""
start, end = f"-- >>> {marker}", f"-- <<< {marker}"
block = f"{start}\n{snippet.rstrip()}\n{end}\n"
if start in text and end in text:
    pre, _, rest = text.partition(start)
    _, _, post = rest.partition(end)
    text = pre.rstrip() + "\n\n" + block + post.lstrip("\n")
else:
    text = (text.rstrip() + "\n\n" if text.strip() else "") + block
file.write_text(text if text.endswith("\n") else text + "\n")
PY
}

# Skip when this machine already has the block, so a re-run does not double it.
if ! grep -q 'cp2077.frag' "$HYPR/looknfeel.lua" 2>/dev/null; then
  upsert "$HYPR/looknfeel.lua" nightcity-glitch "$(cat "$SRC/extras/looknfeel.lua")"
fi
if ! grep -q 'OMARCHY_MENU_FONT' "$HYPR/hyprland.lua" 2>/dev/null; then
  upsert "$HYPR/hyprland.lua" nightcity-path "$(cat "$SRC/extras/hyprland.lua")"
fi
if ! grep -q 'cp2077-glitch' "$HYPR/bindings.lua" 2>/dev/null; then
  upsert "$HYPR/bindings.lua" nightcity-key "$(cat "$SRC/extras/bindings.lua")"
fi
if ! grep -q 'cp2077-walls' "$HYPR/autostart.lua" 2>/dev/null; then
  upsert "$HYPR/autostart.lua" nightcity-start "$(cat "$SRC/extras/autostart.lua")"
fi

python3 - << 'PY'
import json
from pathlib import Path
path = Path.home() / ".config/omarchy/shell.json"
if not path.exists():
    raise SystemExit(0)
data = json.loads(path.read_text())
found = False

def walk(node):
    global found
    if isinstance(node, dict):
        if node.get("id") in {"omarchy.workspaces", "nightcity.workspaces"}:
            node["id"] = "nightcity.workspaces"
            found = True
        if node.get("id") == "omarchy.clock":
            node["format"] = "NC  dd.MM  HH:mm"
            node["formatAlt"] = "CHOOM  dddd  dd.MM.yyyy  HH:mm"
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)

walk(data)
if not found:
    left = data.setdefault("bar", {}).setdefault("layout", {}).setdefault("left", [])
    at = 0
    for i, item in enumerate(left):
        if isinstance(item, dict) and item.get("id") == "omarchy.menu":
            at = i + 1
    left.insert(at, {"id": "nightcity.workspaces"})
bak = path.with_name("shell.json.nightcity-bak")
if not bak.exists():
    bak.write_text(path.read_text())
path.write_text(json.dumps(data, indent=2) + "\n")
PY

if command -v omarchy >/dev/null; then
  omarchy theme set cyberpunk-2077
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null 2>&1 || true
  setsid "$CFG/omarchy/bin/cp2077-walls" >/dev/null 2>&1 < /dev/null &
  setsid "$CFG/omarchy/bin/cp2077-keys" >/dev/null 2>&1 < /dev/null &
fi

if command -v omarchy >/dev/null; then
  omarchy restart shell >/dev/null 2>&1 || true
fi

cat << 'EOF'

Jacked in.

  Theme   cyberpunk-2077
  Glitch  Super+Shift+Alt+G
  Walls   they follow the desk

The glitch redraws every frame. Small battery cost. The key turns it off.
EOF
