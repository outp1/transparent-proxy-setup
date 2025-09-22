#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "Resolving api.openai.com via local dnsmasq..."
dig +short api.openai.com @127.0.0.1 || true
echo "Resolving chatgpt.com via local dnsmasq..."
dig +short chatgpt.com @127.0.0.1 || true
echo "Resolving api.anthropic.com via local dnsmasq..."
dig +short api.anthropic.com @127.0.0.1 || true

echo "Current openai ipset contents:"
sudo ipset list openai 2>/dev/null | sed -n '1,120p' || echo "(requires sudo)"

echo "Testing HTTPS HEAD to api.openai.com (transparent via redsocks)"
set +e
curl --noproxy "*" -I --max-time 10 https://api.openai.com 2>/dev/null | head -n1 || true
set -e

echo "Testing HTTPS HEAD to api.anthropic.com (transparent via redsocks)"
set +e
curl --noproxy "*" -I --max-time 10 https://api.anthropic.com/v1/models \
    --header "x-api-key: $ANTHROPIC_API_KEY" \
    --header "anthropic-version: 2023-06-01" \
    2>/dev/null | head -n1 || true
set -e

echo "Testing explicit proxy URL if present (HTTP and SOCKS)"
if [[ -n "${OPENAI_HTTP_PROXY:-}" ]]; then
  curl -I -x "$OPENAI_HTTP_PROXY" --max-time 10 https://api.openai.com 2>/dev/null | head -n1 || true

  echo "Requesting anthropic api with HTTPs proxies"
  curl -I -x "$OPENAI_HTTP_PROXY" https://api.anthropic.com/v1/models \
     --header "x-api-key: $ANTHROPIC_API_KEY" \
     --header "anthropic-version: 2023-06-01" \
     2>/dev/null | head -n1 || true
fi
if [[ -n "${SOCKS5_PROXY:-${SOCKS_PROXY:-${ALL_PROXY:-}}}" ]]; then
  purl="${SOCKS5_PROXY:-${SOCKS_PROXY:-${ALL_PROXY}}}"
  curl -I -x "$purl" --max-time 10 https://api.openai.com 2>/dev/null | head -n1 || true

  echo "Requesting anthropic api with SOCKS5 proxies"
  curl -I -x "$purl" https://api.anthropic.com/v1/models \
     --header "x-api-key: $ANTHROPIC_API_KEY" \
     --header "anthropic-version: 2023-06-01" \
    2>/dev/null | head -n1 || true
fi

echo "iptables nat OUTPUT rules that redirect to redsocks:" 
sudo iptables -t nat -L OUTPUT -n -v | sed -n '1,200p' || echo "(requires sudo)"
