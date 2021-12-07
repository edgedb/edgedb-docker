load testbase

setup() {
  build_container
}

@test "run external command" {
  run docker run --rm edgedb/edgedb:latest sh -c 'echo "CMD $((7*3))"'
  [[ ${lines[-1]} = "CMD 21" ]]
}
