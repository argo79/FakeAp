#!/bin/bash
dnsmasq -C /etc/dnsmasq.conf -d
sysctl -w net.ipv4.ip_forward=1
iptables -P FORWARD ACCEPT
iptables --table nat -A POSTROUTING -o wlan1 -j MASQUERADE
