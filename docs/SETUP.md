# Setup Guide

This guide describes how to build the complete WireGuard topology:

```text
Remote Laptop
      │
      ▼
 Public VPS
      │
      ▼
 MikroTik
      │
      ▼
Remote LAN
```

The VPS acts as the central WireGuard hub. The MikroTik initiates an outbound VPN connection to the VPS, so the MikroTik side can be behind NAT or CGNAT.

---

## 1. VPS Requirements

Recommended VPS configuration:

- Ubuntu Server 24.04 LTS
- Public IPv4 address
- 1 vCPU or more
- 1 GB RAM or more
- SSH access
- UDP port `51820` reachable from the Internet

Connect to the VPS:

```bash
ssh root@<VPS_PUBLIC_IP>
```

Update the system:

```bash
apt update
apt upgrade -y
```

Install WireGuard:

```bash
apt install wireguard -y
```

---

## 2. Generate VPS WireGuard Keys

Generate the VPS private key:

```bash
wg genkey | tee /etc/wireguard/server_private.key
```

Protect the private key:

```bash
chmod 600 /etc/wireguard/server_private.key
```

Display the VPS public key:

```bash
cat /etc/wireguard/server_private.key | wg pubkey
```

Save the public key for later use.

Do not publish or share the VPS private key.

---

## 3. Enable IPv4 Forwarding

Create a persistent sysctl configuration:

```bash
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-wireguard.conf
```

Apply the configuration:

```bash
sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

Expected result:

```text
net.ipv4.ip_forward = 1
```

---

## 4. Configure WireGuard on the VPS

Create the WireGuard configuration:

```bash
nano /etc/wireguard/wg0.conf
```

Add:

```ini
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = <VPS_PRIVATE_KEY>

# MikroTik peer
[Peer]
PublicKey = <MIKROTIK_PUBLIC_KEY>
AllowedIPs = 10.66.66.2/32, 192.168.88.0/24

# Remote Windows client
[Peer]
PublicKey = <WINDOWS_CLIENT_PUBLIC_KEY>
AllowedIPs = 10.66.66.3/32
```

Protect the configuration:

```bash
chmod 600 /etc/wireguard/wg0.conf
```

Start WireGuard:

```bash
wg-quick up wg0
```

Verify the interface:

```bash
ip addr show wg0
```

The VPS should now have:

```text
10.66.66.1/24
```

Check WireGuard:

```bash
wg show
```

---

## 5. Enable Automatic WireGuard Startup

Enable the WireGuard service at boot:

```bash
systemctl enable wg-quick@wg0
```

After a reboot, verify:

```bash
systemctl status wg-quick@wg0 --no-pager
```

A successful startup should show:

```text
Active: active (exited)
```

Because the MikroTik peer contains:

```text
AllowedIPs = 10.66.66.2/32, 192.168.88.0/24
```

`wg-quick` also installs the route to the remote LAN automatically:

```text
192.168.88.0/24 → wg0
```

Verify it with:

```bash
ip route get 192.168.88.1
```

The route should use the `wg0` interface.

---

## 6. Configure MikroTik

The following example assumes:

```text
WAN:       ether1
LAN:       ether2-ether5
LAN subnet: 192.168.88.0/24
MikroTik:   192.168.88.1
WireGuard:  10.66.66.2
VPS WG:     10.66.66.1
```

### Configure WAN

Create a DHCP client on `ether1`:

```routeros
/ip dhcp-client
add interface=ether1 disabled=no
```

Verify Internet connectivity:

```routeros
/ping 8.8.8.8
```

### Create the LAN Bridge

```routeros
/interface bridge
add name=bridge-LAN
```

Add the LAN Ethernet ports:

```routeros
/interface bridge port
add bridge=bridge-LAN interface=ether2
add bridge=bridge-LAN interface=ether3
add bridge=bridge-LAN interface=ether4
add bridge=bridge-LAN interface=ether5
```

Assign the LAN address:

```routeros
/ip address
add address=192.168.88.1/24 interface=bridge-LAN
```

### Configure DHCP

Create the DHCP pool:

```routeros
/ip pool
add name=dhcp_pool_LAN ranges=192.168.88.100-192.168.88.200
```

Create the DHCP server:

```routeros
/ip dhcp-server
add name=dhcp-LAN interface=bridge-LAN address-pool=dhcp_pool_LAN disabled=no
```

Configure the LAN network:

```routeros
/ip dhcp-server network
add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1
```

Enable DNS requests from LAN clients:

```routeros
/ip dns
set allow-remote-requests=yes
```

### Configure Internet NAT

```routeros
/ip firewall nat
add chain=srcnat action=masquerade out-interface=ether1
```

At this point, devices connected to the LAN should receive an address from:

```text
192.168.88.100 - 192.168.88.200
```

and have Internet access through the MikroTik.

---

## 7. Configure WireGuard on MikroTik

Create the WireGuard interface:

```routeros
/interface wireguard
add name=wg-vps listen-port=51820 mtu=1420
```

Display the generated MikroTik public key:

```routeros
/interface wireguard print detail
```

Keep the private key secret. Only the public key should be added to the VPS configuration.

Assign the WireGuard address:

```routeros
/ip address
add address=10.66.66.2/24 interface=wg-vps
```

### Add the VPS Peer

```routeros
/interface wireguard peers
add \
    interface=wg-vps \
    public-key="<VPS_PUBLIC_KEY>" \
    endpoint-address=<VPS_PUBLIC_IP> \
    endpoint-port=51820 \
    allowed-address=10.66.66.1/32,10.66.66.3/32 \
    persistent-keepalive=25s
```

The MikroTik initiates the connection to the VPS, so no inbound WireGuard port forwarding is required on the MikroTik side.

`10.66.66.3/32` is included in `allowed-address` so the MikroTik can send return traffic to the remote Windows client through the VPS peer.

### Verify the MikroTik Tunnel

Ping the VPS WireGuard address:

```routeros
/ping 10.66.66.1
```

Check the WireGuard peer:

```routeros
/interface wireguard peers print detail
```

A recent handshake confirms that the MikroTik has established the tunnel with the VPS.

### Verify from the VPS

On the VPS:

```bash
wg show
```

The MikroTik peer should show a recent handshake.

Then test:

```bash
ping -c 4 10.66.66.2
```

and:

```bash
ping -c 4 192.168.88.1
```

Both addresses should be reachable through the WireGuard tunnel.

---

## 8. Configure the Windows WireGuard Client

Install the official WireGuard client for Windows.

Create a new empty tunnel. WireGuard will automatically generate a private and public key pair.

Assign the client address:

```ini
[Interface]
PrivateKey = <WINDOWS_CLIENT_PRIVATE_KEY>
Address = 10.66.66.3/32
```

Add the VPS as the peer:

```ini
[Peer]
PublicKey = <VPS_PUBLIC_KEY>
Endpoint = <VPS_PUBLIC_IP>:51820
AllowedIPs = 10.66.66.1/32, 10.66.66.2/32, 192.168.88.0/24
PersistentKeepalive = 25
```

Add the Windows client's public key to the VPS configuration:

```ini
[Peer]
PublicKey = <WINDOWS_CLIENT_PUBLIC_KEY>
AllowedIPs = 10.66.66.3/32
```

Restart or reload WireGuard on the VPS after changing the persistent configuration.

### Verify Laptop → VPS

Activate the WireGuard tunnel on Windows.

Test the VPS:

```powershell
ping 10.66.66.1
```

### Verify Laptop → MikroTik

Test the MikroTik WireGuard address:

```powershell
ping 10.66.66.2
```

Then test the MikroTik LAN address:

```powershell
ping 192.168.88.1
```

### Verify Access to a Remote LAN Device

For example, if a device behind the MikroTik uses:

```text
192.168.88.88
```

test it from the remote Windows client:

```powershell
ping 192.168.88.88
```

A successful reply confirms the complete routed path:

```text
Windows Client
10.66.66.3
      │
      ▼
VPS
10.66.66.1
      │
      ▼
MikroTik
10.66.66.2
      │
      ▼
Remote LAN
192.168.88.0/24
      │
      ▼
Remote Device
192.168.88.88
```

Only the VPN networks and remote LAN are routed through WireGuard. Normal Internet traffic from the Windows client continues to use its regular Internet connection.

---

## 9. Verify Automatic Recovery

The VPS WireGuard interface should start automatically after a reboot.

Reboot the VPS:

```bash
reboot
```

Reconnect over SSH and verify the service:

```bash
systemctl status wg-quick@wg0 --no-pager
```

Expected status:

```text
Active: active (exited)
```

Check WireGuard:

```bash
wg show
```

Both the MikroTik and Windows peers should appear. When they are connected, each peer should show a recent handshake.

Verify that the remote LAN route was restored automatically:

```bash
ip route get 192.168.88.1
```

The route should use:

```text
dev wg0
```

Finally, from the remote Windows client test a device behind the MikroTik:

```powershell
ping 192.168.88.88
```

If the device responds after the VPS reboot, the complete VPN path and automatic recovery are working correctly.

---

## Result

The final topology provides secure remote access to a MikroTik LAN even when the MikroTik Internet connection is behind NAT or CGNAT.

```text
Remote Client
     │
     │ WireGuard
     ▼
Public VPS
     │
     │ WireGuard
     ▼
MikroTik
     │
     ▼
Remote LAN Devices
```

No public IPv4 address is required on the MikroTik side.
