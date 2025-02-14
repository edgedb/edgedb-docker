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
  [[ ${lines[0]} = GEL_SERVER_* ]]

  run docker exec "$container_id" gel-show-secrets.sh \
    --format=raw GEL_SERVER_TLS_CERT
  [[ ${lines[0]} = "-----BEGIN CERTIFICATE-----" ]]

  run docker exec "$container_id" gel-show-secrets.sh \
    --format=shell GEL_SERVER_TLS_CERT GEL_SERVER_TLS_KEY
}
