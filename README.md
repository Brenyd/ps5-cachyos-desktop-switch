# PS5 CachyOS: "Switch to Desktop" fix

A fix for switching from gaming mode (Gamescope + Steam) to desktop mode (KDE Plasma) on a PS5 running the ps5-linux CachyOS image.

## The problem

- Steam's built-in **Power → Switch to Desktop** button shows "switching to desktop" and does nothing.
- `~/switch-to-desktop.sh` gives a black screen / no signal on the TV.

## Why it happens

1. **Steam's button isn't wired up.** Steam is launched with `-gamepadui` but not `-steamos3` (left out on purpose to avoid an update-error loop on CachyOS), so the button never calls `steamos-session-select`.
2. **The old script killed itself.** `pkill -f "g[a]mescope"` matched the script's own `bash -c` command line, so it died before restarting tty1.
3. **Leftover Plasma sessions.** kwin and plasmashell run as systemd user services. `pkill kwin_wayland` alone gets them restarted by `kwin_wayland_wrapper`/systemd, and a new Plasma session then hangs waiting on the old one.
4. **Double restart race.** Killing gamescope already makes tty1 respawn and start Plasma. The old script then restarted tty1 again a few seconds later, killing Plasma mid-startup.

The fixed script stops Plasma's user services properly, uses anchored `pkill` patterns, lets tty1 respawn on its own, and only forces a restart if Plasma didn't start within 10 seconds.

## Install

1. Copy `ps5-desktop-switch-fix.sh` to your PS5's home folder, for example from your PC:
   ```bash
   scp ps5-desktop-switch-fix.sh steam@<ps5-ip>:~/
   ```
   Or download it directly on the PS5:
   ```bash
   curl -LO https://raw.githubusercontent.com/Brenyd/ps5-cachyos-desktop-switch/main/ps5-desktop-switch-fix.sh
   ```
2. SSH in as `steam` and run it (no sudo):
   ```bash
   bash ~/ps5-desktop-switch-fix.sh
   ```
   Your old `~/switch-to-desktop.sh` is backed up next to it.
3. Switch to desktop once from SSH:
   ```bash
   ~/switch-to-desktop.sh
   ```
4. In desktop mode, open Steam → **Games → Add a Non-Steam Game to My Library** → tick **Switch to Desktop** → **Add Selected Programs**.

## Usage

- **Gaming → Desktop:** launch **Switch to Desktop** from your Steam library. Takes about 5–15 seconds.
- **Desktop → Gaming:** use the **Return to Gaming Mode** icon on the desktop.

## If you get a black screen

SSH in, wait about 15 seconds, then:

```bash
sudo systemctl restart getty@tty1.service
```

Logs worth checking:

```bash
cat /tmp/ps5-desktop-switch-root.log
tail -20 /tmp/ps5-tty-session.log
pgrep -a "startplasma|kwin|plasmashell|gamescope"
cat ~/.config/ps5-next-session
```

## Requirements

Assumes the standard ps5-linux CachyOS image:

- user `steam` with passwordless sudo
- tty1 autologin
- `/etc/profile.d/ps5-tty-session.sh` reading `~/.config/ps5-next-session`

Use at your own risk.
