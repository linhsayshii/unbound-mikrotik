# unbound-mikrotik

Small Docker image for running Unbound as a real recursive resolver inside a MikroTik RouterOS container. It asks the DNS root servers directly, validates DNSSEC, and listens on IPv4 and IPv6.

## What is included

- Alpine-based image with `unbound` and `unbound-anchor`.
- Recursive config using InterNIC root hints, not upstream forwarders.
- DNSSEC validation with IANA KSK-2017 and KSK-2024 trust anchors.
- Router-friendly defaults for use behind AdGuard Home: one thread, no Unbound answer cache, small infra cache, EDNS buffer `1232`.
- Private resolver defaults: localhost, RFC1918 IPv4, ULA IPv6, and link-local IPv6 are allowed; public clients are refused by Unbound.
- MikroTik RouterOS example script with veth IPv4 and IPv6.

## Build

Pick the platform that matches your RouterOS device:

```sh
make build PLATFORM=linux/arm64 IMAGE=unbound-mikrotik
make build PLATFORM=linux/arm/v7 IMAGE=unbound-mikrotik
make build PLATFORM=linux/amd64 IMAGE=unbound-mikrotik
```

For upload/import from a PC:

```sh
make archive IMAGE=unbound-mikrotik PLATFORM=linux/arm64 ARCHIVE=unbound-mikrotik-linux-arm64.tar
```

You can also use GitHub Actions. Run the **Build RouterOS container archives** workflow and download the artifact that matches your router:

- `unbound-mikrotik-linux-arm64.tar`
- `unbound-mikrotik-linux-armv7.tar`
- `unbound-mikrotik-linux-amd64.tar`

Upload the `.tar` to the router with Winbox **Files**, preferably onto external storage such as `disk1/`. Then import it with RouterOS:

```routeros
/container/add file=disk1/unbound-mikrotik-linux-arm64.tar interface=veth-unbound root-dir=disk1/containers/unbound name=unbound
```

GitHub downloads artifacts as `.zip` files. Extract the `.zip` on your computer first, then upload the contained `.tar` to Winbox **Files**.

Do not upload the GitHub `.zip` file to RouterOS. The file in Winbox **Files** must be the Docker archive itself, for example:

```text
disk1/unbound-mikrotik-linux-arm64.tar
```

When pushing a tag like `v1.0.0`, the workflow also publishes the `.tar` files and checksums as GitHub Release assets.

Optional registry pull from RouterOS:

```sh
docker tag unbound-mikrotik:latest your-dockerhub-user/unbound-mikrotik:latest
docker push your-dockerhub-user/unbound-mikrotik:latest
```

## Local test

```sh
make check IMAGE=unbound-mikrotik
make run IMAGE=unbound-mikrotik
drill @127.0.0.1 -p 5353 cloudflare.com A +dnssec
drill @127.0.0.1 -p 5353 dnssec-failed.org A
```

The `dnssec-failed.org` query should return `SERVFAIL`, which confirms DNSSEC validation is active.

## Performance tuning

The default config assumes AdGuard Home is in front of Unbound and handles client-facing cache/filtering. Unbound stays as a thin recursive DNSSEC-validating upstream:

- `num-threads: 1`: avoids thread overhead on low-power ARM CPUs.
- `msg-cache-size: 0`, `rrset-cache-size: 0`, `key-cache-size: 0`, `neg-cache-size: 0`: disables Unbound's DNS answer/RRset/DNSKEY/negative caches.
- TTL overrides are not used, so AdGuard Home can still cache answers using the TTLs returned through Unbound.
- `infra-cache-numhosts: 512`: keeps only a small infrastructure cache so iterative lookups do not repeatedly relearn basic nameserver behavior.
- `outgoing-range: 64`, `num-queries-per-thread: 32`, `outgoing-num-tcp: 4`, `incoming-num-tcp: 2`: keeps socket and TCP buffer use low for a single AdGuard Home upstream.
- `harden-referral-path: no`: avoids extra recursive lookups that cost CPU and latency.
- `prefetch: no`, `prefetch-key: no`, `serve-expired: no`: avoids cache-refresh/background stale-answer behavior that AdGuard Home should handle instead.
- No Docker healthcheck: avoids a background DNS query every 30 seconds.

If you ever run Unbound directly for LAN clients without AdGuard Home cache, use small cache values instead:

```unbound
msg-cache-size: 8m
rrset-cache-size: 16m
key-cache-size: 2m
neg-cache-size: 1m
infra-cache-numhosts: 5000
outgoing-range: 256
num-queries-per-thread: 128
prefetch: yes
serve-expired: yes
```

## RouterOS install

Use [routeros/unbound-container.rsc](routeros/unbound-container.rsc) as the starting point. Change `disk`, `unboundArchive`, `adguardImage`, `lanDnsAddress`, and address values before importing.

Important MikroTik notes:

- Enable container mode first: `/system/device-mode/update container=yes`.
- Install the `container` package.
- Use external storage for `root-dir` and `tmpdir`.
- Build/pull the correct architecture for your router.

The included RouterOS script creates a container bridge, IPv4+IPv6 veth interfaces for Unbound and AdGuard Home, outbound NAT for the containers, imports Unbound from the uploaded `.tar`, pulls AdGuard Home, and publishes AdGuard Home DNS on the router LAN IP.

Configure AdGuard Home upstream DNS to the Unbound container:

```text
172.18.53.2
```

The intended flow is:

```text
LAN/router DNS -> AdGuard Home -> Unbound -> DNS root servers
```

After deployment, follow [VALIDATION.md](VALIDATION.md).

## Runtime knobs

Environment variables:

- `RUN_UNBOUND_ANCHOR=yes`: force `unbound-anchor` to refresh `/var/lib/unbound/root.key` at container start.
- `UNBOUND_CONF=/path/to/unbound.conf`: use another config path.

By default the image does not refresh files over the network at start, so boot stays fast and deterministic on RouterOS. Unbound still uses `auto-trust-anchor-file` for RFC5011 trust anchor maintenance while it runs.

## Sources

- Root hints: https://www.internic.net/domain/named.root
- DNSSEC trust anchors: https://www.iana.org/dnssec/files
- MikroTik container docs: https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container
