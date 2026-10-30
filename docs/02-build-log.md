# 02. Build log

The build in order. Each step lists the goal, the commands or settings, the result, any problem and its fix, and the screenshot.

---

## Step 1. Create the OPNsense VM with four network cards

**Goal:** a firewall VM with one port on the internet side and one on each internal zone.

**Settings:**
- VMware Workstation Pro, New Virtual Machine, Custom (advanced), guest OS FreeBSD 14 64-bit
- 2048 MB RAM, 10 GB thin-provisioned disk
- Network adapter 1: **NAT**. Adapters 2, 3 and 4: **LAN Segment**, created in VMware as `LAN`, `DMZ` and `GUEST`
- CD/DVD: the OPNsense amd64 DVD image

**Result:** VM created with NAT, LAN, DMZ and GUEST adapters.

**Problem and fix:** the dropdown does not always select a newly created segment, so each adapter was checked individually. Two adapters on the same segment would merge two zones.

**Screenshots:** [02](../screenshots/02-vmware-opnsense-vm-summary.png), [03](../screenshots/03-vmware-opnsense-adapters-lan-segments.png)

---

## Step 2. Install OPNsense

**Goal:** OPNsense installed on the virtual disk.

**Settings:** boot the ISO, log in at the installer prompt, choose the UFS install on the 10 GB disk, set a root password, reboot, and disconnect the ISO under CD/DVD settings.

**Result:** OPNsense 26.7 (amd64) boots to its console menu.

**Screenshot:** [04](../screenshots/04-opnsense-installer-login.png)

---

## Step 3. Assign interfaces and set the LAN address

**Goal:** tell OPNsense which adapter is which, and give the LAN a gateway address with DHCP.

**Console menu:**
- Option 1, Assign interfaces: declined LAGG and VLAN prompts, then set `em0` WAN, `em1` LAN, `em2` OPT1, `em3` OPT2. Interface names were matched to adapters by MAC address from the VMware adapter settings.
- Option 2, Set interface IP: LAN `10.10.10.1/24`, DHCP enabled for `10.10.10.100` to `10.10.10.200`.

**Result:** WAN got `192.168.25.132/24` from VMware's NAT DHCP. LAN shows `10.10.10.1/24`.

**Problem and fix:** the LAGG prompt was answered "yes" by mistake. Pressing Enter on the empty member list skipped it.

---

## Step 4. LAN client and the web interface

**Goal:** a machine on the LAN to reach the firewall's web interface (it is not reachable from the host PC, by design).

**Commands (Lubuntu):**
```bash
ip a
ping -c 3 10.10.10.1
ping -c 3 8.8.8.8
sudo apt update && sudo apt install -y open-vm-tools-desktop
```

**Result:** Lubuntu received `10.10.10.170/24` from OPNsense DHCP, and the web interface opened at `https://10.10.10.1`.

**Screenshots:** [06](../screenshots/06-lubuntu-dhcp-lease.png)

---

## Step 5. DMZ and GUEST interfaces

**Goal:** enable and address the two remaining ports.

**Settings (web interface, Interfaces):**
- OPT1: enabled, renamed `DMZ`, static IPv4 `10.10.20.1/24`
- OPT2: enabled, renamed `GUEST`, static IPv4 `10.10.30.1/24`
- WAN: "Block private networks" unticked, because the VMware NAT network uses a private range

**Result:** all four interfaces show as up with the expected addresses.

**Screenshot:** [05](../screenshots/05-opnsense-interfaces-overview.png)

---

## Step 6. DMZ web server

**Goal:** an Ubuntu Server in the DMZ with a fixed address, reachable over SSH from the LAN.

**Settings:** Ubuntu 64-bit VM, 2 GB RAM, 15 GB disk, adapter on LAN Segment `DMZ`, OpenSSH server selected at install. Static address configured with netplan ([`configs/web-server/50-cloud-init.yaml`](../configs/web-server/50-cloud-init.yaml)):

```bash
sudo netplan apply
ip a
```

**Result:** `ens33` shows `10.10.20.10/24`. SSH from the LAN client works with `ssh user1@10.10.20.10`.

**Problems and fixes:**
- The first boot showed a VMware NAT address (`192.168.25.x`), because the adapter was still on NAT. Switching it to the `DMZ` segment fixed it.
- Typos in the hand-typed netplan line caused `Invalid YAML` until corrected. See [troubleshooting](06-troubleshooting.md#netplan-invalid-yaml).

**Screenshot:** [07](../screenshots/07-dmz-webserver-static-ip.png)

---

## Step 7. DMZ rules and nginx

**Goal:** let the server update and install packages without giving it any path to the LAN.

**Rules:** DNS to the firewall, block to `Internal_Zones` (logged), web ports out. See [firewall rules](03-firewall-rules.md#dmz-interface-em2).

**Commands (web server):**
```bash
sudo apt update
sudo apt install -y nginx open-vm-tools
systemctl is-active nginx
```

**Result:** nginx 1.30.4 installed and active. The web server's ping to the LAN host shows 100% loss, logged by the block rule.

**Problem and fix:** with no DMZ rules, `apt` failed with "Temporary failure resolving". A temporary allow-all rule was used to install nginx, then deleted and replaced with the real rules before any test was run.

**Screenshots:** [08](../screenshots/08-dmz-apt-update-ok.png), [09](../screenshots/09-dmz-rules-and-blocked-ping.png), [10](../screenshots/10-firewall-log-dmz-block.png)

---

## Step 8. Kali and GUEST DHCP

**Goal:** an attacker machine in the GUEST zone with an address from OPNsense.

**Settings:** Kali (installer ISO), adapter on LAN Segment `GUEST`, DHCP range `10.10.30.100` to `10.10.30.200` on GUEST.

**Commands (Kali):**
```bash
ip a
sudo nmcli device connect eth0
```

**Result:** `eth0` received `10.10.30.146/24`.

**Problem and fix:** Kali got no address. Cause: the Dnsmasq interface list contained only LAN. Adding GUEST fixed it. See [troubleshooting](06-troubleshooting.md#kali-gets-no-ip-address).

**Screenshots:** [11](../screenshots/11-kali-no-dhcp-troubleshooting.png), [12](../screenshots/12-dnsmasq-interface-setting.png), [13](../screenshots/13-kali-dhcp-lease.png)

---

## Step 9. GUEST rules and tests

**Goal:** Kali reaches the website and the internet and nothing internal.

**Rules:** website only, DNS, block `RFC1918`, internet. See [firewall rules](03-firewall-rules.md#guest-interface-em3).

**Commands (Kali):**
```bash
curl -I http://10.10.20.10
ssh -o ConnectTimeout=5 user1@10.10.20.10
ping -c 3 10.10.10.170
curl -I https://example.com
```

**Result:** website and internet work. SSH and the LAN ping are blocked and logged. Full table in [test results](04-test-results.md).

**Screenshots:** [14](../screenshots/14-guest-rules.png), [15](../screenshots/15-firewall-log-guest-blocks.png), [16](../screenshots/16-kali-curl-tests.png)

---

## Step 10. Harden the web server

Lynis before and after, fixes applied. See [hardening](05-hardening-lynis.md). Score **61 to 73**.
