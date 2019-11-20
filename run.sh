#!/bin/bash

set -ex

# Try to create /dev/kvm if it does not exist
if [ ! -e /dev/kvm ]; then
   mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')
fi

# Try to create /dev/net/tun if it does not exist
if [ ! -e /dev/net/tun ]; then
   mkdir -p /dev/net
   mknod /dev/net/tun c 10 200
fi

# Create default pridge for libvirt
# ip link add br0 type bridge
# ip link set dev br0 up
# ip addr add dev br0 192.168.66.02/24

# Set iptables rules so that all VMs can reach the outside world
# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# iptables -A FORWARD -i br0 -o eth0 -j ACCEPT

/usr/sbin/virtlogd &
/usr/sbin/libvirtd --listen &
wait
