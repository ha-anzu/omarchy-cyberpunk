# What this theme does

Night City for Omarchy. Black field, yellow `FCEE0A`, cyan `00F0FF`, red `FE1038`, neon green `57 255 20`. The screen glitches and then goes clean. Each desk has a wallpaper. Windows, the lock page, the password plate, and the screensaver share one broken frame.

This file is the record of the behavior and the files. `NOTES.md` is the short list of things that must not be undone.

## Files

| Path | What it is |
|---|---|
| `shader/cp2077.frag` | Full-screen glitch. Quiet windows `8.0` s and `12.5` s |
| `bin/cp2077-glitch` | `Super+Shift+Alt+G`. Turns the shader, damage tracking, and vfr together |
| `bin/cp2077-keys` | Keyboard glitch. Brightness on most ASUS boards. Live color on the Flow Z13 GZ301ZE |
| `bin/cp2077-walls` | One wallpaper per workspace, with a fallback |
| `bin/omarchy-screensaver` | Bloody Arasaka flatline. Must stay executable |
| `extras/looknfeel.lua` | Shader on or off, then border 0, gaps 2 and 3, shadow off |
| `theme/hyprland.lua` | Same border and gaps inside the theme itself |
| `plugin/nightcity.frame/` | Click-through window frames. Id `nightcity.frame` |
| `plugin/nightcity.lock/` | Lock page and password plate. The auth service is copied at install time |
| `install.sh` | The only install path |

`install.sh` does not vendor the lock's `Service.qml`. It copies the copy that shipped with Omarchy, then replaces `LockView.qml`, `i18n/en.json`, and `manifest.json`.

## Screen glitch

The shader is a compositor effect. Hits are uneven: a faint snap, a hard tear, or a longer stutter. Between hits the split stays a fraction of a pixel so text stays readable.

Two things have to be true while it is on.

- `debug:damage_tracking = 0`, or the time uniform does not move and the effect looks stuck.
- `debug:vfr = false`. Variable frame rate skips the next redraw when the screen is still, so a hit freezes on the last picture until something else damages the screen.

`bin/cp2077-glitch` sets both when it turns the effect on. Off clears the shader, sets damage tracking back to 2, and sets vfr back to true. The same pair is in `extras/looknfeel.lua`, so a reload comes back in the same state. The off flag is `~/.local/state/omarchy/cp2077-glitch-off`.

The quiet windows are `consider(time, 8.0, 1.0, 1.7)` and `consider(time, 12.5, 0.30, 8.9)`. Leave them there.

On a ROG Flow Z13 GZ301ZE the extra draw was about 1 W at 120 Hz on AC, and about 0.5–1 W at 60 Hz on battery. That is roughly 1–2% of a capped charge per hour. The cost is the full-screen redraw, not a second animation. Do not run a 60 fps overlay while the glitch is off.

## Keyboard

The lights are not being asked to do anything outside a normal color change.

Most ASUS boards flicker `asus::kbd_backlight`: off, full, off, full, then the level the user had. The script reads `max_brightness`. It does not assume 3.

The ROG Flow Z13 GZ301ZE has no `kbd_rgb_mode` node. Color goes through asusd as a live static color. The script finds the Aura objects on the bus at runtime. Do not paste an object path from another machine. USB product ids on that model are `0b05:18c6` and `0b05:1a30`. The model name is enough. Do not read or write a serial, a UUID, a hostname, a home path, a MAC, or a machine id.

There is one backlight zone. Different rows cannot hold different colors at the same time. A "line" is the whole keyboard stepping through a sweep.

The palette is yellow `252 238 10`, cyan `0 240 255`, red `254 16 56`, and neon green `57 255 20`. Each step is 40–80 ms. Then the color that was already showing comes back.

Three burst shapes, picked per hit:

- About 3 in 10 hold one color for 3–5 steps.
- About 3 in 10 sweep yellow, green, cyan, red, green, cyan for 5–8 steps, either direction.
- The rest jump around the palette for 4–8 steps, sometimes repeating the current color.

Quiet time is about 4–9 seconds, and about one hit in five is half that. The glitch-off flag, or a backlight level of 0, leaves the lights still. One process, with `flock`. The script restores the previous color and brightness when it exits.

Never write `cmd` `1` to `kbd_rgb_mode`. That saves into the controller. A live write (`cmd` `0`) is the whole point. A save on every hit wears the controller. The LEDs themselves are inside normal use. `KEYBOARD.md` has the other keyboards.

## Wallpapers

The repo ships original pictures: `17-net.jpg`, `18-ice.jpg`, `19-bd.jpg`, `20-doc.jpg`, `21-deck.jpg`. Desks 1–5 use them in that order, then 6–10 repeat.

If you already have the free CD PROJEKT RED desktop wallpapers in `~/.local/share/omarchy/cyberpunk-wallpapers`, and the file named for that desk is present, the script uses it. The names are listed in `NOTES.md`. This repo does not contain those files and does not download them. No CDPR font, logo, or screenshot is in the tree.

`cp2077-walls` listens on the Hyprland socket and calls `omarchy-shell -q background setInstant`.

## Window frames

Hyprland 0.56 has one `border_size`, one `rounding`, and one `rounding_power`. It cannot draw a different chamfer per corner, a gap in a stroke, or two halves that miss each other by a pixel.

`plugin/nightcity.frame` is a Quickshell service. One `PanelWindow` per screen, layer Overlay, keyboard focus none, exclusion mode Ignore, empty input mask, so clicks pass through. Namespace `nightcity-frame`.

The paint:

- Seed comes from the window address, so each window keeps its own cuts.
- Each corner is cut by a different amount, clamped to 22% of the shorter side.
- Each edge is two runs. The gap is about 12–34 px, and its center sits somewhere in the middle 22–74% of the span.
- The two halves step inward by different amounts, 0 against 1 or 2, so they are not colinear.
- A chamfer breaks into two pieces when its mix value is above 0.62.
- Every 1100 ms, while shell animations are enabled, one edge's shift flips. The step runs 0 through 7.
- The active window is `#FCEE0A`. The longest corner gets a short `#00F0FF` tick. Other windows use `rgba(252, 238, 10, 0.42)`.

Client coordinates from Hyprland are physical pixels. The layer's width and height are logical. Divide by the monitor scale, then inset 3 px. On a 1.5 scale panel, forgetting the divide paints the lines in the wrong place.

`gaps_in` 2 and `gaps_out` 3 keep the yellow wallpaper from reading as a fat border. `border_size` 0 and the shadow off mean Hyprland is not drawing a second frame under the overlay. `resize_on_border` can stay on. Fullscreen mode 2 and above is skipped, and so are hidden, unmapped, and tiny windows. Pinned windows and the open special workspace are included.

The service is `keepLoaded`. Editing the QML logs a reload and keeps the old instance. `omarchy restart shell` loads the new one.

`install.sh` adds `{ "id": "nightcity.frame" }` only when `shell.json` has no plugin id ending in `.frame`.

## Lock page

The packaged lock under `/usr/share/omarchy/shell/plugins/lock` stays untouched. The theme clones it to `nightcity.lock` and replaces the view.

The page frame and the password plate use the same `strokeFrame` rules as the windows. The page seed is 4. The password seed is 11. The page stroke is `#FCEE0A` with a `#00F0FF` tick, inset 16 px. The password plate is an uneven chamfered octagon, filled `rgba(8, 12, 18, 0.86)`, or `rgba(40, 8, 14, 0.88)` after a bad password. A bad password turns the stroke `#FE1038` and the tick yellow. The caption reads ACCESS. Above the field, the row is text only: NIGHT CITY in yellow, SEALED in cyan. Those three strings are `plugin/nightcity.lock/i18n/en.json`. The password field still focuses itself, drops auto-repeat, and reserves room for the fingerprint mark.

`install.sh` will not install this clone when another plugin id ending in `.lock` is already in `shell.json`. It will not remove that plugin. When it does install, it disables `omarchy.lock` and records `nightcity.lock` in `cloneSourceRestores`, which is how the shell can hand the lock back later.

The shell has to restart once so this clone is the first lock handler. Preview with `omarchy-shell lock preview`, then `omarchy-shell lock hidePreview`. Do not lock the session just to look at it.

## Screensaver

Omarchy launches `omarchy-screensaver` in foot, class `org.omarchy.screensaver`. Putting the script in `~/.config/omarchy/bin` and putting that directory first on PATH is what shadows the logo saver. `extras/hyprland.lua` does the PATH part. If the script is not executable, Hyprland falls through to the logo.

The picture stays dead. Torn dark-red field, eight blood drips, a flatline that twitches and goes flat, and the words ARASAKA and FLATLINED in a 6-by-6 cell font. The words sit still except when the tick is a rip frame, and then only every third row jumps. A white flash is about one frame in 26, not a strobe. The log stays dead: cardiac output 00, blood ox 00, neural lattice dark, soulkiller with no pattern, relic offline, time of death locked. About every 17 ticks one of those lines turns to junk.

`frame_overlay` then paints the same broken frame in character cells. Cuts are a few cells, the gap is 4–8 cells, one half of each run steps inward, the stroke is yellow, and the longest corner gets a cyan tick. It is drawn after the blood picture so it wins.

Leaving it:

- Any key exits. The terminal is in cbreak and polled every 50 ms.
- About 1.2 s after start, every 12th tick exits if the active window is no longer `org.omarchy.screensaver`.
- SIGINT, SIGTERM, and SIGHUP call the same cleanup.
- Cleanup shows the terminal cursor, clears the screen, and sets Hyprland `cursor:invisible` to false. The cursor is hidden only while the saver is up.
- `CP2077_SAVER_FRAMES` renders that many frames and exits, for a headless check. It does not grab the tty.

The stock `branding/screensaver.txt` is not used. Idle timeouts are the user's. This theme does not write them.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ha-anzu/omarchy-cyberpunk/main/install.sh | bash
```

Or clone the repo and run `install.sh` from it. Do not use `omarchy theme install` on this repo.

What the script changes:

- Replaces `~/.config/omarchy/themes/cyberpunk-2077` with a copy that has no `.git`.
- Copies `bin/`, the shader, the post-boot hook, the Night City icon theme, `nightcity.workspaces`, and `nightcity.frame`.
- Copies the screensaver into `~/.config/omarchy/bin`.
- Installs the lock clone unless another lock plugin is already enabled.
- Replaces the marked Night City blocks in looknfeel, hyprland, bindings, and autostart.
- Sets the bar widget id to `nightcity.workspaces` and the clock to `NC`, without changing idle times.
- Adds the frame plugin id when no `*.frame` plugin is listed.
- Saves `shell.json.nightcity-bak` and `omarchy-menu.jsonc.nightcity-bak` once, then writes the theme menu file.
- Sets the theme, reloads Hyprland, starts the wall and key scripts, and restarts the shell.

What it does not change:

- It does not install `extras/monitors-60hz.lua`.
- It does not download wallpapers.
- It does not read hardware serials.
- It does not write keyboard color into flash.
- It does not remove a lock or frame plugin you already enabled.
- It does not change idle or lock timeouts.

A second run refreshes the theme's own files and the marked blocks. It still will not replace your lock or frame plugin.

## Left out on purpose

- Official wallpaper binaries.
- A serial, a board serial, a product UUID, a hostname, a home directory, an email address, a MAC, a machine id, or a copied Aura object path.
- Per-key USB color writes. This keyboard cannot do them.
- A forced monitor name or refresh rate.
- A second copy of the Omarchy lock service inside git.
