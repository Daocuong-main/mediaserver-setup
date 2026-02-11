# Ultimate Media Server Setup Guide

This guide walks through setting up a media server (Jellyfin, *Arr stack, qBittorrent) on Ubuntu Server with Docker, focusing on correct permissions, unified path mapping, and network optimizations.

## 1. Initial Server Setup

### Network Configuration (Static IP)

1. Check current interface name: `ip addr show`
2. Edit Netplan config: `sudo nano /etc/netplan/50-cloud-init.yaml` (Name might vary).
3. Paste the following configuration (Ensure indentation is correct):

```yaml
network:
    version: 2
    ethernets:
        enp0s25:  # Replace with your interface name
            dhcp4: no
            addresses:
                - 192.168.1.100/24
            routes:
                - to: default
                  via: 192.168.1.1
            nameservers:
                addresses:
                    - 1.1.1.1
                    - 8.8.8.8

```

4. Apply changes:
```bash
sudo netplan apply

```



### Install Docker & Git

```bash
sudo apt update && sudo apt install git -y
# Install Docker using the convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
# Add current user to docker group (Avoids using sudo for docker commands)
sudo usermod -aG docker $USER
newgrp docker

```

---

## 2. Storage & Permissions (CRITICAL STEP)

### A. Mount External Drives (Permanent)

**Important:** If using NTFS drives, you MUST mount them via `/etc/fstab` with specific UID/GID to allow Docker to write.

1. Get UUID of drives: `ls -l /dev/disk/by-uuid/`
2. Edit fstab: `sudo nano /etc/fstab`
3. Add/Edit lines:

```ini
# Example for NTFS Drive (Windows formatted)
UUID=XXXX-XXXX  /mnt/external   ntfs-3g   defaults,uid=1000,gid=1000,umask=002  0  0
UUID=YYYY-YYYY  /mnt/external2  ntfs-3g   defaults,uid=1000,gid=1000,umask=002  0  0

# Example for Ext4 Drive (Linux formatted)
UUID=ZZZZ-ZZZZ  /mnt/data       ext4      defaults  0  0

```

4. Mount all: `sudo mount -a`

### B. Fix Permissions (The "Golden" Script)

Run this script to ensure your user (ID 1000) owns everything and future files inherit correct permissions across all storage locations.

```bash
# 1. Ownership
sudo chown -R 1000:1000 /home/$USER/Config
sudo chown -R 1000:1000 /home/$USER/Data
sudo chown -R 1000:1000 /mnt/external
sudo chown -R 1000:1000 /mnt/external2

# 2. Permissions (Read/Write for User & Group)
sudo chmod -R 775 /home/$USER/Config
sudo chmod -R 775 /home/$USER/Data
sudo chmod -R 775 /mnt/external
sudo chmod -R 775 /mnt/external2

# 3. Sticky Bit (Ensures new files belong to group 1000)
# Skip this step for NTFS drives
sudo find /mnt/external -type d -exec chmod g+s {} +
sudo find /mnt/external2 -type d -exec chmod g+s {} +

```

---

## 3. Essential App Configuration & Optimization

### A. Path Mapping (Crucial)

Since we used Unified Path Mapping, configure apps as follows:

1. **qBittorrent** (`:8080`):
* **Tools > Options > Downloads**:
* Default Save Path: `/data/media_local` (Internal SSD).
* *Note*: You can manually change specific torrents to `/data/media_ext1` or `/data/media_ext2`.


2. **Radarr / Sonarr** (`:7878` / `:8989`):
* **Settings > Media Management > Root Folders**:
* Add: `/data/media_local` (Internal).
* Add: `/data/media_ext1` (External 1).
* Add: `/data/media_ext2` (External 2).


3. **Jellyfin** (`:8096`):
* **Libraries**: Point to `/data/media_local`, `/data/media_ext1`, etc.



### B. Enable Hardware Transcoding (Intel QuickSync)

Offload video processing to the GPU to save CPU usage.

1. Open **Jellyfin** > **Dashboard** > **Playback**.
2. **Hardware Acceleration**: Select `Intel QuickSync` (QSV) or `VAAPI`.
3. **Enable Hardware Encoding**: Check all boxes (H264, HEVC, VC1, etc.).
4. Save and restart Jellyfin container.

### C. Bypass Cloudflare (Prowlarr + Flaresolverr)

Fixes indexer errors for sites like 1337x.

1. Open **Prowlarr** > **Settings** > **Indexers**.
2. Add **FlareSolverr**.
* **Name:** FlareSolverr
* **Tags:** `flaresolverr`
* **Host:** `http://flaresolverr:8191`


3. When adding a new Indexer, add the tag `flaresolverr` to it.

### D. Optimize Subtitles (Bazarr)

1. **Providers:** Register accounts on https://www.google.com/search?q=OpenSubtitles.com and add credentials in Bazarr > Settings > Providers.
2. **Path Mapping:** Ensure Bazarr paths match Sonarr/Radarr exactly (Fixed in Docker Compose).

---

## 4. Utilities & Maintenance

### Bandwidth Test (iperf3)

**Client (Linux):** `sudo apt install iperf3`
**Server (Windows):** Download iperf3.exe

1. **Windows (Server):** Run `iperf3.exe -s`
2. **Linux (Client):** Run `iperf3 -c <WINDOWS_IP>`

For Gigabit speed, ensure ethernet negotiation is correct:

```bash
sudo ethtool eth0 | grep Speed
# If not 1000Mb/s, force it:
sudo ethtool -s eth0 speed 1000 duplex full

```

### ZeroTier Setup

1. Install: `curl -s https://install.zerotier.com | sudo bash`
2. Join network: `sudo zerotier-cli join <NETWORK_ID>`
3. **Routing (Linux as Router):**
* Enable IP Forwarding in `/etc/sysctl.conf`: `net.ipv4.ip_forward=1` -> `sudo sysctl -p`
* iptables rules:
```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i zt+ -o eth0 -j ACCEPT

```


* Persist rules: `sudo apt install iptables-persistent`



### Cloning Disk (dd)

**WARNING:** Use with caution. Verify drive letters (`lsblk`) before running.

1. Stop containers: `sudo docker compose down`
2. Unmount: `sudo umount /mnt/external`
3. Clone sdb to sdc:
```bash
sudo dd if=/dev/sdb of=/dev/sdc bs=64K conv=noerror,sync status=progress

```