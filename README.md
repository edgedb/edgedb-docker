Official Dockerfile for EdgeDB
==============================

To build, run:

```bash
$ docker build -t edgedb:<edgedbver> --build-arg version=<edgedbver> .
```

Where `<edgedbver>` is the version of EdgeDB available for Debian 9.

The container exposes the TCP/IP port 5656, and the `/var/lib/edgedb/data`
as the persistent data volume.