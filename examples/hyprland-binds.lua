-- Example Hyprland (Lua config) key binds for the ASUS Zenbook UX7602.
--
-- These cover the keys that reach the compositor once the fixes in this repo
-- are installed. The commands are from a noctalia shell setup and are
-- commented out: replace each with whatever your shell / OSD / notifier uses.
--
-- Keys that need NO bind, because firmware or the kernel handles them:
--   Fn+F7   keyboard backlight level (keyboard firmware, after asus-kbd-rgb init)
--   Fn+F10  webcam on/off (firmware; LED and notification come from the
--           asus-camera-led and asus-hotkey-notify services)
--   Fn+Esc  Fn lock (hid-asus, via the QUIRK_HID_FN_LOCK flag)

-- local noctCall = "noctalia msg "

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio (Fn+F1/F2/F3, Fn+F9). The mic-mute LED follows PipeWire's mute state
-- through the micmute-led-sync service, whatever toggles the mute.
-- hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
-- hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
-- hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })
-- hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "mic-mute"),    { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

-- Screen brightness (Fn+F4/F5)
-- hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
-- hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true })

-- Touchpad toggle (Fn+F6)
local TOUCHPAD = "asup1413:00-093a:3f01-touchpad"
local touchpadEnabled = true
hl.bind("XF86TouchpadToggle", function()
    touchpadEnabled = not touchpadEnabled
    hl.device({ name = TOUCHPAD, enabled = touchpadEnabled })
    -- hl.exec_cmd(noctCall .. "notification-show Touchpad " .. (touchpadEnabled and "enabled" or "disabled"))
    hl.exec_cmd("notify-send Touchpad " .. (touchpadEnabled and "enabled" or "disabled"))
end, { locked = true })

-- Fn+F8 and Fn+F11 arrive as the Windows chords Super+P ("project") and
-- Super+Shift+S ("snip"), so these binds fire for the keys and the chords alike.
-- hl.bind("SUPER + P",         hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center monitor"))
-- hl.bind("SUPER SHIFT + S",   hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind("SUPER + P",         hl.dsp.exec_cmd("your-display-switcher"))
hl.bind("SUPER SHIFT + S",   hl.dsp.exec_cmd("your-region-screenshot-tool"))

-- Optional: keyboard backlight off while the lid is closed without suspending.
-- Needs the sudoers drop-in described in the README.
-- hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("sudo -n /usr/local/sbin/asus-kbd-rgb sleep"), { locked = true })
-- hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("sudo -n /usr/local/sbin/asus-kbd-rgb wake"),  { locked = true })
