# ============================================
# MikroTik WireGuard VPS example configuration
# ============================================

# ---------- Identity ----------
/system identity
set name=MAXX-VPS

# ---------- WAN ----------
/ip dhcp-client
add interface=ether1 disabled=no

# ---------- LAN bridge ----------
/interface bridge
add name=bridge-LAN

/interface bridge port
add bridge=bridge-LAN interface=ether2
add bridge=bridge-LAN interface=ether3
add bridge=bridge-LAN interface=ether4
add bridge=bridge-LAN interface=ether5

# ---------- LAN address ----------
/ip address
add address=192.168.88.1/24 interface=bridge-LAN

# ---------- DHCP ----------
/ip pool
add name=dhcp_pool_LAN ranges=192.168.88.100-192.168.88.200

/ip dhcp-server
add name=dhcp-LAN interface=bridge-LAN address-pool=dhcp_pool_LAN disabled=no

/ip dhcp-server network
add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1

# ---------- DNS ----------
/ip dns
set allow-remote-requests=yes

# ---------- Internet NAT ----------
/ip firewall nat
add chain=srcnat action=masquerade out-interface=ether1

# ---------- WireGuard ----------
/interface wireguard
add name=wg-vps listen-port=51820 mtu=1420 private-key="<MIKROTIK_PRIVATE_KEY>"

/ip address
add address=10.66.66.2/24 interface=wg-vps

# ---------- VPS peer ----------
/interface wireguard peers
add \
    interface=wg-vps \
    public-key="<VPS_PUBLIC_KEY>" \
    endpoint-address=<VPS_PUBLIC_IP> \
    endpoint-port=51820 \
    allowed-address=10.66.66.1/32,10.66.66.3/32 \
    persistent-keepalive=25s
