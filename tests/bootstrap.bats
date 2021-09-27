containers=()
instances=()

setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/stretch.nightly.json \
        | jq -r '[.packages[] | select(.basename == "edgedb-server")] | sort_by(.slot) | reverse | .[0].slot')
    docker build -t edgedb/edgedb:latest \
        --build-arg "version=$slot" --build-arg "subdist=.nightly" \
        .
    docker build -t edgedb-test:bootstrap tests/bootstrap
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

@test "full bootstrap" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    # The user declared here is ignored
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_GENERATE_SELF_SIGNED_CERT=1 \
        edgedb-test:bootstrap
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo password2 | edgedb --wait-until-available=120s -P$port \
        -u user1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    output=$(edgedb -I "${instance}" query --output-format=tab-separated \
        "SELECT Bootstrap.name ORDER BY Bootstrap.name")
    echo "$output"
    run echo "$output"
    [[ ${lines[0]} = "01-shell script" ]]
    [[ ${lines[1]} = "02-edgeql file" ]]
    [[ ${lines[2]} = "03-edgeql file" ]]
}
