containers=()
instances=()

setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/buster.nightly.json \
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
}

@test "show secrets" {
    container_id="edb_dock_$(uuidgen | sed s/-//g)"
    containers+=($container_id)
    instance="testinst_$(uuidgen | sed s/-//g)"
    instances+=($instance)
    docker run -d --name=$container_id --publish=5656 \
        --env=EDGEDB_PASSWORD=password2 \
        --env=EDGEDB_SERVER_TLS_CERT_MODE=generate_self_signed \
        edgedb/edgedb:latest
    port=$(docker inspect "$container_id" \
        | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')
    echo password2 \
        | edgedb --wait-until-available=120s -P$port \
            --password-from-stdin \
            instance link --trust-tls-cert --non-interactive "${instance}"
    run docker exec "$container_id" edgedb-show-secrets.sh --format=toml --all
    [[ ${lines[0]} = EDGEDB_SERVER_* ]]
    run docker exec "$container_id" edgedb-show-secrets.sh --format=raw EDGEDB_SERVER_TLS_CERT
    [[ ${lines[0]} = "-----BEGIN CERTIFICATE-----" ]]
    run docker exec "$container_id" edgedb-show-secrets.sh --format=shell EDGEDB_SERVER_TLS_CERT EDGEDB_SERVER_TLS_KEY
}
