containers=()

setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/stretch.nightly.json \
        | jq -r '[.packages[] | select(.basename == "edgedb-server")] | sort_by(.slot) | reverse | .[0].slot')
    docker build -t edgedb/edgedb:latest \
        --build-arg "version=$slot" --build-arg "subdist=.nightly" \
        .

}

teardown() {
    for cont in "${containers[@]}"; do
        echo "--- CONTAINER: $cont ---"
        docker logs "$cont"
    done
    docker rm -f "${containers[@]}"
}

@test "new user plain password" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test2 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test2 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "new user hashed password" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=test1 \
        --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw=' \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test3 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        query "SELECT 7*3")
    run echo "$output"
    [[ ${lines[-1]} = "21" ]]
}

@test "create role manually" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_BOOTSTRAP_COMMAND="CREATE SUPERUSER ROLE test1 { SET password := 'test4'; };" \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test4 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        query "SELECT 7*4")
    run echo "$output"
    [[ ${lines[-1]} = "28" ]]
}

@test "edgedb: plain password" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_PASSWORD=test2 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test2 | edgedb --wait-until-available=120s -P$port \
        --password-from-stdin \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "edgedb: hashed password" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw=' \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test3 | edgedb --wait-until-available=120s -P$port \
        --password-from-stdin \
        query "SELECT 7*3")
    run echo "$output"
    [[ ${lines[-1]} = "21" ]]
}

@test "named database" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_DATABASE=hello \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test5 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test5 | edgedb --wait-until-available=120s -P$port \
        -d hello -u test1 --password-from-stdin \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "named database with deprecated environment variables" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_DATABASE=hello \
        --env=EDGEDB_USER=test1 \
        --env=EDGEDB_PASSWORD=test5 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo test5 | edgedb --wait-until-available=120s -P$port \
        -d hello -u test1 --password-from-stdin \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}
