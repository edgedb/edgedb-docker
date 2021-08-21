#!/usr/bin/env bash

source "/usr/local/bin/docker-entrypoint-funcs.sh"

edbdocker_setup_shell
edbdocker_parse_args "$@"

if ! edbdocker_is_server_command "$@"; then
  edbdocker_run_regular_command "$@"
else
  edbdocker_prepare

  if edbdocker_bootstrap_needed; then
    edbdocker_bootstrap_instance
  else
    edbdocker_run_migrations
  fi

  edbdocker_run_server "$@"
fi
