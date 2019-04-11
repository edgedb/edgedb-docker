#!/usr/bin/env bash

set -Eeo pipefail

if [ "${1:0:1}" = '-' ]; then
	set -- edgedb-server "$@"
fi

if [ "$1" = 'edgedb-server' ] && [ "$(id -u)" = '0' ]; then
	mkdir -p "$EDGEDB_DATADIR"
	chown -R edgedb "$EDGEDB_DATADIR"
	chmod 700 "$EDGEDB_DATADIR"

	mkdir -p /var/run/edgedb
	chown -R edgedb /var/run/edgedb
	chmod 775 /var/run/edgedb

	exec gosu edgedb "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'edgedb-server' ]; then
	mkdir -p "$EDGEDB_DATADIR"
	chown -R "$(id -u)" "$EDGEDB_DATADIR" 2>/dev/null || :
    chmod 700 "$EDGEDB_DATADIR" 2>/dev/null || :
fi

exec "$@"