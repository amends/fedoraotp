# FedoraOTP

FedoraOTP is a small Fedora/GNOME utility that copies one-time passcodes from mirrored Android/SMS desktop notifications to your clipboard.

It is intended for setups like:

```text
Android phone / Google Messages
  -> KDE Connect Android notification mirroring
  -> GSConnect on Fedora GNOME
  -> FedoraOTP notification listener
  -> Wayland clipboard
```

It is basically a local, inspectable Linux version of the "2FHey" workflow: no cloud service, no browser extension, no daemon running as root.

## Features

- Watches GNOME desktop notifications on the session D-Bus.
- Extracts likely OTP/security/verification codes, including common 4–10 digit numeric codes when the notification has login/code/security wording.
- Copies only the code to the clipboard with `wl-copy`.
- Runs as a normal user-level `systemd --user` service.
- Adds an optional GNOME top-bar indicator: `OTP ●`.
- Stores only masked status, e.g. `••••56`, not full OTPs.
- Includes uninstall script.

## Requirements

Tested on Fedora 44 / GNOME 50 / Wayland.

Expected packages/commands:

- `python3`
- `dbus-monitor`
- `systemctl --user`
- `notify-send`
- `wl-copy` / `wl-paste`
- `gsettings`
- GNOME Shell, if you want the top-bar indicator

Fedora package install if needed:

```bash
sudo dnf install python3 dbus-tools libnotify wl-clipboard glib2 gnome-shell
```

For Android SMS OTP mirroring, you also want:

- GSConnect GNOME extension on Fedora
- KDE Connect Android app
- Notification access enabled for KDE Connect on Android
- Message notification content visible on Android/Fedora

## Install

```bash
git clone https://github.com/amends/fedoraotp.git
cd fedoraotp
./install.sh
```

If dependencies are missing and you are okay with `sudo dnf` installing them:

```bash
./install.sh --install-deps
```

Installer options:

```text
--install-deps       Install missing Fedora packages with sudo dnf
--no-service         Copy files but do not enable/start the user service
--no-extension       Copy files but do not enable the GNOME top-bar extension
--dry-run            Print actions without making changes
```

## Verify

After install:

```bash
systemctl --user status otp-clipboard-listener.service
```

Send a fake notification:

```bash
notify-send 'OTP Test' 'Your verification code is 123456'
wl-paste --no-newline
```

Expected output:

```text
123456
```

## GNOME top-bar indicator

The indicator appears as:

```text
OTP ●
```

Dot colors:

- Green: listener heartbeat is fresh/running
- Yellow: no fresh heartbeat/status unknown
- Red: listener stopped

The menu shows last copied masked code and has Restart/Stop actions.

GNOME Shell on Wayland often does **not** discover brand-new local extensions in the already-running session. If `OTP ●` does not appear right after install, log out and back in once.

## Real phone test

1. Pair Android KDE Connect with Fedora GSConnect.
2. Enable notification mirroring.
3. Confirm Fedora shows SMS/Google Messages notification text.
4. Trigger a real OTP.
5. Paste on Fedora.

If Fedora receives the notification with the code visible, FedoraOTP should copy the code automatically.

## Files installed

```text
~/.local/bin/otp-clipboard-listener
~/.config/systemd/user/otp-clipboard-listener.service
~/.local/share/gnome-shell/extensions/otp-clipboard@amends.local/
~/.local/share/fedoraotp/uninstall.sh
~/.local/state/otp-clipboard/status.json
~/.local/state/otp-clipboard/events.log
```

## Uninstall

```bash
~/.local/share/fedoraotp/uninstall.sh
```

Remove status/log state too:

```bash
~/.local/share/fedoraotp/uninstall.sh --remove-state
```

## Security and privacy notes

- FedoraOTP does not use the network.
- It listens to desktop notification traffic available to the current user session.
- It copies matching OTPs to the user's clipboard.
- It logs masked codes only, never full codes.
- It is intentionally small and local so another agent/human can inspect it before install.

## Development

Run basic checks:

```bash
/usr/bin/python3 -m py_compile bin/otp-clipboard-listener
bash -n install.sh scripts/uninstall.sh
./bin/otp-clipboard-listener --extract 'Your verification code is 123456'
```
