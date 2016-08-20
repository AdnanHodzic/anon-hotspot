#!/bin/bash
#
# pi-hotspot: Tool which turns Raspberry Pi 3 into a WiFi Hotspot
#
# Copyleft: Adnan Hodzic <adnan@hodzic.org>
# License: GPLv3

root_check(){
if (( $EUID != 0 )); then
  echo -e "\nMust be run as root. Type in 'sudo $0' to run it as root.\n"
  exit 1
fi
}

# Wrong key error message
wrong_key(){
echo -e "\n-----------------------------"
echo -e "\nWrong value. Concentrate!\n"
echo -e "----------------------------\n"
echo -e "Enter any key to continue"
read key
}

configure_pkg(){
# package list update
echo -e "\nUpdating packge list\n"
apt-get update -y

# install needed packages
echo -e "\nInstalling deps: dnsmasq hostapd\n"
apt-get install dnsmasq hostapd
}

configure_interfaces(){

# configuring interfaces | static IP
# should be added to the bottom of page, not overwrite whole file

echo -e "\nSetting static wlan0 IP, backup location: /etc/dhcpcd.conf.org.bak\n"
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.org.bak
cat >> /etc/dhcpcd.conf << EOL

interface wlan0
    static ip_address=172.24.1.1/24
EOL

# configuring interfaces | disable wpa_supplicant interference
echo -e "\nDisabling wpa_supplicant interface, backup location: /etc/network/interfaces.org.bak\n"
cp /etc/network/interfaces /etc/network/interfaces.org.bak

# match, delete next line
sed -i '/iface wlan0 inet manual/{n;N;N;N;N;d}' /etc/network/interfaces
# match, append new line
sed -i '/\iface wlan0 inet manual/a #    wpa-conf \/etc\/wpa_supplicant\/wpa_supplicant.conf' /etc/network/interfaces

echo -e "\nrestarting dhcpd\n"
service dhcpcd restart
}

settings(){

set_ssid(){
read -p "Specify \"SSID\": " -i "Pi Wifi" -e pissid
}

set_passphrase(){
read -p "Specify \"WPA Passphrase\": " -i "71-P5Whr-ze" -e pipass
}
}

settings_show(){
echo -e "\n--------------------------------------------------\n"
echo -e "You've specified following values:"
echo -e "\n++++++++++++++++++++++++++++++++++++++++++++++++++\n"
echo -e "WiFi SSID: $pissid"
echo -e "WPA Passphrase: $pipass"
echo -e "\n++++++++++++++++++++++++++++++++++++++++++++++++++\n"
}

# Confirm Service Settings
settings_confirm(){

while [ settings_confrim != "Q" ]
do 
clear

settings_show
default=Y
read -p "Are these settings correct [Y/n]? " settings_confrim
settings_confrim=${settings_confrim:-$default}
	
	case $settings_confrim in 

	Y|y)
		echo "Moving to next step"
		break
	;;
	
	N|n)
		settings_show

		echo -e "What would you like to edit?\n"
		echo "[1] WiFi SSID"
		echo "[2] WPA Passphrase"
	
	read -p "Enter option number: " settings_edit

	for letter in "$settings_edit"; do

	if [[ "$letter" == [1] ]]; 
	then
		set_ssid
		settings_show

	elif [[ "$letter" == [2] ]]; 
	then
		set_passphrase
		settings_show

	else
		wrong_key

	fi
	done
	;;

	*) 
	wrong_key
	;;
	
	esac
done
}

configure_hostapd(){
echo -e "\nconfiguring hostapd\n"

hostapd_conf="/etc/hostapd/hostapd.conf"
hostapd_conf_bak="/etc/hostapd/hostapd.conf.org.bak"

if [ -f $hostapdf ];
then
	echo "Found existing $hostapd_conf"
	echo "Backup location: $hostapd_conf_bak"
	cp -f $hostapd_conf $hostapd_conf_bak
fi

cat > /etc/hostapd/hostapd.conf << EOL
# This is the name of the WiFi interface we configured above
interface=wlan0

# Use the nl80211 driver with the brcmfmac driver
driver=nl80211

# This is the name of the network
ssid=$pissid

# Use the 2.4GHz band
hw_mode=g

# Use channel 6
channel=6

# Enable 802.11n
ieee80211n=1

# Enable WMM
wmm_enabled=1

# Enable 40MHz channels with 20ns guard interval
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

# Accept all MAC addresses
macaddr_acl=0

# Use WPA authentication
auth_algs=1

# Require clients to know the network name
ignore_broadcast_ssid=0

# Use WPA2
wpa=2

# Use a pre-shared key
wpa_key_mgmt=WPA-PSK

# The network passphrase
wpa_passphrase=$pipass

# Use AES, instead of TKIP
rsn_pairwise=CCMP
EOL

hostapd_def_conf=/etc/default/hostapd
hostapd_def_conf_bak=/etc/default/hostapd.org.bak

if [ -f $hostapd_def_conf ];
then
	echo "Found existing $hostapd_def_conf"
	echo "Backup location: $hostapd_def_conf_bak"
	cp -f $hostapd_def_conf $hostapd_def_conf_bak
fi

# help hostapd find its config
sed -i "s/#DAEMON_CONF=\"\"/DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"/g" $hostapd_def_conf

# run hostpad + config (no need to run now?)
# /usr/sbin/hostapd /etc/hostapd/hostapd.conf

}

configure_dnsmasq(){
dnsmasq_conf=/etc/dnsmasq.conf
dnsmasq_conf_bak=/etc/dnsmasq.conf.org.bak

if [ -f $dnsmasq_conf ];
then
	echo "Found existing $dnsmasq_conf"
	echo "Backup location: $dnsmasq_conf_bak"
	cp -f $dnsmasq_conf $dnsmasq_conf_bak
fi

cat > $dnsmasq_conf << EOL
interface=wlan0      						# Use interface wlan0
listen-address=172.24.1.1 					# Explicitly specify the address to listen on
bind-interfaces      						# Bind to the interface to make sure we aren't sending things elsewhere
server=8.8.8.8       						# Forward DNS requests to Google DNS
domain-needed        						# Don't forward short names
bogus-priv           						# Never forward addresses in the non-routed address spaces
dhcp-range=172.24.1.50,172.24.1.150,12h 	# Assign IP addresses between 172.24.1.50 and 172.24.1.150 with a 12 hour lease time
EOL
}

configure_ivp4(){

sysctl_conf=/etc/sysctl.conf
sysctl_conf_bak=/etc/sysctl.conf.org.bak

if [ -f $sysctl_conf ];
then
	echo "Found existing $sysctl_conf"
	echo "Backup location: $sysctl_conf_bak"
	cp -f $sysctl_conf $sysctl_conf_bak
fi

# enable ipv4 packet forwarding
sudo sed -i "s/#net.ipv4.ip_forward/net.ipv4.ip_forward/g" $sysctl_conf
# immediately apply settings
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# NAT between wlan0 and eth0

ipv4nat_conf="/etc/iptables.ipv4.nat"
ipv4nat_conf_bak="/etc/iptables.ipv4.nat.org.bak"

if [ -f $ipv4nat_conf ];
then
	echo "Found existing $ipv4nat_conf"
	echo "Backup location: $ipv4nat_conf_bak"
	cp -f $ipv4nat_conf $ipv4nat_conf_bak
fi

cat > $ipv4nat_conf << EOL
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT  
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT 
EOL
}

dhcpd_config_update(){
# tell dhcpcd about this config
dhcpcd_nat=/lib/dhcpcd/dhcpcd-hooks/70-ipv4-nat
echo "iptables-restore < /etc/iptables.ipv4.nat" > $dhcpcd_nat
}

start_services(){
sudo service hostapd start
sudo service dnsmasq start
}

# function calls
root_check
configure_pkg
configure_interfaces
settings
settings_confirm
configure_hostapd
configure_ivp4
configure_dnsmasq
dhcpd_config_update
start_services
