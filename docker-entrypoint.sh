#!/bin/sh
set -eu

if [ "$#" -gt 0 ] && [ "$1" != "unbound" ]; then
  exec "$@"
fi

if [ "$#" -gt 0 ]; then
  shift
fi

: "${UNBOUND_CONF:=/etc/unbound/unbound.conf}"
: "${UNBOUND_ROOT_KEY:=/var/lib/unbound/root.key}"
: "${RUN_UNBOUND_ANCHOR:=no}"

mkdir -p /var/lib/unbound /run/unbound
chown -R unbound:unbound /var/lib/unbound /run/unbound 2>/dev/null || true

if [ ! -s "$UNBOUND_ROOT_KEY" ] && [ -s /etc/unbound/root.key ]; then
  cp /etc/unbound/root.key "$UNBOUND_ROOT_KEY"
  chown unbound:unbound "$UNBOUND_ROOT_KEY" 2>/dev/null || true
  chmod 0644 "$UNBOUND_ROOT_KEY"
  echo "Seeded DNSSEC root trust anchor from bundled fallback"
fi

if [ ! -s "$UNBOUND_ROOT_KEY" ] || [ "$RUN_UNBOUND_ANCHOR" = "yes" ]; then
  if unbound-anchor -a "$UNBOUND_ROOT_KEY"; then
    chown unbound:unbound "$UNBOUND_ROOT_KEY" 2>/dev/null || true
    chmod 0644 "$UNBOUND_ROOT_KEY"
    echo "Bootstrapped DNSSEC root trust anchor"
  else
    echo "Warning: unbound-anchor failed, continuing with existing trust anchor if present" >&2
  fi
fi

if [ ! -s "$UNBOUND_ROOT_KEY" ]; then
  echo "Error: DNSSEC root trust anchor is missing at $UNBOUND_ROOT_KEY" >&2
  exit 1
fi

exec unbound -d -c "$UNBOUND_CONF" "$@"
