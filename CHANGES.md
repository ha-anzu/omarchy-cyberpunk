# What this theme does

Night City for Omarchy. Black field, yellow `FCEE0A`, cyan `00F0FF`, red `FE1038`, neon green `57 255 20`. The screen glitches and then goes clean. Each desk has a wallpaper. Window frames are broken yellow lines, and the focused window is the one that glows, with a very dim red wash behind it. The lock page, the password plate, and the fingerprint plate stay a 1 px stroke with no glow. The idle screen is a breach protocol whose headline is CONNECTION FLATLINED. The pointer is the same yellow, with a dark edge and a cyan tick.

This file is the record of the behavior and the files. `NOTES.md` is the short list of things that must not be undone.

## Files

| Path | What it is |
|---|---|
| `shader/cp2077.frag` | Full-screen glitch. Quiet windows `8.0` s and `12.5` s |
| `bin/cp2077-glitch` | `Super+Shift+Alt+G`. Turns the shader, damage tracking, and vfr together |
| `bin/cp2077-keys` | Keyboard glitch. Brightness on most ASUS boards. Live color on the Flow Z13 GZ301ZE |
| `bin/cp2077-walls` | One wallpaper per workspace, with a fallback |
| `bin/omarchy-screensaver` | Breach-protocol idle screen. Headline CONNECTION FLATLINED. Must stay executable |
| `bin/cp2077-sixel.c` | Fixed-palette sixel encoder. `install.sh` compiles it with gcc |
| `cursor/` | Pointer source. Yellow fill, dark edge, cyan tick. `install.sh` builds it |
| `extras/looknfeel.lua` | Shader on or off, then border 0, gaps 2 and 3, shadow off |
| `theme/hyprland.lua` | Same border and gaps inside the theme itself |
| `plugin/nightcity.frame/` | Click-through window frames. Id `nightcity.frame` |
| `plugin/nightcity.lock/` | Lock page, password plate, fingerprint plate. The auth service is copied at install time |
| `plugin/nightcity.polkit/` | Fingerprint prompt plate. The agent is copied at install time |
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

The frame lines step every 1100 ms. That is one overlay paint. It does not add a measurable amount on top of the shader redraw, so the lines stay in motion. Freezing them would not be what saves the battery. The key that turns the shader off is the battery switch.

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
- Each edge is two runs. The gap is about 6–14 px, and it is capped at 18% of the span. Its center sits in the middle of the run.
- The two halves step inward by 1 px, so they are not colinear. Every 1100 ms, while shell animations are enabled, one half's shift flips. The step runs 0 through 7.
- A chamfer breaks into two pieces when its mix value is above 0.62.
- Line caps are butt, so a gap stays open. A wide glow stack turns those gaps into black blocks, so the halo is one pass.
- The focused window is thicker, yellow `#FCEE0A`, with one halo at `lineWidth + 7` and alpha 0.22, and a short `#00F0FF` tick on the longest corner. The tick is a 2.4 px core over an 8 px cyan wash at alpha 0.35.
- Behind that halo, one wide wash at `lineWidth + 28` in `rgba(255, 132, 136, 0.07)`. It is a very dim light red, so the active page looks lit from behind. A wider yellow stack reads as a second border. Idle windows do not get this wash.
- Other windows are one thinner stroke, `rgba(252, 238, 10, 0.42)`, and they do not glow.
- Thickness still varies per edge. A focused edge is about 1.7–4.5. An idle edge is about 1.1–1.8.

Hyprland's `at` and `size` are already logical pixels, the same space as the layer. Do not divide by the monitor scale. Dividing paints the frame inside the window. Inset 3 px.

`gaps_in` 2 and `gaps_out` 3 keep the yellow wallpaper from reading as a fat border. `border_size` 0 and the shadow off mean Hyprland is not drawing a second frame under the overlay. A shadow on this layer paints full-height lines when a window sits off the monitor origin, so the shadow stays off. `resize_on_border` can stay on. Fullscreen mode 2 and above is skipped, and so are hidden and unmapped windows. A window with less than 48 px still on the monitor is skipped, so a scrolled-off neighbor does not paint a second line in the margin. Pinned windows and the open special workspace are included.

Geometry is polled every 160 ms and also on open, close, move, float, fullscreen, workspace, and focus events. The poll does not repaint when the window list is unchanged. The 1100 ms step clears that signature, so the lines do move. `Canvas` `shadowBlur` does not show on this layer.

The frame layer sits above ordinary windows, including the screensaver. The saver workspace is named `special:screensaver-<output>`. A check for a name that ends in `screensaver` misses that. While any mapped window has class `org.omarchy.screensaver`, or a workspace name contains `screensaver`, the layer sets `visible` false and paints nothing. The breach screen keeps its own chamfer. The windows underneath do not.

The service is `keepLoaded`. Editing the QML logs a reload and keeps the old instance. `omarchy restart shell` loads the new one.

`install.sh` adds `{ "id": "nightcity.frame" }` only when `shell.json` has no plugin id ending in `.frame`.

## Lock page

The packaged lock under `/usr/share/omarchy/shell/plugins/lock` stays untouched. The theme clones it to `nightcity.lock` and replaces the view.

The page frame, the password plate, and the fingerprint plate use a 1 px `strokeFrame`. No halo, and no thick core. The window glow does not belong on these plates. The page seed is 4. The password seed is 11. The fingerprint plate seed is 19. The page stroke is `#FCEE0A` with a `#00F0FF` tick, inset 16 px. The password plate is an uneven chamfered octagon, filled `rgba(8, 12, 18, 0.86)`, or `rgba(40, 8, 14, 0.88)` after a bad password. A bad password turns the stroke `#FE1038` and the tick yellow. The caption reads ACCESS.

The page is not only that box. Inside the screen stroke, `paintPage` draws 1 px cyan corner marks, a cyan rule on each side of the title, and a footer rule with two cyan diamonds. Yellow rules disappear on a yellow wallpaper, so those marks are cyan. Above the field, the row is text: NIGHT CITY in yellow, SEALED in cyan. The fingerprint reader, when one is enrolled, is its own plate under the field. The caption is TOUCH. Those four strings are `plugin/nightcity.lock/i18n/en.json`. The password field still focuses itself and drops auto-repeat.

The gaps still slide every 1100 ms while shell animations are on. That timer is the same small step as the windows.

`install.sh` will not install this clone when another plugin id ending in `.lock` is already in `shell.json`. It will not remove that plugin. When it does install, it disables `omarchy.lock` and records `nightcity.lock` in `cloneSourceRestores`, which is how the shell can hand the lock back later.

The shell has to restart once so this clone is the first lock handler. Preview with `omarchy-shell lock preview`, then `omarchy-shell lock hidePreview`. Do not lock the session just to look at it.

## Polkit

The packaged agent under `/usr/share/omarchy/shell/plugins/polkit` stays untouched. The theme clones it to `nightcity.polkit` and replaces `PolkitAgent.qml`, `i18n/en.json`, and `manifest.json`.

Password prompts stay the wide field. A fingerprint prompt is a square plate with the same 1 px broken stroke as the lock, seed 19, caption TOUCH. The plate does not glow. Its 1100 ms step runs only while that fingerprint page is showing.

`install.sh` skips the clone when another plugin id ending in `.polkit` is already enabled. It will not remove that plugin. When it does install, it disables `omarchy.polkit` and records `nightcity.polkit` in `cloneSourceRestores`. Two agents must not both be enabled.

## Screensaver

Omarchy launches `omarchy-screensaver` in foot, class `org.omarchy.screensaver`. Putting the script in `~/.config/omarchy/bin` and putting that directory first on PATH is what shadows the logo saver. `extras/hyprland.lua` does the PATH part. If the script is not executable, Hyprland falls through to the logo.

The picture is a breach screen, drawn with ImageMagick and a real font, then encoded to sixel. The headline is CONNECTION in yellow `#FCEE0A` and FLATLINED in red `#FE1038`, centered and large. A small line above it still says BREACH PROTOCOL. Under that: a 6 by 5 code grid, one daemon sequence at a time (SYNAPSE BURN, WEAPON GLITCH, REBOOT OPTICS, SONIC SHOCK), buffer pips, an upload bar, and a right-hand column for RAM, ICE, and the uplink. Dim yellow is `#6E6412`, cyan is `#00F0FF`. One tick in 22 draws a single cyan tear. It is not a character-cell picture.

`bin/cp2077-sixel.c` is the encoder. ImageMagick's own sixel quantizer turns this yellow black, and `img2sixel` is not used. The header is `ESC P 0 ; 2 ; 0 q`. P2 = 2 paints palette color 0 as opaque black. P2 = 1 leaves black transparent, and the desktop frames show through. `install.sh` compiles it with `gcc -O2` to `cp2077-sixel` beside the script. The script finds that binary next to itself.

Leaving it:

- Any key exits. The terminal is in cbreak.
- About 1.2 s after start, every 4th tick exits if the active window is no longer `org.omarchy.screensaver`.
- SIGINT, SIGTERM, and SIGHUP call the same cleanup.
- Cleanup sets Hyprland `cursor:invisible` to false. The cursor is hidden only while the saver is up. The same restore runs if the process is interrupted.
- Do not `pkill -f` the script path. That can hit the launcher pipe. Move focus to another window and let the script exit.
- `CP2077_SAVER_FRAMES` renders that many frames and exits, for a headless check. `CP2077_SAVER_PNG` writes one PNG and returns. Neither grabs the tty.

The stock `branding/screensaver.txt` is not used. Idle timeouts are the user's. This theme does not write them.

## Pointer

`cursor/` is the Night City pointer. The arrow is yellow `#FCEE0A` with a dark edge so it still shows on a yellow wallpaper, and a short cyan tick. Links use a yellow hand. Text uses a yellow bar. Resize marks are the same yellow. The not-allowed mark is a yellow ring with a red slash.

`install.sh` runs `cursor/build.py`. That compiles a hyprcursor theme with `hyprcursor-util` and an Xcursor fallback with `magick`, into `~/.local/share/icons/nightcity`, at sizes 24, 32, and 48. The theme size it selects is 32. `extras/hyprland.lua` sets `HYPRCURSOR_THEME`, `HYPRCURSOR_SIZE`, `XCURSOR_THEME`, and `XCURSOR_SIZE`. The repo keeps the SVG source. It does not keep the compiled `.hlc` files or the Xcursor blobs.

The screensaver hides the pointer while it runs and sets `cursor:invisible` back to false on the way out. A shell restart can leave it hidden if the saver is not there to restore it. Restore with `hyprctl eval 'hl.config({ cursor = { invisible = false } })'`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ha-anzu/omarchy-cyberpunk/main/install.sh | bash
```

Or clone the repo and run `install.sh` from it. Do not use `omarchy theme install` on this repo.

What the script changes:

- Replaces `~/.config/omarchy/themes/cyberpunk-2077` with a copy that has no `.git`.
- Copies `bin/`, the shader, the post-boot hook, the Night City icon theme, `nightcity.workspaces`, and `nightcity.frame`.
- Copies the screensaver into `~/.config/omarchy/bin` and compiles `cp2077-sixel` there with `gcc -O2`.
- Builds the `nightcity` pointer into `~/.local/share/icons/nightcity` and selects it at size 32.
- Installs the lock clone unless another lock plugin is already enabled.
- Installs the polkit clone unless another polkit plugin is already enabled.
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
- It does not remove a lock, frame, or polkit plugin you already enabled.
- It does not change idle or lock timeouts.
- It does not commit the compiled `cp2077-sixel` binary, the compiled pointer, or a screenshot.

A second run refreshes the theme's own files and the marked blocks. It still will not replace your lock, frame, or polkit plugin.

## Left out on purpose

- Official wallpaper binaries.
- A serial, a board serial, a product UUID, a hostname, a home directory, an email address, a MAC, a machine id, or a copied Aura object path.
- Per-key USB color writes. This keyboard cannot do them.
- A forced monitor name or refresh rate.
- A second copy of the Omarchy lock service or polkit agent inside git. The clones overlay the view. The service files stay the ones that shipped with Omarchy.
- The compiled `cp2077-sixel` binary. The C source is what the repo keeps.
- The compiled pointer. `cursor/` keeps the SVG source. `install.sh` builds it.
