
# mediaserver-setup
My setup media server step to step

## Proxmox setup (Optinal)
1. Download [Proxmox VE ISO](https://www.proxmox.com/en/downloads)
2. Boot ISO to USB using [Rufus](https://rufus.ie/en/) 
3. Plug USB to machine and turn on it.
4. While turning on go to BOOT menu
5. Select boot from USB
6. Install proxmox following the instructions on the screen if still don't know how to do it, follow the instructions of this [video](https://youtu.be/u8E3-Zy9NvI)
7. After the installation is complete, follow the commands below for the initial setup.
8. Login command line as root user on Proxmox machine
9. Keep the laptop always on when the screen is closed: \
`sudo nano /etc/systemd/logind.conf`\
modify the line\
`#HandleLidSwitch=suspend`\
to\
`HandleLidSwitch=ignore`\
Additionally, ensure that the file also has this line:\
`LidSwitchIgnoreInhibited=no`\
Then restart the OS via:\
`sudo service systemd-logind restart`
## Ubuntu server setup
### Create virtual machine (Optinal)
1. Go to Datacenter -> pve01 -> local(pve01) -> ISO images -> Upload ISO to upload ubuntu server ISO
![image](https://github.com/Daocuong-main/mediaserver-setup/assets/47266136/fa2d6237-ebbd-464e-9a24-bd7cad28f764)
2. Then create a virtual machine according to the instructions as shown in the [video](https://youtu.be/xBUnV2rQ7do)
3. After booting into ubuntu server, run apt update: `sudo apt update && sudo apt dist-upgrade`
4. Check current ip address: `ip addr show`
5. Edit `sudo nano /etc/netplan/50-cloud-init.yaml`
6. Edit:
```
# This is the network config
network:
    version: 2
    ethernets:
        enp0s25:
            addresses:
                - 192.168.1.100/24
            routes:
                - to: default
                  via: 192.168.1.1
            nameservers:
                addresses:
                    - 1.1.1.1
                    - 1.0.0.1
                search: []
```
7. `sudo netplan apply`
## Install some stuff
1. Install Git
`sudo apt update` \
`sudo apt install git`
2. Insall [Docker engine](https://docs.docker.com/engine/install/ubuntu/)
## Configure qBittorrent

- Open qBitTorrent at http://localhost:8080.
- Default username is `admin`.
- Temporary password can be collected from container log `docker logs qbittorrent`
1. **Get the Container ID**:
   ```bash
   sudo docker ps
   ```
   Look for the `qbittorrent` container and note its Container ID.

2. **Check the Logs**:
   ```bash
   sudo docker logs <container_id>
   ```
   Replace `<container_id>` with the actual Container ID of your `qbittorrent` container. Look for a line in the logs that mentions a temporary password.
- Go to Tools --> Options --> WebUI --> Change password
- Run below commands on the server

```bash
sudo docker exec -it qbittorrent bash # Get inside qBittorrent container

# Above command will get you inside qBittorrent interactive terminal, Run below command in qbt terminal
mkdir /downloads/movies /downloads/tvshows
chown 1000:1000 /downloads/movies /downloads/tvshows
exit
```

## Configure Radarr

- Open Radarr at http://localhost:7878
- Settings --> Media Management --> Check mark "Movies deleted from disk are automatically unmonitored in Radarr" under File management section --> Save
- Settings --> Media Management --> Scroll to bottom --> Add Root Folder --> Browse to /downloads/movies --> OK
- Settings --> Download clients --> qBittorrent --> Add Host (qbittorrent) and port (5080) --> Username and password --> Test --> Save
- Settings --> General --> Enable advance setting --> Select Authentication and add username and password
- Indexer will get automatically added during configuration of Prowlarr. See 'Configure Prowlarr' section.

Sonarr can also be configured in similar way.

**Add a movie** (After Prowlarr is configured)

- Movies --> Search for a movie --> Add Root folder (/downloads/movies) --> Quality profile --> Add movie
- All queued movies download can be checked here, Activities --> Queue 
- Go to qBittorrent (http://localhost:8080) and see if movie is getting downloaded (After movie is queued. This depends on availability of movie in indexers configured in Prowlarr.)

## Configure Jellyfin

- Open Jellyfin at http://localhost:8096
- When you access the jellyfin for first time using browser, A guided configuration will guide you to configure jellyfin. Just follow the guide.
- Add media library folder and choose /data/movies/

## Make sure the device runs at maximum bandwidth
To perform an iperf test between a Linux machine (client) and a Windows machine (server), you'll need to follow these steps:

1. Set up the server-side (Windows machine):
   - Download the iperf utility for Windows from the official website: https://iperf.fr/iperf-download.php#windows
   - Extract the downloaded file to a directory on your Windows machine.
   - Open a command prompt window with administrator privileges.
   - Navigate to the directory where you extracted iperf.
   - Run the following command to start iperf in server mode:
     ```
     iperf3.exe -s
     ```

2. Set up the client-side (Linux machine):
   - Open a terminal on your Linux machine.
   - Install iperf using the appropriate package manager for your Linux distribution. For example, on Debian or Ubuntu, you can use the following command:
     ```
     sudo apt-get install iperf3
     ```
   - Once installed, run the following command to test the network speed to the Windows server:
     ```
     iperf3 -c <server-ip>
     ```
     Replace `<server-ip>` with the IP address or hostname of your Windows machine.

   - Wait for the test to complete. It will provide you with the network speed results.

It's worth noting that Windows machines may have built-in firewall settings that could block iperf traffic. Therefore, ensure that the Windows firewall allows iperf traffic or temporarily disable the firewall during the test. Additionally, keep in mind that the network speed you measure with iperf may depend on various factors, including network congestion, hardware limitations, and other network traffic on your local network.
### Otherwise run the following command
```
sudo apt-get install ethtool
sudo ethtool -s eth0 speed 1000 duplex full
sudo ethtool eth0
```
eth0 is the ethernet interface of the current machine using `ip addr show` to know.

## Zerotier setup
1. Create an account, install everything according to the instructions [here](https://docs.zerotier.com/getting-started/getting-started).
2. [Route between ZeroTier and Physical Networks](https://zerotier.atlassian.net/wiki/spaces/SD/pages/224395274/Route+between+ZeroTier+and+Physical+Networks)
3. Change group to user on rules.v4 
  ```
  sudo chgrp "usergroup" /etc/iptables/rules.v*
  ```
Enable writting permission to group 
  ```
  sudo chmod 664 /etc/iptables/rules.v*
  ```
Try again 
  ```
  sudo iptables-save > /etc/iptables/rules.v4
  ```
speedtest: ```curl -Lso- vietpn.co | bash```

## Unmount and clone disk
Before clone, turn off docker compose:

```sudo docker compose down```

Here are the steps to clone `sdb` to `sdc` and then eject `sdb`:

1. **Unmount the drives** (if they are mounted):
    ```bash
    sudo umount /mnt/external
    ```

2. **Clone `sdb` to `sdc`** using `dd`:
    ```bash
    sudo dd if=/dev/sdb of=/dev/sdc bs=64K conv=noerror,sync status=progress
    ```

    - `if=/dev/sdb`: Input file (source drive)
    - `of=/dev/sdc`: Output file (destination drive)
    - `bs=64K`: Block size (you can adjust this if needed)
    - `conv=noerror,sync`: Continue on read errors, pad blocks with zeros
    - `status=progress`: Show progress during the operation

3. **Eject `sdb`**:
    ```bash
    sudo eject /dev/sdb
    ```

Make sure to double-check the device names (`sdb` and `sdc`) before running these commands to avoid data loss. If you have any questions or need further assistance, feel free to ask!
