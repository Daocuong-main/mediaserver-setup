# Media Server Setup Guide

Ubuntu Server media stack using Docker Compose.

This setup includes:

| Service           | Purpose                        | Port           |
| ----------------- | ------------------------------ | -------------- |
| Jellyfin          | Media streaming server         | `8096`         |
| qBittorrent       | Torrent client                 | `8080`, `6881` |
| Radarr            | Movie automation               | `7878`         |
| Sonarr            | TV automation                  | `8989`         |
| Bazarr            | Subtitle automation            | `6767`         |
| Prowlarr          | Indexer manager                | `9696`         |
| FlareSolverr      | Cloudflare bypass helper       | `8191`         |
| Homarr            | Server dashboard               | `7575`         |
| Speedtest Tracker | Scheduled internet speed tests | `6875`         |
| DashDot           | Server monitoring dashboard    | `3001`         |

Current server addresses:

```text
LAN IP:       <SERVER_LAN_IP>
ZeroTier IP: <SERVER_ZEROTIER_IP>
```

Use the LAN IP when you are on the same local network. Use the ZeroTier IP when accessing the server remotely through ZeroTier.

---

## 1. Repository Layout

Recommended project location:

```bash
/home/cuong/mediaserver-setup
```

Expected files:

```text
mediaserver-setup/
├── docker-compose.yml
├── .env
├── README.md
```

Main persistent config path:

```text
/home/cuong/Config
```

Main media/data paths:

```text
/home/cuong/Data/Torrents
/mnt/external
/mnt/external2
```

Inside Docker containers, these paths are mapped consistently:

```text
/data/media_local  -> /home/cuong/Data/Torrents
/data/media_ext1   -> /mnt/external
/data/media_ext2   -> /mnt/external2
```

This unified path mapping is important. Jellyfin, qBittorrent, Radarr, Sonarr, and Bazarr should all see the same media paths inside their containers.

---

## 2. Install Base Packages

Update Ubuntu and install Git:

```bash
sudo apt update
sudo apt install -y git curl nano htop ca-certificates
```

Install Docker:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

Add your user to the Docker group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Check Docker:

```bash
docker --version
docker compose version
```

---

## 3. Clone or Update the Repo

Clone the repo:

```bash
git clone https://github.com/Daocuong-main/mediaserver-setup.git
cd mediaserver-setup
```

Update the repo later:

```bash
cd ~/mediaserver-setup
git pull
```

---

## 4. Environment File

Create the `.env` file in the same folder as `docker-compose.yml`:

```bash
cd ~/mediaserver-setup
nano .env
```

Example:

```env
TZ=Asia/Ho_Chi_Minh

# Homarr
HOMARR_SECRET_KEY=replace_with_64_character_hex_key
DOCKER_GID=987

# Speedtest Tracker
SPEEDTEST_APP_KEY=base64:replace_with_generated_base64_key
SPEEDTEST_APP_URL=http://<SERVER_LAN_IP>:6875

# FlareSolverr
LOG_LEVEL=info
LOG_HTML=false
CAPTCHA_SOLVER=none
```

Generate the Homarr secret key:

```bash
openssl rand -hex 32
```

Generate the Speedtest Tracker app key:

```bash
echo -n 'base64:'; openssl rand -base64 32
```

Check Docker group ID:

```bash
getent group docker
```

Current expected result on this server:

```text
docker:x:987:cuong
```

So:

```env
DOCKER_GID=987
```

Do not change `HOMARR_SECRET_KEY` after Homarr has already been configured. Homarr uses it to encrypt stored secrets. Changing it later can break saved integrations.

---

## 5. Static IP Configuration

Check network interface name:

```bash
ip addr show
```

Edit Netplan config:

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

Example static LAN IP config:

```yaml
network:
  version: 2
  ethernets:
    enp0s25:
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

Apply:

```bash
sudo netplan apply
```

Verify:

```bash
ip addr show
ip route
```

---

## 6. Storage and Mounts

Create mount points:

```bash
sudo mkdir -p /mnt/external
sudo mkdir -p /mnt/external2
```

Check drives:

```bash
lsblk -f
ls -l /dev/disk/by-uuid/
```

Edit fstab:

```bash
sudo nano /etc/fstab
```

Example for ext4 drives:

```text
UUID=YOUR-UUID-1  /mnt/external   ext4  defaults,nofail  0  2
UUID=YOUR-UUID-2  /mnt/external2  ext4  defaults,nofail  0  2
```

Example for NTFS drives:

```text
UUID=YOUR-UUID-1  /mnt/external   ntfs-3g  defaults,nofail,uid=1000,gid=1000,umask=002  0  0
UUID=YOUR-UUID-2  /mnt/external2  ntfs-3g  defaults,nofail,uid=1000,gid=1000,umask=002  0  0
```

Mount:

```bash
sudo mount -a
```

Check:

```bash
df -h
lsblk
```

For a Linux media server, ext4 is preferred for long-term stability. NTFS works, but ext4 usually gives better Linux permissions behavior.

---

## 7. Folder Structure

Create config folders:

```bash
sudo mkdir -p /home/cuong/Config/Jellyfin
sudo mkdir -p /home/cuong/Config/qbittorrent
sudo mkdir -p /home/cuong/Config/Radarr
sudo mkdir -p /home/cuong/Config/Sonarr
sudo mkdir -p /home/cuong/Config/Bazarr
sudo mkdir -p /home/cuong/Config/prowlarr
sudo mkdir -p /home/cuong/Config/speedtest-tracker
sudo mkdir -p /home/cuong/Config/Homarr
```

Create media folders:

```bash
sudo mkdir -p /home/cuong/Data/Torrents
sudo mkdir -p /mnt/external
sudo mkdir -p /mnt/external2
```

Optional recommended subfolders:

```bash
sudo mkdir -p /home/cuong/Data/Torrents/downloads
sudo mkdir -p /home/cuong/Data/Torrents/movies
sudo mkdir -p /home/cuong/Data/Torrents/tv

sudo mkdir -p /mnt/external/movies
sudo mkdir -p /mnt/external/tv

sudo mkdir -p /mnt/external2/movies
sudo mkdir -p /mnt/external2/tv
```

---

## 8. Permissions

Most services run as:

```text
PUID=1000
PGID=1000
```

Homarr uses Docker integration, so it also needs access to the Docker socket group. On this server, the Docker group ID is:

```text
987
```

Fix normal app permissions:

```bash
sudo chown -R 1000:1000 \
  /home/cuong/Config/Jellyfin \
  /home/cuong/Config/qbittorrent \
  /home/cuong/Config/Radarr \
  /home/cuong/Config/Sonarr \
  /home/cuong/Config/Bazarr \
  /home/cuong/Config/prowlarr \
  /home/cuong/Config/speedtest-tracker \
  /home/cuong/Data/Torrents \
  /mnt/external \
  /mnt/external2
```

Fix Homarr permissions:

```bash
sudo chown -R 1000:987 /home/cuong/Config/Homarr
```

Set directory and file permissions:

```bash
sudo find /home/cuong/Config -type d -exec chmod 775 {} \;
sudo find /home/cuong/Config -type f -exec chmod 664 {} \;

sudo find /home/cuong/Data -type d -exec chmod 775 {} \;
sudo find /home/cuong/Data -type f -exec chmod 664 {} \;

sudo find /mnt/external -type d -exec chmod 2775 {} \;
sudo find /mnt/external -type f -exec chmod 664 {} \;

sudo find /mnt/external2 -type d -exec chmod 2775 {} \;
sudo find /mnt/external2 -type f -exec chmod 664 {} \;
```

Important:

```bash
sudo chown -R 775 /some/path
```

is wrong. That changes ownership to UID `775`.

Use this for permissions:

```bash
sudo chmod -R 775 /some/path
```

Check permissions:

```bash
sudo stat -c '%n -> owner=%U:%G uid:gid=%u:%g perms=%A %a' \
/home/cuong/Config/Jellyfin \
/home/cuong/Config/qbittorrent \
/home/cuong/Config/Radarr \
/home/cuong/Config/Sonarr \
/home/cuong/Config/Bazarr \
/home/cuong/Config/prowlarr \
/home/cuong/Config/speedtest-tracker \
/home/cuong/Config/Homarr \
/home/cuong/Data/Torrents \
/mnt/external \
/mnt/external2
```

Expected:

```text
Most config folders: 1000:1000
Homarr config:       1000:987
Media folders:       1000:1000
```

Check write access:

```bash
touch /home/cuong/Data/Torrents/test-permission && rm /home/cuong/Data/Torrents/test-permission
touch /mnt/external/test-permission && rm /mnt/external/test-permission
touch /mnt/external2/test-permission && rm /mnt/external2/test-permission
```

---

## 9. Docker Compose: Homarr Docker Integration

Homarr can run as a normal dashboard without Docker access. This setup uses Docker integration, so Homarr mounts the Docker socket:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This lets Homarr detect containers and show Docker status.

Check Docker socket permissions:

```bash
sudo stat -c '%n -> owner=%U:%G uid:gid=%u:%g perms=%A %a' /var/run/docker.sock
```

Expected:

```text
/var/run/docker.sock -> owner=root:docker uid:gid=0:987 perms=srw-rw---- 660
```

Homarr should use the Docker group ID:

```env
DOCKER_GID=987
```

Security note: Docker socket access is powerful. Keep Homarr private. Do not expose it directly to the public internet.

---

## 10. Start the Stack

From the project folder:

```bash
cd ~/mediaserver-setup
docker compose pull
docker compose up -d
```

Check status:

```bash
docker compose ps
```

Check all logs for permission or startup problems:

```bash
docker compose logs --tail=300 | grep -Ei "permission|denied|not writable|read-only|readonly|database is locked|sqlite|error|fatal"
```

Check one service:

```bash
docker compose logs --tail=100 homarr
docker compose logs --tail=100 jellyfin
docker compose logs --tail=100 qbittorrent
```

Do not use this for normal updates unless you intentionally want to remove Docker-managed volumes:

```bash
docker compose down -v
```

For normal restart:

```bash
docker compose down
docker compose up -d
```

---

## 11. Service URLs

LAN access:

```text
Homarr:            http://<SERVER_LAN_IP>:7575
Jellyfin:          http://<SERVER_LAN_IP>:8096
qBittorrent:       http://<SERVER_LAN_IP>:8080
Radarr:            http://<SERVER_LAN_IP>:7878
Sonarr:            http://<SERVER_LAN_IP>:8989
Bazarr:            http://<SERVER_LAN_IP>:6767
Prowlarr:          http://<SERVER_LAN_IP>:9696
FlareSolverr:      http://<SERVER_LAN_IP>:8191
Speedtest Tracker: http://<SERVER_LAN_IP>:6875
DashDot:           http://<SERVER_LAN_IP>:3001
```

ZeroTier access:

```text
Homarr:            http://<SERVER_ZEROTIER_IP>:7575
Jellyfin:          http://<SERVER_ZEROTIER_IP>:8096
qBittorrent:       http://<SERVER_ZEROTIER_IP>:8080
Radarr:            http://<SERVER_ZEROTIER_IP>:7878
Sonarr:            http://<SERVER_ZEROTIER_IP>:8989
Bazarr:            http://<SERVER_ZEROTIER_IP>:6767
Prowlarr:          http://<SERVER_ZEROTIER_IP>:9696
Speedtest Tracker: http://<SERVER_ZEROTIER_IP>:6875
DashDot:           http://<SERVER_ZEROTIER_IP>:3001
```

For communication between containers, prefer Docker service names instead of IP addresses:

```text
http://jellyfin:8096
http://qbittorrent:8080
http://radarr:7878
http://sonarr:8989
http://bazarr:6767
http://prowlarr:9696
http://flaresolverr:8191
```

Use IP addresses for browser access. Use service names for app-to-app communication inside Docker.

---

## 12. First-Time App Setup

### qBittorrent

Open:

```text
http://<SERVER_LAN_IP>:8080
```

Set download paths under:

```text
Tools -> Options -> Downloads
```

Recommended save paths:

```text
/data/media_local/downloads
/data/media_ext1/downloads
/data/media_ext2/downloads
```

Use categories to separate downloads:

```text
movies
tv
music
anime
```

qBittorrent must use the same container paths that Radarr, Sonarr, Bazarr, and Jellyfin can see.

---

### Prowlarr

Open:

```text
http://<SERVER_LAN_IP>:9696
```

Add indexers under:

```text
Indexers -> Add Indexer
```

Add Radarr and Sonarr under:

```text
Settings -> Apps
```

Use Docker service names:

```text
Radarr URL:  http://radarr:7878
Sonarr URL:  http://sonarr:8989
```

For the Prowlarr server URL, use:

```text
http://prowlarr:9696
```

Use API keys from Radarr and Sonarr:

```text
Radarr -> Settings -> General -> Security -> API Key
Sonarr -> Settings -> General -> Security -> API Key
```

---

### FlareSolverr

FlareSolverr is used when an indexer requires Cloudflare bypass.

In Prowlarr:

```text
Settings -> Indexers -> Add FlareSolverr
```

Use:

```text
Name: FlareSolverr
Host: http://flaresolverr:8191
Tags: flaresolverr
```

Then add the `flaresolverr` tag to indexers that need it.

---

### Radarr

Open:

```text
http://<SERVER_LAN_IP>:7878
```

Add root folders:

```text
/data/media_local/movies
/data/media_ext1/movies
/data/media_ext2/movies
```

Add qBittorrent as download client:

```text
Settings -> Download Clients -> Add qBittorrent
```

Use:

```text
Host: qbittorrent
Port: 8080
Category: movies
```

---

### Sonarr

Open:

```text
http://<SERVER_LAN_IP>:8989
```

Add root folders:

```text
/data/media_local/tv
/data/media_ext1/tv
/data/media_ext2/tv
```

Add qBittorrent as download client:

```text
Settings -> Download Clients -> Add qBittorrent
```

Use:

```text
Host: qbittorrent
Port: 8080
Category: tv
```

---

### Bazarr

Open:

```text
http://<SERVER_LAN_IP>:6767
```

Connect Bazarr to Radarr and Sonarr:

```text
Radarr URL: http://radarr:7878
Sonarr URL: http://sonarr:8989
```

Use API keys from Radarr and Sonarr.

Bazarr paths should match Radarr and Sonarr paths exactly:

```text
/data/media_local
/data/media_ext1
/data/media_ext2
```

Add subtitle providers under:

```text
Settings -> Providers
```

---

### Jellyfin

Open:

```text
http://<SERVER_LAN_IP>:8096
```

Add libraries using the container paths:

```text
Movies: /data/media_local/movies
Movies: /data/media_ext1/movies
Movies: /data/media_ext2/movies

TV:     /data/media_local/tv
TV:     /data/media_ext1/tv
TV:     /data/media_ext2/tv
```

## 14. Homarr

Open:

```text
http://<SERVER_LAN_IP>:7575
```

Homarr stores data in:

```text
/home/cuong/Config/Homarr
```

Docker integration requires:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

Homarr can use app URLs such as:

```text
Jellyfin:          http://<SERVER_LAN_IP>:8096
qBittorrent:       http://<SERVER_LAN_IP>:8080
Radarr:            http://<SERVER_LAN_IP>:7878
Sonarr:            http://<SERVER_LAN_IP>:8989
Bazarr:            http://<SERVER_LAN_IP>:6767
Prowlarr:          http://<SERVER_LAN_IP>:9696
Speedtest Tracker: http://<SERVER_LAN_IP>:6875
DashDot:           http://<SERVER_LAN_IP>:3001
```

For remote access through ZeroTier, use the ZeroTier IP in bookmarks:

```text
http://<SERVER_ZEROTIER_IP>:SERVICE_PORT
```

For app integrations that require API keys, generate API keys inside the target app and paste them into Homarr.

Jellyfin integration usually requires Jellyfin authorization. A `401 Unauthorized` response means Homarr can reach Jellyfin, but the Jellyfin credentials or API key are wrong.

---

## 15. Speedtest Tracker

Open:

```text
http://<SERVER_LAN_IP>:6875
```

Required `.env` values:

```env
SPEEDTEST_APP_KEY=base64:your_generated_key
SPEEDTEST_APP_URL=http://<SERVER_LAN_IP>:6875
```

Generate key:

```bash
echo -n 'base64:'; openssl rand -base64 32
```

Speedtest Tracker config path:

```text
/home/cuong/Config/speedtest-tracker
```

Default schedule:

```text
0 */6 * * *
```

This runs every 6 hours.

To list available Speedtest servers:

```bash
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/speedtest-tracker:latest list-servers
```

If `SPEEDTEST_SERVERS` is empty, Speedtest Tracker chooses automatically.

---

## 16. DashDot

Open:

```text
http://<SERVER_LAN_IP>:3001
```

DashDot uses:

```yaml
privileged: true
volumes:
  - /:/mnt/host:ro
```

CPU temperature monitoring is enabled:

```yaml
DASHDOT_ENABLE_CPU_TEMPS: 'true'
```

Security note: DashDot can read host system information. Keep it LAN-only or accessible only through ZeroTier/VPN.

---

## 17. ZeroTier

Install ZeroTier:

```bash
curl -s https://install.zerotier.com | sudo bash
```

Join network:

```bash
sudo zerotier-cli join NETWORK_ID
```

Check status:

```bash
sudo zerotier-cli status
sudo zerotier-cli listnetworks
```

Current ZeroTier server IP:

```text
<SERVER_ZEROTIER_IP>
```

Use this IP when accessing services remotely through ZeroTier.

Optional: enable Linux routing through ZeroTier.

Enable IP forwarding:

```bash
sudo nano /etc/sysctl.conf
```

Set:

```text
net.ipv4.ip_forward=1
```

Apply:

```bash
sudo sysctl -p
```

Example iptables rules:

```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i zt+ -o eth0 -j ACCEPT
```

Persist rules:

```bash
sudo apt install -y iptables-persistent
```

Only enable routing if the server is intended to route traffic for other ZeroTier devices.

---

## 18. USB Drive Disconnect Fix: Disable UAS

Some USB HDD enclosures, especially JMicron-based boxes, can disconnect under load when using UAS.

Symptoms:

```text
USB disconnect
I/O error
drive disappears from df -h
mount point becomes unavailable
```

Check device ID:

```bash
lsusb
```

Example:

```text
ID 152d:0578 JMicron Technology Corp. JMS578 SATA 6Gb/s
```

Create UAS disable config:

```bash
echo "options usb-storage quirks=152d:0578:u" | sudo tee /etc/modprobe.d/disable_uas.conf
```

Replace `152d:0578` with the real device ID.

Update initramfs and reboot:

```bash
sudo update-initramfs -u
sudo reboot
```

Verify:

```bash
lsusb -t
```

Expected result:

```text
Driver=usb-storage
```

instead of:

```text
Driver=uas
```

Useful drive commands:

```bash
lsblk
df -h
sudo mount -a
sudo dmesg -T | tail -n 50
sudo umount -l /mnt/external
sudo fsck -y /dev/sdX1
```

Only run `fsck` on an unmounted filesystem.

---

## 19. Network Speed Test with iperf3

Install iperf3:

```bash
sudo apt install -y iperf3
```

On the server:

```bash
iperf3 -s
```

On another machine:

```bash
iperf3 -c <SERVER_LAN_IP>
```

Check Ethernet link speed:

```bash
sudo ethtool eth0 | grep Speed
```

Replace `eth0` with the real interface name.

---

## 20. Updating Containers

Update all containers:

```bash
cd ~/mediaserver-setup
docker compose pull
docker compose up -d
```

Remove unused Docker images:

```bash
docker image prune -f
```

Check status:

```bash
docker compose ps
```

Check logs:

```bash
docker compose logs --tail=200
```

---

## 21. Backup

Back up all app configs:

```bash
sudo tar -czf mediaserver-config-backup-$(date +%F-%H%M%S).tar.gz /home/cuong/Config
```

Back up Homarr only:

```bash
sudo tar -czf homarr-backup-$(date +%F-%H%M%S).tar.gz /home/cuong/Config/Homarr
```

Back up Compose project:

```bash
tar -czf mediaserver-compose-backup-$(date +%F-%H%M%S).tar.gz ~/mediaserver-setup
```

Store backups outside the server if possible.

---

## 22. Disk Clone Warning

Cloning disks with `dd` is dangerous. Verify drive names first:

```bash
lsblk
```

Stop containers:

```bash
cd ~/mediaserver-setup
docker compose down
```

Unmount the source or target if needed:

```bash
sudo umount /mnt/external
```

Example clone:

```bash
sudo dd if=/dev/sdb of=/dev/sdc bs=64K conv=noerror,sync status=progress
```

Be absolutely sure `if=` is the source disk and `of=` is the destination disk.

---

## 23. Troubleshooting Checklist

Check containers:

```bash
docker compose ps
```

Check ports:

```bash
docker port homarr
sudo ss -tulpn | grep 7575
```

Check logs for errors:

```bash
docker compose logs --tail=300 | grep -Ei "permission|denied|not writable|read-only|readonly|database is locked|sqlite|error|fatal"
```

Check one container:

```bash
docker compose logs --tail=100 SERVICE_NAME
```

Check permissions:

```bash
sudo stat -c '%n -> owner=%U:%G uid:gid=%u:%g perms=%A %a' /path/to/check
```

Check whether a service can write to a mounted folder:

```bash
touch /mnt/external/test-permission && rm /mnt/external/test-permission
```

Check Docker socket:

```bash
sudo stat -c '%n -> owner=%U:%G uid:gid=%u:%g perms=%A %a' /var/run/docker.sock
```

Check Homarr Docker socket inside the container:

```bash
docker exec -it homarr id
docker exec -it homarr ls -l /var/run/docker.sock
```

Common issues:

| Problem                     | Likely Cause                           | Fix                                                |
| --------------------------- | -------------------------------------- | -------------------------------------------------- |
| `ERR_CONNECTION_REFUSED`    | Container exited or port not published | `docker compose ps`, `docker compose logs SERVICE` |
| `401 Unauthorized`          | Wrong API key or credentials           | Recreate API key in target app                     |
| Permission denied           | Wrong UID/GID or chmod                 | `chown 1000:1000`, `chmod 775`                     |
| Homarr cannot see Docker    | Docker socket group mismatch           | Check `getent group docker`, set `DOCKER_GID`      |
| Radarr/Sonarr cannot import | Path mismatch                          | Use identical `/data/...` paths in all apps        |
| Prowlarr indexer timeout    | Indexer/network problem                | Test indexer, use FlareSolverr if needed           |
| Jellyfin transcoding fails  | GPU permission or codec issue          | Check `/dev/dri`, Jellyfin logs                    |

---

## 24. Security Notes

Do not expose these services directly to the public internet unless you know what you are doing:

```text
qBittorrent
Radarr
Sonarr
Bazarr
Prowlarr
Homarr
DashDot
Speedtest Tracker
```

Safer access methods:

```text
LAN only
ZeroTier
VPN
Reverse proxy with HTTPS and authentication
```

DashDot runs privileged and can read host system information.

Homarr with Docker socket access can interact with Docker. Treat it as sensitive.

qBittorrent should always have a strong password.

Change default credentials after first login for any app that provides defaults.

---

## 25. Quick Command Reference

Start:

```bash
docker compose up -d
```

Stop:

```bash
docker compose down
```

Restart one service:

```bash
docker compose restart jellyfin
```

Logs:

```bash
docker compose logs -f jellyfin
```

Update:

```bash
docker compose pull
docker compose up -d
```

Status:

```bash
docker compose ps
```

Shell into container:

```bash
docker exec -it container_name bash
```

Check disk usage:

```bash
df -h
du -sh /home/cuong/Config/*
```

Check mounts:

```bash
lsblk
findmnt
```

Check recent system logs:

```bash
sudo dmesg -T | tail -n 100
```

---

## 26. Current Path Summary

Host paths:

```text
/home/cuong/Config/Jellyfin
/home/cuong/Config/qbittorrent
/home/cuong/Config/Radarr
/home/cuong/Config/Sonarr
/home/cuong/Config/Bazarr
/home/cuong/Config/prowlarr
/home/cuong/Config/speedtest-tracker
/home/cuong/Config/Homarr

/home/cuong/Data/Torrents
/mnt/external
/mnt/external2
```

Container paths:

```text
/config
/data/media_local
/data/media_ext1
/data/media_ext2
/appdata
```

Use container paths inside apps. Use host paths only in Docker Compose and Linux shell commands.
