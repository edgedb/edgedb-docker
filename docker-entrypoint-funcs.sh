!/usr/bin/env bash


edbdocker_setup_shell() {
  set -Eeo pipefail
  shopt -s dotglob inherit_errexit nullglob compat"${BASH_COMPAT=42}"
  if [ -n "$EDGEDB_DOCKER_TRACE" ]; then
      set -x
  fi
}


edbdocker_is_server_command() {
  [ $# -eq 0 -o "${1:0:1}" = "-" -o "$1" = "edgedb-server" ] \
  && [ -z "$_EDBDOCKER_SHOW_HELP" ]
}


edbdocker_run_regular_command() {
  if [ "${1:0:1}" = '-' ]; then
    set -- edgedb-server "$@"
  fi

  exec "$@"
}


# Parse server arguments and populate environment variables accordingly.
# Arguments override environment variables.
edbdocker_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        export _EDBDOCKER_SHOW_HELP="1"
        shift
        ;;
      -D|--data-dir)
        _edbdocker_parse_arg "EDGEDB_SERVER_DATADIR" "$1" "$2"
        shift 2
        ;;
      --data-dir=*)
        export EDGEDB_SERVER_DATADIR="${1#*=}"
        shift
        ;;
      --runstate-dir)
        _edbdocker_parse_arg "EDGEDB_SERVER_RUNSTATE_DIR" "$1" "$2"
        shift 2
        ;;
      --runstate-dir=*)
        export EDGEDB_SERVER_RUNSTATE_DIR="${1#*=}"
        shift
        ;;
      --postgres-dsn)
        _edbdocker_parse_arg "EDGEDB_SERVER_POSTGRES_DSN" "$1" "$2"
        shift 2
        ;;
      --postgres-dsn=*)
        export EDGEDB_SERVER_POSTGRES_DSN="${1#*=}"
        shift
        ;;
      -P|--port)
        _edbdocker_parse_arg "EDGEDB_SERVER_PORT" "$1" "$2"
        shift 2
        ;;
      --port=*)
        export EDGEDB_SERVER_PORT="${1#*=}"
        shift
        ;;
      -I|--bind-address)
        _edbdocker_parse_arg "EDGEDB_SERVER_BIND_ADDRESS" "$1" "$2"
        shift 2
        ;;
      --bind-address=*)
        export EDGEDB_SERVER_BIND_ADDRESS="${1#*=}"
        shift
        ;;
      --bootstrap-command)
        _edbdocker_parse_arg "EDGEDB_SERVER_BOOTSTRAP_COMMAND" "$1" "$2"
        shift 2
        ;;
      --bootstrap-command=*)
        export EDGEDB_SERVER_BOOTSTRAP_COMMAND="${1#*=}"
        shift
        ;;
      --bootstrap-script)
        _edbdocker_parse_arg "EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE" "$1" "$2"
        shift 2
        ;;
      --bootstrap-script=*)
        export EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE="${1#*=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}


_edbdocker_parse_arg() {
  local var
  local opt
  local val

  var="$1"
  opt="$2"
  val="$3"

  if [ -n "$val" ] && [ "${val:0:1}" != "-" ]; then
    export "$var"="$val"
  else
    local msg
    msg=(
      "ERROR: The argument '${opt} <val>' requires a value, but none was supplied."
      "       Try '--help' for more information."
    )
    edbdocker_die "${msg[@]}"
  fi
}


edbdocker_prepare() {
  edbdocker_run_entrypoint_parts
  edbdocker_setup_env
  edbdocker_ensure_dirs
}


edbdocker_run_entrypoint_parts() {
  if [ -d "/docker-entrypoint.d" ]; then
    /bin/run-parts --verbose "/docker-entrypoint.d"
  fi
}


edbdocker_bootstrap_needed() {
  if [ -n "${EDGEDB_SERVER_POSTGRES_DSN}" ]; then
    ! edbdocker_remote_cluster_is_initialized "${EDGEDB_SERVER_POSTGRES_DSN}"
  else
    [ -z "$(ls -A "${EDGEDB_SERVER_DATADIR}")" ]
  fi
}


edbdocker_run_server() {
  local server_args=(
    --bind-address="$EDGEDB_SERVER_BIND_ADDRESS"
    --port="$EDGEDB_SERVER_PORT"
  )

  if [ -n "${EDGEDB_SERVER_POSTGRES_DSN}" ]; then
    server_args+=( --postgres-dsn="${EDGEDB_SERVER_POSTGRES_DSN}" )
  else
    server_args+=( --data-dir="${EDGEDB_SERVER_DATADIR}" )
  fi

  if [ "${1:0:1}" = '-' ]; then
    set -- edgedb-server "$@"
  fi

  if [ "$(id -u)" = "0" ]; then
    exec gosu "${EDGEDB_SERVER_UID}" "$@" ${EDGEDB_SERVER_EXTRA_ARGS} "${server_args[@]}"
  else
    exec "$@" ${EDGEDB_SERVER_EXTRA_ARGS} "${server_args[@]}"
  fi
}


# Populate important environment variables and make sure they are sane.
edbdocker_setup_env() {
  : ${EDGEDB_SERVER_PORT:="5656"}
  : ${EDGEDB_SERVER_BIND_ADDRESS:="0.0.0.0"}
  : ${EDGEDB_SERVER_AUTH_METHOD:="scram"}
  : ${EDGEDB_SERVER_UID:="edgedb"}

  edbdocker_lookup_env_var "EDGEDB_SERVER_USER" "edgedb"
  edbdocker_lookup_env_var "EDGEDB_SERVER_DATABASE" "edgedb"
  edbdocker_lookup_env_var "EDGEDB_SERVER_PASSWORD"
  edbdocker_lookup_env_var "EDGEDB_SERVER_PASSWORD_HASH"
  edbdocker_lookup_env_var "EDGEDB_SERVER_POSTGRES_DSN"

  if [ -n "${EDGEDB_SERVER_DATADIR:-}" ] &&
     [ -n "${EDGEDB_SERVER_POSTGRES_DSN:-}" ]; then
    edbdocker_die "ERROR: EDGEDB_SERVER_DATADIR and EDGEDB_SERVER_POSTGRES_DSN are mutually exclusive, but both are set"
  elif [ -z "${EDGEDB_SERVER_POSTGRES_DSN}" ]; then
    export EDGEDB_SERVER_DATADIR="${EDGEDB_SERVER_DATADIR:-/var/lib/edgedb/data}"
  fi

  if [ -n "${EDGEDB_SERVER_PASSWORD:-}" ] &&
     [ -n "${EDGEDB_SERVER_PASSWORD_HASH:-}" ]; then
    edbdocker_die "ERROR: EDGEDB_SERVER_PASSWORD and EDGEDB_SERVER_PASSWORD_PASH are mutually exclusive, but both are set"
  fi

  if [ -n "${EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE:-}" ] &&
     [ -n "${EDGEDB_SERVER_BOOTSTRAP_COMMAND:-}" ]; then
    edbdocker_die "ERROR: EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE and EDGEDB_SERVER_BOOTSTRAP_COMMAND are mutually exclusive, but both are set"
  fi

  export EDGEDB_SERVER_RUNSTATE_DIR="${EDGEDB_SERVER_RUNSTATE_DIR:-/run/edgedb}"
}


# Resolve the value of the specified variable.
# Usage: edbdocker_lookup_env_var VARNAME [default]
# The function looks for $VARNAME in the environment block directly,
# and also tries to read the value from ${VARNAME}_FILE, if set.
# For example, `edbdocker_lookup_env_var EDGEDB_SERVER_PASSWORD foo` would
# look for $EDGEDB_SERVER_PASSWORD, the file specified by
# $EDGEDB_SERVER_PASSWORD_FILE, and if neither is set, default to 'foo'.
edbdocker_lookup_env_var() {
  local var="$1"
  local file_var="${var}_FILE"
  local old_var="${var/EDGEDB_SERVER_/EDGEDB_}"
  local old_file_var="${old_var}_FILE"
  local deflt="${2:-}"
  local val="$deflt"
  local var_val="${!var:-}"
  local file_var_val="${!file_var:-}"
  local old_var_val="${!old_var:-}"
  local old_file_var_val="${!old_file_var:-}"

  if [ -n "${old_var_val}" ]; then
    msg=(
      "=============================================================== "
      "WARNING: ${old_var} is deprecated use ${var} instead. "
      "=============================================================== "
    )
    edbdocker_log "${msg[@]}"
  fi

  if [ -n "${old_file_var_val}" ]; then
    msg=(
      "=============================================================== "
      "WARNING: ${old_file_var} is deprecated use ${file_var} instead. "
      "=============================================================== "
    )
    edbdocker_log "${msg[@]}"
  fi

  local -A exclusive_pairs=(
    ["${var}"]="${file_var}"
    ["${var}"]="${old_var}"
    ["${var}"]="${old_file_var}"
    ["${old_var}"]="${file_var}"
    ["${old_var}"]="${old_file_var}"
    ["${file_var}"]="${old_file_var}"
  )

  for a in "${!exclusive_pairs[@]}"; do
    b="${exclusive_pairs[$a]}"
    if [ -n "${!a:-}" ] && [ -n "${!b:-}" ]; then
      edbdocker_die \
        "ERROR: ${a} and ${b} are exclusive, but both are set."
    fi
  done

  if [ -n "${old_var_val}" ]; then
    var_val="${old_var_val}"
  fi

  if [ -n "${old_file_var_val}" ]; then
    file_var="${old_file_var}"
    file_var_val="${old_file_var_val}"
  fi

  if [ -n "${var_val}" ]; then
    val="${var_val}"
  elif [ "${file_var_val}" ]; then
    if [ -e "${file_var_val}" ]; then
      val="$(< "${file_var_val}")"
    else
      edbdocker_die \
        "ERROR: the file specified by ${file_var} (${file_var_val}) does not exist."
    fi
  fi

  export "$var"="$val"
  unset "$file_var"
  unset "$old_var"
  unset "$old_file_var"
}


# Create directories required by EdgeDB server and set correct permissions
# if running as root.
edbdocker_ensure_dirs() {
  if [ -n "${EDGEDB_SERVER_DATADIR}" ]; then
    mkdir -p "${EDGEDB_SERVER_DATADIR}"
    chmod 700 "${EDGEDB_SERVER_DATADIR}" || :

    if [ "$(id -u)" = "0" ]; then
      chown -R "${EDGEDB_SERVER_UID}" "${EDGEDB_SERVER_DATADIR}"
    fi
  else
    unset EDGEDB_SERVER_DATADIR
  fi

  mkdir -p "${EDGEDB_SERVER_RUNSTATE_DIR}"
  chmod 775 "${EDGEDB_SERVER_RUNSTATE_DIR}"

  if [ "$(id -u)" = "0" ]; then
    chown -R "${EDGEDB_SERVER_UID}" "${EDGEDB_SERVER_RUNSTATE_DIR}"
  fi
}


# Check if the specified Postgres DSN contains an initialized EdgeDB instance.
# Returns 0 if so, 1 otherwise.
edbdocker_remote_cluster_is_initialized() {
  local pg_dsn="$1"
  local psql="$(dirname "$(readlink -f /usr/bin/edgedb-server)")/psql"

  if echo "\\l" \
     | "$psql" "${pg_dsn}" 2>/dev/null \
     | grep "__edgedbsys__" >/dev/null
  then
    return 0
  else
    # Either psql couldn't connect to the specified DSN, or EdgeDB
    # is not bootstrapped on the target cluster.  In the former case,
    # bootstrap will likely fail with an informative error.
    return 1
  fi
}


# Bootstrap the configured EdgeDB instance.  Expects either
# EDGEDB_SERVER_DATADIR or EDGEDB_SERVER_POSTGRES_DSN to be set in the
# environment.  Optionally takes extra server arguments.  Bootstrap is
# performed by a temporary edgedb-server process that gets started on a random
# port and is shut down once bootstrap is complete.
#
# Usage: `EDGEDB_SERVER_DATADIR=/foo/bar edbdocker_bootstrap_instance --arg=val`
edbdocker_bootstrap_instance() {
  local bootstrap_cmd
  local bootstrap_opts
  local server_info
  local server_pid
  local conn_opts

  bootstrap_opts=( "$@" )

  if [ -n "${EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE}" ]; then
    if ! [ -e "${EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE}" ]; then
      edbdocker_die "ERROR: the file specified by EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE (${EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE}) does not exist."
    else
      bootstrap_opts+=(--bootstrap-script="${EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE}")
    fi

  elif [ -n "${EDGEDB_SERVER_BOOTSTRAP_COMMAND}" ]; then
    bootstrap_opts+=(--bootstrap-command="${EDGEDB_SERVER_BOOTSTRAP_COMMAND}")

  elif [ -e "/edgedb-bootstrap.edgeql" ]; then
    bootstrap_opts+=(--bootstrap-script="/edgedb-bootstrap.edgeql")

  else
    if [ -z "${bootstrap_cmd}" ]; then
      if [ -n "${EDGEDB_SERVER_PASSWORD_HASH:-}" ]; then
        if [ "$EDGEDB_SERVER_USER" = "edgedb" ]; then
          bootstrap_cmd="ALTER ROLE ${EDGEDB_SERVER_USER} { SET password_hash := '${EDGEDB_SERVER_PASSWORD_HASH}'; }"
        else
          bootstrap_cmd="CREATE SUPERUSER ROLE ${EDGEDB_SERVER_USER} { SET password_hash := '${EDGEDB_SERVER_PASSWORD_HASH}'; }"
        fi
      elif [ -n "$EDGEDB_SERVER_PASSWORD" ]; then
        if [[ "$EDGEDB_SERVER_USER" = "edgedb" ]]; then
          bootstrap_cmd="ALTER ROLE ${EDGEDB_SERVER_USER} { SET password := '${EDGEDB_SERVER_PASSWORD}'; }"
        else
          bootstrap_cmd="CREATE SUPERUSER ROLE ${EDGEDB_SERVER_USER} { SET password := '${EDGEDB_SERVER_PASSWORD}'; }"
        fi
      elif [ "${EDGEDB_SERVER_AUTH_METHOD:-}" = "trust" ]; then
        bootstrap_cmd="CONFIGURE SYSTEM INSERT Auth {priority := 0, method := (INSERT Trust)};"
        msg=(
          "=============================================================== "
          "WARNING: EDGEDB_SERVER_AUTH_METHOD is set to 'trust'.  This will"
          "         allow unauthenticated access to this EdgeDB instance   "
          "         for all who have access to the database port! This     "
          "         might include other containers or processes on the same"
          "         host and, if port ${EDGEDB_SERVER_PORT} is bound to an "
          "         accessible interface on the host, other machines on    "
          "         the network.                                           "
          "                                                                "
          "         Use only for TESTING in a known environment without    "
          "         sensitive data.  It is strongly recommended to use     "
          "         password authentication via the EDGEDB_SERVER_PASSWORD "
          "         or EDGEDB_SERVER_PASSWORD_HASH environment variables.  "
          "=============================================================== "
        )
        edbdocker_log "${msg[@]}"
      else
        msg=(
          "ERROR: the EdgeDB instance at the specified location is not     "
          "       initialized and superuser password is not specified.     "
          "       Please set EDGEDB_SERVER_PASSWORD or                     "
          "       EDGEDB_SERVER_PASSWORD_HASH environment variable to a    "
          "       non-empty value.                                         "
          "                                                                "
          "       For example:                                             "
          "                                                                "
          "       $ docker run -e EDGEDB_SERVER_PASSWORD=password edgedb/edgedb   "
        )
        edbdocker_die "${msg[@]}"
      fi
    fi

    bootstrap_opts+=( --bootstrap-command="$bootstrap_cmd" )
  fi

  if [ -n "${EDGEDB_SERVER_POSTGRES_DSN}" ]; then
    edbdocker_log "Bootstrapping EdgeDB instance on remote Postgres cluster..."
  else
    edbdocker_log "Bootstrapping EdgeDB instance on the local volume..."
  fi

  edbdocker_run_temp_server \
    _edbdocker_bootstrap_cb \
    _edbdocker_bootstrap_abort_cb \
    "${bootstrap_opts[@]}"
}


_edbdocker_bootstrap_cb() {
  local conn_opts
  local dir

  dir="/edgedb-bootstrap.d"
  conn_opts=( "$@" )

  if [ "$EDGEDB_SERVER_DATABASE" != "edgedb" ]; then
    echo "CREATE DATABASE ${EDGEDB_SERVER_DATABASE};" \
      | edbdocker_cli "${conn_opts[@]}" --database="edgedb"
  fi

  if [ -d "${dir}" ]; then
    local envopts=()
    local opt

    for opt in "${conn_opts[@]}"; do
      case "$opt" in
        --port=*)
          envopts+=( "EDGEDB_SERVER_PORT=${opt#*=}" )
          ;;
        --host=*)
          envopts+=( "EDGEDB_HOST=${opt#*=}" )
          ;;
        *)
          ;;
      esac
    done

    if [ "$(id -u)" = "0" ]; then
      gosu "${EDGEDB_SERVER_UID}" \
        env "${envopts[@]}" /bin/run-parts --verbose "$dir" --regex='\.sh$'
    else
      env "${envopts[@]}" /bin/run-parts --verbose "$dir" --regex='\.sh$'
    fi

    # Feeding scripts one by one, so that errors are easier to debug
    for filename in $(/bin/run-parts --list "$dir" --regex='\.edgeql$'); do
      edbdocker_log "Bootstrap script $filename"
      cat "$filename" | edbdocker_cli "${conn_opts[@]}"
    done
  fi

  if [ -d "/dbschema" ] && [ -z "${EDGEDB_SERVER_SKIP_MIGRATIONS:-}" ]; then
    _edbdocker_migrations_cb "${conn_opts[@]}"
  fi
}


_edbdocker_bootstrap_abort_cb() {
  if [ -n "${EDGEDB_SERVER_DATADIR}" ] &&
     [ -e "${EDGEDB_SERVER_DATADIR}" ]; then
    (shopt -u nullglob; rm -rf "${EDGEDB_SERVER_DATADIR}/"* || :)
  fi

  edbdocker_die "$1"
}


# Runs schema migrations found in /dbschema unless
# EDGEDB_SERVER_SKIP_MIGRATIONS is set.  Expects either EDGEDB_SERVER_DATADIR
# or EDGEDB_SERVER_POSTGRES_DSN to be set in the environment.  Migrations are
# applied by a temporary edgedb-server process that gets started on a random
# port and is shut down once bootstrap is complete.
#
# Usage: `EDGEDB_SERVER_DATADIR=/foo/bar edbdocker_run_migrations`
edbdocker_run_migrations() {
  if [ -d "/dbschema" ] && [ -z "${EDGEDB_SERVER_SKIP_MIGRATIONS:-}" ]; then
    edbdocker_log "Applying schema migrations..."
    edbdocker_run_temp_server \
      _edbdocker_migrations_cb \
      _edbdocker_migrations_abort_cb
  fi
}


_edbdocker_migrations_cb() {
  if ! edbdocker_cli "${@}" migrate --schema-dir=/dbschema; then
    edbdocker_log "ERROR: Migrations failed. Stopping server."
    return 1
  fi
}


_edbdocker_migrations_abort_cb() {
  edbdocker_die "$1"
}


edbdocker_cli() {
  if [ "$(id -u)" = "0" ]; then
    gosu "${EDGEDB_SERVER_UID}" edgedb "$@"
  else
    edgedb "$@"
  fi
}


# Write arguments to stderr separated by newlines.
# Example: `edbdocker_log "some" "long" "message"`
# will output:
#   some
#   long
#   message
#
edbdocker_log() {
  printf >&2 "%s\n" "${@}"
}


# Log arguments to stderr using `edbdocker_log` and exit with 1.
edbdocker_die() {
  edbdocker_log "${@}"
  exit 1
}


# Start edgedb-server on a random port, execute the specified callback
# and shut down the server.
#
# Usage: `edbdocker_run_temp_server callback abort_callback --server-arg=val ...`
edbdocker_run_temp_server() {
  local edgedb_pid
  local shell_pid
  local timeout_pid
  local timeout
  local retry_period
  local runstate_dir
  local port
  local ecode
  local server_opts
  local conn_opts
  local callback
  local result

  result=0
  callback="$1"
  abort_callback="$2"
  shift 2
  server_opts=( "${@}" )

  if [ -n "${EDGEDB_SERVER_POSTGRES_DSN}" ]; then
    server_opts+=(--postgres-dsn="${EDGEDB_SERVER_POSTGRES_DSN}")
  else
    server_opts+=(--data-dir="${EDGEDB_SERVER_DATADIR}")
  fi

  runstate_dir="$(edbdocker_mktemp_for_server -d)"

  server_opts+=(
    --runstate-dir="$runstate_dir"
    --port="auto"
    --bind-address="127.0.0.1"
  )
  conn_opts=( --admin --host="$runstate_dir" --wait-until-available="2s" )

  # Start the server
  if [ "$(id -u)" = "0" ]; then
    gosu "${EDGEDB_SERVER_UID}" \
      "${EDGEDB_SERVER_BINARY:-edgedb-server}" "${server_opts[@]}" &
  else
    "${EDGEDB_SERVER_BINARY:-edgedb-server}" "${server_opts[@]}" &
  fi
  edgedb_pid="$!"

  timeout=120
  retry_period=5

  function _abort() {
    if [ -e "${runstate_dir}" ]; then
      rm -r "${runstate_dir}" || :
    fi
    if [ -n "${abort_callback}" ]; then
      $abort_callback "$1"
    fi
    result=1
  }

  (
    local port
    local sock
    local i
    local check

    shopt -s nullglob  # to properly match the Unix socket

    for i in $(seq 1 $(($timeout / $retry_period))); do
      sleep $retry_period
      if [ "${runstate_dir}/.s.EDGEDB.admin."* ]; then
        break
      fi
    done

    for sock in "${runstate_dir}/.s.EDGEDB.admin."*; do
      port="${sock##*.}"
      break
    done

    if [ -z "${port}" ]; then
      _abort "ERROR: Server socket did not appear within ${timeout} seconds."
    fi

    check_args=(
      --admin
      --host="${runstate_dir}"
      --port="${port}"
      --database="edgedb"
      --wait-until-available="2s"
      query "SELECT 1"
    )

    if ! edbdocker_cli "${check_args[@]}" >/dev/null; then
      _abort ""
    fi

    sleep 1
  ) &
  timeout_pid="$!"

  set +e
  wait -n "$edgedb_pid" "$timeout_pid"
  ecode=$?
  if [ $ecode -eq 0 ]; then
    # The first succeeding task would be the server due
    # to a trailing sleep above.
    wait "$timeout_pid"
    ecode=$?
  else
    kill "$timeout_pid"
  fi
  if [ $ecode -ne 0 ]; then
    _abort "ERROR: Could not bootstrap EdgeDB server instance."
    return $ecode
  fi
  set -e

  for sock in "${runstate_dir}/.s.EDGEDB.admin."*; do
    port="${sock##*.}"
    break
  done

  if [ -z "${port}" ]; then
    _abort "ERROR: EdgeDB server seems to have died before bootstrap could complete."
    return 1
  fi

  conn_opts+=( --port="${port}" )

  if [ -n "${callback}" ]; then
    if ! $callback "${conn_opts[@]}"; then
      result=$?
    fi
  fi

  shell_pid=$$
  trap "_abort" 10

  kill $edgedb_pid
  (
    sleep 10;
    edbdocker_log "ERROR: Could not complete bootstrap: server did not stop within 10 seconds."
    kill -10 $shell_pid
  ) &
  timeout_pid=$!
  wait $edgedb_pid
  kill $timeout_pid
  trap - 10

  rm -r "${runstate_dir}" || :

  return $resuit
}


edbdocker_mktemp_for_server() {
  local result
  result=$(mktemp "$@")

  if [ "$(id -u)" = "0" ]; then
    chown -R "${EDGEDB_SERVER_UID}" "${result}"
  fi

  echo "${result}"
}
