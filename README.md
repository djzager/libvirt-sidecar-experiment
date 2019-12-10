```
sudo podman build . -t libvirt
sudo podman run \
  --rm -it \
  --user root \
  --net host \
  --privileged \
  -v /etc/sysconfig/network-scripts:/etc/sysconfig/network-scripts \
  -v ${DEV_SCRIPTS}/cache:/output \
  libvirt
```

# Libvirt Sidecar Experiment

The purpose of this project is to demonstrate our ability to perform a baremetal
cluster install from a running cluster using `libvirt` as a sidecar to an
installer container.

## Pre-Requisites

1. A sufficiently large VM host (cpu/mem/disk). System used in this test had 8
   cores, 125G memory, and space allocations of 50G (root partition), 100G
   (/var/lib/libvirt/images, 100G (/opt).
1. Pull-secrets to access registry.svc.ci.openshift.org.
1. podman installed
1. [dev-scripts](https://github.com/openshift-metal3/dev-scripts) cloned.
1. [crc](https://github.com/code-ready/crc) installed

## Setup

1. Ran `cd dev-scripts` to move into the cloned copy of that repo.
2. Ran `cp config_example.sh config_<user>.sh` with the following overrides:
    ```
    # Pull secret must include auth to access registry.svc.ci.openshift.org
    export PULL_SECRET=$(cat ./pull-secret.json)
    # Nightlies are regularly cleaned up, when changing this value, use the
    # latest "Accepted" 4.3.0-0.nightly from https://openshift-release.svc.ci.openshift.org/
    export OPENSHIFT_RELEASE_IMAGE="registry.svc.ci.openshift.org/ocp/release:4.3.0-0.nightly-2019-12-06-094536"
    ```
3. Ran `make clean`
4. Ran `./01_install_requirements.sh`. This ensures all of the needed
   dependencies for dev-scripts are installed on the system.
5. Ran `./02_configure_host.sh`. This creates the 3 master VMs, configures `provisioning`
   and `baremetal` networks, and configures vbmc with the IPMI services for the
   VMs using addresses on the `baremetal` network.
6. Ran `./03_build_installer.sh`. This extracts a copy of the installer from the
   `OPENSHIFT_RELEASE_IMAGE` that is used to populate `ocp/`.
7. Ran `./04_start_ironic.sh`. This launches copies of the Ironic provisioning tools on the host using podman.
8. Populate `ocp/`:
    1. Modify `./ocp_install_env.sh` to add `libvirtURI: qemu+tcp://127.0.0.1/system` to the baremetal section of the install-config.yml produced by the script.
    1. Modify `./utils.sh` to comment out the line that runs `create cluster` and exit at that point.
    1. Start the libvirt container with `sudo podman run --rm -it --user root --net host --privileged -v /etc/sysconfig/network-scripts:/etc/sysconfig/network-scripts -v $PWD/cache:/output docker.io/djzager/libvirt`
    2. Ran `./06_create_cluster.sh` that has been modified to create the manifests and exit.
9. Configure the CodeReadyContainers (CRC) VM.
    1. Run `crc start --cpus 8 --memory 32768`. Make sure that you use the same pull-secret you are using with dev-scripts so that the CRC VM can pull the appropriate images.
    2. Modify the `crc` domain to include interfaces on the `baremetal` and
       `provisioning` networks -- `sudo virsh edit crc`:
      ```xml
            <domain type='kvm'>
              <name>crc</name>
            ...
              <devices>
                <interface type='bridge'>
                  <mac address='00:c3:8e:65:8a:de'/>
                  <source bridge='provisioning'/>
                  <model type='virtio'/>
                  <address type='pci' domain='0x0000' bus='0x01' slot='0x08' function='0x0'/>
                </interface>
                <interface type='bridge'>
                  <mac address='00:c3:8e:65:8a:e8'/>
                  <source bridge='baremetal'/>
                  <model type='virtio'/>
                  <address type='pci' domain='0x0000' bus='0x02' slot='0x09' function='0x0'/>
                </interface>
              </devices>
            </domain>
      ```
    3. Modify the `baremetal` network definition to include an IP for the CRC VM -- `sudo virsh net-edit baremetal`:
      ```xml
            <network>
              <name>baremetal</name>
            ...
              <ip address='192.168.111.1' netmask='255.255.255.0'>
                <dhcp>
                  <range start='192.168.111.20' end='192.168.111.60'/>
                  <host mac='00:c3:8e:65:8a:df' name='master-0' ip='192.168.111.20'/>
                  <host mac='00:c3:8e:65:8a:e3' name='master-1' ip='192.168.111.21'/>
                  <host mac='00:c3:8e:65:8a:e7' name='master-2' ip='192.168.111.22'/>
                  <host mac='00:c3:8e:65:8a:e8' name='crc' ip='192.168.111.50'/>
                </dhcp>
              </ip>
            </network>
      ```
    4. Restart the `baremetal` network: `sudo virsh net-destroy baremetal && sudo virsh net-start baremetal`
    5. Restart the CRC VM: `crc stop && crc start`
    6. SSH into the CRC VM `ssh -i ~/.crc/machines/crc/id_rsa core@192.168.130.11`
    7. Disable selinux with `sudo setenforce 0` and `sudo sed -i "s/=enforcing/=permissive/g" /etc/selinux/config`
    8. There aren't any useful networking tools installed on the VM and installing them is painful so I just ran a privileged container, the libvirt container works because it has some basic tools installed `sudo podman run --entrypoint /bin/bash --rm -it --net host --privileged docker.io/djzager/libvirt`
    9. Add two bridges `provisioning` and `baremetal` with `brctl addbr <bridgeName>`
    10. Add the appropriate interfaces `ens8 -> provisioning` and `enp2s9 -> baremetal` with `brctl addif <bridge> <device>`
    11. Bring the `provisioning` and `baremetal` interfaces up with `ip link set <device> up`. Need to make sure that there is only one default route (`ip route show`). If needed, `ip route del default via 192.168.111.1`.
    12. Check our work
      ```
            # brctl show
            bridge name     bridge id               STP enabled     interfaces
            baremetal               8000.00c38e658ae8       no              enp2s9
            cni0            8000.3af966ca4dad       no              veth9049b993
            provisioning            8000.00c38e658ade       no              ens8
 
            # ip addr show provisioning
            59: provisioning: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
                link/ether 00:c3:8e:65:8a:de brd ff:ff:ff:ff:ff:ff
                inet6 fe80::2c3:8eff:fe65:8ade/64 scope link
                   valid_lft forever preferred_lft forever
            # ip addr show baremetal
            60: baremetal: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
                link/ether 00:c3:8e:65:8a:e8 brd ff:ff:ff:ff:ff:ff
                inet6 fe80::2c3:8eff:fe65:8ae8/64 scope link
                   valid_lft forever preferred_lft forever
      ```

## Execution
1. Create the `ConfigMap`s to be used with the installer `Pod`
    ```
    oc create configmap manifests --from-file ocp/manifests && \
    oc create configmap openshift --from-file ocp/openshift && \
    oc create configmap deploy --from-file ocp/deploy && \
    oc create configmap ocp --from-file ocp/install-config.yaml --from-file ocp/install-config.yaml.tmp --from-file ocp/master_nodes.json
    ```
1. Create the [Pod](pod.yaml) -- `oc create -f pod.yaml`
