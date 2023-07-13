
# mediaserver-setup
My setup media server step to step

# Proxmox setup
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
