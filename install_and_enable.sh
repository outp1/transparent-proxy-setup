#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ensure we have the proxy parsed for info messages
source "$SCRIPT_DIR/env.sh"

# Install required packages (respect legacy iptables; avoid nft-only packages)
sudo pacman -S --needed --noconfirm dnsmasq ipset || true
if ! command -v redsocks >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm redsocks || yay --noconfirm -S redsocks || true
fi

# Create ipsets early so dnsmasq can populate them
sudo ipset create openai hash:ip family inet timeout 86400 2>/dev/null || true
sudo ipset create openai6 hash:ip family inet6 timeout 86400 2>/dev/null || true

# Render redsocks.conf from template using ~/.openai_env
"$SCRIPT_DIR/render_redsocks.sh"

# Copy configs into /etc
sudo install -m 0644 "$SCRIPT_DIR/dnsmasq-openai.conf" /etc/dnsmasq.d/openai-ipset.conf
sudo install -m 0644 "$SCRIPT_DIR/redsocks.conf" /etc/redsocks.conf

# Snapshot current upstream resolvers before switching to 127.0.0.1
if [[ -f /etc/resolv.conf ]]; then
  awk '/^nameserver /{print}' /etc/resolv.conf | sudo tee /etc/dnsmasq.upstream >/dev/null
fi

# Ensure dnsmasq uses fixed upstream file and listens locally
sudo tee /etc/dnsmasq.d/00-openai-local.conf >/dev/null <<'EOF'
listen-address=127.0.0.1
bind-interfaces
cache-size=10000
resolv-file=/etc/dnsmasq.upstream
EOF

# Ensure dnsmasq is enabled and started
sudo systemctl enable --now dnsmasq || true
if ! systemctl is-active --quiet dnsmasq; then
  # Disable known conflicting interface config if present
  if [[ -f /etc/dnsmasq.d/ap0.conf ]]; then
    echo "Disabling conflicting /etc/dnsmasq.d/ap0.conf (unknown interface ap0)"
    sudo mv /etc/dnsmasq.d/ap0.conf /etc/dnsmasq.d/ap0.conf.disabled
  fi
  sudo systemctl restart dnsmasq
fi

# Ensure local resolver uses dnsmasq. If resolv.conf is managed by NetworkManager, set dns=default and a 127.0.0.1 nameserver.
if command -v nmcli >/dev/null 2>&1; then
  # Do not break existing DNS fully; prefer to add 127.0.0.1 as first server
  sudo nmcli general hostname >/dev/null 2>&1 || true
  # For all connections, prepend 127.0.0.1; users may need to reconnect
  for con in $(nmcli -t -f NAME connection show | sed '/^$/d'); do
    sudo nmcli connection modify "$con" ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no || true
    sudo nmcli connection modify "$con" ipv4.dns "127.0.0.1" || true
  done
  echo "Set NetworkManager to use 127.0.0.1 DNS; reconnect network if needed."
else
  # Fallback: replace resolv.conf to use dnsmasq
  echo -e "nameserver 127.0.0.1\n" | sudo tee /etc/resolv.conf >/dev/null
fi

# Restart dnsmasq after DNS changes
sudo systemctl restart dnsmasq

# Enable and start redsocks
sudo systemctl enable --now redsocks || true
if ! systemctl is-active --quiet redsocks; then
  # Some distros lack unit; fall back to spawning
  sudo pkill -f "redsocks.*local_port 12345" 2>/dev/null || true
  sudo nohup redsocks -c /etc/redsocks.conf >/var/log/redsocks.log 2>&1 &
fi

echo "Installed and enabled dnsmasq/ipset/redsocks. Proxy ($PROXY_MODE): $PROXY_HOST:$PROXY_PORT"
