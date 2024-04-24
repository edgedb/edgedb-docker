load testbase

setup() {
  build_container
}

teardown() {
  common_teardown
}

@test "default user plain password" {
  local container_id
  local instance

  create_instance container_id instance '{"password":"test2"}' \
    --env=EDGEDB_SERVER_PASSWORD=test2

  run edgedb -I "${instance}" query "SELECT 7+7"
  [[ ${lines[-1]} = "14" ]]
}

@test "new user plain password" {
  local container_id
  local instance

  create_instance container_id instance '{"user":"test2", "password":"test2"}' \
    --env=EDGEDB_SERVER_USER=test2 \
    --env=EDGEDB_SERVER_PASSWORD=test2

  run edgedb -I "${instance}" query "SELECT 7+7"
  [[ ${lines[-1]} = "14" ]]
}

@test "default user hashed password" {
  local container_id
  local instance

  create_instance container_id instance '{"password":"test3"}' \
    --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw='

  run edgedb -I "${instance}" query "SELECT 7*3"
  [[ ${lines[-1]} = "21" ]]
}

@test "new user hashed password" {
  local container_id
  local instance

  create_instance container_id instance '{"user":"test3", "password":"test3"}' \
    --env=EDGEDB_SERVER_USER=test3 \
    --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw='

  run edgedb -I "${instance}" query "SELECT 7*3"
  [[ ${lines[-1]} = "21" ]]
}

@test "create role manually (via env)" {
  local container_id
  local instance

  create_instance container_id instance '{"user":"test4", "password":"test4"}' \
    --env=EDGEDB_SERVER_BOOTSTRAP_COMMAND="CREATE SUPERUSER ROLE test4 { SET password := 'test4'; };"

  run edgedb -I "${instance}" query "SELECT 7*4"
  [[ ${lines[-1]} = "28" ]]
}

@test "create role manually (via cmdline)" {
  local container_id
  local instance

  create_instance container_id instance '{"user":"test5", "password":"test5"}' \
    -- \
    --bootstrap-command="CREATE SUPERUSER ROLE test5 { SET password := 'test5'; };"

  run edgedb -I "${instance}" query "SELECT 7*5"
  [[ ${lines[-1]} = "35" ]]
}

@test "named database" {
  local container_id
  local instance

  create_instance container_id instance '{"database":"hello"}' \
    --env=EDGEDB_SERVER_DATABASE=hello

  run edgedb -I "${instance}" query "SELECT sys::get_current_database()"
  echo "${lines[@]}"
  [[ ${lines[-1]} = '"hello"' ]]
}

@test "custom default branch" {
  local container_id
  local instance

  create_instance container_id instance '{}' \
    --env=EDGEDB_SERVER_DEFAULT_BRANCH=hello

  run edgedb -I "${instance}" query "SELECT sys::get_current_database()"
  echo "${lines[@]}"
  [[ ${lines[-1]} = '"hello"' ]]
}

@test "tls in env vars" {
  local container_id
  local instance

  create_instance container_id instance '{"tls_ca_file":"tests/compose/certs/ca.pem"}' \
    --env=EDGEDB_SERVER_TLS_KEY="$(cat tests/compose/certs/server_key.pem)" \
    --env=EDGEDB_SERVER_TLS_CERT="$(cat tests/compose/certs/server_cert.pem)"

  run edgedb -I "${instance}" query "SELECT 'secure'"
  [[ ${lines[-1]} = '"secure"' ]]
}
