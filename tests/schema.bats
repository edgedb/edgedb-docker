containers=()
instances=()

setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/buster.nightly.json \
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
        docker rm -f "${containers[@]}" || :
    fi
    for instance in "${instances[@]}"; do
        edgedb instance unlink "${instance}" || :
    done
}

@test "applying schema" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    # The user declared here is ignored
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_SERVER_USER=user1 \
        --env=EDGEDB_SERVER_PASSWORD=password2 \
        --env=EDGEDB_SERVER_TLS_CERT_MODE=generate_self_signed \
        edgedb-test:schema
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    # ensure started
    echo password2 | edgedb --wait-until-available=120s -P$port \
        -u user1 --password-from-stdin \
        instance link --trust-tls-cert --non-interactive "${instance}"
    # wait until migrations are complete
    sleep 3
    # now check that this worked
    edgedb -I "${instance}" \
        query --output-format=tab-separated "INSERT Item { name := 'hello' }"
}
