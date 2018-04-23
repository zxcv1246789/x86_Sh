echo "PXE Server Setting..."
sleep 2s

ifconfig=$(ifconfig)

interface=`echo $ifconfig | cut -d' ' -f1`

echo "Interface is $interface"
sleep 2s

username=`awk -F ':' '{if($3>=500)print $1}' /etc/passwd`

user=`echo $username | cut -d' ' -f2`

echo "User is $user"
sleep 2s

DHCPip=192.170.10.10
DHCPsubnet=192.170.10.0
DHCPnetmask=255.255.255.0
DHCPrange=("192.170.10.100" "192.170.10.200")
DHCPDefLeaseTime=600
DHCPMaxLeaseTime=7200

:<<'END'

echo "DHCP Server IP is $DHCPip"
sleep 2s

echo "update & upgrade start..."
sleep 3s

apt-get update -y
apt-get upgrade -y

echo "TFTP server Install and Setting..."
sleep 3s

apt-get install tftp tftpd -y

cat > /etc/xinetd.d/tftp <<-EOF
service tftp
{
	socket_type	= dgram
	protocol	= udp
	port		= 69
	wait		= yes
	user		= root
	server		= /usr/sbin/in.tftpd
	server_args	= -s /tftpboot
	disable		= no
}
EOF

mkdir /tftpboot

chmod -R 777 /tftpboot

service xinetd restart

echo "Static IP Setting..."
sleep 2s

mv /etc/network/interfaces /etc/network/interfaces.orig

cat > /etc/network/interfaces <<-EOF
auto lo
iface lo inet loopback

auto $interface
iface $interface inet static

address $DHCPip
EOF

echo "DHCP Server install and Setting..."
sleep 3s

apt-get install isc-dhcp-server -y

mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig

cat > /etc/dhcp/dhcpd.conf <<-EOF
ddns-update-style none;
allow booting;
allow bootp;

option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org;

default-lease-time $DHCPDefLeaseTime;
max-lease-time $DHCPMaxLeaseTime;

log-facility local7;

class "pxeclients" {
	match if substring(option vendor-class-identifier, 0, 9) = "PXEClient";
	next-server $DHCPip;
	filename = "pxelinux.0";
}

subnet $DHCPsubnet netmask $DHCPnetmask {
	range ${DHCPrange[0]} ${DHCPrange[1]};
}
EOF

service isc-dhcp-server restart
service isc-dhcp-server status

echo "NFS-KERNEL-SERVER Install and Setting..."
sleep 3s

apt-get install nfs-kernel-server -y

mkdir -p /home/$user/ubuntu-livecd-16/amd64

mv /etc/exports /etc/exports.orig

cat > /etc/exports <<-EOF
/home/$user/ubuntu-livecd-16/amd64 *(ro,insecure,no_root_squash,async,no_subtree_check)
EOF

exportfs -a

END

echo "LiveCD iso file Download AND Setting..."
sleep 3s

wget http://releases.ubuntu.com/16.04.4/ubuntu-16.04.4-desktop-amd64.iso && wget http://releases.ubuntu.com/14.04/ubuntu-14.04.5-server-amd64.iso

mkdir /mnt/ubuntu-16.04-desktop
mkdir /mnt/ubuntu-14.04-server

mount -o loop ubuntu-16.04.4-desktop-amd64.iso /mnt/ubuntu-16.04-desktop
mount -o loop ubuntu-14.04.5-server-amd64.iso /mnt/ubuntu-14.04-server

cp /mnt/ubuntu-14.04-server/install/netboot/pxelinux.0 /tftpboot

mkdir -p /tftpboot/ubuntu-installer/amd64

cp -R /mnt/ubuntu-14.04-server/install/netboot/ubuntu-installer/amd64/boot-screens /tftpboot/ubuntu-installer/amd64

mkdir /tftpboot/pxelinux.cfg

cat > /tftpboot/pxelinux.cfg/default <<-EOF
include mybootmenu.cfg
default ubuntu-installer/amd64/boot-screens/vesamenu.c32
prompt 0
timeout 100
EOF


cp -av /mnt/ubuntu-16.04-desktop/* /home/$user/ubuntu-livecd-16/amd64
cp -av /mnt/ubuntu-16.04-desktop/.disk /home/$user/ubuntu-livecd-16/amd64

mkdir -p /tftpboot/ubuntu-livecd-boot/amd64

cp -av /mnt/ubuntu-16.04-desktop/casper/initrd.lz /tftpboot/ubuntu-livecd-boot/amd64
cp -av /mnt/ubuntu-16.04-desktop/casper/vmlinuz.efi /tftpboot/ubuntu-livecd-boot/amd64


cat > /tftpboot/mybootmenu.cfg <<-EOF
menu hshift 12
menu width 49
menu margin 8
menu title My Customised Network Boot Menu
include ubuntu-installer/amd64/boot-screens/stdmenu.cfg
label Boot from the first HDD
	losalhost 0
label Live CD 64-bit(16.04.4)
	kernel ubuntu-livecd-boot/amd64/vmlinuz.efi
	append boot=casper netboot=nfs nfsroot=$DHCPip:/home/$user/ubuntu-livecd-16/amd64 initrd=ubuntu-livecd-boot/amd64/initrd.lz -- splash quiet
EOF


unsquashfs /home/$user/ubuntu-livecd-16/amd64/casper/filesystem.squashfs

mksquashfs squashfs-root /home/$user/ubuntu-livecd-16/amd64/casper/filesystem.squashfs


echo "JAVA JDK Install..."
sleep 3s

apt-get update -y && apt-get upgrade -y

add-apt-repository ppa:webupd8team/java -y
apt-get update -y

apt-get install oracle-java8-installer -y
