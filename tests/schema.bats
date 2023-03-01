load testbase

setup() {
  build_container
  docker build -t edgedb-test:schema tests/schema
}

teardown() {
  common_teardown
}

@test "applying schema" {
  local container_id
  local instance

  create_instance container_id instance '{"image":"edgedb-test:schema"}'

  # wait until migrations are complete
  sleep 3

  # now check that this worked
  edgedb -I "${instance}" query --output-format=tab-separated \
    "INSERT Item { name := 'hello' }"
}

@test "skip applying schema" {
  local container_id
  local instance

  create_instance container_id instance '{"image":"edgedb-test:schema"}' \
    --env=EDGEDB_DOCKER_APPLY_MIGRATIONS=never

  # wait until migrations are complete
  sleep 3

  # now check that this worked
  edgedb -I "${instance}" query --output-format=tab-separated \
    "CREATE TYPE Item"
}
