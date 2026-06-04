#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="otp-clipboard-listener.service"
EXT_UUID="otp-clipboard@amends.local"
REMOVE_STATE=0

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--remove-state]

Removes FedoraOTP's user service, listener, GNOME top-bar extension, and installed uninstall helper.

Options:
  --remove-state   Also delete ~/.local/state/otp-clipboard logs/status.
  -h, --help       Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --remove-state) REMOVE_STATE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/$SERVICE_NAME"
systemctl --user daemon-reload 2>/dev/null || true

python3 - <<'PY'
import ast
import subprocess
uuid = 'otp-clipboard@amends.local'
try:
    cur = subprocess.check_output(['gsettings', 'get', 'org.gnome.shell', 'enabled-extensions'], text=True).strip()
    arr = ast.literal_eval(cur)
    if uuid in arr:
        arr = [x for x in arr if x != uuid]
        subprocess.run(['gsettings', 'set', 'org.gnome.shell', 'enabled-extensions', str(arr)], check=True)
except Exception as e:
    print(f'warning: could not update GNOME enabled extensions: {e}')
PY

rm -f "$HOME/.local/bin/otp-clipboard-listener"
rm -rf "$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
rm -rf "$HOME/.local/share/fedoraotp"

if [ "$REMOVE_STATE" -eq 1 ]; then
  rm -rf "$HOME/.local/state/otp-clipboard"
fi

echo 'FedoraOTP removed. Log out/in if GNOME still shows the indicator.'
