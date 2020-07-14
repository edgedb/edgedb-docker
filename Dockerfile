FROM debian:buster-slim
ARG version
ARG subdist

ENV GOSU_VERSION 1.11

SHELL ["/bin/bash", "-c"]

RUN set -ex; export DEBIAN_FRONTEND=noninteractive; \
(try=1; while [ $try -le 5 ]; do \
    apt-get update && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& (try=1; while [ $try -le 5 ]; do \
    apt-get install -y --no-install-recommends \
        apt-utils gnupg dirmngr curl wget ca-certificates apt-transport-https \
        locales procps gosu && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8\
&& (curl https://packages.edgedb.com/keys/edgedb.asc | apt-key add -) \
&& echo deb https://packages.edgedb.com/apt buster${subdist} main \
        >/etc/apt/sources.list.d/edgedb.list \
&& (try=1; while [ $try -le 5 ]; do apt-get update && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& (try=1; while [ $try -le 5 ]; do \
    env _EDGEDB_INSTALL_SKIP_BOOTSTRAP=1 \
    apt-get install -y edgedb-${version} edgedb-cli && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& ln -s /usr/bin/edgedb-server-${version} /usr/bin/edgedb-server \
&& apt-get remove -y apt-utils gnupg dirmngr wget curl apt-transport-https \
&& apt-get purge -y --auto-remove \
&& rm -rf /var/lib/apt/lists/*

ENV LANG en_US.utf8
ENV VERSION ${version}
ENV EDGEDB_DATADIR /var/lib/edgedb/data

EXPOSE 5656

VOLUME /var/lib/edgedb/data

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["edgedb-server"]
