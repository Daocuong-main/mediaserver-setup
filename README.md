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
                - <SERVER_LAN_IP>/24
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

Chúc mừng bạn! Việc sử dụng `modprobe.d` là cách can thiệp trực tiếp vào module của nhân Linux, thường có hiệu quả cao hơn và ổn định hơn so với việc sửa Grub.

Dưới đây là bản Document (Cheat Sheet) tóm tắt lại toàn bộ quá trình xử lý để bạn lưu trữ.

---

# DOCUMENT: XỬ LÝ LỖI VĂNG Ổ CỨNG RỜI (USB DISCONNECT) TRÊN LINUX

## 1. Triệu chứng & Nguyên nhân

* **Triệu chứng:** Ổ cứng ngoài (thường là các Box Orico, Seagate, chip JMicron) đang hoạt động bình thường thì bị mất kết nối (unmount). Kiểm tra `df -h` không thấy ổ, `dmesg` báo lỗi `I/O error` hoặc `USB disconnect`.
* **Nguyên nhân:** Xung đột giữa giao thức **UAS (USB Attached SCSI)** hiện đại và Chip điều khiển (Controller) của Box HDD giá rẻ. Chip không xử lý kịp hàng đợi lệnh dẫn đến treo và reset kết nối.

## 2. Giải pháp: Disable UAS (Force USB-Storage)

Ép hệ thống sử dụng driver `usb-storage` truyền thống (BOT) để đảm bảo sự ổn định tuyệt đối cho Media Server 24/7.

### Bước 1: Xác định mã định danh thiết bị (Hardware ID)

Chạy lệnh:

```bash
lsusb

```

Tìm dòng chứa ổ cứng lỗi. Ví dụ:
`Bus 003 Device 002: ID 152d:0578 JMicron Technology Corp. JMS578 SATA 6Gb/s`

* **Vendor ID:** `152d`
* **Product ID:** `0578`

### Bước 2: Cấu hình chặn UAS qua Modprobe

Tạo file cấu hình để ép module `usb-storage` nhận diện thiết bị này dưới dạng "quirks" (đặc biệt):

```bash
echo "options usb-storage quirks=152d:0578:u" | sudo tee /etc/modprobe.d/disable_uas.conf

```

*(Lưu ý: Thay `152d:0578` bằng ID thực tế của bạn).*

### Bước 3: Cập nhật hệ thống khởi động

Để cấu hình có tác dụng ngay từ lúc máy vừa bật (khi nạp Kernel), cần cập nhật lại `initramfs`:

```bash
sudo update-initramfs -u
sudo reboot

```

### Bước 4: Kiểm tra kết quả

Sau khi reboot, kiểm tra xem Driver nào đang điều khiển thiết bị:

```bash
lsusb -t

```

**Kết quả chuẩn:** Dòng thiết bị phải hiện `Driver=usb-storage` (Thay vì `Driver=uas`).

---

## 3. Cấu hình Mount cố định (fstab)

Để tránh việc ổ cứng thay đổi tên (lúc `sdb`, lúc `sdc`) làm hỏng đường dẫn Docker, luôn sử dụng **UUID**.

**File:** `/etc/fstab`
**Cấu hình khuyến nghị:**

```text
UUID=efcf16bd-c481-4bed-8675-492145522416  /mnt/external2  ext4  defaults,nofail  0  2

```

* `nofail`: Giúp server vẫn khởi động được nếu chẳng may ổ cứng bị rút ra.
* Không nên dùng `x-systemd.automount` nếu ổ cứng không ổn định.

---

## 4. Các lệnh cứu hộ nhanh (Cheat Sheet)

| Lệnh | Tác dụng |
| --- | --- |
| `lsblk` | Xem danh sách ổ cứng và điểm mount |
| `df -h` | Kiểm tra dung lượng và trạng thái mount |
| `sudo mount -a` | Ép hệ thống mount lại toàn bộ theo file fstab |
| `sudo umount -l /mnt/folder` | Gỡ mount cưỡng bách (khi bị treo "target is busy") |
| `sudo dmesg -T | tail -n 50` | Xem log hệ thống thời gian thực (đã convert sang giờ người đọc) |
| `sudo fsck -y /dev/sdX1` | Sửa lỗi định dạng file system (chỉ chạy khi đã unmount ổ) |

---

## 5. Lưu ý về phần cứng (Hardware Tips)

1. **Cổng USB:** Ưu tiên cắm cổng USB 3.0 (màu xanh) trực tiếp trên Mainboard (phía sau case), tránh cắm qua Hub hoặc cổng mặt trước.
2. **Cáp tín hiệu:** Cáp đi kèm Box Orico thường chất lượng trung bình. Nếu vẫn bị văng, hãy thay cáp USB 3.0 loại tốt.
3. **Nguồn điện:** Nếu dùng ổ 3.5 inch, hãy đảm bảo cục nguồn của Box HDD đủ công suất (thường là 12V-2A).

---

*Tài liệu này giúp hệ thống Media Server (Jellyfin, qBittorrent, *Arr) của bạn hoạt động bền bỉ, tránh tình trạng mất dữ liệu giữa chừng.*


# Dashdot and speedtest tracker
Yes, but only a few checks.

Your `dashdot` service is basically ready after:

```bash
docker compose up -d
```

It maps DashDot to:

```text
http://SERVER-IP:3001
```

Your config matches the official DashDot Docker Compose pattern: `privileged: true`, host root mounted read-only at `/mnt/host`, and port `3001:3001`. CPU temps are also enabled with `DASHDOT_ENABLE_CPU_TEMPS: 'true'`.  DashDot’s own Compose docs show the same core requirements: privileged mode, `/:/mnt/host:ro`, and optional environment config such as CPU temperatures. ([getdashdot.com][1])

For `speedtest-tracker`, you do need to make sure the `.env` variables exist before relying on it:

```env
SPEEDTEST_APP_KEY=base64:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SPEEDTEST_APP_URL=http://SERVER-IP:6875
```

Generate the key with:

```bash
echo -n 'base64:'; openssl rand -base64 32
```

The Speedtest Tracker docs say `APP_KEY` is required for encryption and `APP_URL` is required; your compose references them as `${SPEEDTEST_APP_KEY}` and `${SPEEDTEST_APP_URL}`.  ([docs.speedtest-tracker.dev][2])

After it starts, open:

```text
http://SERVER-IP:6875
```

Default login is:

```text
admin@example.com
password
```

Change that immediately after first login. LinuxServer’s docs list those default credentials and confirm that `/config` stores the app config and SQLite database. ([docs.linuxserver.io][3])

Also check permissions for the Speedtest Tracker config directory:

```bash
sudo mkdir -p /home/cuong/Config/speedtest-tracker
sudo chown -R 1000:1000 /home/cuong/Config/speedtest-tracker
```

Your schedule is already set to run every 6 hours:

```yaml
SPEEDTEST_SCHEDULE=0 */6 * * *
```

That is fine. Leaving `SPEEDTEST_SERVERS=` empty is also acceptable unless you want to force a specific Ookla server. The LinuxServer docs say server IDs can be listed with:

```bash
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/speedtest-tracker:latest list-servers
```

Security note: I would not expose DashDot or Speedtest Tracker directly to the internet. DashDot runs privileged and can read host-level system information through `/:/mnt/host:ro`, so keep it LAN-only, behind VPN, or behind a reverse proxy with authentication and HTTPS.

[1]: https://getdashdot.com/docs/installation/docker-compose "Docker-Compose"
[2]: https://docs.speedtest-tracker.dev/getting-started/installation/using-docker-compose "Using Docker Compose | Speedtest Tracker"
[3]: https://docs.linuxserver.io/images/docker-speedtest-tracker/ "speedtest-tracker - LinuxServer.io"
