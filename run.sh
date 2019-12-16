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

#################################
# Networks
#################################
# Provisioning
# We create the network on a file basis to not
# have to wait for libvirtd to come up
mkdir -p /etc/libvirt/qemu/networks/autostart
cat > /etc/libvirt/qemu/networks/provisioning.xml <<EOX
<!-- Generated by run.sh container script -->
<network>
  <name>provisioning</name>
  <forward mode="bridge"/>
  <bridge name="provisioning"/>
</network>
EOX
ln -s /etc/libvirt/qemu/networks/provisioning.xml /etc/libvirt/qemu/networks/autostart/provisioning.xml
cat > /etc/libvirt/qemu/networks/baremetal.xml <<EOX
<!-- Generated by run.sh container script -->
<network>
  <name>baremetal</name>
  <forward mode="bridge"/>
  <bridge name="baremetal"/>
</network>
EOX
ln -s /etc/libvirt/qemu/networks/baremetal.xml /etc/libvirt/qemu/networks/autostart/baremetal.xml

cat > /etc/sysconfig/network-scripts/ifcfg-provisioning <<EOX
NAME=provisioning
DEVICE=provisioning
TYPE=Bridge
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
EOX


cat > /etc/sysconfig/network-scripts/ifcfg-baremetal <<EOX
NAME=baremetal
DEVICE=baremetal
TYPE=Bridge
ONBOOT=yes
NM_CONTROLLED=no
EOX

#################################
# Storage
#################################
mkdir -p /etc/libvirt/storage/autostart
cat > /etc/libvirt/storage/default.xml <<EOX
<pool type='dir'>
  <name>default</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOX
ln -s /etc/libvirt/storage/default.xml /etc/libvirt/storage/autostart/default.xml

#################################
# Start
#################################
/usr/sbin/virtlogd &
/usr/sbin/libvirtd --listen &
wait
