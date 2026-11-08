# Notes

Short version for the next person, or the next agent.

**Install with `install.sh`.** `omarchy theme install` sees the `.git` folder and throws away `hyprland.lua`. The script copies the theme without that folder, so the lua stays.

**Do not retune the glitch.** `shader/cp2077.frag` is the look. Idle split stays tiny so text stays solid. Hits are uneven on purpose.

**It redraws every frame.** `debug:damage_tracking = 0` while the shader is on. That is the battery cost. The flag file `~/.local/state/omarchy/cp2077-glitch-off` means off, and damage tracking goes back to 2.

**Walls.** 1 and 6 NET, 2 and 7 ICE, 3 and 8 BD, 4 and 9 DOC, 5 and 10 DECK. `cp2077-walls` listens to Hyprland and calls `omarchy-shell -q background setInstant`.

**Keyboard.** `cp2077-keys` flickers brightness on ASUS, except the ROG Flow Z13 GZ301ZE, which cycles live Aura color. Other models: `KEYBOARD.md`. Never save color to flash inside the loop. Name the model only. Do not record a serial, a UUID, or a home directory.

**60 Hz** is a choice. See `extras/monitors-60hz.lua`. Do not force `eDP-2` on every machine.

**Bar widget** id is `nightcity.workspaces`. The QML `moduleName` stays `omarchy.workspaces`.

**Menu names stay stock.** A label-only override of `apps` clears `provider`, and the Apps list opens empty.
