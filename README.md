**Transparent proxy configurator for specified domains via dnsmasq + ipset + redsocks**

## Requirements:
- `yay` explicitly installed (TODO: make this optional for non-Arch users)

NOTE: if you are not arch-linux user you can just install `dnsmasq`, `ipset`, `redsocks` by yourself.

## Files:
- scripts/env.sh: sources ~/.socks_proxy (preferred) and exports proxy vars
- configs/domains.txt: list of domains to proxy (one per line, supports comments with #)
- configs/dnsmasq-openai.conf: dnsmasq rules to populate ipset 'openai' and 'openai6' (generated from domains.txt)
- configs/redsocks.conf: redsocks config bound on 127.0.0.1:12345 using HTTP CONNECT to your proxy
- configs/redsocks.conf.template: template for redsocks config
- scripts/iptables-apply.sh: apply iptables/ip6tables rules
- scripts/iptables-clear.sh: clear the rules
- scripts/install_and_enable.sh: install packages, copy configs to /etc, enable services
- scripts/openai-proxy-apply-domains.sh: apply domain changes and reload dnsmasq (TODO: may not be working)
- scripts/render_dnsmasq_from_domains.sh: generate dnsmasq config from domains.txt
- scripts/render_redsocks.sh: render redsocks config from template and env
- scripts/test.sh: test script for proxy functionality

## Usage:
1) Edit configs/domains.txt to list domains to proxy.
2) Provide proxy:
   - SOCKS (recommended for transparent mode): create ~/.socks_proxy with one of:
     SOCKS5_PROXY="socks5://user:pass@host:port"  (or SOCKS_PROXY/ALL_PROXY)
     or explicit vars:
     SOCKS_HOST=host
     SOCKS_PORT=port
     SOCKS_USER=user
     SOCKS_PASS=pass
   - HTTP fallback: set OPENAI_HTTP_PROXY in ~/.openai_env as before
3) sudo -E ./scripts/install_and_enable.sh
4) sudo -E ./scripts/iptables-apply.sh
5) Test: Run ./scripts/test.sh or request domains you have listed
6) Rollback: sudo ./scripts/iptables-clear.sh

NOTE: If fallback script didn't help, try this one: 
```bash
sudo bash -c '
# remove non-default policy rules (keep 0:, 32766:, 32767:)
for p in $(ip -o rule show | awk "!(\$1==\"0:\"||\$1==\"32766:\"||\$1==\"32767:\") {print \$1}" | cut -d: -f1); do ip rule del pref "$p" 2>/dev/null || true; done
# drop any stale SNX interface (also clears routes bound to it)
ip link del tunsnx 2>/dev/null || true
# optional: clear routes still pointing at tunsnx, if any
ip route flush dev tunsnx 2>/dev/null || true
'
```
