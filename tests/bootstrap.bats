containers=()

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
    if [[ ${#containers[@]} ]]; then
        docker rm -f "${containers[@]}"
    fi
}

@test "full bootstrap" {
    container_id="edb_dock_$(uuidgen)"
    containers+=($container_id)
    # The user declared here is ignored
    docker run -d --name=$container_id --publish=5656 edgedb-test:bootstrap
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    output=$(echo password2 | edgedb --wait-until-available=120s -P$port \
        -u user1 --password-from-stdin \
        --tab-separated query "SELECT Bootstrap.name ORDER BY Bootstrap.name")
    echo "$output"
    run echo "$output"
    [[ ${lines[0]} = "01-shell script" ]]
    [[ ${lines[1]} = "02-edgeql file" ]]
    [[ ${lines[2]} = "03-edgeql file" ]]
}
