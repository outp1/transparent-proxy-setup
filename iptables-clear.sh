#!/usr/bin/env bash
set -euo pipefail
# Remove OUTPUT NAT rules that redirect to redsocks and delete sets
REDSOCKS_PORT=${REDSOCKS_PORT:-12345}

# Delete specific redirect rules if present
sudo iptables  -t nat -D OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || true
sudo iptables  -t nat -D OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || true
sudo iptables  -t nat -D OUTPUT -p tcp -d 127.0.0.0/8 -j RETURN 2>/dev/null || true
sudo iptables  -t nat -D OUTPUT -p tcp -m owner --uid-owner redsocks -j RETURN 2>/dev/null || true

if command -v ip6tables >/dev/null 2>&1; then
  sudo ip6tables -t nat -D OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || true
  sudo ip6tables -t nat -D OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || true
fi

sudo ipset destroy openai 2>/dev/null || true
sudo ipset destroy openai6 2>/dev/null || true

echo "iptables rules cleared and ipsets destroyed"
