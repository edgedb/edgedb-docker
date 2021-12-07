load testbase

setup() {
  build_container
  cd tests/compose
}

teardown() {
    docker-compose logs
    docker-compose rm --stop --force -v
}

@test "composed app works" {
    docker-compose up --detach --build
    for i in {0..120}; do
        output=$(curl -s http://localhost:34089/increment/some) || output="500"
        if ! [[ $output =~ ^500 ]]; then
            break;
        fi
        sleep 5
    done
    echo OUTPUT: $output
    [[ $status -eq 0 ]]
    [[ $output = "Updated counter value: 1" ]]
    run curl -s http://localhost:34089/increment/some
    echo OUTPUT: $output
    [[ $status -eq 0 ]]
    [[ $output = "Updated counter value: 2" ]]
}
