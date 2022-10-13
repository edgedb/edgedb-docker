FROM debian:buster-slim
ARG version
ARG exact_version
ARG subdist

ENV GOSU_VERSION 1.11

SHELL ["/bin/bash", "-c"]

RUN set -Eeo pipefail; shopt -s dotglob inherit_errexit nullglob; \
export DEBIAN_FRONTEND=noninteractive; \
(test -n "${version}" || \
  (echo ">>> ERROR: missing required 'version' build-arg" >&2 && exit 1)) \
&& ( \
    for i in $(seq 1 5); do [ $i -gt 1 ] && sleep 1; \
        apt-get update \
    && s=0 && break || s=$?; done; exit $s \
) \
&& ( \
    for i in $(seq 1 5); do [ $i -gt 1 ] && sleep 1; \
        apt-get install -y --no-install-recommends \
            apt-utils \
            gnupg \
            dirmngr \
            curl \
            wget ca-certificates \
            apt-transport-https \
            locales \
            procps \
            gosu \
            jq \
    && s=0 && break || s=$?; done; exit $s \
) \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8\
&& curl -fsSL https://packages.edgedb.com/keys/edgedb.asc \
       -o /etc/apt/trusted.gpg.d/edgedb.asc \
&& echo deb https://packages.edgedb.com/apt buster ${subdist:-main} \
       >/etc/apt/sources.list.d/edgedb.list \
&& ( \
    for i in $(seq 1 5); do [ $i -gt 1 ] && sleep 1; \
        apt-get update \
    && s=0 && break || s=$?; done; exit $s \
) \
&& ( \
    server=edgedb-server-${version}; \
    [ -n "${exact_version}" ] && server+="=${exact_version}+*"; \
    for i in $(seq 1 5); do [ $i -gt 1 ] && sleep 1; \
        env apt-get install -y "${server}" edgedb-cli \
    && s=0 && break || s=$?; done; exit $s \
) \
&& ln -s /usr/bin/edgedb-server-${version} /usr/bin/edgedb-server \
&& apt-get remove -y apt-utils gnupg dirmngr wget apt-transport-https \
&& apt-get purge -y --auto-remove \
&& rm -rf /var/lib/apt/lists/*

ENV LANG en_US.utf8
ENV VERSION ${version}

EXPOSE 5656

VOLUME /var/lib/edgedb/data

COPY docker-entrypoint-funcs.sh docker-entrypoint.sh edgedb-show-secrets.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["edgedb-server"]
