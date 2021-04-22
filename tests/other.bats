setup() {
    slot=$(
        curl https://packages.edgedb.com/apt/.jsonindexes/stretch.nightly.json \
        | jq -r '[.packages[] | select(.basename == "edgedb-server")] | sort_by(.slot) | reverse | .[0].slot')
    docker build -t edgedb/edgedb:latest \
        --build-arg "version=$slot" --build-arg "subdist=.nightly" \
        .

}

@test "run external command" {
    run docker run --rm edgedb/edgedb:latest sh -c 'echo "CMD $((7*3))"'
    [[ ${lines[-1]} = "CMD 21" ]]
}
