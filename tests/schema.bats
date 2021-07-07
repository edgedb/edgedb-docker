containers=()

setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/stretch.nightly.json \
        | jq -r '[.packages[] | select(.basename == "edgedb-server")] | sort_by(.slot) | reverse | .[0].slot')
    docker build -t edgedb/edgedb:latest \
        --build-arg "version=$slot" --build-arg "subdist=.nightly" \
        .
    docker build -t edgedb-test:schema tests/schema
}

teardown() {
    for cont in "${containers[@]}"; do
        echo "--- CONTAINER: $cont ---"
        docker logs "$cont"
    done
    if [[ ${#containers[@]} ]]; then
        docker rm -f "${containers[@]}"
    fi
}

@test "applying schema" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    # The user declared here is ignored
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=user1 \
        --env=EDGEDB_SERVER_PASSWORD=password2 \
        edgedb-test:schema
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    # ensure started
    echo password2 | edgedb --wait-until-available=120s -P$port \
        -u user1 --password-from-stdin \
        --tab-separated query "SELECT 1"
    # wait until migrations are complete
    sleep 3
    # now check that this worked
    echo password2 | edgedb --wait-until-available=120s -P$port \
        -u user1 --password-from-stdin \
        --tab-separated query "INSERT Item { name := 'hello' }"
}
