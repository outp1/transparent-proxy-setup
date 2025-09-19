#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"
auth_block=""
if [[ -n "${PROXY_USER}" ]]; then
  auth_block=$'login = "'"$PROXY_USER"'";\n  password = "'"$PROXY_PASS"'";'
fi

# Decide redsocks type
proxy_type="http-connect"
if [[ "$PROXY_MODE" == "socks" ]] || [[ "$PROXY_PROTO" == socks* ]]; then
  proxy_type="socks5"
fi

sed -e "s/{{PROXY_HOST}}/$PROXY_HOST/g" \
    -e "s/{{PROXY_PORT}}/$PROXY_PORT/g" \
    -e "s/{{PROXY_TYPE}}/$proxy_type/g" \
    -e "s#{{AUTH_BLOCK}}#$auth_block#" \
    "$SCRIPT_DIR/redsocks.conf.template" > "$SCRIPT_DIR/redsocks.conf"
echo "Rendered redsocks.conf ($proxy_type) for $PROXY_HOST:$PROXY_PORT"
