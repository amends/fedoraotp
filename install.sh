#!/usr/bin/env bash
set -euo pipefail

APP_NAME="fedoraotp"
SERVICE_NAME="otp-clipboard-listener.service"
EXT_UUID="otp-clipboard@amends.local"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENABLE_SERVICE=1
ENABLE_EXTENSION=1
INSTALL_DEPS=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs FedoraOTP: a user-scoped GNOME notification OTP copier with a top-bar indicator.

Options:
  --install-deps       Install missing Fedora packages with sudo dnf.
  --no-service         Copy files but do not enable/start the user systemd service.
  --no-extension       Copy files but do not enable the GNOME top-bar extension.
  --dry-run            Print actions without changing files/services/settings.
  -h, --help           Show this help.

Normal install:
  git clone https://github.com/amends/fedoraotp.git
  cd fedoraotp
  ./install.sh

Test after install:
  notify-send 'OTP Test' 'Your verification code is 123456'
  wl-paste --no-newline
EOF
}

for arg in "$@"; do
  case "$arg" in
    --install-deps) INSTALL_DEPS=1 ;;
    --no-service) ENABLE_SERVICE=0 ;;
    --no-extension) ENABLE_EXTENSION=0 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

copy_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
    local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing $dest -> $backup"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp -a "$dest" "$backup"
    fi
  fi
  echo "Installing $dest"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dest")"
    install -m "$mode" "$src" "$dest"
  fi
}

need_cmds=(python3 dbus-monitor systemctl notify-send wl-copy wl-paste gsettings)
missing=()
for c in "${need_cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing commands: ${missing[*]}" >&2
  if [ "$INSTALL_DEPS" -eq 1 ]; then
    if ! command -v dnf >/dev/null 2>&1; then
      echo "dnf not found; cannot auto-install dependencies." >&2
      exit 1
    fi
    echo "Installing Fedora dependencies with sudo dnf..."
    if [ "$DRY_RUN" -eq 0 ]; then
      sudo dnf install -y python3 dbus-tools libnotify wl-clipboard glib2 gnome-shell
    fi
  else
    cat >&2 <<'EOF'
Install dependencies first, or rerun with --install-deps.
Fedora packages usually needed:
  sudo dnf install python3 dbus-tools libnotify wl-clipboard glib2 gnome-shell
EOF
    exit 1
  fi
fi

if command -v gnome-shell >/dev/null 2>&1; then
  shell_version="$(gnome-shell --version 2>/dev/null || true)"
  echo "Detected: ${shell_version:-gnome-shell present}"
fi

copy_file "$REPO_DIR/bin/otp-clipboard-listener" "$HOME/.local/bin/otp-clipboard-listener" 0755
copy_file "$REPO_DIR/systemd/user/$SERVICE_NAME" "$HOME/.config/systemd/user/$SERVICE_NAME" 0644
copy_file "$REPO_DIR/gnome-extension/$EXT_UUID/metadata.json" "$HOME/.local/share/gnome-shell/extensions/$EXT_UUID/metadata.json" 0644
copy_file "$REPO_DIR/gnome-extension/$EXT_UUID/extension.js" "$HOME/.local/share/gnome-shell/extensions/$EXT_UUID/extension.js" 0644
copy_file "$REPO_DIR/scripts/uninstall.sh" "$HOME/.local/share/fedoraotp/uninstall.sh" 0755

if [ "$DRY_RUN" -eq 0 ]; then
  /usr/bin/python3 -m py_compile "$HOME/.local/bin/otp-clipboard-listener"
fi

if [ "$ENABLE_SERVICE" -eq 1 ]; then
  echo "Enabling user service..."
  if [ "$DRY_RUN" -eq 0 ]; then
    systemctl --user daemon-reload
    if systemctl --user is-active --quiet "$SERVICE_NAME"; then
      systemctl --user restart "$SERVICE_NAME"
    else
      systemctl --user enable --now "$SERVICE_NAME"
    fi
    systemctl --user enable "$SERVICE_NAME" >/dev/null
  fi
fi

if [ "$ENABLE_EXTENSION" -eq 1 ]; then
  echo "Enabling GNOME extension in enabled-extensions list..."
  if [ "$DRY_RUN" -eq 0 ]; then
    python3 - <<'PY'
import ast
import subprocess
uuid = 'otp-clipboard@amends.local'
key = ['gsettings', 'get', 'org.gnome.shell', 'enabled-extensions']
try:
    cur = subprocess.check_output(key, text=True).strip()
    arr = ast.literal_eval(cur)
    if not isinstance(arr, list):
        arr = []
except Exception:
    arr = []
if uuid not in arr:
    arr.append(uuid)
    subprocess.run(['gsettings', 'set', 'org.gnome.shell', 'enabled-extensions', str(arr)], check=True)
PY
    if command -v gnome-extensions >/dev/null 2>&1; then
      gnome-extensions enable "$EXT_UUID" >/dev/null 2>&1 || true
    fi
  fi
fi

cat <<EOF

FedoraOTP installed.

Status:
  systemctl --user status $SERVICE_NAME

Test:
  notify-send 'OTP Test' 'Your verification code is 123456'
  wl-paste --no-newline

Top-bar indicator:
  Look for "OTP ●" in GNOME's top bar. If it does not appear immediately,
  log out and back in once; GNOME Wayland often does not discover brand-new
  local extensions until the next shell session.

Uninstall:
  ~/.local/share/fedoraotp/uninstall.sh
EOF
