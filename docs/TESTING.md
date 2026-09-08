# Testing Guide

This document provides a simple verification procedure for the complete WireGuard topology.

```text
Remote Laptop
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
```

---

## 1. Check WireGuard on the VPS

Run:

```bash
wg show
```

Verify that both peers are present:

- MikroTik — `10.66.66.2/32`
- Windows client — `10.66.66.3/32`

Connected peers should show a recent handshake and transferred data.

---

## 2. Test VPS → MikroTik

From the VPS:

```bash
ping -c 4 10.66.66.2
```

Then test the MikroTik LAN address:

```bash
ping -c 4 192.168.88.1
```

Both should respond.

---

## 3. Test VPS → Remote LAN Device

If a device behind the MikroTik uses `192.168.88.88`:

```bash
ping -c 4 192.168.88.88
```

A successful reply confirms:

```text
VPS → WireGuard → MikroTik → Remote LAN
```

---

## 4. Test Windows Client → VPS

Activate the WireGuard tunnel on Windows.

Run:

```powershell
ping 10.66.66.1
```

The VPS WireGuard address should respond.

---

## 5. Test Windows Client → MikroTik

Test the MikroTik WireGuard address:

```powershell
ping 10.66.66.2
```

Then test its LAN address:

```powershell
ping 192.168.88.1
```

Both should respond.

---

## 6. Test Windows Client → Remote LAN Device

Test a device behind the MikroTik:

```powershell
ping 192.168.88.88
```

A successful reply verifies the complete path:

```text
Windows Client
      │
      ▼
     VPS
      │
      ▼
  MikroTik
      │
      ▼
Remote LAN Device
```

---

## 7. Verify VPS Routing

On the VPS:

```bash
ip route get 192.168.88.1
```

The route should use:

```text
dev wg0
```

IPv4 forwarding should also be enabled:

```bash
sysctl net.ipv4.ip_forward
```

Expected:

```text
net.ipv4.ip_forward = 1
```

---

## 8. Reboot Test

Reboot the VPS:

```bash
reboot
```

After reconnecting over SSH:

```bash
systemctl status wg-quick@wg0 --no-pager
```

Expected:

```text
Active: active (exited)
```

Then:

```bash
wg show
```

Verify that both peers are present and reconnect automatically.

Finally, from the remote Windows client:

```powershell
ping 192.168.88.88
```

If the remote device responds, automatic recovery is working correctly.

---

## Expected Result

All of the following should succeed:

- [ ] VPS → MikroTik WireGuard (`10.66.66.2`)
- [ ] VPS → MikroTik LAN (`192.168.88.1`)
- [ ] VPS → Remote LAN device (`192.168.88.88`)
- [ ] Windows → VPS (`10.66.66.1`)
- [ ] Windows → MikroTik WireGuard (`10.66.66.2`)
- [ ] Windows → MikroTik LAN (`192.168.88.1`)
- [ ] Windows → Remote LAN device (`192.168.88.88`)
- [ ] WireGuard automatically recovers after VPS reboot

When all tests pass, the complete remote-access topology is operational.
