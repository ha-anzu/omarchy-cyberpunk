# Agent prompt

Copy the block. Nothing else.

```
Install the Omarchy theme at https://github.com/ha-anzu/omarchy-cyberpunk
by running its install.sh. That sets the theme, the glitch, the broken
window frames, the screensaver, the district bar, and a wallpaper per desk.
Read NOTES.md and CHANGES.md before you change any of it.

Do not edit shader/cp2077.frag or the glitch timing. Quiet windows stay
8.0 and 12.5. While the shader is on, damage_tracking stays 0 and vfr
stays false. Off restores damage_tracking 2 and vfr true.
Do not run `omarchy theme install` (Omarchy deletes the theme's lua).
Do not run `omarchy refresh`.
Do not change the monitor refresh rate unless I ask.
Do not install extras/monitors-60hz.lua unless I ask.
The glitch key is Super+Shift+Alt+G. Leave it.

The frame plugin id is nightcity.frame. Hyprland's border stays 0 and
the shadow stays off. Hyprland at/size are already logical pixels.
Do not divide them by monitor.scale. Only the focused window glows:
one yellow halo, then one dim red wash at lineWidth + 28 and alpha 0.07.
The frame layer hides while the screensaver is up. The workspace name
is special:screensaver-<output>. Match the substring screensaver.
Do not enable a second frame plugin.
A QML change needs `omarchy restart shell` because the service stays loaded.

The lock clone is nightcity.lock. The polkit clone is nightcity.polkit.
Do not edit the packaged copies under /usr/share. If another lock or
polkit plugin is already enabled, leave it. Do not enable both agents.
Lock, password, fingerprint, and polkit plates stay a 1 px stroke with
no glow. Do not lock the session to preview. Use `omarchy-shell lock preview`.

bin/omarchy-screensaver must stay executable. install.sh builds
cp2077-sixel beside it with gcc. Do not commit that binary. The sixel
header keeps P2 = 2 so black stays opaque. Any key or a lost window
exits the saver, and it must restore cursor:invisible to false.
Do not pkill -f the screensaver path.
The headline is CONNECTION in yellow and FLATLINED in red.

The pointer theme is nightcity, size 32. install.sh builds it from
cursor/. Do not commit the compiled cursor. The saver must restore
cursor:invisible to false.

If I also want the keyboard to glitch, read KEYBOARD.md first.
Detect the keyboard. Do not reuse the ASUS script on other hardware.
Never save a keyboard color to flash. Never write a serial, a UUID,
a hostname, a home path, or an Aura object path into the repo.
```
