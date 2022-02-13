# Helium miner VPS bridge setup

Some carriers (or, most carriers) do not allow port forwarding. So, we will fix this by using VPN.

You can also use it if you want to have static ip address even at home, without calling to ISP.

## Getting started

I will split this setup into two parts. First one will be server configuration, second one will be router configuration.

Server configuration is meant to be the hardest one, but I have written script that makes this setup dead simple.

## Server configuration

All you have to do is download bash script and run it. It will do all hard work. Login with root user and run:

```
cd /root/
wget https://raw.githubusercontent.com/kostamilorava/helium-vpn-bridge/main/server/setup.sh --output-document=/root/setup.sh
chmod 700 setup.sh
./setup.sh
#Just a breakline :)
```

That's it. You have own running VPN server for any of your devices.

To generate qr code for mobile application, run `qrencode -t ansiutf8 < configfile.conf`

## OpenWRT configuration

Here we will need bit more time.

Press 'Update lists...' in `System > Software` and install  `luci-app-wireguard`. This will install all dependencies.

Reboot router, go to `Network > interfaces` and press 'Add new interface...'. Type any name, select 'WireGuard VPN' in
protocol and press 'Create interface button'.

In 'General settings' write private key from server's `/root/wireguard/openwrt/private.key`. In 'IP Addresses'
enter `10.1.1.2`.

In 'Firewall Settings' select 'wan' (red interface). Go to 'Peers' tab and click 'Add peer'. In description enter any
value you want. In public key enter public key of server `/etc/wireguard/public.key`.

In allowed IPs enter '0.0.0.0/0', click + button and add '::/0' as well.

Check 'Route Allowed IPs' checkbox.

Write your server's public ip address in 'Endpoint Host'. Write 25 in 'Persistent Keep Alive' and click 'save'.

That's it. Your openwrt is now routed through your VPS. Also, from vps ports can be forwarded to OpenWRT or any lan
device (you need to set it).

Now we should set static Lease for our miner to be sure that it will always take one ip address.


