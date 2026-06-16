#!/usr/bin/env bash
#
# geoblock.sh — Block the whole VPS (HTTP/HTTPS only) for selected countries.
#
# Method: ipset (kernel-level IP sets) + iptables/ip6tables DROP on ports 80/443.
# SSH (port 22) and every other port are NEVER touched -> no lock-out risk.
# Covers both IPv4 and IPv6. Country IP ranges come from ipdeny.com (aggregated).
#
# Subcommands:
#   refresh  download fresh country ranges, rebuild sets, save state, apply rules
#   apply    restore sets from saved state (fast, no network) + ensure rules  [boot]
#   status   show active rules and set sizes
#   remove   delete rules + sets + saved state (full rollback)
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
# ISO 3166-1 alpha-2 codes (lowercase). Arab League (22) + Iran + Turkey.
COUNTRIES="ma dz tn ly mr eg sd so dj km sa ae qa kw bh om ye iq sy lb jo ps ir tr"
SET4=geoblock4
SET6=geoblock6
PORTS=80,443
STATE=/etc/geoblock/ipset.conf
V4=https://www.ipdeny.com/ipblocks/data/aggregated
V6=https://www.ipdeny.com/ipv6/ipaddresses/aggregated
# ─────────────────────────────────────────────────────────────────────────────

[ "$(id -u)" = 0 ] || { echo "Must run as root (sudo)." >&2; exit 1; }

ensure_rules() {
  # Idempotent: remove a possible old copy, then insert at top of INPUT.
  iptables  -D INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET4" src -j DROP 2>/dev/null || true
  iptables  -I INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET4" src -j DROP
  ip6tables -D INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET6" src -j DROP 2>/dev/null || true
  ip6tables -I INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET6" src -j DROP
}

refresh() {
  command -v ipset >/dev/null || { apt-get update -qq; apt-get install -y ipset; }
  command -v curl  >/dev/null || { apt-get update -qq; apt-get install -y curl; }

  local tmp; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN

  ipset create "${SET4}_t" hash:net family inet  hashsize 65536 maxelem 1000000 -exist; ipset flush "${SET4}_t"
  ipset create "${SET6}_t" hash:net family inet6 hashsize 65536 maxelem 1000000 -exist; ipset flush "${SET6}_t"

  local cc n
  for cc in $COUNTRIES; do
    if curl -fsS "$V4/${cc}-aggregated.zone" -o "$tmp/v4"; then
      while read -r n; do [ -n "$n" ] && ipset add "${SET4}_t" "$n" -exist; done < "$tmp/v4"
    else echo "WARN: no IPv4 zone for '$cc'" >&2; fi
    if curl -fsS "$V6/${cc}-aggregated.zone" -o "$tmp/v6"; then
      while read -r n; do [ -n "$n" ] && ipset add "${SET6}_t" "$n" -exist; done < "$tmp/v6"
    else echo "WARN: no IPv6 zone for '$cc'" >&2; fi
  done

  # Atomic swap so there is never a window with empty/partial sets.
  ipset create "$SET4" hash:net family inet  hashsize 65536 maxelem 1000000 -exist
  ipset create "$SET6" hash:net family inet6 hashsize 65536 maxelem 1000000 -exist
  ipset swap "${SET4}_t" "$SET4"; ipset destroy "${SET4}_t"
  ipset swap "${SET6}_t" "$SET6"; ipset destroy "${SET6}_t"

  mkdir -p "$(dirname "$STATE")"
  { ipset save "$SET4"; ipset save "$SET6"; } > "$STATE"

  ensure_rules
  echo "geoblock refreshed: IPv4=$(ipset list "$SET4" | grep -c / || true) IPv6=$(ipset list "$SET6" | grep -c / || true) networks"
}

apply() {
  if [ -f "$STATE" ]; then
    ipset restore -exist < "$STATE"
    ensure_rules
    echo "geoblock applied from $STATE"
  else
    echo "No saved state, running full refresh..."
    refresh
  fi
}

status() {
  echo "── iptables (IPv4) ──"; iptables  -S INPUT | grep -i "$SET4" || echo "  (no rule)"
  echo "── ip6tables (IPv6) ──"; ip6tables -S INPUT | grep -i "$SET6" || echo "  (no rule)"
  echo "── set sizes ──"
  echo "  IPv4: $(ipset list "$SET4" 2>/dev/null | grep -c / || true) networks"
  echo "  IPv6: $(ipset list "$SET6" 2>/dev/null | grep -c / || true) networks"
}

remove() {
  iptables  -D INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET4" src -j DROP 2>/dev/null || true
  ip6tables -D INPUT -p tcp -m multiport --dports "$PORTS" -m set --match-set "$SET6" src -j DROP 2>/dev/null || true
  ipset destroy "$SET4" 2>/dev/null || true
  ipset destroy "$SET6" 2>/dev/null || true
  rm -f "$STATE"
  echo "geoblock removed."
}

case "${1:-}" in
  refresh) refresh ;;
  apply)   apply ;;
  status)  status ;;
  remove)  remove ;;
  *) echo "usage: $0 {refresh|apply|status|remove}" >&2; exit 1 ;;
esac
