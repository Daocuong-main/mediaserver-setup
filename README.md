# mediaserver-setup
My setup media server step to step

## Proxmox setup
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
### Create virtual machine
1. Go to Datacenter -> pve01 -> local(pve01) -> ISO images -> Upload ISO to upload ubuntu server ISO
![image](https://github.com/Daocuong-main/mediaserver-setup/assets/47266136/fa2d6237-ebbd-464e-9a24-bd7cad28f764)
2. Then create a virtual machine according to the instructions as shown in the [video](https://youtu.be/xBUnV2rQ7do)
3. After booting into ubuntu server, run apt update: `sudo apt update && sudo apt dist-upgrade`
4. Check current ip address: `ip addr show`
5. Edit 00-installer-config.yaml `sudo nano /etc/netplan/00-installer-config.yaml`
6. Edit:
```
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens18:
      dhcp4: true
  version: 2                                                                                                      
```
to this:
```
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens18:
      dhcp4: no
      addresses: [192.168.1.10/24]
      gateway4: 192.168.1.1
      nameservers:
            addresses: [123.23.23.23,123.26.26.26]
  version: 2
```
7. `sudo netplan apply`
### Install some stuff
1. Install Git
`sudo apt update` \
`sudo apt install git`
2. Insall [Docker engine](https://docs.docker.com/engine/install/ubuntu/)
### Make sure the device runs at maximum bandwidth
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
  bash sudo chgrp "usergroup" /etc/iptables/rules.v*
  ```
Enable writting permission to group 
  ```
  bash sudo chmod 664 /etc/iptables/rules.v*
  ```
Try again 
  ```
  bash sudo iptables-save > /etc/iptables/rules.v4
  ```
