FROM debian:stretch-slim
ARG version

ENV GOSU_VERSION 1.11

RUN set -ex; \
apt-get update \
&& apt-get install -y --no-install-recommends \
	apt-utils gnupg dirmngr curl wget ca-certificates apt-transport-https \
	locales procps \
&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
&& export GNUPGHOME="$(mktemp -d)" \
&& echo "disable-ipv6" >> "${GNUPGHOME}/dirmngr.conf" \
&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
&& rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8\
&& (curl https://packages.edgedb.com/keys/edgedb.asc | apt-key add -) \
&& echo deb https://packages.edgedb.com/apt stretch main \
        >/etc/apt/sources.list.d/edgedb.list \
&& apt-get update \
&& env _EDGEDB_INSTALL_SKIP_BOOTSTRAP=1 apt-get install -y edgedb-${version} \
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