# ASUS Zenbook Pro 16X (UX7602) Linux fixes

Userspace workarounds for hardware that doesn't work out of the box on Linux
on the ASUS Zenbook UX7602. Developed on a UX7602VI (BIOS 300) running CachyOS
with kernel 7.2, Hyprland and PipeWire 1.6 / WirePlumber 0.5. Nothing here
patches or rebuilds the kernel.

## What it fixes

| Problem | Cause | Fix |
|---|---|---|
| Most Fn hotkeys dead (brightness, touchpad, mic mute, ...) | Keyboard `0b05:8854` is missing from `hid-asus`'s ID table and falls back to `hid-generic` | `asus-kbd-8854` registers the ID with `hid-asus` at boot and rebinds the hotkey interface |
| Fn+Esc (Fn lock) does nothing | Same; needs the driver's Fn-lock quirk | Same registration, with `QUIRK_HID_FN_LOCK` |
| Keyboard backlight dark / not controllable | Firmware only accepts lighting commands on USB interface 0; the kernel LED uses interface 1 | `asus-kbd-rgb` talks to the keyboard over hidraw; restored at boot, off across suspend |
| Keyboard dark at the disk-encryption passphrase prompt | Same, and the backlight comes up dark after a cold boot, before `asus-kbd-rgb` runs | `asus-kbd-backlight` mkinitcpio hook lights it from a udev rule in the initramfs |
| Mic-mute key LED never lights | PipeWire mutes in software and never drives the LED | `micmute-led-sync` user service follows the default source's mute state |
| Camera key (Fn+F10) LED never lights, no feedback | Key code unmapped by the kernel; LED is a GPIO behind an unused WMI ID | `asus-camera-led` (LED) and `asus-hotkey-notify` (notification) read the raw key report |
| Touchpad haptic click strength random after boot/resume, sometimes no click at all | Nothing sets the pad's HID haptic intensity feature | `asus-touchpad-haptic` sets it at boot and after resume |
| Volume only changes one of the two speaker pairs | The second pair's DAC has no hardware volume control | WirePlumber rule switching the card to software volume |

## Install

```sh
./install.sh      # as your normal user; asks for sudo
./uninstall.sh
```

Requirements: `python3`, `perl` (initramfs hook), `v4l-utils` (`v4l2-ctl`), `alsa-utils`,
`brightnessctl`, `libnotify` (`notify-send`, used when `noctalia` is not on `PATH`),
PipeWire with `pipewire-pulse` (`pactl`) and WirePlumber, and debugfs mounted (for
the camera LED).

The initramfs hook needs `mkinitcpio` (`install.sh` skips it on other initramfs
generators) and rebuilds your images with `limine-mkinitcpio` where Limine's hook
manages them (it ships no presets, so `mkinitcpio -P` finds nothing to build) and
with `mkinitcpio -P` elsewhere.

Kernel lockdown, which Secure Boot enables on most distributions, blocks writes to
debugfs. The camera LED service then logs one message and stays stopped, and
everything else still works.

Your user must be in the `video` group. The mic-mute LED is driven from the user
session through a udev rule that gives that group write access to it.

Your compositor session has to activate `graphical-session.target`, because it
starts the two user services (`micmute-led-sync`, `asus-hotkey-notify`). Desktop
environments and uwsm-managed sessions do. A bare Hyprland or sway session
started from a TTY without systemd integration does not, and the services would
then only run once, at install time.

`examples/hyprland-binds.lua` and `examples/niri/binds.kdl` have key binds for
the keys that reach the compositor. niri has no runtime touchpad toggle, so
`examples/niri/touchpad-toggle` implements Fn+F6 by flipping a one-line config
include that niri reloads.

The speaker fix has two parts. The WirePlumber rule matches the card by name
(`alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic`), and `install.sh`
sets the hardware "Speaker" control of the `sofhdadsp` card to 100% once.

That level must stay at 100%. It survives reboots only if your distribution
restores the ALSA mixer state at boot (`alsa-restore.service`, enabled by default
on Arch). If the speakers come back unbalanced after a reboot, re-run
`amixer -c sofhdadsp sset Speaker 100% unmute` or enable that service.

## Change backlight colour, brightness and click strength

```sh
sudo asus-kbd-rgb color ff8800       # backlight colour (saved)
sudo asus-kbd-rgb brightness 0-3     # backlight level restored at boot (saved)
sudo asus-touchpad-haptic set 50     # click strength: 0, 25, 50, 75 or 100 (saved)
```

To run `asus-kbd-rgb` without a password (for example from a key bind):

```sh
printf '%s\n' \
  "Defaults!/usr/local/sbin/asus-kbd-rgb secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/bin\"" \
  "$USER ALL=(root) NOPASSWD: /usr/local/sbin/asus-kbd-rgb" | sudo tee /etc/sudoers.d/asus-kbd-rgb >/dev/null
sudo chmod 440 /etc/sudoers.d/asus-kbd-rgb && sudo visudo -cf /etc/sudoers.d/asus-kbd-rgb
```

The `Defaults` line pins `PATH` for that command, so the rule stays limited to
the script even on systems whose sudoers policy does not set `secure_path`.

## Keyboard backlight at the disk-encryption passphrase prompt

The `asus-kbd-backlight` mkinitcpio hook (`/etc/initcpio/install`, enabled through
`/etc/mkinitcpio.conf.d/30-asus-kbd-backlight.conf`) puts `asus-kbd-rgb-initrd`, a
perl cut of `asus-kbd-rgb` (python does not fit in an initramfs; perl has `ioctl`
built in and needs no modules), and a udev rule into the image. The rule runs it the
moment the keyboard's interface 0 hidraw node appears, so the keys are lit before
the passphrase prompt. It works with both the `udev` and the `systemd` hook and
needs the `keyboard` hook, which every encrypted setup already has.

The level and colour are the saved `asus-kbd-rgb` settings at the time the image is
built, with a saved level of 0 raised to 1. After changing them, rebuild the
images (`sudo limine-mkinitcpio`, or `sudo mkinitcpio -P` with presets) if you want
the prompt to match; otherwise it catches up at the next kernel update.

## Hardware findings behind the scripts

These notes are for anyone who wants to do this properly upstream.

### Keyboard (USB `0b05:8854`, "N-KEY Device")

- Three HID interfaces: 0 = plain keyboard, 1 = vendor page `0xff31`
  (report `0x5a`) plus consumer control, 2 = vendor page `0xff82`.
- Works with `hid-asus` using `QUIRK_USE_KBD_BACKLIGHT | QUIRK_ROG_NKEY_KEYBOARD |
  QUIRK_HID_FN_LOCK` (`0x4820`), registered through
  `/sys/bus/hid/drivers/asus/new_id`. A dynamic ID can't be removed or changed
  without unloading `hid_asus`.
- Two keys are not media keys at all. The firmware sends them as ordinary
  keyboard chords that mirror Windows shortcuts, so your compositor sees them
  exactly as if you had typed the chord, and must bind the chord to give the
  key a meaning:
  - Fn+F8 ("project") = Super+P. Unbound, it reaches the focused window, and a
    terminal types a plain `p`.
  - Fn+F11 ("snip") = Super+Shift+S. Whatever you bind there runs on Fn+F11 too.
- Vendor codes `0x85` (Fn+F10, camera) and `0x86` (Fn+F12) are unmapped in
  `hid-asus`.
- Fn+Alt+F4 is special-cased by the firmware and arrives as a plain Alt+F4
  instead of Alt + brightness-down (Fn+Alt+F5 is a normal Alt + brightness-up).
  Use another modifier for a fine brightness step.
- The camera report is `5a 85 <state>`: `0x10` = camera blocked, `0x01` =
  available. The firmware toggles the webcam itself; the webcam's read-only V4L2
  `privacy` control reflects the state.
- Fn lock: feature report `5a d0 4e <0|1>` on interface 1; 1 = F1-F12
  without Fn. Fn+Esc sends `5a 4e`.
- Backlight (protocol from [zenauracore](https://github.com/Novaryu/zenauracore)),
  64-byte feature reports on **interface 0**:
  init `5a "ASUS Tech.Inc."`, colour `5c a0 00 00 R G B` then `5c a5 00 00 R G B`,
  brightness `5a ba c5 c4 <0-3>`. The kernel's `asus::kbd_backlight` LED sends
  to interface 1 and has no effect.
- After the init message the firmware cycles brightness on Fn+F7 by itself,
  and restores its level on resume. It does not turn the light off on suspend
  and comes up dark after a cold boot.

### Camera key LED

GPIO `0x090E000F` (`CLED` in the DSDT, active low), reachable through WMI
device ID `0x00060078` (`ASUS_WMI_DEVID_CAMERA_LED_NEG`, unused by the
kernel). `DEVS` only accepts 5 (LED on) and 4 (LED off). The scripts go
through `/sys/kernel/debug/asus-nb-wmi`.

### Touchpad (I2C HID `093a:3f01`, `ASUP1413`)

Exposes HID "Simple Haptic Controller / Intensity" (usage page `0x0e`, usage
`0x23`) as feature report `0x09`, one byte. The firmware accepts only 0, 25,
50, 75 and 100; other values are ignored, and the value can't be read back.
0 disables clicking entirely.

### Speakers (ALC285 + 2x CS35L41, SSID `1043:16f3`)

Pin `0x14` ("Speaker") is fed by DAC `0x02`, which has a volume control; pin
`0x17` ("Bass Speaker") is fed by DAC `0x06`, which has none. Hardware volume
therefore changes the balance between the pairs. The WirePlumber rule sets
`api.alsa.soft-mixer` for the card; the hardware "Speaker" control must stay
at 100%. A kernel-side fix would be routing pin `0x17` to DAC `0x02`.

### Dial (I2C HID `0b05:0220`, `ASUS2020`) - not handled by this repo

A standard HID radial controller (application usage "System Multi-Axis
Controller"). The kernel binds `hid-generic` but creates no input device for
that application, so events are only visible on the device's hidraw node.
Input report `01 <button> <delta lo> <delta hi>`: `button` is 1 while the
centre button is held; `delta` is a signed 16-bit rotation step (+1 / -1 per
detent). Touching or tapping the ring without rotating reports nothing. A
small root service (or a udev `uaccess` rule plus a user service) could turn
these into uinput events.

### Touchpad NumberPad - not handled by this repo

Only the backlight is a hardware feature. Feature report `0x0d` with payload
`14 03 <value> ad` on the touchpad's hidraw node controls it: `01` = on,
`00` = off, `41`..`48` = brightness (dim to bright). This is the same command
[asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver)
sends over raw I2C to other ASUS touchpads.

With the backlight on, the pad still behaves as a plain touchpad: the
firmware does not type digits and does not react to the two corner icons.
The hot zones and the digit layout have to be implemented in software (grab
the touchpad, map touch positions to keys through uinput), which is what the
project above does for other models.

### Plymouth boot splash: black screen until Esc (OLED panel self-refresh) - not handled by this repo

With full-disk encryption the Plymouth passphrase prompt stayed black; pressing
Esc twice (details view, then back) made it appear. Plymouth's debug log showed
it had drawn the prompt and presented exactly one frame; the kernel logged
nothing.

The cause: the eDP OLED panel supports PSR1 and was sitting in self-refresh
(`i915_edp_psr_status`: `SRDENT`) when i915 took over from the firmware
framebuffer. That first page flip never reached the panel. Later flips (the Esc
redraws) did.

Fix: `i915.enable_psr=0` on the kernel command line (`/etc/default/limine`,
then `limine-update`). Two related changes are kept as well, both harmless on
their own: `/etc/mkinitcpio.conf.d/20-early-kms-intel.conf` with
`MODULES=(i915)` so only the Intel driver is in the initramfs (the panel is
wired to the iGPU; the NVIDIA modules chwd adds there are not needed before
root is mounted), and a `plymouth-start.service` drop-in with
`After=systemd-modules-load.service` so Plymouth starts with the DRM device
already present. `plymouth.use-simpledrm=0` was tried first and is not the fix;
it is kept only because Plymouth now starts after i915 anyway.
