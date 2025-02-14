load testbase

setup() {
  build_container
}

@test "run external command" {
  run docker run --rm edgedb/edgedb:latest sh -c 'echo "CMD $((7*3))"'
  [[ ${lines[-1]} = "CMD 21" ]]
}

@test "run as non-root edgedb" {
  local container_id
  local instance

  create_instance container_id instance '{}' -u nobody \
    --env=EDGEDB_SERVER_DATADIR=/tmp/data

  run edgedb -I "${instance}" query "SELECT 7+7"
  [[ ${lines[-1]} = "14" ]]
}

@test "run as non-root" {
  local container_id
  local instance

  create_instance container_id instance '{}' -u nobody \
    --env=GEL_SERVER_DATADIR=/tmp/data

  run edgedb -I "${instance}" query "SELECT 7+7"
  [[ ${lines[-1]} = "14" ]]
}
