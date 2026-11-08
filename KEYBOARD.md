# Keyboard glitch

For an agent. Detect the keyboard, then pick one path. Do not paste the ASUS script onto a different machine.

The screen glitch stays as it is. Do not edit `shader/cp2077.frag`.

## Always

- Quiet for about 4–9 seconds, sometimes half that. Then a burst of 4–6 steps, 40–80 ms each. Not a metronome.
- Colors, when the hardware has them: yellow `FCEE0A`, cyan `00F0FF`, red `FE1038`. Then put the user's color back.
- Brightness only: off, full, off, full, then the level they had. Read `max_brightness`. Do not assume 3.
- Flag file `~/.local/state/omarchy/cp2077-glitch-off` means lights stay still. `Super+Shift+Alt+G` owns that flag.
- If they turn the backlight off, leave it off.
- Restore their level when the script exits.
- One process. `flock` on a runtime lock.
- Start from `~/.config/hypr/autostart.lua` with `o.launch_on_start`.
- Never save a color into the keyboard's flash inside the loop. A live write is fine. A save every hit wears the controller. The LEDs themselves are fine.

`bin/cp2077-keys` is the brightness path for `asus::kbd_backlight`, whose max is 3. Copy it. Change the device name and the max.

## Detect

```bash
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
brightnessctl -l | rg -i 'kbd|keyboard'
ls /sys/class/leds
command -v asusctl; command -v openrgb
```

Use the first row that matches.

| You find | Path |
|---|---|
| Product name contains `GZ301ZE` | Flow Z13 color. The script in this repo does it. See below |
| `asus::kbd_backlight` and a writable `kbd_rgb_mode` | ASUS color |
| `asus::kbd_backlight`, color node not writable | ASUS brightness. This is the script in the repo |
| `asusctl` works, no writable color node | asusctl, one live color at a time |
| `system76::kbd_backlight` or `system76_acpi::kbd_backlight` with `color` or `color_left` | System76 color |
| Any other `*kbd_backlight*` that `brightnessctl` can set | Brightness only |
| `openrgb -l` lists a keyboard | OpenRGB, that device only |
| Nothing | Stop. Tell them this keyboard has no software backlight |

## ASUS color

Node: `/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode`

Write six numbers. Do not save.

```bash
# cmd 0 = this boot only. mode 0 = static. speed 1 = normal.
# yellow
echo "0 0 252 238 10 1" > /sys/class/leds/asus::kbd_backlight/kbd_rgb_mode
```

`cmd` must stay `0`. `1` writes the controller's flash. Test one write. Permission denied means use the brightness script. Do not add a udev rule unless they ask for color.

Cyan is `0 0 0 240 255 1`. Red is `0 0 254 16 56 1`.

## ASUS brightness

`brightnessctl -d 'asus::kbd_backlight'`. Max is often 3 on TUF, not always. Read it.

The repo script already does this and exits if the LED is missing.

## ROG Flow Z13 GZ301ZE

The product name is `ROG Flow Z13 GZ301ZE`. That is the model. Do not read or write `product_serial`, `board_serial`, `product_uuid`, a hostname, or a home path.

There is no `kbd_rgb_mode` node, so the sysfs save bit is not available. Color goes through asusd. The keyboard is two N-KEY devices, USB `0b05:18c6` and `0b05:1a30`. Find their Aura objects. Do not copy an object path off one machine. The interface numbers at the end of the path are not part of the model.

```bash
busctl tree xyz.ljones.Asusd | grep -oE '/xyz/ljones/aura/[A-Za-z0-9_]+'
```

Write `LedModeData` as static (`0`), one live color, speed `Med`, direction `Right`. Yellow is `252 238 10`, cyan `0 240 255`, red `254 16 56`. Then write the color that was already showing.

A color write reapplies the brightness saved in asusd. Before the first burst, set the Aura `Brightness` property from the current `asus::kbd_backlight` level, and do it again if that level changes. If the backlight is `0`, leave it off.

`bin/cp2077-keys` takes this branch when the product name contains `GZ301ZE`. Other machines stay on the brightness flicker.

## asusctl

```bash
asusctl aura static -c FCEE0A
```

Same rule: set a live color, do not save a profile on every hit. If `asusctl` has no `static` on that model, stop and say so.

## System76

```bash
# one zone
echo FCEE0A > /sys/class/leds/system76_acpi::kbd_backlight/color
# or the split zones, same hex on each that exists
echo FCEE0A > /sys/class/leds/system76::kbd_backlight/color_left
```

The folder is `system76_acpi::kbd_backlight` or `system76::kbd_backlight`. Write only the files that exist. These nodes are often root-only. One denied write, fall back to brightness.

## Brightness only

ThinkPads (`tpacpi::kbd_backlight`), Dell (`dell::kbd_backlight`), Framework, and a lot of others. No color. Flicker the level `brightnessctl` already controls. Use that device's max, not 3.

## OpenRGB

```bash
openrgb -l
openrgb -d 0 -m static -c FCEE0A
```

`0` is an example. Pick the keyboard from the list, not the GPU fans. Mode name comes from `-l` (`static` or `Static`). Do not load or save a profile inside the loop.

## Done

Run one burst. Confirm the light returns to their level. Tell them which path you used, and whether color was possible.
