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

