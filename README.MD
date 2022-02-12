# Helium miner VPS bridge setup

Some carriers (or, most carriers) do not allow port forwarding. So, we will fix this by using VPN.

You can also use it if you want to have static ip address even at home, without calling to ISP.

## Getting started

I will split this setup into two parts. First one will be server configuration, second one will be router configuration.

Server configuration is meant to be the hardest one, but I have written script that makes this setup dead simple.


## Server configuration

All you have to to is to download bash script and run it. It will do most hard work. Login with root user and run:

```
cd /root/ wget -O - https://raw.githubusercontent.com/<username>/<project>/<branch>/<path>/<file>
chmod 700 server.sh
./server.sh
```