OpenAI transparent proxy via dnsmasq + ipset + redsocks

Requirements:
- yay explicitely installed

Files:
- env.sh: sources ~/.socks_proxy (preferred) or ~/.openai_env and exports PROXY_* vars
- dnsmasq-openai.conf: dnsmasq rules to populate ipset 'openai' and 'openai6'
- redsocks.conf: redsocks config bound on 127.0.0.1:12345 using HTTP CONNECT to your proxy
- iptables-apply.sh: apply iptables/ip6tables rules
- iptables-clear.sh: clear the rules
- install_and_enable.sh: install packages, copy configs to /etc, enable services

Usage:
1) Provide proxy:
   - SOCKS (recommended for transparent mode): create ~/.socks_proxy with one of:
     SOCKS5_PROXY="socks5://user:pass@host:port"  (or SOCKS_PROXY/ALL_PROXY)
     # or explicit vars:
     SOCKS_HOST=host
     SOCKS_PORT=port
     SOCKS_USER=user
     SOCKS_PASS=pass
   - HTTP fallback: set OPENAI_HTTP_PROXY in ~/.openai_env as before
2) sudo ./install_and_enable.sh
3) sudo ./iptables-apply.sh
4) Test: curl https://api.openai.com and check proxy logs
5) Rollback: sudo ./iptables-clear.sh
