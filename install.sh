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

# Copies Omarchy's lock service, then lays our frame view on top.
# Skips the copy when another lock plugin is already enabled, so a custom
# lock is left alone. The auth service itself is not stored in this repo.
install_nightcity_lock() {
  local stock="/usr/share/omarchy/shell/plugins/lock"
  local dst="$CFG/omarchy/plugins/nightcity.lock"
  local choice=install
  if [[ ! -f $stock/Service.qml ]]; then
    echo "Lock clone skipped. Omarchy's lock plugin was not on this machine."
    return 0
  fi
  if [[ -f $CFG/omarchy/shell.json ]]; then
    choice=$(python3 - "$CFG/omarchy/shell.json" << 'PY'
import json, sys
data = json.loads(open(sys.argv[1], encoding="utf-8").read())
ids = []
for entry in data.get("plugins") or []:
    if isinstance(entry, dict):
        ids.append(str(entry.get("id") or ""))
    elif isinstance(entry, str):
        ids.append(entry)
print("skip" if any(i.endswith(".lock") and i != "nightcity.lock" for i in ids) else "install")
PY
)
  fi
  if [[ $choice == skip ]]; then
    echo "Lock clone skipped. Another lock plugin is already enabled."
    return 0
  fi
  rm -rf "$dst"
  cp -a "$stock" "$dst"
  cp -a "$SRC/plugin/nightcity.lock/LockView.qml" "$dst/LockView.qml"
  mkdir -p "$dst/i18n"
  cp -a "$SRC/plugin/nightcity.lock/i18n/en.json" "$dst/i18n/en.json"
  cp -a "$SRC/plugin/nightcity.lock/manifest.json" "$dst/manifest.json"
}

install_nightcity_polkit() {
  local stock="/usr/share/omarchy/shell/plugins/polkit"
  local dst="$CFG/omarchy/plugins/nightcity.polkit"
  local choice=install
  if [[ ! -f $stock/PolkitAgent.qml ]]; then
    echo "Polkit clone skipped. Omarchy's polkit plugin was not on this machine."
    return 0
  fi
  if [[ -f $CFG/omarchy/shell.json ]]; then
    choice=$(python3 - "$CFG/omarchy/shell.json" << 'PY'
import json, sys
data = json.loads(open(sys.argv[1], encoding="utf-8").read())
ids = []
for entry in data.get("plugins") or []:
    if isinstance(entry, dict):
        ids.append(str(entry.get("id") or ""))
    elif isinstance(entry, str):
        ids.append(entry)
print("skip" if any(i.endswith(".polkit") and i != "nightcity.polkit" for i in ids) else "install")
PY
)
  fi
  if [[ $choice == skip ]]; then
    echo "Polkit clone skipped. Another polkit plugin is already enabled."
    return 0
  fi
  rm -rf "$dst"
  cp -a "$stock" "$dst"
  cp -a "$SRC/plugin/nightcity.polkit/PolkitAgent.qml" "$dst/PolkitAgent.qml"
  mkdir -p "$dst/i18n"
  cp -a "$SRC/plugin/nightcity.polkit/i18n/en.json" "$dst/i18n/en.json"
  cp -a "$SRC/plugin/nightcity.polkit/manifest.json" "$dst/manifest.json"
}

mkdir -p "$CFG/omarchy/themes" "$CFG/omarchy/bin" "$CFG/omarchy/plugins" \
  "$CFG/omarchy/extensions" "$CFG/omarchy/hooks/post-boot.d" \
  "$HYPR/shaders" "$HOME_DIR/.local/share/icons"

rm -rf "$THEME_DST"
cp -a "$SRC/theme" "$THEME_DST"
chmod +x "$SRC/bin/omarchy-screensaver" "$SRC/bin/cp2077-glitch" "$SRC/bin/cp2077-keys" "$SRC/bin/cp2077-walls" "$SRC/hooks/"*
cp -a "$SRC/bin/." "$CFG/omarchy/bin/"
if command -v gcc >/dev/null; then
  gcc -O2 -o "$CFG/omarchy/bin/cp2077-sixel" "$SRC/bin/cp2077-sixel.c"
  chmod +x "$CFG/omarchy/bin/cp2077-sixel"
else
  echo "Could not build cp2077-sixel. The breach saver needs gcc."
fi
cp -a "$SRC/shader/cp2077.frag" "$HYPR/shaders/cp2077.frag"
cp -a "$SRC/hooks/cp2077-jacked-in.sh" "$CFG/omarchy/hooks/post-boot.d/cp2077-jacked-in.sh"
rm -rf "$CFG/omarchy/plugins/nightcity.workspaces"
cp -a "$SRC/plugin/nightcity.workspaces" "$CFG/omarchy/plugins/nightcity.workspaces"
rm -rf "$CFG/omarchy/plugins/nightcity.frame"
cp -a "$SRC/plugin/nightcity.frame" "$CFG/omarchy/plugins/nightcity.frame"
install_nightcity_lock
install_nightcity_polkit
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

# The markers belong to the theme. A re-run replaces that block and leaves
# the rest of the file. It does not add a second copy.
upsert "$HYPR/looknfeel.lua" nightcity-glitch "$(cat "$SRC/extras/looknfeel.lua")"
upsert "$HYPR/hyprland.lua" nightcity-path "$(cat "$SRC/extras/hyprland.lua")"
upsert "$HYPR/bindings.lua" nightcity-key "$(cat "$SRC/extras/bindings.lua")"
upsert "$HYPR/autostart.lua" nightcity-start "$(cat "$SRC/extras/autostart.lua")"

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

def entry_id(entry):
    if isinstance(entry, dict):
        return str(entry.get("id") or "")
    if isinstance(entry, str):
        return entry
    return ""

plugins = data.setdefault("plugins", [])
if not isinstance(plugins, list):
    plugins = []
    data["plugins"] = plugins
ids = [entry_id(entry) for entry in plugins]

# One frame painter. A machine that already has one is left on that id.
if not any(plugin_id.endswith(".frame") for plugin_id in ids):
    plugins.append({"id": "nightcity.frame"})
    ids.append("nightcity.frame")

lock_dir = Path.home() / ".config/omarchy/plugins/nightcity.lock"
other_lock = any(plugin_id.endswith(".lock") and plugin_id != "nightcity.lock" for plugin_id in ids)
if lock_dir.is_dir() and not other_lock and "nightcity.lock" not in ids:
    plugins.append({"id": "nightcity.lock"})
    ids.append("nightcity.lock")

# Disabling the stock lock is what lets this clone own the lock handler.
if "nightcity.lock" in ids:
    disabled = data.get("disabledPlugins")
    if not isinstance(disabled, list):
        disabled = []
    if "omarchy.lock" not in disabled:
        disabled.append("omarchy.lock")
    data["disabledPlugins"] = disabled
    restores = data.get("cloneSourceRestores")
    if not isinstance(restores, list):
        restores = []
    if "nightcity.lock" not in restores:
        restores.append("nightcity.lock")
    data["cloneSourceRestores"] = restores

polkit_dir = Path.home() / ".config/omarchy/plugins/nightcity.polkit"
other_polkit = any(plugin_id.endswith(".polkit") and plugin_id != "nightcity.polkit" for plugin_id in ids)
if polkit_dir.is_dir() and not other_polkit and "nightcity.polkit" not in ids:
    plugins.append({"id": "nightcity.polkit"})
    ids.append("nightcity.polkit")

# Two polkit agents must not both stay enabled.
if "nightcity.polkit" in ids:
    disabled = data.get("disabledPlugins")
    if not isinstance(disabled, list):
        disabled = []
    if "omarchy.polkit" not in disabled:
        disabled.append("omarchy.polkit")
    data["disabledPlugins"] = disabled
    restores = data.get("cloneSourceRestores")
    if not isinstance(restores, list):
        restores = []
    if "nightcity.polkit" not in restores:
        restores.append("nightcity.polkit")
    data["cloneSourceRestores"] = restores

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
  Frames  nightcity.frame
  Saver   breach protocol

The glitch redraws every frame. Small battery cost. The key turns it off.
The lock clone is installed only when no other lock plugin is already enabled.
The polkit clone is installed only when no other polkit plugin is already enabled.
See NOTES.md before changing the shader, the frames, or the lock.
EOF
