#!/usr/bin/env bash
set -euo pipefail
DOMAINS_FILE="/home/danya/openai-proxy/domains.txt"
RENDER_SCRIPT="/home/danya/openai-proxy/render_dnsmasq_from_domains.sh"
TMP_CONF="/home/danya/openai-proxy/dnsmasq-openai.conf"
DST_CONF="/etc/dnsmasq.d/openai-ipset.conf"

# Ensure ipsets exist
ipset create -exist openai  hash:ip family inet  timeout 86400
ipset create -exist openai6 hash:ip family inet6 timeout 86400

# Re-render dnsmasq rules from domain list
"${RENDER_SCRIPT}" "${DOMAINS_FILE}"
install -m 0644 "${TMP_CONF}" "${DST_CONF}"

# Reload dnsmasq to pick up changes
if systemctl reload dnsmasq 2>/dev/null; then :; else systemctl restart dnsmasq; fi
sleep 1

# Pre-resolve to populate ipsets quickly
if command -v dig >/dev/null 2>&1; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%#*}"; line="${line//[$'\t\r\n ']}"; [[ -z "$line" ]] && continue
    host="${line#*://}"; host="${host%%/*}"; [[ -z "$host" ]] && continue
    echo "Resolving host: ${host}"
    # dig +short "$host" @127.0.0.1 >/dev/null 2>&1 || true
    result="$(dig +short "$host" @127.0.0.1 || true)"
    if [[ -n "$result" ]]; then
      echo "$host resolved to:"
      echo "$result"
    else
      echo "$host could not be resolved"
    fi
  done < "$DOMAINS_FILE"
fi

echo "Applied domains from ${DOMAINS_FILE} and reloaded dnsmasq"
