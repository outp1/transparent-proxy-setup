#!/usr/bin/env bash
set -euo pipefail
# Apply iptables/ip6tables rules for redirecting OpenAI traffic to redsocks
REDSOCKS_PORT=${REDSOCKS_PORT:-12345}

# Ensure IP sets exist (idempotent)
sudo ipset create -exist openai  hash:ip family inet  timeout 86400
sudo ipset create -exist openai6 hash:ip family inet6 timeout 86400

# Avoid localhost loops (not strictly needed, but harmless)
sudo iptables  -t nat -C OUTPUT -p tcp -d 127.0.0.0/8 -j RETURN 2>/dev/null || \
sudo iptables  -t nat -I OUTPUT -p tcp -d 127.0.0.0/8 -j RETURN

# Force browsers to fall back from QUIC by rejecting UDP/443 to matched domains
sudo iptables -C OUTPUT -p udp -m set --match-set openai dst --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || \
sudo iptables -I OUTPUT -p udp -m set --match-set openai dst --dport 443 -j REJECT --reject-with icmp-port-unreachable

# Redirect IPv4 OpenAI traffic on 80/443 (legacy iptables), try TPROXY alternative if REDIRECT unsupported
sudo iptables  -t nat -C OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || \
sudo iptables  -t nat -I OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT"
sudo iptables  -t nat -C OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || \
sudo iptables  -t nat -I OUTPUT -p tcp -m set --match-set openai dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT"

# IPv6 rules (if ip6tables-nft supported)
if command -v ip6tables >/dev/null 2>&1; then
  # Block QUIC (UDP/443) for IPv6 too
  sudo ip6tables -C OUTPUT -p udp -m set --match-set openai6 dst --dport 443 -j REJECT --reject-with icmp6-port-unreachable 2>/dev/null || \
  sudo ip6tables -I OUTPUT -p udp -m set --match-set openai6 dst --dport 443 -j REJECT --reject-with icmp6-port-unreachable

  sudo ip6tables -t nat -C OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || \
  sudo ip6tables -t nat -I OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 80  -j REDIRECT --to-ports "$REDSOCKS_PORT"
  sudo ip6tables -t nat -C OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT" 2>/dev/null || \
  sudo ip6tables -t nat -I OUTPUT -p tcp -m set --match-set openai6 dst -m tcp --dport 443 -j REDIRECT --to-ports "$REDSOCKS_PORT"
fi

echo "iptables rules applied (redirect -> $REDSOCKS_PORT)"
