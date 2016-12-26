#!/bin/bash
# ifconfig wlan1 down
# iwconifg wlan1 mode monitor
# ifconfig wlan1 up
# aibase-ng -e "freeway" -c 11 wlan1
clear
#> impostare bridge con regole di /etc/dhcpd/dhcpd.conf
#ifconfig at0 up
ifconfig at1 192.168.2.129 netmask 255.255.255.128
#ifconfig at0 mtu 1500
#> aggiungere il gw al routing
route add -net 192.168.2.128 netmask 255.255.255.128 gw 192.168.2.129
#> impostare iptables (reset)
iptables -F
iptables -t nat -F
iptables --delete-chain
iptables -t nat --delete-chain
#> nuove regole
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
# service isc-dhcp-server start
