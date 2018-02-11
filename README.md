# Vagrant Matchbox environment

A vagrant [coreos/matchbox](github.com/coreos/matchbox) client/server environment.
Forked from http://github.com/eoli3n/vagrant-pxe.
Supports virtualbox and libvirt providers.  

## Setup

1. install Vagrant / Qemu / Libvirt / Virtualbox
  ( `brew cask install virtualbox` for macs )
2. if using **virtualbox**, install the __VirtualBox Extension Pack__ for PXE support
  ( `brew cask install virtualbox-extension-pack` for macs )
3. if using **libvirt**, install the [vagrant-libvirt provider](https://github.com/vagrant-libvirt/vagrant-libvirt)
4. `git clone http://github.com/stealthybox/vagrant-matchbox`

## Boot the Matchbox server vm
* **System Box** => debian/jessie64
* **Default CPU** => 1
* **Default RAM** => 1024
* **Networking**
 * **eth0** => Management network
 * **eth1** => Private network "pxe_network"

```
cd vagrant-matchbox/server
vagrant up  # you can use the --provider flag to select virtualbox or libvirt
vagrant ssh
```
[config/setup.sh](./server/config/setup.sh) will:
- start the vm
- install `docker-ce` / `terraform` / `terraform-matchbox-provider`
- clone the coreos/matchbox repo
- generate and configure matchbox gRPC certs
- daemonize the `matchbox` container and coreOS `dnsmasq/dhcp/tftp` container
- configure `matchbox/examples/terraform/simple-install` from the matchbox repo to use local assets
- fetch a coreOS image into the matchbox local assets

Note matchbox profiles/groups will not be configured.

After the docker containers start, `vagrant ssh` into the vm:
```
sudo docker logs -f dnsmasq   # view dns, dhcp, and tftp logs
sudo docker logs -f matchbox  # view matchbox HTTP and gRPC logs

cd ~/matchbox/examples/terraform/simple-install \
  && terraform init \
  && terraform apply  # add the default group and coreOS profile to matchbox
```

## Boot the iPXE client vm
* **System Box** => debian/jessie64
* **Default CPU** => 1
* **Default RAM** => 2048
* **Networking**
 * **eth0** => Private network "pxe_network"

```
cd vagrant-matchbox/client
vagrant up  # you can use the --provider flag to select virtualbox or libvirt
vagrant ssh
```
This will:
- boot the vm
- load iPXE over tftp from the dnsmasq container on the server vm
- PXE boot any matching profiles

Press Ctrl+B during boot to drop into a PXE shell.
To restart the boot procedure:
```
vagrant reload
```
If you don't provision a profile and group for the machine in matchbox,
the `autoboot` iPXE command will fail, and you will see `no matching profile` in the matchbox container logs.
Use terraform to provision these as described in the server section.

**Matchbox Refs**
* https://github.com/coreos/matchbox/blob/master/Documentation/deployment.md
* https://github.com/coreos/matchbox/blob/master/Documentation/getting-started-docker.md
* https://coreos.com/matchbox/docs/latest/matchbox.html
* https://github.com/coreos/matchbox/blob/master/Documentation/network-setup.md#network-setup

**Vagrant PXE Refs**
* http://www.syslinux.org/wiki/index.php?title=PXELINUX
* https://help.ubuntu.com/community/DisklessUbuntuHowto
* https://github.com/vagrant-libvirt/vagrant-libvirt#no-box-and-pxe-boot
