# Notes

Short version for the next person, or the next agent. The long record is `CHANGES.md`.

**Install with `install.sh`.** `omarchy theme install` sees the `.git` folder and throws away `hyprland.lua`. The script copies the theme without that folder, so the lua stays.

**Do not retune the glitch.** `shader/cp2077.frag` is the look. Quiet windows are `8.0` (always) and `12.5` (30%). Idle split stays tiny so text stays solid. Hits are uneven on purpose.

**A still screen freezes a hit unless vfr is off.** While the shader is on, `debug:damage_tracking = 0` and `debug:vfr = false`. Damage tracking off is what redraws. Variable frame rate still skips the next frame when nothing else moves, and the last tear stays up. Off restores shader `""`, damage tracking `2`, and `vfr true`. The flag file `~/.local/state/omarchy/cp2077-glitch-off` means off. `Super+Shift+Alt+G` owns that flag. Do not add a 60 fps animation for the time the glitch is off.

**Battery.** The redraw is the cost. On a ROG Flow Z13 GZ301ZE it was about 1 W extra at 120 Hz on AC, and about 0.5–1 W at 60 Hz on battery, roughly 1–2% of a capped charge per hour. The key turns it off.

**Walls.** Shipped pictures: 1 and 6 NET, 2 and 7 ICE, 3 and 8 BD, 4 and 9 DOC, 5 and 10 DECK. If `~/.local/share/omarchy/cyberpunk-wallpapers` exists and the file for that desk is there, `cp2077-walls` uses it instead. The names, in order, are `cover-art.jpg`, `love-or-burn.jpg`, `night-city.png`, `male-v.jpg`, `female-v.png`, `corporate-plaza.png`, `downtown.png`, `kabuki.png`, `japantown.png`, `dogtown.png`, `heywood.png`, `santo-domingo.png`, `pacifica.png`, `badlands.png`, `north-oak.png`, `northside.png`, `arasaka-waterfront.png`. A missing file falls back to the theme picture for that desk. Do not put those images in this repo.

**Keyboard.** `cp2077-keys` flickers brightness on ASUS, except the ROG Flow Z13 GZ301ZE, which cycles live Aura color through yellow `FCEE0A`, cyan `00F0FF`, red `FE1038`, and neon green `57 255 20`. That keyboard is one zone. A sweep is the whole board, not a row. Other models: `KEYBOARD.md`. Never save color to flash inside the loop. `cmd` stays `0`. Name the model only. Do not record a serial, a UUID, a hostname, a home directory, a MAC, a machine id, or an Aura object path. Interface numbers on the bus are not part of the model.

**Frames.** Hyprland draws one continuous border and one chamfer. The visible frame is the click-through layer from `plugin/nightcity.frame` (id `nightcity.frame`, namespace `nightcity-frame`). `border_size` is 0, shadow is off, `gaps_in` is 2, `gaps_out` is 3, so the wallpaper in the gap does not read as a thick frame. The layer paints a 1 px stroke: a different cut on each corner, a gap in each run, and a 1 px inward step so the halves do not meet. Active windows are `#FCEE0A` with a short `#00F0FF` tick on the longest corner. Inactive is the same yellow at 42% opacity. Hyprland client `at` and `size` are physical pixels. The layer is logical. Divide by `monitor.scale` and inset 3 px. Skip fullscreen mode 2 or more, hidden, unmapped, and tiny windows. Geometry polls every 160 ms. The dislocation steps every 1100 ms, and only when shell animations are on. `keepLoaded` is true, so a QML edit applies after `omarchy restart shell`. Do not enable two `*.frame` plugins. `install.sh` will not add `nightcity.frame` when one is already listed.

**Lock.** `plugin/nightcity.lock` is the view and the strings, not the auth service. `install.sh` copies `/usr/share/omarchy/shell/plugins/lock` to `~/.config/omarchy/plugins/nightcity.lock`, overlays `LockView.qml`, `i18n/en.json`, and `manifest.json`, then adds id `nightcity.lock`, puts `omarchy.lock` in `disabledPlugins`, and lists the clone in `cloneSourceRestores`. It skips that whole step when some other `*.lock` plugin is already enabled. Two lock handlers fight, and the first one wins. A bad lock file can block unlocking. After a change, `omarchy restart shell`, then preview with `omarchy-shell lock preview` and leave with `hidePreview`. Do not lock the session to test. The page frame uses seed 4. The password plate uses seed 11. Error turns the plate `#FE1038` and the tick yellow. The words are NIGHT CITY, SEALED, and ACCESS.

**Screensaver.** `bin/omarchy-screensaver` is the Arasaka flatline. `install.sh` copies it into `~/.config/omarchy/bin`, which is ahead of the stock logo saver on PATH. The file must stay executable. Any key, or leaving the screensaver window, exits. It hides the Hyprland cursor on start and sets `cursor:invisible` back to false on the way out. Preview with `omarchy-launch-screensaver force`. Do not change the idle times in `shell.json` from this theme. The yellow and cyan character frame around the picture uses the same cut, gap, and tick rules as the windows.

**60 Hz** is a choice. See `extras/monitors-60hz.lua`. Do not force `eDP-2` on every machine. `install.sh` does not install that snippet.

**Bar widget** id is `nightcity.workspaces`. The QML `moduleName` stays `omarchy.workspaces`.

**Menu names stay stock.** A label-only override of `apps` clears `provider`, and the Apps list opens empty. `install.sh` still replaces `omarchy-menu.jsonc` after saving `omarchy-menu.jsonc.nightcity-bak` once. Do not invent a new Apps label.

**Re-run.** Marked blocks in `looknfeel.lua`, `hyprland.lua`, `bindings.lua`, and `autostart.lua` are replaced. The rest of those files stays. Idle timeouts stay. An existing `*.frame` or `*.lock` plugin id stays. The theme directory, the user bin scripts, the frame plugin, and the menu extension are copied again.

**Theme lua versus look.** `theme/hyprland.lua` sets the same border and gaps. The user's `looknfeel.lua` loads later and is the one that also owns the shader. The second `hl.config` in the Night City block must not set `screen_shader` or `debug`.
