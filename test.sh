echo "PXE Server Setting..."
sleep 3s

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

apt-get update -y
apt-get upgrade -y

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
	server_args	= /tftpboot
	disable		= no
}
EOF

mkdir /tftpboot

chmod -R 777 /tftpboot

service xinetd restart

:<<'END'

cat > /etc/network/interfaces <<-EOF
auto lo
iface lo inet loopback

auto $interface
iface $interface inet static

address $DHCPip
EOF

END
