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
$ docker run -it -p 15656:5656 \
> -p 5656:5656 -p 6565:16565 -p 16565:16565 \
> -p 18888:18888 -p 8888:8888 edgedb:<edgedbver> bash
# Or as a one-liner (see Appendix 1)
root@e3fd91361668:/# apt-get update && apt-get install -y git wget curl 
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
```

### Appendix
> 1: docker run -it -p 15656:5656 -p 5656:5656 -p 6565:16565 -p 16565:16565 -p 18888:18888 -p 8888:8888 edgedb:1-alpha2 bash

