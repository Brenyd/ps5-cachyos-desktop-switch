#!/bin/bash
# PS5 CachyOS - "Switch to Desktop" fix installer
#
# What it does:
#   1. Backs up your current ~/switch-to-desktop.sh (if any)
#   2. Installs a fixed ~/switch-to-desktop.sh
#   3. Adds a "Switch to Desktop" app entry you can add to Steam as a Non-Steam Game
#
# Run as the steam user (NOT with sudo):   bash ~/ps5-desktop-switch-fix.sh
# Assumes the standard ps5-linux CachyOS image: user "steam", tty1 autologin,
# /etc/profile.d/ps5-tty-session.sh reading ~/.config/ps5-next-session.

set -e

if [ "$(id -un)" != "steam" ]; then
  echo "Run this as the 'steam' user, without sudo."
  exit 1
fi

if [ -f ~/switch-to-desktop.sh ]; then
  cp ~/switch-to-desktop.sh ~/switch-to-desktop.sh.bak-$(date +%Y%m%d-%H%M%S)
  echo "Backed up old ~/switch-to-desktop.sh"
fi

cat > ~/switch-to-desktop.sh << 'SCRIPT_EOF'
#!/bin/bash
# Switch to Desktop v10 - no double getty restart; fallback only if Plasma didn't start
# If you ever black-screen after switching: SSH in and run
#   sudo systemctl restart getty@tty1.service

sudo systemctl stop session-rollback.timer session-rollback.service ps5-desktop-switch.service 2>/dev/null

sudo systemd-run --unit=ps5-desktop-switch --collect bash -c '
  LOG=/tmp/ps5-desktop-switch-root.log
  log() { echo "$(date +%T) $*" >> "$LOG"; }
  TOKEN=/home/steam/.config/ps5-next-session
  log "=== start"

  echo plasma > "$TOKEN"

  # 1. Clear any leftover Plasma (systemd user services first, then stragglers)
  systemctl --user -M steam@ stop graphical-session.target "plasma-*" 2>/dev/null
  pkill -f "^/usr/bin/kwin_wayland_wrapper" 2>/dev/null
  pkill -x kwin_wayland 2>/dev/null
  pkill -x plasmashell 2>/dev/null
  pkill -f "^/usr/bin/startplasma-wayland" 2>/dev/null
  for i in $(seq 10); do
    pgrep -x kwin_wayland >/dev/null || pgrep -x plasmashell >/dev/null || break
    sleep 0.5
  done
  log "plasma leftovers: $(pgrep -a "kwin|plasmashell" | tr "\n" " ")"

  # 2. Re-assert token, then end gaming mode. tty1 respawns on its own.
  echo plasma > "$TOKEN"
  pkill gamescope 2>/dev/null
  pkill -f "^(/usr/bin/)?gamescope" 2>/dev/null
  log "gamescope killed"

  # 3. Fallback: only restart tty1 if Plasma did not start by itself
  sleep 10
  if pgrep -f "^/usr/bin/startplasma-wayland" >/dev/null; then
    log "startplasma running - ok"
  else
    log "startplasma NOT running - forcing getty restart (token=$(cat $TOKEN))"
    echo plasma > "$TOKEN"
    systemctl restart getty@tty1.service
  fi
  log "=== done"
' >/dev/null 2>&1

echo "switching to desktop..."
SCRIPT_EOF

chmod +x ~/switch-to-desktop.sh

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/switch-to-desktop.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Name=Switch to Desktop
Exec=/home/steam/switch-to-desktop.sh
Icon=computer
Type=Application
Terminal=false
DESKTOP_EOF

echo
echo "Installed. Next steps:"
echo "  1. Go to desktop mode once:  ~/switch-to-desktop.sh"
echo "  2. In desktop Steam: Games > Add a Non-Steam Game to My Library > tick 'Switch to Desktop'"
echo "  3. In gaming mode, launch 'Switch to Desktop' from your library"
