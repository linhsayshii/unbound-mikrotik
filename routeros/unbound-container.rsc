# Topology:
#   LAN/router DNS -> AdGuard Home container -> Unbound recursive container -> root DNS
#
# Adjust these values before paste/import.
:local disk "disk1"
:local unboundArchive ($disk . "/unbound-mikrotik-linux-arm64.tar")
:local adguardImage "adguard/adguardhome:latest"
:local bridgeName "containers"
:local unboundName "unbound"
:local adguardName "adguardhome"
:local unboundVeth "veth-unbound"
:local adguardVeth "veth-adguard"
:local unboundV4 "172.18.53.2"
:local adguardV4 "172.18.53.3"
:local bridgeV4 "172.18.53.1"
:local unboundV6 "fd8d:5ad2:53::2"
:local adguardV6 "fd8d:5ad2:53::3"
:local bridgeV6 "fd8d:5ad2:53::1"
:local lanDnsAddress "192.168.88.1"

/container/config/set registry-url=https://registry-1.docker.io tmpdir=($disk . "/tmp")

/interface/bridge/add name=$bridgeName comment="Container bridge"
/ip/address/add address=($bridgeV4 . "/24") interface=$bridgeName comment="Container IPv4 gateway"
/ipv6/address/add address=($bridgeV6 . "/64") interface=$bridgeName advertise=no comment="Container IPv6 gateway"

/interface/veth/add name=$unboundVeth address=($unboundV4 . "/24," . $unboundV6 . "/64") gateway=$bridgeV4 gateway6=$bridgeV6
/interface/veth/add name=$adguardVeth address=($adguardV4 . "/24," . $adguardV6 . "/64") gateway=$bridgeV4 gateway6=$bridgeV6
/interface/bridge/port add bridge=$bridgeName interface=$unboundVeth
/interface/bridge/port add bridge=$bridgeName interface=$adguardVeth

/ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.18.53.0/24 comment="NAT IPv4 from DNS containers"
/ipv6/firewall/nat/add chain=srcnat action=masquerade src-address=fd8d:5ad2:53::/64 comment="NAT IPv6 from DNS containers"

/container/mounts/add list=MOUNT_ADGUARD src=($disk . "/volumes/adguard/work") dst=/opt/adguardhome/work
/container/mounts/add list=MOUNT_ADGUARD src=($disk . "/volumes/adguard/conf") dst=/opt/adguardhome/conf

/container/add file=$unboundArchive interface=$unboundVeth root-dir=($disk . "/containers/unbound") name=$unboundName start-on-boot=yes auto-restart-interval=10s logging=no memory-high=33554432 memory-max=67108864
/container/add remote-image=$adguardImage interface=$adguardVeth root-dir=($disk . "/containers/adguardhome") mountlists=MOUNT_ADGUARD name=$adguardName dns=$unboundV4 start-on-boot=yes auto-restart-interval=10s logging=no

/container/start $unboundName
/container/start $adguardName

# RouterOS itself uses AdGuard Home. LAN clients should also hit AdGuard, not Unbound.
/ip/dns/set servers=$adguardV4 allow-remote-requests=no

# Publish AdGuard DNS on the router LAN IP. Set AdGuard upstream DNS to:
#   172.18.53.2
/ip/firewall/nat/add chain=dstnat action=dst-nat dst-address=$lanDnsAddress protocol=udp dst-port=53 to-addresses=$adguardV4 to-ports=53 comment="LAN DNS UDP to AdGuard Home"
/ip/firewall/nat/add chain=dstnat action=dst-nat dst-address=$lanDnsAddress protocol=tcp dst-port=53 to-addresses=$adguardV4 to-ports=53 comment="LAN DNS TCP to AdGuard Home"

# Optional first-run UI:
# /ip/firewall/nat/add chain=dstnat action=dst-nat dst-address=$lanDnsAddress protocol=tcp dst-port=3000 to-addresses=$adguardV4 to-ports=3000 comment="AdGuard Home setup UI"
