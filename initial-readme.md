Official Dockerfile for EdgeDB
==============================

To build, run:

```bash
$ docker build -t edgedb:<edgedbver> --build-arg version=<edgedbver> .
```

Where `<edgedbver>` is the version of EdgeDB available for Debian 9, and
might resemble `1-alpha2`. If this holds true for you, then run:

```bash
$ docker build -t edgedb:1-alpha2 --build-arg version=1-alpha2 .
```

The container exposes the TCP/IP ports 5656, 6565, 8888, and the `/var/lib/edgedb/data`
as the persistent data volume. If you are already using these ports locally,
you can safely rewrite the Dockerfile to map the following ports to:
```
    - 5656 -> 15656
    - 6565 -> 16565
    - 8888 -> 18888
```

Additional setup is required that is not directly handled by the Dockerfile. Please
follow these steps:

```bash
$ export PATH=$PATH:"$( pwd )"
$ docker run -it edgedb:<edgedbver> bash

root@e3fd91361668:/# apt-get update && apt-get install -y git wget curl python2
root@e3fd91361668:/# export portfile='/proc/sys/net/ipv4/conf/all/forwarding'
root@e3fd91361668:/# function getip() { echo $( bash -c "python2 -c 'import socket; print([l for l in ([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith(\"127.\")][:1], [[(s.connect((\"8.8.8.8\", 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]]) if l][0][0])'" ); }
root@e3fd91361668:/# myip="$( getip )"
root@e3fd91361668:/# if [ "$(cat $portfile )" != "1" ]; then echo 1 > "$portfile"; fi && exec bash
root@e3fd91361668:/# iptables -t nat -A PREROUTING -p tcp -i enp8s0 --dport 6565 -j DNAT --to-destination $myip:16565
root@e3fd91361668:/# iptables -A FORWARD -p tcp -d $myip --dport 16565 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
root@e3fd91361668:/# iptables -t nat -A PREROUTING -p tcp -i enp8s0 --dport 8888 -j DNAT --to-destination $myip:18888
root@e3fd91361668:/# iptables -A FORWARD -p tcp -d $myip --dport 18888 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
root@e3fd91361668:/# iptables -t nat -A PREROUTING -p tcp -i enp8s0 --dport 15656 -j DNAT --to-destination $myip:5656
root@e3fd91361668:/# iptables -A FORWARD -p tcp -d $myip --dport 15656 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
# Double checking that this step worked: `ip route`
root@e3fd91361668:/# adduser edbpool
root@e3fd91361668:/# su edbpool
$ cd ~ && git clone https://github.com/dmgolembiowski/edbpool.git
$ cd edbpool
$ /bin/bash docker-mock-scripts/phase_1/pyenv_installer.sh
$ exec bash
$ pyenv install 3.8-dev
$ pyenv shell 3.8-dev
$ pip install -U pip wheel
$ pip install -r dev-requirements.txt
$ python3 docker-mock-scripts/phase_2/rpc-server.py "docker-mock-scripts/config.json"
