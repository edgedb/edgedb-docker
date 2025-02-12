#!/usr/bin/env bash

declare -A _edbdocker_log_levels=(
  [trace]=0
  [debug]=1
  [info]=2
  [warning]=3
  [error]=4
)

duplicate_envvar_warning() {
    local gelvar
    local edbvar

    gelvar="$1"
    edbvar="EDGEDB_${1#GEL_}"

    if [[ -n "${!gelvar-}" ]] && [[ -n "${!edbvar-}" ]]; then
        edbdocker_log_at_level "wraning" "Both $gelvar and $edbvar are set. Ignoring $edbvar."
    fi
}


edbdocker_setup_shell() {
  set -Eeu -o pipefail
  shopt -s dotglob inherit_errexit nullglob compat"${BASH_COMPAT=42}"
  duplicate_envvar_warning "GEL_DOCKER_LOG_LEVEL"
  : "${GEL_DOCKER_LOG_LEVEL:=${EDGEDB_DOCKER_LOG_LEVEL:-info}}"

  GEL_DOCKER_LOG_LEVEL="${GEL_DOCKER_LOG_LEVEL,,}"

  if [ -z "${_edbdocker_log_levels[$GEL_DOCKER_LOG_LEVEL]:-}" ]; then
    edbdocker_die "unknown level passed to GEL_DOCKER_LOG_LEVEL: \"$GEL_DOCKER_LOG_LEVEL\", supported values are "
  fi

  if [ "$GEL_DOCKER_LOG_LEVEL" == "trace" ]; then
    set -x
    export PS4='+$(date +"%Y-%m-%d %H:%M:%S"): $(basename ${BASH_SOURCE}):${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  fi
}


edbdocker_is_server_command() {
  [ $# -eq 0 ] \
  || [ "${1:0:1}" = "-" ] \
  || [ "$1" = "server" ] \
  && [ -z "${_EDBDOCKER_SHOW_HELP:-}" ]
}


edbdocker_run_regular_command() {
  if [ "${1:0:1}" = '-' ]; then
    set -- "$DEFAULT_SERVER_BINARY" "$@"
  elif [ "$1" = "server" ]; then
    set -- "$DEFAULT_SERVER_BINARY" "${@:1}"
  fi

  exec "$@"
}


# Parse server arguments and populate environment variables accordingly.
# Arguments override environment variables.
_EDGEDB_DOCKER_CMDLINE_ARGS=()

# Set by a caller to edbdocker_die() to signal a specific exict code.
EDGEDB_DOCKER_ABORT_CODE=1

# VERSION was set in Dockerfile, in the format of either a single major version
# like "5", or a nightly like "6-3762"
VERSION_MAJOR=$(echo "${VERSION}" | awk -F '-' '{print $1}')


edbdocker_parse_args() {
  if [ "${1:0:1}" != '-' ]; then
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _EDBDOCKER_SHOW_HELP="1"
        shift
        ;;
      -D|--data-dir)
        _edbdocker_parse_arg "GEL_SERVER_DATADIR" "$1" "$2"
        shift 2
        ;;
      --data-dir=*)
        GEL_SERVER_DATADIR="${1#*=}"
        shift
        ;;
      --runstate-dir)
        _edbdocker_parse_arg "GEL_SERVER_RUNSTATE_DIR" "$1" "$2"
        shift 2
        ;;
      --runstate-dir=*)
        GEL_SERVER_RUNSTATE_DIR="${1#*=}"
        shift
        ;;
      --backend-dsn)
        _edbdocker_parse_arg "GEL_SERVER_BACKEND_DSN" "$1" "$2"
        shift 2
        ;;
      --backend-dsn=*)
        GEL_SERVER_BACKEND_DSN="${1#*=}"
        shift
        ;;
      --tenant-id)
        _edbdocker_parse_arg "GEL_SERVER_TENANT_ID" "$1" "$2"
        shift 2
        ;;
      --tenant-id=*)
        GEL_SERVER_TENANT_ID="${1#*=}"
        shift
        ;;
      -P|--port)
        _edbdocker_parse_arg "GEL_SERVER_PORT" "$1" "$2"
        shift 2
        ;;
      --port=*)
        GEL_SERVER_PORT="${1#*=}"
        shift
        ;;
      -I|--bind-address)
        _edbdocker_parse_arg "GEL_SERVER_BIND_ADDRESS" "$1" "$2" "true"
        shift 2
        ;;
      --bind-address=*)
        if [ -n "${GEL_SERVER_BIND_ADDRESS:-}" ]; then
          GEL_SERVER_BIND_ADDRESS="${GEL_SERVER_BIND_ADDRESS},${1#*=}"
        else
          GEL_SERVER_BIND_ADDRESS="${1#*=}"
        fi
        shift
        ;;
      --bootstrap-command)
        _edbdocker_parse_arg "GEL_SERVER_BOOTSTRAP_COMMAND" "$1" "$2"
        shift 2
        ;;
      --bootstrap-command=*)
        GEL_SERVER_BOOTSTRAP_COMMAND="${1#*=}"
        shift
        ;;
      --bootstrap-command-file)
        _edbdocker_parse_arg "GEL_SERVER_BOOTSTRAP_COMMAND_FILE" "$1" "$2"
        shift 2
        ;;
      --bootstrap-command-file=*)
        GEL_SERVER_BOOTSTRAP_COMMAND_FILE="${1#*=}"
        shift
        ;;
      --bootstrap-only)
        GEL_SERVER_BOOTSTRAP_ONLY="1"
        shift
        ;;
      --security)
        _edbdocker_parse_arg "GEL_SERVER_SECURITY" "$1" "$2"
        shift 2
        ;;
      --security=*)
        GEL_SERVER_SECURITY="${1#*=}"
        shift
        ;;
      --binary-endpoint-security)
        _edbdocker_parse_arg "GEL_SERVER_BINARY_ENDPOINT_SECURITY" "$1" "$2"
        shift 2
        ;;
      --binary-endpoint-security=*)
        GEL_SERVER_BINARY_ENDPOINT_SECURITY="${1#*=}"
        shift
        ;;
      --http-endpoint-security)
        _edbdocker_parse_arg "GEL_SERVER_HTTP_ENDPOINT_SECURITY" "$1" "$2"
        shift 2
        ;;
      --http-endpoint-security=*)
        GEL_SERVER_HTTP_ENDPOINT_SECURITY="${1#*=}"
        shift
        ;;
      --tls-cert-mode)
        _edbdocker_parse_arg "GEL_SERVER_TLS_CERT_MODE" "$1" "$2"
        shift 2
        ;;
      --tls-cert-mode=*)
        GEL_SERVER_TLS_CERT_MODE="${1#*=}"
        shift
        ;;
      --tls-cert-file)
        _edbdocker_parse_arg "GEL_SERVER_TLS_CERT_FILE" "$1" "$2"
        shift 2
        ;;
      --tls-cert-file=*)
        GEL_SERVER_TLS_CERT_FILE="${1#*=}"
        shift
        ;;
      --tls-key-file)
        _edbdocker_parse_arg "GEL_SERVER_TLS_KEY_FILE" "$1" "$2"
        shift 2
        ;;
      --tls-key-file=*)
        GEL_SERVER_TLS_KEY_FILE="${1#*=}"
        shift
        ;;
      --jws-key-file)
        _edbdocker_parse_arg "GEL_SERVER_JWS_KEY_FILE" "$1" "$2"
        shift 2
        ;;
      --jws-key-file=*)
        GEL_SERVER_JWS_KEY_FILE="${1#*=}"
        shift
        ;;
      --emit-server-status)
        _edbdocker_parse_arg "GEL_SERVER_EMIT_SERVER_STATUS" "$1" "$2"
        shift 2
        ;;
      --emit-server-status=*)
        GEL_SERVER_EMIT_SERVER_STATUS="${1#*=}"
        shift
        ;;
      --admin-ui)
        _edbdocker_parse_arg "GEL_SERVER_ADMIN_UI" "$1" "$2"
        shift 2
        ;;
      --admin-ui=*)
        GEL_SERVER_ADMIN_UI="${1#*=}"
        shift
        ;;
      *)
        _EDGEDB_DOCKER_CMDLINE_ARGS+=( "$1" )
        shift
        ;;
    esac
  done
}


_edbdocker_parse_arg() {
  local var
  local opt
  local val
  local multi
  local curval

  var="$1"
  opt="$2"
  val="$3"
  multi="$4"
  curval="${!var:-}"

  if [ -n "$val" ] && [ "${val:0:1}" != "-" ]; then
    if [ -n "${curval}" ]; then
      if [ -n "${multi}" ]; then
        printf -v "$var" "%s" "${curval},${val}"
      fi
    else
      printf -v "$var" "%s" "$val"
    fi
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
  if [ -n "${GEL_SERVER_BACKEND_DSN}" ]; then
    # shellcheck disable=SC2251
    ! edbdocker_remote_cluster_is_initialized "${GEL_SERVER_BACKEND_DSN}"
  else
    [ -z "$(ls -A "${GEL_SERVER_DATADIR}")" ]
  fi
}


edbdocker_run_server() {
  local server_args
  local -a bind_addrs
  local bind_addr
  local status_file

  if [ -n "${GEL_SERVER_BOOTSTRAP_ONLY}" ]; then
    return
  fi

  if [ -n "${GEL_SERVER_INSTANCE_NAME}" ]; then
    server_args+=(--instance-name="${GEL_SERVER_INSTANCE_NAME}")
  fi

  if [ -n "${GEL_SERVER_LOG_LEVEL}" ]; then
    server_args+=(--log-level="${GEL_SERVER_LOG_LEVEL}")
  fi

  IFS=',' read -ra bind_addrs <<< "$GEL_SERVER_BIND_ADDRESS"
  for bind_addr in "${bind_addrs[@]}"; do
    server_args+=(
      --bind-address="$bind_addr"
    )
  done

  server_args+=( --port="$GEL_SERVER_PORT" )

  if [ -n "${GEL_SERVER_BACKEND_DSN}" ]; then
    server_args+=( --backend-dsn="${GEL_SERVER_BACKEND_DSN}" )
  else
    server_args+=( --data-dir="${GEL_SERVER_DATADIR}" )
  fi

  if [ -n "${GEL_SERVER_RUNSTATE_DIR}" ]; then
    server_args+=( --runstate-dir="${GEL_SERVER_RUNSTATE_DIR}" )
  fi

  if [ -n "${GEL_SERVER_TLS_CERT_MODE}" ]; then
    if edbdocker_server_supports "--tls-cert-mode"; then
      server_args+=(--tls-cert-mode="${GEL_SERVER_TLS_CERT_MODE}")
    elif [ "${GEL_SERVER_TLS_CERT_MODE}" = "generate_self_signed" ] \
         && edbdocker_server_supports "--generate-self-signed-cert"
    then
      server_args+=(--generate-self-signed-cert)
    fi
  fi

  if [ -n "${GEL_SERVER_TLS_CERT_FILE}" ]; then
    server_args+=(--tls-cert-file="${GEL_SERVER_TLS_CERT_FILE}")
  fi

  if [ -n "${GEL_SERVER_TLS_KEY_FILE}" ]; then
    server_args+=(--tls-key-file="${GEL_SERVER_TLS_KEY_FILE}")
  fi

  if [ -n "${GEL_SERVER_JWS_KEY_FILE}" ]; then
    server_args+=(--jws-key-file="${GEL_SERVER_JWS_KEY_FILE}")
  fi

  if [ -n "${GEL_SERVER_EMIT_SERVER_STATUS}" ]; then
    server_args+=(--emit-server-status="${GEL_SERVER_EMIT_SERVER_STATUS}")
  fi

  if [ -n "${GEL_SERVER_ADMIN_UI}" ]; then
    server_args+=(--admin-ui="${GEL_SERVER_ADMIN_UI}")
  fi

  if [ -n "${GEL_SERVER_DEFAULT_AUTH_METHOD}" ] \
     && edbdocker_server_supports "--default-auth-method"
  then
    server_args+=(--default-auth-method="${GEL_SERVER_DEFAULT_AUTH_METHOD}")
  fi

  if [ -n "${GEL_SERVER_BINARY_ENDPOINT_SECURITY}" ]; then
    server_args+=(--binary-endpoint-security="${GEL_SERVER_BINARY_ENDPOINT_SECURITY}")
  fi

  if [ -n "${GEL_SERVER_HTTP_ENDPOINT_SECURITY}" ]; then
    server_args+=(--http-endpoint-security="${GEL_SERVER_HTTP_ENDPOINT_SECURITY}")
  fi

  if [ -n "${GEL_SERVER_COMPILER_POOL_MODE}" ]; then
    server_args+=(--compiler-pool-mode="${GEL_SERVER_COMPILER_POOL_MODE}")
  fi

  if [ -n "${GEL_SERVER_COMPILER_POOL_SIZE}" ]; then
    server_args+=(--compiler-pool-size="${GEL_SERVER_COMPILER_POOL_SIZE}")
  fi

  if [ -n "${GEL_SERVER_TENANT_ID}" ]; then
    server_args+=(--tenant-id="${GEL_SERVER_TENANT_ID}")
  fi

  server_args+=( "${_EDGEDB_DOCKER_CMDLINE_ARGS[@]}" )

  status_file="$(edbdocker_mktemp_for_server)"
  server_args+=( --emit-server-status="$status_file" )
  _edbdocker_print_last_generated_cert_if_needed \
    "$(_edbdocker_wait_for_status "$status_file")" &

  duplicate_envvar_warning "GEL_SERVER_EXTRA_ARGS"
  # shellcheck disable=SC2086
  set -- "$DEFAULT_SERVER_BINARY" "${server_args[@]}" ${GEL_SERVER_EXTRA_ARGS:-${EDGEDB_SERVER_EXTRA_ARGS:-}}

  if [ "$(id -u)" = "0" ]; then
    exec gosu "${GEL_SERVER_UID}" "$@"
  else
    exec "$@"
  fi
}


# Populate important environment variables and make sure they are sane.
edbdocker_setup_env() {
  duplicate_envvar_warning "GEL_DOCKER_SHOW_GENERATED_CERT"
  duplicate_envvar_warning "GEL_DOCKER_APPLY_MIGRATIONS"
  duplicate_envvar_warning "GEL_DOCKER_BOOTSTRAP_TIMEOUT_SEC"
  duplicate_envvar_warning "GEL_SERVER_BINARY_ENDPOINT_SECURITY"
  duplicate_envvar_warning "GEL_SERVER_HTTP_ENDPOINT_SECURITY"
  duplicate_envvar_warning "GEL_SERVER_UID"
  duplicate_envvar_warning "GEL_SERVER_INSTANCE_NAME"
  duplicate_envvar_warning "GEL_SERVER_BINARY"
  duplicate_envvar_warning "GEL_SERVER_DATADIR"
  duplicate_envvar_warning "GEL_SERVER_SECURITY"
  duplicate_envvar_warning "GEL_SERVER_EMIT_SERVER_STATUS"
  duplicate_envvar_warning "GEL_SERVER_ADMIN_UI"
  duplicate_envvar_warning "GEL_SERVER_BOOTSTRAP_ONLY"
  duplicate_envvar_warning "GEL_SERVER_LOG_LEVEL"
  duplicate_envvar_warning "GEL_SERVER_TENANT_ID"
  duplicate_envvar_warning "GEL_SERVER_RUNSTATE_DIR"

  : "${GEL_DOCKER_SHOW_GENERATED_CERT:=${EDGEDB_DOCKER_SHOW_GENERATED_CERT:-default}}"
  : "${GEL_DOCKER_APPLY_MIGRATIONS:=${EDGEDB_DOCKER_APPLY_MIGRATIONS:-default}}"
  : "${GEL_DOCKER_BOOTSTRAP_TIMEOUT_SEC:=${EDGEDB_DOCKER_BOOTSTRAP_TIMEOUT_SEC:-300}}"
  : "${GEL_SERVER_BINARY_ENDPOINT_SECURITY:=${EDGEDB_SERVER_BINARY_ENDPOINT_SECURITY:-}}"
  : "${GEL_SERVER_HTTP_ENDPOINT_SECURITY:=${EDGEDB_SERVER_HTTP_ENDPOINT_SECURITY:-}}"
  : "${GEL_SERVER_UID:=${EDGEDB_SERVER_UID:-$DEFAULT_OS_USER}}"
  : "${GEL_SERVER_INSTANCE_NAME:=${EDGEDB_SERVER_INSTANCE_NAME:-}}"
  : "${GEL_SERVER_BINARY:=${EDGEDB_SERVER_BINARY:-$DEFAULT_SERVER_BINARY}}"
  : "${GEL_SERVER_DATADIR:=${EDGEDB_SERVER_DATADIR:-}}"
  : "${GEL_SERVER_BACKEND_DSN:=}"
  : "${GEL_SERVER_PASSWORD:=}"
  : "${GEL_SERVER_PASSWORD_HASH:=}"
  : "${GEL_SERVER_SECURITY:=${EDGEDB_SERVER_SECURITY:-}}"
  : "${GEL_SERVER_EMIT_SERVER_STATUS:=${EDGEDB_SERVER_EMIT_SERVER_STATUS:-}}"
  : "${GEL_SERVER_ADMIN_UI:=${EDGEDB_SERVER_ADMIN_UI:-}}"
  : "${GEL_SERVER_BOOTSTRAP_ONLY:=${EDGEDB_SERVER_BOOTSTRAP_ONLY:-}}"
  : "${GEL_SERVER_DEFAULT_AUTH_METHOD:=}"
  : "${GEL_SERVER_LOG_LEVEL:=${EDGEDB_SERVER_LOG_LEVEL:-}}"
  : "${GEL_SERVER_TLS_CERT_MODE:=}"
  : "${GEL_SERVER_TLS_CERT_FILE:=}"
  : "${GEL_SERVER_TLS_KEY_FILE:=}"
  : "${GEL_SERVER_JWS_KEY_FILE:=}"
  : "${GEL_SERVER_BOOTSTRAP_COMMAND:=}"
  : "${GEL_SERVER_COMPILER_POOL_MODE:=}"
  : "${GEL_SERVER_COMPILER_POOL_SIZE:=}"
  : "${GEL_SERVER_TENANT_ID:=${EDGEDB_SERVER_TENANT_ID:-}}"
  : "${GEL_SERVER_RUNSTATE_DIR:=${EDGEDB_SERVER_RUNSTATE_DIR:-}}"

  if [ -z "${GEL_SERVER_UID:-}" ]; then
    if [ "$(id -u)" = "0" ]; then
      GEL_SERVER_UID="$DEFAULT_OS_USER"
    else
      GEL_SERVER_UID="$(id -un)"
    fi
  fi

  if [ -z "${GEL_SERVER_RUNSTATE_DIR:-}" ]; then
    if [ "$(id -u)" = "0" ]; then
      GEL_SERVER_RUNSTATE_DIR="/run/${BRANDING}"
    else
      GEL_SERVER_RUNSTATE_DIR="/tmp/${BRANDING}"
    fi
  fi

  if [ "${GEL_DOCKER_SHOW_GENERATED_CERT}" = "default" ]; then
    GEL_DOCKER_SHOW_GENERATED_CERT="always"
  elif [ "${GEL_DOCKER_SHOW_GENERATED_CERT}" = "always" ] \
       || [ "${GEL_DOCKER_SHOW_GENERATED_CERT}" = "never" ]
  then
    :
  else
    edbdocker_die "ERROR: invalid value for GEL_DOCKER_SHOW_GENERATED_CERT: ${GEL_DOCKER_SHOW_GENERATED_CERT}, supported values are: always, never, default."
  fi

  if [ "${GEL_DOCKER_APPLY_MIGRATIONS}" = "default" ]; then
    GEL_DOCKER_APPLY_MIGRATIONS="always"
  elif [ "${GEL_DOCKER_APPLY_MIGRATIONS}" = "always" ] \
       || [ "${GEL_DOCKER_APPLY_MIGRATIONS}" = "never" ]
  then
    :
  else
    edbdocker_die "ERROR: invalid value for GEL_DOCKER_APPLY_MIGRATIONS: ${GEL_DOCKER_APPLY_MIGRATIONS}, supported values are: always, never, default."
  fi

  if [ "${VERSION_MAJOR}" -ge 6 ]; then
    DEFAULT_SERVER_USER="admin"
  else
    DEFAULT_SERVER_USER="edgedb"
  fi

  edbdocker_lookup_env_var "GEL_SERVER_PORT" "5656"
  edbdocker_lookup_env_var "GEL_SERVER_BIND_ADDRESS" "0.0.0.0,::"
  edbdocker_lookup_env_var "GEL_SERVER_DEFAULT_AUTH_METHOD" "default"
  edbdocker_lookup_env_var "GEL_SERVER_USER" "$DEFAULT_SERVER_USER"
  edbdocker_lookup_env_var "EDGEDB_SERVER_DATABASE"
  edbdocker_lookup_env_var "GEL_SERVER_DEFAULT_BRANCH"
  edbdocker_lookup_env_var "GEL_SERVER_PASSWORD"
  edbdocker_lookup_env_var "GEL_SERVER_PASSWORD_HASH"
  edbdocker_lookup_env_var "GEL_SERVER_BACKEND_DSN"
  edbdocker_lookup_env_var "GEL_SERVER_JWS_KEY" "" true
  edbdocker_lookup_env_var "GEL_SERVER_TLS_KEY" "" true
  edbdocker_lookup_env_var "GEL_SERVER_TLS_CERT" "" true
  edbdocker_lookup_env_var "GEL_SERVER_TLS_CERT_MODE"
  edbdocker_lookup_env_var "GEL_SERVER_BOOTSTRAP_COMMAND"
  edbdocker_lookup_env_var "GEL_SERVER_COMPILER_POOL_MODE"
  edbdocker_lookup_env_var "GEL_SERVER_COMPILER_POOL_SIZE"

  if [ "${VERSION_MAJOR}" -ge 5 ]; then
    if [ -n "${EDGEDB_SERVER_DATABASE}" ]; then
      if [ -n "${GEL_SERVER_DEFAULT_BRANCH}" ]; then
        edbdocker_die "ERROR: EDGEDB_SERVER_DATABASE and GEL_SERVER_DEFAULT_BRANCH are mutually exclusive, but both are set"
      else
        msg=(
          "======================================================="
          "WARNING: EDGEDB_SERVER_DATABASE is deprecated.      "
          "         Use GEL_SERVER_DEFAULT_BRANCH instead."
          "======================================================="
        )
        edbdocker_log_at_level "warning" "${msg[@]}"
        GEL_SERVER_DEFAULT_BRANCH="${EDGEDB_SERVER_DATABASE}"
      fi
    else
      if [ -z "${GEL_SERVER_DEFAULT_BRANCH}" ]; then
        GEL_SERVER_DEFAULT_BRANCH="main"
      fi
    fi
  else
    if [ -n "${GEL_SERVER_DEFAULT_BRANCH}" ]; then
      msg=(
        "======================================================="
        "WARNING: GEL_SERVER_DEFAULT_BRANCH is ignored"
        "         on server versions prior to 5.0."
        "======================================================="
      )
      edbdocker_log_at_level "warning" "${msg[@]}"
    fi
    if [ -z "${EDGEDB_SERVER_DATABASE}" ]; then
      EDGEDB_SERVER_DATABASE="edgedb"
    fi
  fi

  if [ -n "${GEL_SERVER_TLS_KEY_FILE}" ] && [ -z "${GEL_SERVER_TLS_CERT_FILE}" ]; then
    edbdocker_die "ERROR: GEL_SERVER_TLS_CERT_FILE must be set when GEL_SERVER_TLS_KEY_FILE is set"
  fi

  if [ -n "${GEL_SERVER_TLS_CERT_FILE}" ] && [ -z "${GEL_SERVER_TLS_KEY_FILE}" ]; then
    edbdocker_die "ERROR: GEL_SERVER_TLS_KEY_FILE must be set when GEL_SERVER_TLS_CERT_FILE is set"
  fi

  if [ -n "${GEL_SERVER_DATADIR}" ] && [ -n "${GEL_SERVER_BACKEND_DSN}" ]; then
    edbdocker_die "ERROR: GEL_SERVER_DATADIR and GEL_SERVER_BACKEND_DSN are mutually exclusive, but both are set"
  elif [ -z "${GEL_SERVER_BACKEND_DSN}" ]; then
    GEL_SERVER_DATADIR="${GEL_SERVER_DATADIR:-/var/lib/$BRANDING/data}"
  fi

  if [ -n "${GEL_SERVER_PASSWORD}" ] && [ -n "${GEL_SERVER_PASSWORD_HASH}" ]; then
    edbdocker_die "ERROR: GEL_SERVER_PASSWORD and GEL_SERVER_PASSWORD_HASH are mutually exclusive, but both are set"
  fi

  if [ -z "${GEL_SERVER_HTTP_ENDPOINT_SECURITY}" ]; then
    GEL_SERVER_HTTP_ENDPOINT_SECURITY="optional"
  fi

  if [ "${GEL_SERVER_SECURITY}" = "insecure_dev_mode" ]; then
    if [ -z "${GEL_SERVER_TLS_CERT_FILE}" ] \
       && [ -z "${GEL_SERVER_TLS_CERT_MODE}" ]
    then
      GEL_SERVER_TLS_CERT_MODE="generate_self_signed"
    fi

    if [ -z "${GEL_SERVER_PASSWORD}" ] \
       && [ -z "${GEL_SERVER_PASSWORD_HASH}" ] \
       && [ "${GEL_SERVER_DEFAULT_AUTH_METHOD}" = "default" ]
    then
      GEL_SERVER_DEFAULT_AUTH_METHOD="Trust"
    fi

    if [ -z "${GEL_SERVER_HTTP_ENDPOINT_SECURITY}" ]; then
      GEL_SERVER_HTTP_ENDPOINT_SECURITY="optional"
    fi
  fi

  mkdir -p "/tmp/$BRANDING"
  if [ "$(id -u)" = "0" ]; then
    chown "${GEL_SERVER_UID}" "/tmp/$BRANDING"
  fi

  if [ -z "${GEL_SERVER_TLS_CERT_FILE}" ]; then
    if [ -z "${GEL_SERVER_DATADIR}" ]; then
      GEL_SERVER_TLS_CERT_FILE="/tmp/$BRANDING/edbtlscert.pem"
      GEL_SERVER_TLS_KEY_FILE="/tmp/$BRANDING/edbprivkey.pem"
    else
      GEL_SERVER_TLS_CERT_FILE="${GEL_SERVER_DATADIR}/edbtlscert.pem"
      GEL_SERVER_TLS_KEY_FILE="${GEL_SERVER_DATADIR}/edbprivkey.pem"
    fi
  fi

  echo "GEL_SERVER_TLS_CERT=${GEL_SERVER_TLS_CERT_FILE}" >"/tmp/${BRANDING}/secrets"
  echo "GEL_SERVER_TLS_KEY=${GEL_SERVER_TLS_KEY_FILE}" >>"/tmp/${BRANDING}/secrets"
  echo "GEL_SERVER_JWS_KEY=${GEL_SERVER_JWS_KEY_FILE}" >>"/tmp/${BRANDING}/secrets"

  if [ "${GEL_SERVER_DEFAULT_AUTH_METHOD}" = "default" ]; then
    GEL_SERVER_DEFAULT_AUTH_METHOD="SCRAM"
  elif [ "${GEL_SERVER_DEFAULT_AUTH_METHOD,,}" = "scram" ]; then
    GEL_SERVER_DEFAULT_AUTH_METHOD="SCRAM"
  elif [ "${GEL_SERVER_DEFAULT_AUTH_METHOD,,}" = "trust" ]; then
    GEL_SERVER_DEFAULT_AUTH_METHOD="Trust"
  else
    edbdocker_die "ERROR: unsupported auth method: \"${GEL_SERVER_DEFAULT_AUTH_METHOD}\""
  fi
}


# Resolve the value of the specified variable.
#
# Usage: edbdocker_lookup_env_var VARNAME [default] [prefer-file]
#
# The function looks for $VARNAME in the environment block directly,
# and also tries to read the value from ${VARNAME}_FILE, if set.
# For example, `edbdocker_lookup_env_var GEL_SERVER_PASSWORD foo` would
# look for $GEL_SERVER_PASSWORD, the file specified by $GEL_SERVER_PASSWORD_FILE,
# and if neither is set, default to 'foo'.  If *prefer-file* is passed as
# `true`, then if the value is specified in the environemnt variable,
# it is written into a temporary file and ${VARNAME}_FILE is set to point
# to it.
edbdocker_lookup_env_var() {
  local var
  local file_var
  local old_var
  local old_file_var
  local deflt
  local prefer_file
  local val
  local var_val
  local file_var_val
  local old_var_val
  local old_file_var_val

  var="$1"
  file_var="${var}_FILE"
  alt_var="${var}_ENV"
  old_var="${var/GEL_SERVER_/EDGEDB_SERVER_}"
  old_file_var="${old_var}_FILE"
  old_alt_var="${old_var}_ENV"
  deflt="${2:-}"
  prefer_file="${3:-}"
  val="$deflt"
  var_val="${!var:-}"
  file_var_val="${!file_var:-}"
  alt_var_val="${!alt_var:-}"
  old_var_val="${!old_var:-}"
  old_file_var_val="${!old_file_var:-}"
  old_alt_var_val="${!old_alt_var:-}"

  # keep track of the variable names to use in error messages
  var_origin="$var"
  file_var_origin="$file_var"
  alt_var_origin="$alt_var"

  if [ -n "${old_var_val}" ]; then
    msg=(
      "=============================================================== "
      "WARNING: ${old_var} is deprecated use ${var} instead.           "
      "=============================================================== "
    )
    edbdocker_log_at_level "warning" "${msg[@]}"

    if [ -n "${var_val}" ]; then
      duplicate_envvar_warning "${var}"
    else
      var_val="${old_var_val}"
      var_origin="$old_var"
    fi
    unset "$old_var"
  fi

  if [ -n "${old_file_var_val}" ]; then
    msg=(
      "=============================================================== "
      "WARNING: ${old_file_var} is deprecated use ${file_var} instead. "
      "=============================================================== "
    )
    edbdocker_log_at_level "warning" "${msg[@]}"

    if [ -n "${file_var_val}" ]; then
      duplicate_envvar_warning "${file_var}"
    else
      file_var_val="${old_file_var_val}"
      file_var_origin="$old_file_var"
    fi
    unset "$old_file_var"
  fi

  if [ -n "${old_alt_var_val}" ]; then
    msg=(
      "============================================================= "
      "WARNING: ${old_alt_var} is deprecated use ${alt_var} instead. "
      "============================================================= "
    )
    edbdocker_log_at_level "warning" "${msg[@]}"

    if [ -n "${alt_var_val}" ]; then
      duplicate_envvar_warning "${alt_var}"
    else
      alt_var_val="${old_alt_var_val}"
      alt_var_origin="$old_alt_var"
    fi
    unset "$old_alt_var"
  fi

  if [ "$var" == "GEL_SERVER_PASSWORD" ] || [ "$var" == "GEL_SERVER_PORT" ]; then
    client_var="${var/_SERVER_/_}"
    client_var_val="${!client_var:-}"

    client_file_var="${client_var}_FILE"
    client_file_var_val="${!client_file_var:-}"

    old_client_var="${old_var/_SERVER_/_}"
    old_client_var_val="${!old_client_var:-}"

    old_client_file_var="${old_client_var}_FILE"
    old_client_file_var_val="${!old_client_file_var:-}"

    # keep track of variable names to use in error messages
    client_var_origin="$client_var"
    client_file_var_origin="$client_file_var"

    if [ -n "${old_client_var_val}" ]; then
      msg=(
        "=================================================================== "
        "WARNING: ${old_client_var} is deprecated use ${client_var} instead. "
        "=================================================================== "
      )
      edbdocker_log_at_level "warning" "${msg[@]}"

      if [ -n "${client_var_val}" ]; then
        duplicate_envvar_warning "${client_var}"
      else
        client_var_val="${old_client_var_val}"
        client_var_origin="$old_client_var"
      fi
      unset "$old_client_var"
    fi

    if [ -n "$client_var_val" ]; then
      if [ -n "$var_val" ]; then
        edbdocker_die \
          "ERROR: ${var_origin} and ${client_var_origin} are exclusive, but both are set."
      else
        var_val="$client_var_val"
        var_origin="$client_var_origin"
        unset "$client_var"
      fi
    fi

    if [ -n "${old_client_file_var_val}" ]; then
      msg=(
        "============================================================================= "
        "WARNING: ${old_client_file_var} is deprecated use ${client_file_var} instead. "
        "============================================================================= "
      )
      edbdocker_log_at_level "warning" "${msg[@]}"

      if [ -n "${client_file_var_val}" ]; then
        duplicate_envvar_warning "${client_file_var}"
      else
        client_file_var_val="${old_client_file_var_val}"
        client_file_var_origin="$old_client_file_var"
      fi
      unset "$old_client_file_var"
    fi

    if [ -n "$client_file_var_val" ]; then
      if [ -n "$file_var_val" ]; then
        edbdocker_die \
          "ERROR: ${file_var_origin} and ${client_file_var_origin} are exclusive, but both are set."
      else
        file_var_val="$client_file_var_val"
        file_var_origin="$client_file_var_origin"
        unset "$client_file_var"
      fi
    fi
  fi

  if [ -n "${var_val}" ] && [ -n "${file_var_val}" ]; then
    edbdocker_die \
      "ERROR: ${var_origin} and ${file_var_origin} are exclusive, but both are set."
  fi

  if [ -n "${var_val}" ] && [ -n "${alt_var_val}" ]; then
    edbdocker_die \
      "ERROR: ${var_origin} and ${alt_var_origin} are exclusive, but both are set."
  fi

  if [ -n "${file_var_val}" ] && [ -n "${alt_var_val}" ]; then
    edbdocker_die \
      "ERROR: ${file_var_origin} and ${alt_var_origin} are exclusive, but both are set."
  fi

  if [ "${alt_var_val}" ]; then
    var_val="${!alt_var_val:-}"
  fi

  if [ -n "${var_val}" ]; then
    val="${var_val}"
    if [ "${prefer_file}" = "true" ]; then
      file_var_val=$(mktemp)
      echo -n "${val}" > "${file_var_val}"
      if [ "$(id -u)" = "0" ]; then
        chown "${GEL_SERVER_UID}" "${file_var_val}"
      fi
    fi
  elif [ "${file_var_val}" ]; then
    if [ -e "${file_var_val}" ]; then
      val="$(< "${file_var_val}")"
    else
      edbdocker_die \
        "ERROR: the file specified by ${file_var_origin} (${file_var_val}) does not exist."
    fi
  fi

  if [ "${prefer_file}" = "true" ]; then
    printf -v "$file_var" "%s" "$file_var_val"
    unset "$var"
  else
    printf -v "$var" "%s" "$val"
    unset "$file_var"
  fi
}


# Create directories required by EdgeDB server and set correct permissions
# if running as root.
edbdocker_ensure_dirs() {
  if [ -n "${GEL_SERVER_DATADIR}" ]; then
    mkdir -p "${GEL_SERVER_DATADIR}"
    chmod 700 "${GEL_SERVER_DATADIR}" || :

    if [ "$(id -u)" = "0" ]; then
      chown -R "${GEL_SERVER_UID}" "${GEL_SERVER_DATADIR}"
    fi
  else
    unset GEL_SERVER_DATADIR
  fi

  mkdir -p "${GEL_SERVER_RUNSTATE_DIR}"
  chmod 775 "${GEL_SERVER_RUNSTATE_DIR}"

  if [ "$(id -u)" = "0" ]; then
    chown -R "${GEL_SERVER_UID}" "${GEL_SERVER_RUNSTATE_DIR}"
  fi
}


# Check if the specified Postgres DSN contains an initialized EdgeDB instance.
# Returns 0 if so, 1 otherwise.
edbdocker_remote_cluster_is_initialized() {
  local pg_dsn
  local psql

  pg_dsn="$1"
  psql="$(dirname "$(readlink -f "/usr/bin/${DEFAULT_SERVER_BINARY}")")/psql"

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
# GEL_SERVER_DATADIR or GEL_SERVER_BACKEND_DSN to be set in the environment.
# Optionally takes extra server arguments.  Bootstrap is performed by
# a temporary edgedb-server process that gets started on a random port
# and is shut down once bootstrap is complete.
#
# Usage: `GEL_SERVER_DATADIR=/foo/bar edbdocker_bootstrap_instance --arg=val`
edbdocker_bootstrap_instance() {
  local bootstrap_cmd
  local bootstrap_opts
  local conn_opts

  bootstrap_cmd=""
  bootstrap_opts=( "$@" )

  if [ -n "${GEL_SERVER_BOOTSTRAP_COMMAND}" ]; then
    bootstrap_opts+=(--bootstrap-command="${GEL_SERVER_BOOTSTRAP_COMMAND}")

  elif [ -e "/gel-bootstrap.edgeql" ]; then
    if edbdocker_server_supports "--bootstrap-command-file"; then
        bootstrap_opts+=(--bootstrap-command-file="/gel-bootstrap.edgeql")
    else
        bootstrap_opts+=(--bootstrap-script="/gel-bootstrap.edgeql")
    fi

  elif [ -e "/edgedb-bootstrap.edgeql" ]; then
    if edbdocker_server_supports "--bootstrap-command-file"; then
        bootstrap_opts+=(--bootstrap-command-file="/edgedb-bootstrap.edgeql")
    else
        bootstrap_opts+=(--bootstrap-script="/edgedb-bootstrap.edgeql")
    fi

  else
    if [ -n "${GEL_SERVER_PASSWORD_HASH}" ]; then
      if [ "$GEL_SERVER_USER" = "$DEFAULT_SERVER_USER" ]; then
        bootstrap_cmd="ALTER ROLE ${GEL_SERVER_USER} { SET password_hash := '${GEL_SERVER_PASSWORD_HASH}'; }"
      else
        bootstrap_cmd="CREATE SUPERUSER ROLE ${GEL_SERVER_USER} { SET password_hash := '${GEL_SERVER_PASSWORD_HASH}'; }"
      fi
    elif [ -n "${GEL_SERVER_PASSWORD}" ]; then
      if [[ "$GEL_SERVER_USER" = "$DEFAULT_SERVER_USER" ]]; then
        bootstrap_cmd="ALTER ROLE ${GEL_SERVER_USER} { SET password := '${GEL_SERVER_PASSWORD}'; }"
      else
        bootstrap_cmd="CREATE SUPERUSER ROLE ${GEL_SERVER_USER} { SET password := '${GEL_SERVER_PASSWORD}'; }"
      fi
    elif [ "${GEL_SERVER_DEFAULT_AUTH_METHOD}" = "Trust" ] ; then
      if ! edbdocker_server_supports "--default-auth-method"; then
        bootstrap_cmd="CONFIGURE INSTANCE INSERT Auth {priority := 0, method := (INSERT Trust)};"
      fi
      msg=(
        "================================================================"
        "                          WARNING                               "
        "                          -------                               "
        "                                                                "
        "GEL_SERVER_DEFAULT_AUTH_METHOD is set to 'Trust'.  This will    "
        "allow unauthenticated access to this Gel instance for all who   "
        "have access to the database port! This might include other      "
        "containers or processes on the same host and, if port ${GEL_SERVER_PORT}"
        "is bound to an accessible interface on the host, other machines "
        "on the network.                                                 "
        "                                                                "
        "Use only for DEVELOPMENT and TESTING in a known environment     "
        "without sensitive data.  Otherwise, it is strongly recommended  "
        "to use password authentication via the GEL_SERVER_PASSWORD      "
        "or GEL_SERVER_PASSWORD_HASH environment variables.              "
        "================================================================"
      )
      edbdocker_log_at_level "warning" "${msg[@]}"
    else
      msg=(
        "================================================================"
        "                           ERROR                                "
        "                           -----                                "
        "                                                                "
        "The Gel instance at the specified location is not initialized   "
        "and superuser password has not been specified. Please set either"
        "the GEL_SERVER_PASSWORD or the GEL_SERVER_PASSWORD_FILE         "
        "environment variable to a non-empty value.                      "
        "                                                                "
        "For example:                                                    "
        "                                                                "
        "$ docker run -e GEL_SERVER_PASSWORD_FILE=/pass ${BRANDING}/${BRANDING} "
        "                                                                "
        "Alternatively, if doing local development and database security "
        "is not a concern, set the GEL_SERVER_SECURITY environment       "
        "variable to 'insecure_dev_mode' value, which would disable      "
        "password authentication and let this Gel server use a self-     "
        "signed TLS certificate.                                         "
      )
      edbdocker_die "${msg[@]}"
    fi

    if [ -n "$bootstrap_cmd" ]; then
      bootstrap_opts+=( --bootstrap-command="$bootstrap_cmd" )
    fi
  fi

  if [ -n "${GEL_SERVER_BACKEND_DSN}" ]; then
    edbdocker_log_at_level "info" "Bootstrapping Gel instance on remote Postgres cluster..."
  else
    edbdocker_log_at_level "info" "Bootstrapping Gel instance on the local volume..."
  fi

  edbdocker_run_temp_server \
    _edbdocker_bootstrap_cb \
    _edbdocker_bootstrap_abort_cb \
    "" \
    "${bootstrap_opts[@]}"
}


_edbdocker_bootstrap_run_hooks() {
  local dir
  local -a opts
  local -a env

  dir="$1"
  shift

  if [ -d "${dir}" ]; then
    local opt
    local seen_dashdash

    seen_dashdash=""

    for opt in "$@"; do
      if [ -z "$seen_dashdash" ]; then
        if [ "$opt" = "--" ]; then
          seen_dashdash="1"
        else
          env+=( "$opt" )
        fi
      else
        opts+=( "$opt" )
      fi
    done

    if [ "$(id -u)" = "0" ]; then
      gosu "${GEL_SERVER_UID}" \
        env "${env[@]}" /bin/run-parts --verbose "$dir" --regex='\.sh$'
    else
      env "${env[@]}" /bin/run-parts --verbose "$dir" --regex='\.sh$'
    fi

    # Feeding scripts one by one, so that errors are easier to debug
    for filename in $(/bin/run-parts --list "$dir" --regex='\.edgeql$'); do
      edbdocker_log_at_level "info" "Bootstrap script $filename"
      if [ "$(id -u)" = "0" ]; then
        gosu "${GEL_SERVER_UID}" \
          env "${env[@]}" edgedb "${opts[@]}" <"$filename"
      else
        env "${env[@]}" edgedb "${opts[@]}" <"$filename"
      fi
    done
  fi
}


_edbdocker_bootstrap_cb() {
  local -a conn_opts
  local dir
  local status

  status="$1"
  shift
  conn_opts+=( "$@" )

  _edbdocker_print_last_generated_cert_if_needed "$status"

  if [ "${VERSION_MAJOR}" -lt 5 ]; then
    if [ "${EDGEDB_SERVER_DATABASE}" != "edgedb" ]; then
      echo "CREATE DATABASE \`${EDGEDB_SERVER_DATABASE}\`;" \
        | edbdocker_cli "${conn_opts[@]}" -- --database="edgedb"
    fi
  fi

  if [ -d "/gel-bootstrap.d" ]; then
    _edbdocker_bootstrap_run_hooks "/gel-bootstrap.d" "${conn_opts[@]}"
  elif [ -d "/edgedb-bootstrap.d" ]; then
    _edbdocker_bootstrap_run_hooks "/edgedb-bootstrap.d" "${conn_opts[@]}"
  fi


  if [ -d "/dbschema" ] && [ "${GEL_DOCKER_APPLY_MIGRATIONS}" != "never" ]; then
    if ! _edbdocker_migrations_cb "" "${conn_opts[@]}"; then
      return 1
    fi
  fi

  if [ -d "/gel-bootstrap-late.d" ]; then
    _edbdocker_bootstrap_run_hooks "/gel-bootstrap-late.d" "${conn_opts[@]}"
  elif [ -d "/edgedb-bootstrap-late.d" ]; then
    _edbdocker_bootstrap_run_hooks "/edgedb-bootstrap-late.d" "${conn_opts[@]}"
  fi
}


_edbdocker_bootstrap_abort_cb() {
  local datadir
  datadir="${GEL_SERVER_DATADIR:-}"

  if [ -n "$datadir" ] && [ -e "$datadir" ]; then
    (shopt -u nullglob; rm -rf "${datadir:?}/"* || :)
  fi

  edbdocker_die "$1"
}


# Runs schema migrations found in /dbschema unless
# GEL_DOCKER_APPLY_MIGRATIONS=never.  Expects either GEL_SERVER_DATADIR
# or GEL_SERVER_BACKEND_DSN to be set in the environment.  Migrations are
# applied by a temporary edgedb-server process that gets started on a random
# port and is shut down once bootstrap is complete.
#
# Usage: `GEL_SERVER_DATADIR=/foo/bar edbdocker_run_migrations`
edbdocker_run_migrations() {
  if [ -d "/dbschema" ] && [ "${GEL_DOCKER_APPLY_MIGRATIONS}" != "never" ]; then
    edbdocker_log_at_level "info" "Applying schema migrations..."
    edbdocker_run_temp_server \
      _edbdocker_migrations_cb \
      _edbdocker_migrations_abort_cb
  fi
}


_edbdocker_migrations_cb() {
  shift  # Ignore the server status data in the first argument.
  if ! [ -e /dbschema/migrations ]; then
    return 0
  fi
  if ! edbdocker_cli "${@}" -- migrate --schema-dir=/dbschema; then
    edbdocker_log "ERROR: Migrations failed. Stopping server."
    return 1
  fi
}


_edbdocker_migrations_abort_cb() {
  edbdocker_die "$1"
}


edbdocker_cli() {
  local -a opts
  local -a env
  local opt
  local seen_dashdash

  seen_dashdash=""

  for opt in "$@"; do
    if [ -z "$seen_dashdash" ]; then
      if [ "$opt" = "--" ]; then
        seen_dashdash="1"
      else
        env+=( "$opt" )
      fi
    else
      opts+=( "$opt" )
    fi
  done

  if [ "$(id -u)" = "0" ]; then
    gosu "${GEL_SERVER_UID}" env "${env[@]}" edgedb "${opts[@]}"
  else
    env "${env[@]}" edgedb "${opts[@]}"
  fi
}


edbdocker_log_no_tls_cert() {
  local msg
  msg=(
    "======================================================================="
    "                                 ERROR                                 "
    "                                 -----                                 "
    "                                                                       "
    "Gel server requires a TLS certificate and a corresponding private      "
    "key to operate.  You can either provide them by setting the            "
    "GEL_SERVER_TLS_CERT_FILE and GEL_SERVER_TLS_KEY_FILE environment       "
    "variables to an existing certificate and private key, or set           "
    "GEL_SERVER_TLS_CERT_MODE=generate_self_signed to generate              "
    "a self-signed certificate automatically.                               "
    "======================================================================="
  )
  edbdocker_log_at_level "error" "${msg[@]}"
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


# Log arguments to stderr using `edbdocker_log` and exit with
# $EDGEDB_DOCKER_ABORT_CODE.
edbdocker_die() {
  edbdocker_log "${@}"
  exit $EDGEDB_DOCKER_ABORT_CODE
}


# Usage: edbdocker_log_at_level <level> args...
# Logs arguments to stderr if the specified <level> is greater or equal
# to the configured GEL_DOCKER_LOG_LEVEL.
edbdocker_log_at_level() {
  local level
  local msg_level_no
  local output_level_no

  level=$1
  shift 1
  msg_level_no="${_edbdocker_log_levels[$level]:-}"
  output_level_no="${_edbdocker_log_levels[${GEL_DOCKER_LOG_LEVEL:-info}]}"

  if [ -z "$msg_level_no" ]; then
    edbdocker_die "unknown level passed to edbdocker_log_at_level: \"$level\""
  fi

  if [ "$msg_level_no" -ge "$output_level_no" ]; then
    edbdocker_log "${@}"
  fi
}


# Check if the server supports a given command-line argument.
edbdocker_server_supports() {
  local srv
  srv="${GEL_SERVER_BINARY:-$DEFAULT_SERVER_BINARY}"

  if "${srv}" --help | grep -- "$1" >/dev/null; then
    return 0
  else
    return 1
  fi
}


# Start edgedb-server on a random port, execute the specified callback
# and shut down the server.
#
# Usage: `edbdocker_run_temp_server callback abort_callback status_var --server-arg=val ...`
edbdocker_run_temp_server() {
  local server_pid
  local timeout_pid
  local timeout
  local runstate_dir
  local port
  local ecode
  local emsg
  local -a conn_opts
  local callback
  local abort_callback
  local result
  local status_file
  local tls_cert_file
  local status
  local status_var
  local -a server_opts

  result=0
  callback="${1:-}"
  abort_callback="${2:-}"
  status_var="${3:-}"
  emsg="ERROR: Could not complete instance bootstrap"

  if [ $# -gt 3 ]; then
    shift 3
    server_opts=( "${@}" )
  fi

  if [ -n "${GEL_SERVER_BACKEND_DSN}" ]; then
    if edbdocker_server_supports "--backend-dsn"; then
      server_opts+=(--backend-dsn="${GEL_SERVER_BACKEND_DSN}")
    else
      server_opts+=(--postgres-dsn="${GEL_SERVER_BACKEND_DSN}")
    fi
  else
    server_opts+=(--data-dir="${GEL_SERVER_DATADIR}")
  fi

  if [ -n "${GEL_SERVER_INSTANCE_NAME}" ]; then
    server_opts+=(--instance-name="${GEL_SERVER_INSTANCE_NAME}")
  fi

  if [ -n "${GEL_SERVER_LOG_LEVEL}" ]; then
    server_opts+=(--log-level="${GEL_SERVER_LOG_LEVEL}")
  fi

  if [ -n "${GEL_SERVER_TENANT_ID}" ]; then
    server_opts+=(--tenant-id="${GEL_SERVER_TENANT_ID}")
  fi

  if [ -n "${GEL_SERVER_TLS_CERT_MODE}" ]; then
    if edbdocker_server_supports "--tls-cert-mode"; then
      server_opts+=(--tls-cert-mode="${GEL_SERVER_TLS_CERT_MODE}")
    elif [ "${GEL_SERVER_TLS_CERT_MODE}" = "generate_self_signed" ] \
         && edbdocker_server_supports "--generate-self-signed-cert"
    then
      server_opts+=(--generate-self-signed-cert)
    fi
  fi

  if [ -n "${GEL_SERVER_TLS_CERT_FILE}" ] \
     && edbdocker_server_supports "--tls-cert-file"
  then
    server_opts+=(--tls-cert-file="${GEL_SERVER_TLS_CERT_FILE}")
  fi

  if [ -n "${GEL_SERVER_TLS_KEY_FILE}" ] \
     && edbdocker_server_supports "--tls-key-file"
  then
    server_opts+=(--tls-key-file="${GEL_SERVER_TLS_KEY_FILE}")
  fi

  if [ "${VERSION_MAJOR}" -ge 5 ]; then
    if [ -n "${GEL_SERVER_DEFAULT_BRANCH}" ]; then
      server_opts+=(--default-branch="${GEL_SERVER_DEFAULT_BRANCH}")
    fi
  fi

  if edbdocker_server_supports "--compiler-pool-mode"; then
    server_opts+=(--compiler-pool-mode="on_demand")
  fi

  runstate_dir="$(edbdocker_mktemp_for_server -d)"
  status_file="$(edbdocker_mktemp_for_server)"

  server_opts+=(
    --default-auth-method="Trust"
    --runstate-dir="$runstate_dir"
    --port="auto"
    --bind-address="127.0.0.1"
    --emit-server-status="$status_file"
  )

  # Collect PG* env vars to pass through
  declare -a pg_vars
  for var in $(env | grep -E "^PG" | cut -d '=' -f 1); do
    pg_vars+=("$var=${!var}")
  done

  # Start the server
  if [ "$(id -u)" = "0" ]; then
    gosu "${GEL_SERVER_UID}" \
      env -i "${pg_vars[@]}" "${GEL_SERVER_BINARY}" "${server_opts[@]}" &
  else
    env -i "${pg_vars[@]}" "${GEL_SERVER_BINARY}" "${server_opts[@]}" &
  fi
  server_pid="$!"

  timeout="$GEL_DOCKER_BOOTSTRAP_TIMEOUT_SEC"

  function _abort() {
    if [ -n "${abort_callback}" ]; then
      $abort_callback "${@}"
    fi
    result=1
  }

  status=$(_edbdocker_wait_for_status "$status_file" "$server_pid" "$timeout")

  if [ -n "$status_var" ]; then
    local -n status_var_ref="$status_var"
    # shellcheck disable=SC2034
    status_var_ref="$status"
  fi

  if [ -n "$status" ] && [[ "$status" != READY=* ]]; then
    _abort "could not start server" "$status"
    status=""
  elif [ -n "$status" ] && [[ $status == READY=* ]]; then
    local srvdata="${status#READY=}"

    port=$(echo "$srvdata" | jq -r ".port")
    tls_cert_file=$(echo "$srvdata" | jq -r '.tls_cert_file // ""')

    conn_opts=(
      GEL_HOST="127.0.0.1"
      GEL_PORT="${port}"
      GEL_CLIENT_TLS_SECURITY="insecure"
    )

    if [ "${VERSION_MAJOR}" -lt 5 ]; then
      conn_opts+=(
        EDGEDB_DATABASE="$EDGEDB_SERVER_DATABASE"
      )
    fi

    if [ -n "${tls_cert_file}" ]; then
      conn_opts+=(
        GEL_TLS_CA_FILE="${tls_cert_file}"
      )
    fi

    if [ -n "${GEL_SERVER_USER}" ]; then
      conn_opts+=(
        GEL_USER="${GEL_SERVER_USER}"
      )
    fi

    if [ -n "${GEL_SERVER_PASSWORD}" ]; then
      conn_opts+=(
        GEL_PASSWORD="${GEL_SERVER_PASSWORD}"
      )
    fi

    http_status=$(curl -o /dev/null -s -w "%{http_code}" -k "https://127.0.0.1:${port}/server/status/alive")
    if [ "$http_status" = "404" ]; then
      $callback "$status" "${conn_opts[@]}" || result=$?
    elif [ "$http_status" = "200" ]; then
      $callback "$status" "${conn_opts[@]}" || result=$?
    else
      status=""
    fi
  fi

  set +e
  kill -TERM "$server_pid" 2>/dev/null
  (sleep 10 ; kill -KILL "$server_pid") &
  timeout_pid="$!"
  wait -n "$server_pid"
  ecode=$?
  kill "$timeout_pid" 2>/dev/null
  set -e

  if ps -o pid= -p "$server_pid" >/dev/null; then
    kill -9 "$server_pid"
    ecode=124
  fi

  if [ $ecode -eq 0 ] || [ $ecode -eq 143 ] && [ -z "$status" ]; then
    # This means server did not produce the READY status in $timeout seconds.
    ecode=1
    emsg="ERROR: Could not complete instance bootstrap in ${timeout} seconds."
    emsg+=" If you have slow hardware, consider increasing the timeout"
    emsg+=" via the GEL_DOCKER_BOOTSTRAP_TIMEOUT_SEC variable."
  fi

  if [ $ecode -ne 0 ]; then
    if [ $ecode -eq 10 ]; then
      edbdocker_log_no_tls_cert
    fi
    _abort "$emsg"
  fi

  rm -r "${runstate_dir}" || :

  if [ $result -eq 0 ]; then
    result=$ecode
  fi

  return $result
}


edbdocker_mktemp_for_server() {
  local result
  result=$(mktemp "$@")

  if [ "$(id -u)" = "0" ]; then
    chown -R "${GEL_SERVER_UID}" "${result}"
  fi

  echo "${result}"
}


_edbdocker_wait_for_status() {
  local status_file
  local server_pid
  local timeout
  local status
  local line
  local -a tail_args

  status=""
  status_file="$1"
  server_pid="${2:-}"
  timeout="${3:-0}"

  tail_args=( -f "$status_file" )
  if [ -n "$server_pid" ]; then
    tail_args+=( --pid="$server_pid" )
  fi

  while IFS= read -r line; do
    status="${line}"
    break
  done < <(timeout "$timeout" tail "${tail_args[@]}")

  rm -rf "$status_file" || :

  echo "$status"
}


_edbdocker_print_last_generated_cert_if_needed() {
  local -a link_opts
  local tls_cert_file
  local tls_cert_new
  local status
  local msg

  if [[ $1 != READY=* ]]; then
    return
  fi

  status="${1#READY=}"

  tls_cert_new=$(echo "$status" | jq -r ".tls_cert_newly_generated")

  if [ "${tls_cert_new}" != "true" ] \
     || [ "${GEL_DOCKER_SHOW_GENERATED_CERT}" = "never" ]
  then
    return
  fi

  tls_cert_file=$(echo "$status" | jq -r ".tls_cert_file")

  link_opts+=( "-P" "<published-port>" )

  if [ "${GEL_SERVER_USER}" != "$DEFAULT_SERVER_USER" ]; then
    link_opts+=( "-u" "${GEL_SERVER_USER}" )
  fi

  msg=(
    "================================================================"
    "                             NOTICE                             "
    "                             ------                             "
    "                                                                "
    "A self-signed TLS certificate has been generated and placed in  "
    "'${tls_cert_file}' in this container.                           "
    "                                                                "
    "If you have the Gel CLI installed on the host system, you can   "
    "persist the authentication credentials and the certificate by   "
    "running:                                                        "
    "                                                                "
    "  edgedb ${link_opts[*]} instance link --trust-tls-cert my_instance"
    "                                                                "
    "You can then connect to the instance by running:                "
    "                                                                "
    "  edgedb -I my_instance                                         "
    "                                                                "
    "If you wish to use the generated certificate manually, it is    "
    "printed below.  Please remember to include the BEGIN and END    "
    "CERTIFICATE lines.                                              "
    "                                                                "
  )
  edbdocker_log_at_level "info" "${msg[@]}"
  edbdocker_log_at_level "info" "$(cat "${tls_cert_file}")"
  msg=(
    "                                                                "
    "                                                                "
    "================================================================"
  )
  edbdocker_log_at_level "info" "${msg[@]}"
}
