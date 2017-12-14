#!/bin/bash
set -ex

# user stuff
sudo apt-get update
sudo apt-get install -y vim
sudo -u vagrant cat <<EOF | tee /home/vagrant/.vimrc
syntax enable
EOF

# install docker
sudo apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common
sudo curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce


# install terraform + matchbox provider
sudo apt-get install -y unzip
sudo -u vagrant wget -nv https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip
sudo unzip terraform_0.11.1_linux_amd64.zip -d /bin

sudo -u vagrant wget -nv https://github.com/coreos/terraform-provider-matchbox/releases/download/v0.1.0/terraform-provider-matchbox-v0.1.0-linux-amd64.tar.gz
sudo -u vagrant tar xzf terraform-provider-matchbox-v0.1.0-linux-amd64.tar.gz
sudo -u vagrant cat <<EOF | tee /home/vagrant/.terraformrc
providers {
  matchbox = "/home/vagrant/terraform-provider-matchbox-v0.1.0-linux-amd64/terraform-provider-matchbox"
}
EOF


# clone matchbox
sudo -u vagrant git clone https://github.com/coreos/matchbox
cd matchbox


# generate certs
cd scripts/tls
MATCHBOX_HOST="192.168.0.254"
sudo -u vagrant SAN=DNS.1:matchbox.example.com,IP.1:${MATCHBOX_HOST} ./cert-gen
sudo -u vagrant cp ca.crt server.crt server.key ../../examples/etc/matchbox
sudo -u vagrant mkdir -p /home/vagrant/.matchbox
sudo -u vagrant cp client.crt client.key ca.crt /home/vagrant/.matchbox/
cd ../../


# run matchbox / dnsmasq
ASSETS_DIR="${ASSETS_DIR:-$PWD/examples/assets}"
CONFIG_DIR="${CONFIG_DIR:-$PWD/examples/etc/matchbox}"
MATCHBOX_ARGS="-rpc-address=0.0.0.0:8081"

sudo docker run --name matchbox \
  -d \
  -p 8080:8080 \
  -p 8081:8081 \
  -v $CONFIG_DIR:/etc/matchbox:Z \
  -v $ASSETS_DIR:/var/lib/matchbox/assets:Z \
  $DATA_MOUNT \
  quay.io/coreos/matchbox:f26224c57dbea02adff0200037b14310ccdd2ebc -address=0.0.0.0:8080 -log-level=debug $MATCHBOX_ARGS

sudo docker run -d --rm --cap-add=NET_ADMIN --net=host \
  --name=dnsmasq \
  quay.io/coreos/dnsmasq -d -q \
  --dhcp-range=192.168.0.2,192.168.0.253 \
  --enable-tftp --tftp-root=/var/lib/tftpboot \
  --dhcp-match=set:bios,option:client-arch,0 \
  --dhcp-boot=tag:bios,undionly.kpxe \
  --dhcp-match=set:efi32,option:client-arch,6 \
  --dhcp-boot=tag:efi32,ipxe.efi \
  --dhcp-match=set:efibc,option:client-arch,7 \
  --dhcp-boot=tag:efibc,ipxe.efi \
  --dhcp-match=set:efi64,option:client-arch,9 \
  --dhcp-boot=tag:efi64,ipxe.efi \
  --dhcp-userclass=set:ipxe,iPXE \
  --dhcp-boot=tag:ipxe,http://${MATCHBOX_HOST}:8080/boot.ipxe \
  --address=/matchbox.example/${MATCHBOX_HOST} \
  --log-queries \
  --log-dhcp


# fetch coreos image
COREOS_CHANNEL="stable"
COREOS_VERSION="1576.4.0"

sudo -u vagrant cat <<EOF | tee ./examples/terraform/simple-install/terraform.tfvars
matchbox_http_endpoint = "http://${MATCHBOX_HOST}:8080"
matchbox_rpc_endpoint = "${MATCHBOX_HOST}:8081"
ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMI0J+qxt8GPxiJGphLb7yaLsrjq2b28LVpOoYLwlsFotMx2Sw8dlLhMg2otJ4m/G/TBnZiXxsJ+F9aRl8dJg3hk1OoGR8MwlbmvVgzNmHWhhw4iwbpnoYVFS9cgPJ5rr4jl2+UuALM3Z88Vt0zt5F+YJkH8E89qkGJGq8hh8bjOE5SCjBAOrpW2NOsRD2gQM2VoGa2YrsxTIbq14u3clzm1C044lGdH/I6YEunwi8fEaLcyZu+OU+08L7MFtBE+YeGLnEj+E0+Q0sMEBnvvMI7NNpUYVZfLXA/5+2gB9YaO8DvDwkslBgYx887uILMVlMZWelCoGJAnpUFL13Kgg/ leigh@null.net"
EOF

EDIT_FILE="examples/terraform/simple-install/profiles.tf"
sudo -u vagrant sed -i "s|http://stable.release.core-os.net/amd64-usr/current|/assets/coreos/${COREOS_VERSION}|g" ${EDIT_FILE}

sudo ./scripts/get-coreos ${COREOS_CHANNEL} ${COREOS_VERSION} ./examples/assets
