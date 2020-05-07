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
$ docker run -it -d --rm \
-p 15656:5656 \
-p 5656:5656 \
-p 6565:16565 \
-p 16565:16565 \
-p 18888:18888 \
-p 8888:8888 edgedb:<edgedbver>

# Or as a one-liner (see Appendix 1)
```

Next, you'll need to get its container ID and connect to the test runner's shell
```bash
$ docker ps -a
CONTAINER ID  IMAGE               COMMAND   ...           PORTS                       NAMES
<container_id>  edgedb:1-alpha2     "docker-entrypoint.s…"  0.0.0.0:5656->5656/tcp,...  competent_panini
```
Then execute:
```bash
docker exec -it <container_id> bash
```
The remaining manual steps can be completed as follows:
```bash
root@e3fd91361668:/# su edbpool 
edbpool@e3fd91361668:/$ cd ~/edbpool
edbpool@e3fd91361668:/home/edbpool/edbpool/$ /bin/bash docker-mock-scripts/phase_1/pyenv_installer.sh
edbpool@e3fd91361668:/home/edbpool/edbpool/$ exec bash
edbpool@e3fd91361668:/home/edbpool/edbpool/$ pyenv install 3.8-dev
edbpool@e3fd91361668:/home/edbpool/edbpool/$ pyenv shell 3.8-dev
edbpool@e3fd91361668:/home/edbpool/edbpool/$ python3 -m venv .
edbpool@e3fd91361668:/home/edbpool/edbpool/$ source bin/activate
edbpool@e3fd91361668:/home/edbpool/edbpool/$ pip install -U pip wheel
edbpool@e3fd91361668:/home/edbpool/edbpool/$ pip install -r dev-requirements.txt
edbpool@e3fd91361668:/home/edbpool/edbpool/$ python3 docker-mock-scripts/phase_2/rpc-server.py "docker-mock-scripts/config.json"
edbpool@e3fd91361668:/home/edbpool/edbpool/$ 
```

### Appendix
> 1: docker run -it -p 15656:5656 -p 5656:5656 -p 6565:16565 -p 16565:16565 -p 18888:18888 -p 8888:8888 edgedb:1-alpha2 bash
<!--
### Markup Junk
edbpool@e3fd91361668:/home/edbpool/edbpool/$ 
edbpool@e3fd91361668:/home/edbpool/edbpool/$ 
edbpool@e3fd91361668:/home/edbpool/edbpool/$ 


-->
