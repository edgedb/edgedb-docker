load testbase

setup() {
  build_container
  docker build -t edgedb-test:bootstrap tests/bootstrap
}

teardown() {
  common_teardown
}

@test "full bootstrap" {
  local container_id
  local instance

  create_instance container_id instance '{"image":"edgedb-test:bootstrap"}'

  output=$(edgedb -I "${instance}" query --output-format=tab-separated \
    "SELECT Bootstrap.name ORDER BY Bootstrap.name")
  echo "$output"
  run echo "$output"
  [[ ${lines[0]} = "01-shell script" ]]
  [[ ${lines[1]} = "02-edgeql file" ]]
  [[ ${lines[2]} = "03-edgeql file" ]]
  [[ ${lines[3]} = "04-shell script late" ]]
  [[ ${lines[4]} = "05-edgeql file late" ]]
}
