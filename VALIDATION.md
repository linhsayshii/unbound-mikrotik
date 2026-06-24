# Validation

Use this checklist after GitHub Actions has produced the RouterOS `.tar` archive and after you upload it with Winbox **Files**.

## 1. Pick the correct archive

- ARM64 routers: `unbound-mikrotik-linux-arm64.tar`
- ARMv7 routers: `unbound-mikrotik-linux-armv7.tar`
- x86/CHR routers: `unbound-mikrotik-linux-amd64.tar`

GitHub Actions artifacts download as `.zip`. Extract the `.zip` on your computer first, then upload the contained `.tar` to the router, for example:

```text
disk1/unbound-mikrotik-linux-arm64.tar
```

## 2. RouterOS prerequisites

```routeros
/system/device-mode/update container=yes
/system/reboot
/container/config/set registry-url=https://registry-1.docker.io tmpdir=disk1/tmp
```

The `container` package must be installed, and `disk1` should be external storage.

## 3. Import and start

Edit `routeros/unbound-container.rsc` before importing:

- `disk`
- `unboundArchive`
- `lanDnsAddress`
- IPv4/IPv6 container subnet if it conflicts with your network

Then upload the `.rsc` or paste it into Terminal:

```routeros
/import file-name=unbound-container.rsc
```

## 4. Confirm containers are running

```routeros
/container/print detail
/interface/veth/print detail
/ip/address/print where interface=containers
/ipv6/address/print where interface=containers
```

Expected:

- `unbound` is running on `veth-unbound`.
- `adguardhome` is running on `veth-adguard`.
- Bridge gateway is `172.18.53.1/24`.
- Unbound is `172.18.53.2`.
- AdGuard Home is `172.18.53.3`.

## 5. Configure AdGuard Home

Set upstream DNS to:

```text
172.18.53.2
```

Keep AdGuard Home cache enabled. Unbound cache is intentionally disabled.

## 6. DNS tests

From a LAN client:

```sh
nslookup cloudflare.com 192.168.88.1
nslookup dnssec-failed.org 192.168.88.1
```

Expected:

- `cloudflare.com` resolves.
- `dnssec-failed.org` fails with `SERVFAIL` or equivalent, confirming DNSSEC validation.

From RouterOS:

```routeros
/put [:resolve cloudflare.com server=172.18.53.3]
/tool/fetch url="https://cloudflare.com" keep-result=no
```

The resolve/fetch should use AdGuard Home as the router's DNS path.

## 7. Resource checks

```routeros
/container/print stats
/system/resource/print
/log/print where topics~"container"
```

Unbound should stay small because it runs one thread, has no DNS answer cache, and has no healthcheck loop.

## 8. Safety checks

Do not publish Unbound port `53` directly to WAN. The intended public-facing DNS path inside your LAN is:

```text
LAN/router DNS -> AdGuard Home -> Unbound -> DNS root servers
```
