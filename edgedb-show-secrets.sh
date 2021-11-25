#!/usr/bin/env bash

# shellcheck disable=SC1091
source "/usr/local/bin/docker-entrypoint-funcs.sh"


edb_gs_log() {
  printf >&2 "%s\n" "${@}"
}

edb_gs_die() {
  edb_gs_log "${@}"
  exit 1
}

edb_gs_usage() {
  edb_gs_log "Usage: $0 --all | --specifically=<SECRET_NAME> | <SECRET_NAME> [...]"
  exit "${1:-1}"
}

edb_gs_parse_args() {
  _EDB_GS_ONLY=
  _EDB_GS_ALL=
  _EDB_GS_SECRETS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        edb_gs_usage 0
        ;;
      --all)
        if [ -n "${_EDB_GS_ONLY}" ] || [ "${#_EDB_GS_SECRETS[@]}" -gt 0 ]; then
          edb_gs_log "invalid argument combination"
          edb_gs_usage
        fi
        _EDB_GS_ALL="true"
        shift
        ;;
      --specifically=*)
        if [ -n "${_EDB_GS_ONLY}" ] || [ -n "${_EDB_GS_ALL}" ]; then
          edb_gs_log "invalid argument combination"
          edb_gs_usage
        fi
        _EDB_GS_ONLY="${1#*=}"
        shift
        ;;
      -*)
        edb_gs_log "unexpected option: $1"
        edb_gs_usage
        ;;
      *)
        if [ -n "${_EDB_GS_ONLY}" ] || [ -n "${_EDB_GS_ALL}" ]; then
          edb_gs_log "invalid argument combination"
          edb_gs_usage
        fi
        _EDB_GS_SECRETS+=( "$1" )
        shift
        ;;
    esac
  done

  if [ -z "${_EDB_GS_ONLY}" ] && [ -z "${_EDB_GS_ALL}" ] && [ "${#_EDB_GS_SECRETS[@]}" -eq 0 ]; then
    edb_gs_usage
  fi
}

edb_gs_show_secrets() (
  local k
  local v
  local file
  local lines
  local -A map

  while IFS="=" read -r k v; do
    map["$k"]=$v
  done < "/etc/edgedb.secrets"

  if [ -n "${_EDB_GS_ONLY}" ]; then
    file=${map["$_EDB_GS_ONLY"]:-}
    if [ -z "$file" ]; then
      edb_gs_die "ERROR: '${_EDB_GS_ONLY}' is not a known secret"
    fi
    cat "$file"
  elif [ -n "${_EDB_GS_ALL}" ]; then
    for k in "${!map[@]}"; do
      file=${map["$k"]}
      edb_gs_show_secret "$k" "$file"
    done
  else
    for k in "${_EDB_GS_SECRETS[@]}"; do
      file=${map["$k"]:-}
      if [ -z "$file" ]; then
        edb_gs_die "ERROR: '${k}' is not a known secret"
      fi
    done
    for k in "${_EDB_GS_SECRETS[@]}"; do
      file=${map["$k"]}
      edb_gs_show_secret "$k" "$file"
    done
  fi
)

edb_gs_show_secret() {
  local name
  local file
  name="$1"
  file="$2"

  v=$(cat "$file")
  lines=$(wc -l "$file" | cut -f1 -d' ')
  if [ "$lines" -gt 1 ]; then
    printf '%s="""\n%s\n"""\n' "$name" "$v"
  else
    printf '%s="%v"\n' "$name" "$v"
  fi
}


edbdocker_setup_shell
edb_gs_parse_args "$@"
edb_gs_show_secrets
