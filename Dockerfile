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
        cmake apt-utils gnupg dirmngr curl wget ca-certificates apt-transport-https \
        locales procps gosu git gcc logrotate uvicorn \
        build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev \
        xz-utils tk-dev libffi-dev liblzma-dev python-openssl python3-openssl \
        python3-dev python3-venv && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8\
&& (curl https://packages.edgedb.com/keys/edgedb.asc | apt-key add -) \
&& echo deb https://packages.edgedb.com/apt buster${subdist} main \
        >/etc/apt/sources.list.d/edgedb.list \
&& (try=1; while [ $try -le 5 ]; do apt-get update && break || true; \
    try=$(( $try + 1 )); sleep 1; done) \
&& (try=1; while [ $try -le 5 ]; do \
    env _EDGEDB_INSTALL_SKIP_BOOTSTRAP=1 \
    apt-get install -y edgedb-${version} edgedb-common edgedb-cli && break || true; \
    try=$(( $try + 1 )); sleep 1; done)

ENV LANG en_US.utf8
ENV VERSION ${version}
ENV EDGEDB_DATADIR /var/lib/edgedb/data

EXPOSE 5656
EXPOSE 6565
EXPOSE 8888
EXPOSE 15656
EXPOSE 16565
EXPOSE 18888

VOLUME /var/lib/edgedb/data
COPY docker-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["edgedb-server"]
RUN chmod 776 /srv/

