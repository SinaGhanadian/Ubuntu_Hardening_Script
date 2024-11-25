#!/bin/bash

echo -e "\e[36m Configuring Mac address randomization \e[0m"

#Based on https://privsec.dev/posts/linux/networkmanager-trackability-reduction/#per-connection-overrides

sudo cat << EOF > /etc/NetworkManager/conf.d/random-mac-address.conf

[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random


EOF

sudo systemctl restart NetworkManager

#Static hostname
sudo hostnamectl hostname "localhost"


#Keystroke Anonymization
#https://github.com/vmonaco/kloak
wget https://www.whonix.org/patrick.asc

#Whonix Signing Key
sudo apt-key --keyring /etc/apt/trusted.gpg.d/whonix.gpg add ~/patrick.asc

#Whonix apt repository
echo "deb https://deb.whonix.org bullseye main contrib non-free" | sudo tee /etc/apt/sources.list.d/whonix.list

#Update package lists
sudo apt-get update

#Install Kloak
sudo apt-get install kloak

echo -e "\e[36m Configuring Flatpak \e[0m"

sudo apt install flatpak

#Securing flatpak

sudo flatpak override --system --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=input --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions
flatpak override --user --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=input --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions

flatpak --user override com.github.tchx84.Flatseal --filesystem=/var/lib/flatpak/app:ro --filesystem=xdg-data/flatpak/app:ro --filesystem=xdg-data/flatpak/overrides:create

echo -e "\e[36m Microcode package \e[0m"

if grep -q "GenuineIntel" /proc/cpuinfo; then
    sudo apt install intel-microcode
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    sudo apt install amd64-microcode
else
    echo "Microcode not installed"
fi

echo -e "\e[36m Configuring Secure Firewall Rules \e[0m"

#Installing ipset
sudo apt install ipset
#Creating ip_blocklist ipset
sudo ipset create ip_blocklist hash:ip

#Setting default policies
sudo iptables -P INPUT DROP
sudo iptables -p FORWARD DROP
sudo iptables -p OUTPUT DROP

#Allow loopback interface
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -O OUTPUT -o lo -j ACCEPT

#Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED, RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED, RELATED -j ACCEPT

#Allow DHCP requests
sudo iptables -A OUTPUT -p udp --dport 68 -j ACCEPT

#Allow outbound DNS
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

#Allow HTTPS
sudo iptables -A OUPUT -p tcp --dport 443 -j ACCEPT

#Allow HTTP
sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

#Allow NTP
sudo iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

#Install AppArmour

sudo apt install apparmor
sudo systemctl enable apparmor
sudo systemctl start apparmor

#Disabling unpriviliedged user namespaces

sudo sysctl -w kernel.unprivileged_userns_clone=0

echo -e "\e[36m Configuraing Dynamic Firewall \e[0m"

sudo cat << EOF > /etc/firewall_blocklist.sh

#!/bin/bash


# Download the blocklist
curl -s https://feodotracker.abuse.ch/downloads/ipblocklist.txt -o /etc/blocklist.txt
ipset flush blocklist
#Convert to ipset
while read ip; do
    ipset add blocklist $ip
done
#Block the ipset in iptables
if ! sudo iptables -C INPUT -m set --match-set blocklist src -j DROP 2>/dev/null; then
        sudo iptables -I INPUT -m set --match-set blocklist src -j DROP
        sudo iptables -I OUTPUT -m set --match-set blocklist src -j DROP
fi
EOF

echo -e "\e[31m Scheduling blocklist every 15 minutes \e[0m"

chmod +x /etc/firewall_blocklist.sh

sudo crontab -e "*/15 * * * * /etc/firewall_blocklist.sh"

echo -e "\e[31m Adding applications \e[0m"
sudo apt install clamav clamav-daemon lynis rkhunter usbguard usbutils udisks2 firejail -y

sudo freshclam -d

sudo crontab -e "5 * * * * /usr/local/bin/freshclam")

#Configuring firejail

sudo firejail firefox

#Automatic Updates

echo -e "\e[31m Enabling Automatic Updates \e[0m"

sudo apt install unattended-upgrades -y

sudo dpkg-reconfigure --priority=low unattended-upgrades


echo -e "\e[31m Automatic updates configured to once per day \e[0m"


