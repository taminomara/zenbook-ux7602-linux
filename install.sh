#!/bin/bash
# Install the ASUS Zenbook UX7602 fixes. Run as your normal user; the system
# parts are installed through sudo.
set -euo pipefail
cd "$(dirname "$0")"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not as root." >&2
    exit 1
fi

# Rebuild every initramfs. Distributions that boot through limine-mkinitcpio-hook
# ship no presets, so mkinitcpio -P finds nothing there; its own tool does the job.
rebuild_initramfs() {
    if command -v limine-mkinitcpio >/dev/null; then
        sudo limine-mkinitcpio
    else
        sudo mkinitcpio -P
    fi
}

# Check everything up front, so a missing tool does not stop the script halfway
# with the system half installed.
missing=
for tool in python3 perl v4l2-ctl brightnessctl pactl notify-send amixer; do
    command -v "$tool" >/dev/null || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "missing tools:$missing (see Requirements in README.md)" >&2
    exit 1
fi
if ! systemctl --user is-system-running >/dev/null 2>&1; then
    echo "no user session bus: run this from your desktop session, not from a bare TTY or ssh." >&2
    exit 1
fi

product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case $product in
    *UX7602*) ;;
    *)  echo "warning: this looks like a '${product:-unknown}', not a Zenbook UX7602. The root" >&2
        echo "         services register a hid-asus quirk and poke a WMI device by ID; they" >&2
        echo "         are gated on the keyboard's USB ID but were only tested on a UX7602VI." >&2
        read -r -p "Continue anyway? [y/N] " answer
        case $answer in [Yy]*) ;; *) exit 1 ;; esac ;;
esac

echo "== System scripts, units and udev rule (sudo)"
# Settings used to live in /var/lib/asus-kbd-rgb; carry them over once.
if [ -d /var/lib/asus-kbd-rgb ] && [ ! -d /var/lib/asus-ux7602 ]; then
    sudo mkdir -p /var/lib/asus-ux7602
    [ -f /var/lib/asus-kbd-rgb/state.json ] && sudo mv /var/lib/asus-kbd-rgb/state.json /var/lib/asus-ux7602/kbd-rgb.json
    [ -f /var/lib/asus-kbd-rgb/haptic ] && sudo mv /var/lib/asus-kbd-rgb/haptic /var/lib/asus-ux7602/touchpad-haptic
    sudo rm -rf /var/lib/asus-kbd-rgb
fi
sudo install -Dm755 -t /usr/local/sbin bin/asus-kbd-8854 bin/asus-kbd-rgb bin/asus-kbd-rgb-initrd bin/asus-touchpad-haptic bin/asus-camera-led
sudo install -Dm644 -t /etc/systemd/system systemd/system/asus-kbd-8854.service \
    systemd/system/asus-kbd-rgb.service systemd/system/asus-ux7602-sleep.service systemd/system/asus-touchpad-haptic.service systemd/system/asus-camera-led.service
sudo install -Dm644 -t /etc/udev/rules.d udev/70-asus-kbd-hotkeys.rules udev/70-asus-micmute-led.rules udev/70-asus-touchpad-haptic.rules
sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl enable asus-kbd-8854.service asus-kbd-rgb.service asus-ux7602-sleep.service asus-camera-led.service
sudo systemctl restart asus-kbd-8854.service asus-kbd-rgb.service
sudo udevadm trigger --subsystem-match=hidraw --action=add
sudo udevadm trigger --subsystem-match=leds --action=add
sudo systemctl restart asus-camera-led.service

if command -v mkinitcpio >/dev/null; then
    echo "== Initramfs hook: keyboard backlight at the disk passphrase prompt (sudo)"
    sudo install -Dm644 initcpio/asus-kbd-backlight /etc/initcpio/install/asus-kbd-backlight
    sudo install -Dm644 initcpio/30-asus-kbd-backlight.conf /etc/mkinitcpio.conf.d/30-asus-kbd-backlight.conf
    rebuild_initramfs
else
    echo "warning: no mkinitcpio; skipping the initramfs hook (keyboard stays dark at the disk passphrase prompt)" >&2
fi

echo "== User scripts, units and WirePlumber rule"
install -Dm755 -t ~/.local/bin user-bin/micmute-led-sync user-bin/asus-hotkey-notify
install -Dm644 -t ~/.config/systemd/user systemd/user/micmute-led-sync.service systemd/user/asus-hotkey-notify.service
install -Dm644 -t ~/.config/wireplumber/wireplumber.conf.d wireplumber/50-asus-ux7602-softvol.conf
systemctl --user daemon-reload
systemctl --user enable micmute-led-sync.service asus-hotkey-notify.service
systemctl --user restart micmute-led-sync.service asus-hotkey-notify.service
systemctl --user restart wireplumber.service
sleep 2
# With software volume the hardware control must sit at 0 dB for both speaker pairs to balance.
amixer -q -c sofhdadsp sset Speaker 100% unmute || echo "warning: could not set the hardware Speaker control" >&2

echo
echo "Done. Saved settings (what the tools apply at boot, not a read-back from the hardware):"
echo "      keyboard backlight: $(sudo /usr/local/sbin/asus-kbd-rgb status)"
echo "      touchpad haptics:   $(sudo /usr/local/sbin/asus-touchpad-haptic get)"
echo "If the kernel had an older registration for the keyboard, reboot for a changed QUIRKS value to apply."
echo "See README.md for the settings commands and examples/ for compositor key binds."
