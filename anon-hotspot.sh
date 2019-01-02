#!/bin/bash
#
# anon-hotspot: On demand Debian Linux (Tor) Hotspot setup tool
#
# Blog post: http://foolcontrol.org/?p=1853
#
# Copyleft: Adnan Hodzic <adnan@hodzic.org>
# License: GPLv3

root_check(){
if (( $EUID != 0 )); then
  echo -e "\nMust be run as root. Type in 'sudo $0' to run it as root.\n"
  exit 1
fi
}

separator(){
sep="\n-------------------------------------------------------------------"
echo -e $sep
}

# about message
about(){
echo -e "\n----------- anon-hotspot: Debian Linux (Tor) Hotspot ---------------\n"
echo -e "Tool usage, i.e:"
echo -e "anon-hotspot tor-hotspot"
echo -e "\n----"
}

options(){
echo -e "\navailable options"
echo -e "\nconfiguration:"
echo -e "- tor-hotspot (configure Tor WiFi hotspot)"
echo -e "- hotspot (configure WiFi hotspot)"
echo -e "- tor (configure Tor for existing Wifi hotspot)"
echo -e "- cred (change Tor/WiFi Hotspot ssid/passphrase)"
echo -e "- remove (remove Tor/Wifi Hotspot & revert to original settings)"

echo -e "\noperations:"
echo -e "- start (start Tor/WiFi hotspot)"
echo -e "- stop (stop Tor/WiFi hotspot)"
separator
}

# validator (debugger)
validator(){
ack=${ack:-$default}
default=Y

read -p "all good, continue? [Y/n] " ack
ack=${ack:-$default}

for letter in "$ack"; do
	if [[ "$letter" == [Yy] ]];
		then
		    echo -e "echo moving on ...\n"
	elif [[ "$letter" == [Nn] ]];
	then
		echo -e "\nAborted, bye!"
		exit 1
	else
		wrong_key
		validator
	fi
done
}

# Wrong key error message
wrong_key(){
echo -e "\n-----------------------------"
echo -e "\nWrong value. Concentrate!\n"
echo -e "-----------------------------\n"
echo -e "Enter any key to continue"
read key
}

configure_pkg(){
separator

# package list update
echo -e "\nUpdating packge list\n"
apt-get update -y

# install needed packages
echo -e "\nInstalling deps: dnsmasq hostapd\n"
apt-get -y install dnsmasq hostapd
}

configure_interfaces(){
separator

# configuring interfaces | static IP
# should be added to the bottom of page, not overwrite whole file

echo -e "\nSetting static wlan0 IP, backup location: /etc/dhcpcd.conf.org.bak"
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.org.bak
cat >> /etc/dhcpcd.conf << EOL

denyinterfaces wlan0
EOL

# configuring interfaces | disable wpa_supplicant interference
echo -e "\nGenerating new interface file, backup location: /etc/network/interfaces.org.bak"
cp /etc/network/interfaces /etc/network/interfaces.org.bak

cat > /etc/network/interfaces << EOL
# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet static
    address 172.24.1.1
    netmask 255.255.255.0
    network 172.24.1.0
    broadcast 172.24.1.255
#    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

#allow-hotplug wlan1
#iface wlan1 inet manual
#    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOL
}

settings(){
separator

set_ssid(){
echo ""
read -p "Specify \"SSID\": " -i "Anon Hotspot" -e pissid
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

set_ssid
set_passphrase

while [ settings_confrim != "Q" ]
do 
clear

settings_show
default=Y
read -p "Are these settings correct [Y/n]? " settings_confrim
settings_confrim=${settings_confrim:-$default}
	case $settings_confrim in 
	Y|y)
		break
	;;	N|n)
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
				settings_confirm
			fi
	done
	;;
	*) 
		wrong_key
		settings_confirm
	;;
	esac
done
}

# ToDo
# configure static ip
# alter /etc/network/interfaces
# restart dhcpcd

configure_hostapd(){
separator
echo -e "\nConfiguring WiFi Hotspot\n"

hostapd_conf="/etc/hostapd/hostapd.conf"
hostapd_conf_bak="/etc/hostapd/hostapd.conf.org.bak"

if [ -f $hostapd_conf ];
then
	echo "Found existing: $hostapd_conf"
	echo "Backup location: $hostapd_conf_bak"
	cp -f $hostapd_conf $hostapd_conf_bak
	echo ""
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
	echo ""
fi

# help hostapd find its config
sed -i "s/#DAEMON_OPTS=\"\"/DAEMON_OPTS=\"\/etc\/hostapd\/hostapd.conf\"/g" /etc/default/hostapd

# run hostpad + config (no need to run now?)
# /usr/sbin/hostapd /etc/hostapd/hostapd.conf
}

configure_dnsmasq(){
separator
echo -e "\nConfiguring DNS forwarder and DHCP server\n"

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

configure_ipv4(){
separator

echo -e "\nsetting up ipv4 forwarding\n"

sysctl_conf=/etc/sysctl.conf
sysctl_conf_bak=/etc/sysctl.conf.org.bak

if [ -f $sysctl_conf ];
then
	echo "Found existing: $sysctl_conf"
	echo "Backup location: $sysctl_conf_bak"
	cp -f $sysctl_conf $sysctl_conf_bak
	echo ""
fi

# enable ipv4 packet forwarding
sed -i "s/#net.ipv4.ip_forward/net.ipv4.ip_forward/g" $sysctl_conf
# immediately apply settings
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# NAT between wlan0 and eth0

ipv4nat_conf="/etc/iptables.ipv4.nat"
ipv4nat_conf_bak="/etc/iptables.ipv4.nat.org.bak"

if [ -f $ipv4nat_conf ];
then
	echo "Found existing: $ipv4nat_conf"
	echo "Backup location: $ipv4nat_conf_bak"
	cp -f $ipv4nat_conf $ipv4nat_conf_bak
fi

eval "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
eval "iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"
eval "iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT"

# save rules
sh -c "iptables-save > /etc/iptables.ipv4.nat"

# apply rules on boot
sed -i 's/^exit 0/iptables-restore < \/etc\/iptables.ipv4.nat\n  \n&/' /etc/rc.local
}

dhcpd_config_update(){
# tell dhcpcd about this config
dhcpcd_nat=/lib/dhcpcd/dhcpcd-hooks/70-ipv4-nat
echo "iptables-restore < /etc/iptables.ipv4.nat" > $dhcpcd_nat
}

tor_pkg(){
# pkg install
separator

echo -e "\nUpdating packge list\n"
apt-get update -y
echo -e "\nInstalling Tor\n"
apt-get -y install tor
}

tor_conf(){
# tor config
separator
echo -e "\nConfiguring Tor settings: /etc/tor/torrc"

cat >> /etc/tor/torrc << EOL
Log notice file /var/log/tor/notices.log
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress 172.24.1.1
DNSPort 53
DNSListenAddress 172.24.1.1
EOL
}

tor_net(){
# route wlan0 traffic through tor
separator
echo -e "\nRouting wlan0 traffic through tor"

# flush everything
eval "iptables -F"
eval "iptables -t nat -F"
# hotspot
eval "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
eval "iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"
eval "iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT"
# thru tor
eval "iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 22 -j REDIRECT --to-ports 22"
eval "iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53"
eval "iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040"
# verify
#eval "iptables -t nat -L"
}

tor_log(){
# setup logging
separator
echo -e "\nSetting up logging: /var/log/tor"

touch /var/log/tor/notices.log
chown debian-tor /var/log/tor/notices.log
chown debian-tor /var/log/tor/notices.log
}

tor_boot(){
separator
echo -e "\nStart at boot, still not done"

# start at boot
#sh -c "iptables-save > /etc/iptables.ipv4.nat"
#systemctl enable tor.service
}

tor_start(){
# start tor
separator

echo -e "\nStarting Tor"
service tor stop
service tor start
echo -e "\nTor successfully configured and started"
}

restart_services(){
separator

echo -e "\nRestarting dhcpd"
service dhcpcd restart

echo -e "\nreloading wlan0 configuration"
ifdown wlan0; ifup wlan0

echo -e "\nRestarting dnsmasq"
/etc/init.d/dnsmasq restart
}

start_hotspot(){
separator
echo -e "\nStarting Wifi Hotspot\n"

service hostapd start
service dnsmasq start
hostapd /etc/hostapd/hostapd.conf &
echo -e "[ctrl + c] to move process to background\n"
}

start_hotspot_question(){
separator

ack=${ack:-$default}
default=Y

echo ""
read -p "Start WiFi Hotspot? [Y/n] " ack
ack=${ack:-$default}

for letter in "$ack"; do
	if [[ "$letter" == [Yy] ]];
		then
			#tor_config
			start_hotspot
	elif [[ "$letter" == [Nn] ]];
	then
	echo -e "\nDidn't start Wifi Hotspot"
		exit 0
	else
		wrong_key
		start_hotspot_question
	fi
done
}

stop_hotspot(){
separator
echo -e "\nStopping Wifi Hotspot\n"
service tor stop
service hostapd stop
service dnsmasq stop
pkill hostapd
}

revert_all(){
revert_interfaces(){
echo -e "\nReverting interfaces\n"
echo "/etc/network/interfaces to /etc/network/interfaces.org.bak"
mv /etc/network/interfaces.org.bak /etc/network/interfaces
}

revert_dhcpcd(){
echo -e "\nReverting dhcpcd\n" 
echo "/etc/dhcpcd.conf to /etc/dhcpcd.conf.org.bak "
mv /etc/dhcpcd.conf.org.bak /etc/dhcpcd.conf
echo "/etc/default/hostapd to /etc/default/hostapd.org.bak"
}

revert_hostapd(){
echo -e "\nReverting hostapd\n"
echo "/etc/hostapd/hostapd.conf to /etc/hostapd/hostapd.conf.org.bak"
mv /etc/hostapd/hostapd.conf.org.bak /etc/hostapd/hostapd.conf
}

revert_dnsmasq(){
echo -e "\nReverting dnsmasq\n"
echo "/etc/dnsmasq.conf to /etc/dnsmasq.conf.org.bak"
mv /etc/dnsmasq.conf.org.bak /etc/dnsmasq.conf
}

revert_ipv4(){
echo -e "\nReverting ipv4\n"
echo "/etc/sysctl.conf to sysctl.conf.org.bak"
mv /etc/sysctl.conf.org.bak /etc/sysctl.conf
echo "/etc/iptables.ipv4.nat to /etc/iptables.ipv4.nat.org.bak"
mv /etc/iptables.ipv4.nat.org.bak /etc/iptables.ipv4.nat
echo "deactivating immediate ip_forward"
sh -c "echo 0 > /proc/sys/net/ipv4/ip_forward"
}

revert_tor(){
# should make backup of /etc/tor/torrc and restor it
# temp solution:
echo -e "\nRemoving Tor config: /etc/tor/torrc"
rm /etc/tor/torrc
}

flush_iptables(){
echo -e "\nFlushing all iptables tables\n"
eval "iptables -F"
eval "iptables -t nat -F"
sh -c "iptables-save > /etc/iptables.ipv4.nat"
}

service_restart_stop(){
# restart services with original settings and stop all

echo -e "\nRestarting dhcpd"
service dhcpcd restart

echo -e "\nreloading wlan0 configuration"
ifdown wlan0; ifup wlan0

echo -e "\nRestarting dnsmasq"
/etc/init.d/dnsmasq restart

echo -e "\nStopping Tor"
service tor stop

echo -e "\nStopping dhcpd"
service dhcpcd stop

echo -e "\nStopping dnsmasq"
/etc/init.d/dnsmasq restart
}

remove_pkg(){
echo -e "\nRemoving dnsmasq, hostapd, tor packages\n"
sudo apt-get purge -y dnsmasq hostapd tor
sudo apt-get autoremove -y
}

revert_interfaces
#validator
revert_dhcpcd
#validator
revert_hostapd
#validator
revert_dnsmasq
#validator
revert_ipv4
#validator
revert_tor
#validator
flush_iptables
#validator
service_restart_stop
#validator
remove_pkg
#validator

echo -e "\nSuccessfully removed Tor/Wifi Hotspot & reverted to original settings\n"

}
# param/option check
if [ -z "$1" ];
then
	root_check
	about
	options
	exit 1
elif [[ $1 == "hotspot" || $1 =~ "config" ]];
then
	echo -e "\nConfiguring WiFi Hotspot"
	root_check
	configure_pkg
	configure_interfaces
	settings
	settings_confirm
	configure_hostapd
	configure_dnsmasq
	configure_ipv4
	#dhcpd_config_update
	restart_services
	#start_hotspot
	start_hotspot_question
	#exit 1
elif [[ $1 == "tor-hotspot" || $1 =~ "torhotspot" ]];
then
	echo -e "\nConfiguring Tor WiFi Hotspot"
	root_check
	# hotspot
	configure_pkg
	configure_interfaces
	settings
	settings_confirm
	configure_hostapd
	configure_dnsmasq
	#configure_ipv4
	#dhcpd_config_update
	#restart_services
	# tor
	tor_pkg
	tor_conf
	tor_net
	tor_log
	tor_boot
	restart_services
	tor_start
	start_hotspot_question
	#start_hotspot
	#exit 1
elif [[ $1 =~ "tor" ]];
then
	echo -e "\nConfiguring Tor for existing Wifi hotspot"
	tor_pkg
	tor_conf
	tor_net
	tor_log
	tor_boot
	tor_start
	start_hotspot_question
	#exit 1
elif [[ $1 =~ "cred" ]];
then
	echo -e "\nChanging Tor/WiFi Hotspot ssid/passphrase"
	settings
	settings_confirm
	configure_hostapd
	configure_dnsmasq
	restart_services
	start_hotspot_question
elif [[ $1 =~ "remove" || $1 =~ "uninstall" ]];
then
	echo -e "\nRemoving Tor/Wifi Hotspot & revert to original settings"
	revert_all
elif [[ $1 =~ "start" ]];
then
	start_hotspot
	#exit 1
elif [[ $1 =~ "stop" ]];
then
	stop_hotspot
	#exit 1
else
	separator
	echo "Wrong/Unknown option ..."
	options
	exit 1
fi
