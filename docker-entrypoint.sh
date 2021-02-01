#!/usr/bin/env bash
set -Exeo pipefail

DIR=/docker-entrypoint.d

if [[ -z "$_SKIP_ENTRYPOINT" ]] && [[ -d "$DIR" ]]; then
  /bin/run-parts --verbose "$DIR"
fi


if [[ "${1:0:1}" = '-' ]]; then
	set -- edgedb-server "$@"
fi

if [[ "${1}" = 'edgedb-server' ]] && [[ "$(id -u)" = '0' ]]; then
	if [[ -n "${EDGEDB_DATADIR}" ]]; then
		mkdir -p "${EDGEDB_DATADIR}"
		chown -R edgedb "${EDGEDB_DATADIR}"
		chmod 700 "${EDGEDB_DATADIR}"

		mkdir -p /var/run/edgedb
		chown -R edgedb /var/run/edgedb
		chmod 775 /var/run/edgedb
	else
		unset EDGEDB_DATADIR
	fi

	exec gosu edgedb env _SKIP_ENTRYPOINT=1 "$BASH_SOURCE" "$@"
fi

if [[ "$1" = 'edgedb-server' ]] && [[ "$2" = "--bind-address=0.0.0.0" ]] && [[ "$#" -eq 2 ]]; then
	mkdir -p "${EDGEDB_DATADIR}"
	chown -R "$(id -u)" "${EDGEDB_DATADIR}" 2>/dev/null || :
	chmod 700 "${EDGEDB_DATADIR}" 2>/dev/null || :

	if [[ -z "$(ls -A ${EDGEDB_DATADIR})" ]]; then
		shopt -s dotglob

        bootstrap_opts=("--port=5656")
        edgedb_user="${EDGEDB_USER:-edgedb}"
        edgedb_database="${EDGEDB_DATABASE:-edgedb}"
        if [[ -e "/edgedb-bootstrap.edgeql" ]]; then
            bootstrap_opts+=("--bootstrap-script=/edgedb-bootstrap.edgeql")
        elif [[ -n "$EDGEDB_BOOTSTRAP_COMMAND" ]]; then
            bootstrap_opts+=("--bootstrap-command=$EDGEDB_BOOTSTRAP_COMMAND")
        elif [[ -n "$EDGEDB_PASSWORD_HASH" ]]; then
            if [[ "$edgedb_user" = "edgedb" ]]; then
                bootstrap_opts+=(--bootstrap-command="ALTER ROLE $edgedb_user { SET password_hash := '$EDGEDB_PASSWORD_HASH'; }")
            else
                bootstrap_opts+=(--bootstrap-command="CREATE SUPERUSER ROLE $edgedb_user { SET password_hash := '$EDGEDB_PASSWORD_HASH'; }")
            fi
        elif [[ -n "$EDGEDB_PASSWORD" ]]; then
            if [[ "$edgedb_user" = "edgedb" ]]; then
                bootstrap_opts+=(--bootstrap-command="ALTER ROLE $edgedb_user { SET password := '$EDGEDB_PASSWORD'; }")
            else
                bootstrap_opts+=(--bootstrap-command="CREATE SUPERUSER ROLE $edgedb_user { SET password := '$EDGEDB_PASSWORD'; }")
            fi
        fi

		rm -rf /var/run/edgedb/*
		echo "Bootstrapping EdgeDB instance..."
		edgedb-server "${bootstrap_opts[@]}" &
        edgedb_pid="$!"

        if [[ "$edgedb_database" != edgedb ]]; then
            first_cmd=(edgedb --wait-until-available=120s --admin -d edgedb create-database $edgedb_database)
        else
            first_cmd=(edgedb --wait-until-available=120s --admin query 'SELECT 1')
        fi

		if ! "${first_cmd[@]}"; then
			echo "ERROR: Server did not start within 120 seconds." >&2
			rm -r "${EDGEDB_DATADIR}/"*
			exit 1
		fi


        if [[ -d "/edgedb-bootstrap.d" ]]; then
            /bin/run-parts --verbose /edgedb-bootstrap.d --regex='\.sh$'
            # Feeding scripts one by one, so that errors are easier to debug
            for filename in $(/bin/run-parts --list /edgedb-bootstrap.d --regex='\.edgeql$'); do
                echo "Bootstrap script $filename"
                cat $filename | edgedb --admin
            done
        fi


		kill "${edgedb_pid}"
        shell_pid="$$"
        (
            sleep 10;
			echo "ERROR: Server did not stop within 10 seconds." >&2
            kill $shell_pid
        ) &
        timeout_pid="$!"
        wait "${edgedb_pid}"
        kill "${timeout_pid}"
	fi

    if [[ -d "/dbschema" ]] && [[ -z "$EDGEDB_SKIP_MIGRATIONS" ]]; then
        shell_pid="$$"
        (
            if ! edgedb --wait-until-available=120s \
                --admin migrate --schema-dir=/dbschema
            then
                echo "ERROR: Migrations failed. Stopping server."
                kill "$shell_pid"
            fi
        ) &
    fi
fi


exec "$@"
