#!/bin/bash
# Remove everything install.sh installed. Run as your normal user.
set -uo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not as root." >&2
    exit 1
fi

echo "== User parts"
systemctl --user disable --now micmute-led-sync.service asus-hotkey-notify.service
rm -f ~/.config/systemd/user/micmute-led-sync.service ~/.config/systemd/user/asus-hotkey-notify.service
rm -f ~/.local/bin/micmute-led-sync ~/.local/bin/asus-hotkey-notify
rm -f ~/.config/wireplumber/wireplumber.conf.d/50-asus-ux7602-softvol.conf
systemctl --user daemon-reload
systemctl --user restart wireplumber.service

echo "== System parts (sudo)"
sudo systemctl disable --now asus-camera-led.service asus-ux7602-sleep.service asus-kbd-rgb.service asus-kbd-8854.service
sudo rm -f /etc/systemd/system/asus-kbd-8854.service /etc/systemd/system/asus-kbd-rgb.service /etc/systemd/system/asus-ux7602-sleep.service /etc/systemd/system/asus-touchpad-haptic.service \
    /etc/systemd/system/asus-camera-led.service
sudo rm -f /usr/local/sbin/asus-kbd-8854 /usr/local/sbin/asus-kbd-rgb /usr/local/sbin/asus-touchpad-haptic \
    /usr/local/sbin/asus-camera-led
# The sudoers drop-in is not created by install.sh; the README's Settings section
# tells the user to create it by hand, so it is cleaned up here.
sudo rm -f /etc/udev/rules.d/70-asus-kbd-hotkeys.rules /etc/udev/rules.d/70-asus-micmute-led.rules /etc/udev/rules.d/70-asus-touchpad-haptic.rules /etc/sudoers.d/asus-kbd-rgb
sudo rm -rf /var/lib/asus-ux7602
sudo systemctl daemon-reload
sudo udevadm control --reload

echo
echo "Done. Reboot to hand the keyboard back to hid-generic and reset the hardware state."
