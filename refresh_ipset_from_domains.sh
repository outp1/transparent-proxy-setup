#!/usr/bin/env bash
set -euo pipefail

DOMAINS_FILE="/home/danya/openai-proxy/domains.txt"
IPSET_V4="openai"
IPSET_V6="openai6"
TTL_SECONDS=${TTL_SECONDS:-86400}
DNS_SERVERS=("1.1.1.1" "8.8.8.8" "9.9.9.9")

# Ensure sets exist
ipset create -exist "$IPSET_V4" hash:ip family inet  timeout "$TTL_SECONDS"
ipset create -exist "$IPSET_V6" hash:ip family inet6 timeout "$TTL_SECONDS"

extract_host() {
  local line="$1"
  line="${line%%#*}"         # strip trailing comments
  line="${line##+([[:space:]])}" # ltrim spaces (requires extglob, but we avoid; safe enough)
  line="${line#*://}"        # drop scheme if any
  echo "${line%%/*}"         # drop path
}

resolve_and_add() {
  local host="$1"
  local dns
  for dns in "${DNS_SERVERS[@]}"; do
    # IPv4
    while read -r ip; do
      [[ -z "$ip" ]] && continue
      ipset add -exist "$IPSET_V4" "$ip" timeout "$TTL_SECONDS" || true
    done < <(dig +short A "$host" @"$dns" 2>/dev/null || true)
    # IPv6
    while read -r ip6; do
      [[ -z "$ip6" ]] && continue
      ipset add -exist "$IPSET_V6" "$ip6" timeout "$TTL_SECONDS" || true
    done < <(dig +short AAAA "$host" @"$dns" 2>/dev/null || true)
  done
}

# Iterate unique hosts
awk '{gsub(/#.*/,""); gsub(/^\s+|\s+$/,"", $0); if($0!=""){print}}' "$DOMAINS_FILE" |
  while read -r line; do
    host=$(extract_host "$line")
    [[ -z "$host" ]] && continue
    resolve_and_add "$host"
  done

echo "Refreshed ipsets ($IPSET_V4/$IPSET_V6) from $(wc -l < "$DOMAINS_FILE") entries."