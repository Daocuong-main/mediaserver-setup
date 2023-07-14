

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
`nano /etc/systemd/logind.conf`\
modify the line\
`#HandleLidSwitch=suspend`\
to\
`HandleLidSwitch=ignore`\
Additionally, ensure that the file also has this line:\
`LidSwitchIgnoreInhibited=no`\
Then restart the OS via:\
`sudo service systemd-logind restart`
## Create virtual machine
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
