# Global variables
SERVER_PUBLIC_IP=$(curl https://checkip.amazonaws.com)
INTERFACE_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

##### Linux configurations ####
#Upgrade packages
apt update && apt upgrade -y
apt install wireguard -y

#Enable ivp4 forward
echo net.ipv4.ip_forward=1 >>/etc/sysctl.conf
sysctl -p

#Set DEFAULT_FORWARD_POLICY to ACCEPT and disable ufw ipv6
sed -i -e 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
sed -i -e 's/IPV6=yes/IPV6=no/g' /etc/default/ufw

#Set postrouting rules
ex /etc/ufw/before.rules <<eof
1 insert
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic or VPN
-A POSTROUTING -s 10.1.1.0/24 -o $INTERFACE_NAME -j MASQUERADE
#44158/TCP: the helium hotspot communicates to other helium hotspots over this port. The networking logic knows how to get around a lack of forwarding here, but you will get better performance by forwarding the port
-A PREROUTING -i $INTERFACE_NAME -p tcp -m tcp --dport 44158 -j DNAT --to-destination 10.1.1.2:44158
#1680/UDP: the radio connects to the helium hotspot over this port. You will not be able to forward packets or participate in Proof of Coverage without this
-A PREROUTING -i $INTERFACE_NAME -p udp -m udp --dport 1680 -j DNAT --to-destination 10.1.1.2:1680
COMMIT
.
xit
eof

#### Wireguard Keys Generation ####

#Server WG
mkdir -m 0700 -p /etc/wireguard/
wg genkey | sudo tee /etc/wireguard/private.key
chmod go= /etc/wireguard/private.key
cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/public.key)

#OpenWRT peer
mkdir -m 0700 -p /root/wireguard/openwrt/
wg genkey | sudo tee /root/wireguard/openwrt/private.key
chmod go= /root/wireguard/openwrt/private.key
cat /root/wireguard/openwrt/private.key | wg pubkey | sudo tee /root/wireguard/openwrt/public.key

OPENWRT_PRIVATE_KEY=$(cat /root/wireguard/openwrt/private.key)
OPENWRT_PUBLIC_KEY=$(cat /root/wireguard/openwrt/public.key)

#Manager peer
mkdir -m 0700 -p /root/wireguard/manager/
wg genkey | sudo tee /root/wireguard/manager/private.key
chmod go= /root/wireguard/manager/private.key
cat /root/wireguard/manager/private.key | wg pubkey | sudo tee /root/wireguard/manager/public.key

MANAGER_PRIVATE_KEY=$(cat /root/wireguard/manager/private.key)
MANAGER_PUBLIC_KEY=$(cat /root/wireguard/manager/public.key)

#### Wireguard Server + Client Configuration Files ####

#Create wg server config file
ex /etc/wireguard/wg0.conf <<eof
insert
[Interface]
Address = 10.1.1.1
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE_NAME -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE_NAME -j MASQUERADE

[Peer]
# Openwrt
PublicKey = $OPENWRT_PUBLIC_KEY
AllowedIPs = 10.1.1.2/32

[Peer]
# Manager
PublicKey = $MANAGER_PUBLIC_KEY
AllowedIPs = 10.1.1.3/32
.
xit
eof

#Create wg openwrt config file
ex /wireguard/openwrt/openwrt.conf <<eof
insert
[Interface]
Address = 10.1.1.2
PrivateKey = $OPENWRT_PRIVATE_KEY
ListenPort = 51820
DNS = 1.1.1.1,1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
.
xit
eof

#Create wg manager config file
ex /wireguard/manager/manager.conf <<eof
insert
[Interface]
Address = 10.1.1.3
PrivateKey = $MANAGER_PRIVATE_KEY
ListenPort = 51820
DNS = 1.1.1.1,1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
.
xit
eof

### UFW & Wireguard global ###
ufw allow 22/tcp
ufw allow 51820/udp
yes | sudo ufw enable
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
