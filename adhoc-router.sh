#!/usr/bin/env bash

# This sets up a switch over eth0 and eth1
# and routes between these and wlan0 (internet)
# and provides a DHCP and TFTP to eth0/1
#
#
# check traffic:
#   $ watch -n1 -d ip -s link show eth1
#
# darkstar:
#   eth1  onboard
#   eth0  pci card
#
#


#set -e
set -x


IP="192.168.11.1" 
MASK="255.255.255.0"
ETH="br0"
WAN="wlan0"


# Bridge over NICs (Switch mode)
ifconfig ${ETH} down
ifconfig eth0 0.0.0.0 down
ifconfig eth1 0.0.0.0 down
brctl delbr ${ETH}
brctl addbr ${ETH}
brctl addif ${ETH} eth0 eth1
ifconfig eth0 up
ifconfig eth1 up
ifconfig ${ETH} ${IP} netmask ${MASK} up
sleep 5s


# Warn: Opens everything! TODO
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -F INPUT
iptables -F OUTPUT
iptables -F FORWARD
iptables -A INPUT   -j ACCEPT
iptables -A OUTPUT  -j ACCEPT
iptables -A FORWARD -j ACCEPT
iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE


# DNSmasq implements DHCP and TFTP server,
# provides to all systems connected to both NICs over the bridge
touch /tmp/dnsmasq-eth0.lease
pkill -f /tmp/dnsmasq-eth0.pid
/usr/sbin/dnsmasq \
	--pid-file=/tmp/dnsmasq-eth0.pid \
	--interface=${ETH} \
	--listen-address=${IP} \
	--dhcp-leasefile=/tmp/dnsmasq-eth0.lease \
	--dhcp-range=192.168.11.2,192.168.11.254,255.255.255.0,192.168.11.254 \
	--dhcp-option=3,${IP} \
	--dhcp-option=1,255.255.255.0 \
	--dhcp-option=28,192.168.11.255 \
	--enable-tftp \
	--tftp-root=/tftpboot
	