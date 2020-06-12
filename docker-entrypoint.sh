#!/usr/bin/env bash

set -Eeo pipefail

if [ "${1:0:1}" = '-' ]; then
	set -- edgedb-server "$@"
fi

if [ "${1}" = 'edgedb-server' ] && [ "$(id -u)" = '0' ]; then
	if [ -n "${EDGEDB_DATADIR}" ]; then
		mkdir -p "${EDGEDB_DATADIR}"
		chown -R edgedb "${EDGEDB_DATADIR}"
		chmod 700 "${EDGEDB_DATADIR}"

		mkdir -p /var/run/edgedb
		chown -R edgedb /var/run/edgedb
		chmod 775 /var/run/edgedb
	else
		unset EDGEDB_DATADIR
	fi

	exec gosu edgedb "$BASH_SOURCE" "$@"
fi

if [ "${1}" = 'edgedb-server' -a "$#" -eq 1 ]; then
	mkdir -p "${EDGEDB_DATADIR}"
	chown -R "$(id -u)" "${EDGEDB_DATADIR}" 2>/dev/null || :
	chmod 700 "${EDGEDB_DATADIR}" 2>/dev/null || :

	if ! [ "$(ls -A ${EDGEDB_DATADIR})" ]; then
		shopt -s dotglob

		rm -rf /var/run/edgedb/*
		echo "Bootstrapping EdgeDB instance..."
		env EDGEDB_DEBUG_SERVER=1 edgedb-server -b -P5656
		socket="/var/run/edgedb/.s.EDGEDB.5656"

		try=1
		while [ $try -le 120 ]; do
			[ -e "${socket}" ] && break
			try=$(( $try + 1 ))
			sleep 1
		done

		if [ ! -e "${socket}" ]; then
			echo "ERROR: Server did not start within 120 seconds." >&2
			rm -r "${EDGEDB_DATADIR}/"*
			exit 1
		fi

		edgedb --admin -u edgedb configure \
			insert Auth --method=Trust --priority=0
		edgedb --admin -u edgedb configure \
			set listen_addresses "0.0.0.0"

		pid=$(ps aux | grep 'edgedb-server-5656' | grep -v 'grep' \
					 | awk '{print $2;}')

		kill "${pid}"

		try=1
		while [ $try -le 10 ]; do
			if ! (ps aux | grep 'edgedb-server-5656' \
						 | grep -v 'grep' >/dev/null); then
				break
			fi
			try=$(( $try + 1 ))
			sleep 1
		done

		if (ps aux | grep 'edgedb-server-5656' | grep -v 'grep'); then
			echo "ERROR: Server did not stop within 10 seconds." >&2
			rm -r "${EDGEDB_DATADIR}/"*
			exit 1
		fi
	fi
fi

exec "$@"
