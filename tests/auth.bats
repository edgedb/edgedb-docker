containers=()
instances=()

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
    if [ ${#containers[@]} -gt 0 ]; then
        docker rm -f "${containers[@]}" || :
    fi
    for instance in "${instances[@]}"; do
        edgedb instance unlink "${instance}" || :
    done
}

@test "new user plain password" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test2 \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test2 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "new user plain password old environment vars" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test2 \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test2 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "new user hashed password" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=test1 \
        --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw=' \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test3 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7*3")
    run echo "$output"
    [[ ${lines[-1]} = "21" ]]
}

@test "create role manually (via env)" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_BOOTSTRAP_COMMAND="CREATE SUPERUSER ROLE test1 { SET password := 'test4'; };" \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test4 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7*4")
    run echo "$output"
    [[ ${lines[-1]} = "28" ]]
}

@test "create role manually (via cmdline)" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        edgedb/edgedb:latest \
        --generate-self-signed-cert \
        --bootstrap-command="CREATE SUPERUSER ROLE test1 { SET password := 'test5'; };"
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test5 | edgedb --wait-until-available=120s -P$port \
        -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7*4")
    run echo "$output"
    [[ ${lines[-1]} = "28" ]]
}

@test "edgedb: plain password" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_PASSWORD=test2 \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test2 | edgedb --wait-until-available=120s -P$port \
        --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "edgedb: hashed password" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env='EDGEDB_SERVER_PASSWORD_HASH=SCRAM-SHA-256$4096:rEQ2xuv6ASCA61VMaqU9yg==$uvda3+u+zewd/GvbIofDjk5EEReNJ0KRhLX0001bVRQ=:sdF5jXfPMnM9GNu+JC39fV4Pa5oZEULEm8cdDRZMJDw=' \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test3 | edgedb --wait-until-available=120s -P$port \
        --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7*3")
    run echo "$output"
    [[ ${lines[-1]} = "21" ]]
}

@test "named database" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_DATABASE=hello \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test5 \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test5 | edgedb --wait-until-available=120s -P$port \
        -d hello -u test1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}

@test "tls in env vars" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --publish=5656 \
        --name=$container_id \
        --env=EDGEDB_SERVER_DATABASE=hello \
        --env=EDGEDB_SERVER_USER=test1 \
        --env=EDGEDB_SERVER_PASSWORD=test_tls \
        --env=EDGEDB_SERVER_TLS_KEY="$(cat tests/compose/certs/server_key.pem)" \
        --env=EDGEDB_SERVER_TLS_CERT="$(cat tests/compose/certs/server_cert.pem)" \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo test_tls | edgedb --wait-until-available=120s -P$port \
        -d hello -u test1 --password-from-stdin \
        --tls-ca-file=tests/compose/certs/ca.pem \
        instance link --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" \
        query "SELECT 7+7")
    run echo "$output"
    [[ ${lines[-1]} = "14" ]]
}
