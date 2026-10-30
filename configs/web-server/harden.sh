#!/usr/bin/env bash
# Hardening steps applied to the DMZ web server (Ubuntu Server).
# Run as a normal user with sudo rights, over SSH from the LAN (10.10.10.0/24).
# The UFW SSH rule is added BEFORE enabling UFW so the session survives.
set -euo pipefail

CONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/8] Updating packages"
sudo apt update
sudo apt upgrade -y

echo "[2/8] Host firewall (UFW)"
sudo ufw default deny incoming
sudo ufw allow from 10.10.10.0/24 to any port 22 proto tcp
sudo ufw allow 80/tcp
sudo ufw --force enable

echo "[3/8] Intrusion and malware tools"
sudo apt install -y fail2ban
sudo apt install -y --no-install-recommends rkhunter
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl restart fail2ban

echo "[4/8] Security packages (apt-listbugs has no candidate in this release, so it is left out)"
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  libpam-tmpdir apt-listchanges debsums apt-show-versions \
  libpam-pwquality acct auditd

echo "[5/8] Password aging for new accounts"
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs

echo "[6/8] Legal banner"
echo "Authorized access only. Activity is monitored and logged." | sudo tee /etc/issue /etc/issue.net >/dev/null

echo "[7/8] Block unused kernel modules"
sudo install -m 644 "$CONF_DIR/hardening-modprobe.conf" /etc/modprobe.d/hardening.conf

echo "[8/8] Kernel and network settings"
sudo install -m 644 "$CONF_DIR/99-hardening.conf" /etc/sysctl.d/99-hardening.conf
sudo sysctl --system >/dev/null

echo "Done. Reboot to load any pending kernel update, then run: sudo lynis audit system --quick"
