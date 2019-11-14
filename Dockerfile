FROM kubevirt/libvirt@sha256:840d4502f48f567f9030e22ba8aa8294003f1ac20b6a0c06c01b0236a8964a3a

COPY run.sh /usr/sbin/
COPY libvirtd.conf /etc/libvirt/
COPY qemu.conf /etc/libvirt/

RUN chmod +x /usr/sbin/run.sh

CMD run.sh
