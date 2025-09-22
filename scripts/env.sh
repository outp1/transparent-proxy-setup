#!/usr/bin/env bash
set -euo pipefail

# Load SOCKS credentials first (preferred for transparent mode)
if [[ -f "$HOME/.socks_proxy" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.socks_proxy"
fi

# WARN: HTTP proxies doesn't work. Deprecated
if [[ -f "$HOME/.openai_env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.openai_env"
fi

# Helper to parse URL of form scheme://[user:pass@]host:port
parse_url() {
  local url="$1"
  local scheme rest creds_hostport creds hostport user pass host port
  scheme="${url%%://*}"
  rest="${url#*://}"
  creds_hostport="$rest"
  user=""; pass=""; host=""; port=""
  if [[ "$creds_hostport" == *"@"* ]]; then
    creds="${creds_hostport%@*}"
    hostport="${creds_hostport#*@}"
    user="${creds%%:*}"
    pass="${creds#*:}"
  else
    hostport="$creds_hostport"
  fi
  host="${hostport%%:*}"
  port="${hostport#*:}"
  echo "$scheme" "$host" "$port" "$user" "$pass"
}

# Determine upstream proxy preference: SOCKS first, then HTTP
PROXY_PROTO=""; PROXY_HOST=""; PROXY_PORT=""; PROXY_USER=""; PROXY_PASS=""; PROXY_MODE=""

if [[ -n "${SOCKS5_PROXY:-${SOCKS_PROXY:-${ALL_PROXY:-}}}" ]]; then
  read -r scheme host port user pass < <(parse_url "${SOCKS5_PROXY:-${SOCKS_PROXY:-${ALL_PROXY}}}")
  PROXY_PROTO="$scheme"; PROXY_HOST="$host"; PROXY_PORT="$port"; PROXY_USER="$user"; PROXY_PASS="$pass"; PROXY_MODE="socks"
elif [[ -n "${SOCKS_HOST:-}" && -n "${SOCKS_PORT:-}" ]]; then
  PROXY_PROTO="socks5"; PROXY_HOST="$SOCKS_HOST"; PROXY_PORT="$SOCKS_PORT"; PROXY_USER="${SOCKS_USER:-}"; PROXY_PASS="${SOCKS_PASS:-}"; PROXY_MODE="socks"
elif [[ -n "${OPENAI_HTTP_PROXY:-}" ]]; then
  read -r scheme host port user pass < <(parse_url "$OPENAI_HTTP_PROXY")
  PROXY_PROTO="$scheme"; PROXY_HOST="$host"; PROXY_PORT="$port"; PROXY_USER="$user"; PROXY_PASS="$pass"; PROXY_MODE="http"
else
  echo "No proxy configured. Set ~/.socks_proxy (SOCKS5_PROXY or SOCKS_HOST/PORT) or ~/.openai_env (OPENAI_HTTP_PROXY)" >&2
  exit 1
fi

export PROXY_PROTO PROXY_HOST PROXY_PORT PROXY_USER PROXY_PASS PROXY_MODE
