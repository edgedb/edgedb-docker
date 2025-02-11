load testbase

setup() {
  build_container
}

teardown() {
  common_teardown
}

@test "show secrets" {
  local container_id
  local instance

  create_instance container_id instance

  echo $container_id $instance

  run docker exec "$container_id" gel-show-secrets.sh \
    --format=toml --all
  [[ ${lines[0]} = EDGEDB_SERVER_* ]]

  run docker exec "$container_id" gel-show-secrets.sh \
    --format=raw EDGEDB_SERVER_TLS_CERT
  [[ ${lines[0]} = "-----BEGIN CERTIFICATE-----" ]]

  run docker exec "$container_id" gel-show-secrets.sh \
    --format=shell EDGEDB_SERVER_TLS_CERT EDGEDB_SERVER_TLS_KEY
}
