containers=()
instances=()

latest_server_ver() {
  local dist
  local subdist
  local idx_url_base
  local index
  local jq_query
  local ver_key

  dist="buster"
  subdist="${1:-nightly}"
  if [ -n "${subdist}" ]; then
    dist+=".${subdist}"
  fi

  idx_url_base="https://packages.edgedb.com/apt/.jsonindexes"
  index=$(curl --proto '=https' --tlsv1.2 -fsSL "${idx_url_base}/${dist}.json")

  jq_query="
     .packages[]
     | select(.basename == \"edgedb-server\")
     | select(.slot | contains(\"-rc\") | not)
     | .version_key"

  ver_key=$(echo "$index" \
            | jq -r "$jq_query" \
            | sort --version-sort --reverse \
            | head -n 1)

  if [ -n "${ver_key}" ]; then
    jq_query="
      .packages[]
      | select(.version_key == \"${ver_key}\")
      | select(.basename == \"edgedb-server\")"

    echo "$index" | jq -r "$jq_query"
  fi
}


build_container() {
  local idx_entry
  local slot
  local subdist
  local -a buildargs

  subdist="${1:-nightly}"
  idx_entry=$(latest_server_ver "${subdist}")

  slot=$(echo "$idx_entry" | jq -r '.slot')

  buildargs+=(
    --build-arg
    "version=${slot}"
  )

  if [ -n "${subdist}" ]; then
    buildargs+=(
      --build-arg
      "subdist=${subdist}"
    )
  fi

  docker build -t edgedb/edgedb:latest "${buildargs[@]}" .
}


create_instance() {
  local port
  local -n _container="$1"
  local -n _instance="$2"

  local image
  local password
  local tls_ca_file
  local user

  local -a docker_args
  local -a image_args
  local -a connect_args
  local -a link_args

  image="$(echo $3 | jq -r '.image // ""')"
  image="${image:-edgedb/edgedb:latest}"
  user="$(echo $3 | jq -r '.user // ""')"
  user="${user:-edgedb}"
  password="$(echo $3 | jq -r '.password // ""')"
  database="$(echo $3 | jq -r '.database // ""')"
  tls_ca_file="$(echo $3 | jq -r '.tls_ca_file // ""')"

  if [ $# -gt 2 ]; then
    shift 3
  else
    shift 2
  fi

  _container="edb_dock_$(uuidgen | sed s/-//g)"
  containers+=($_container)
  _instance="testinst_$(uuidgen | sed s/-//g)"
  instances+=($_instance)

  docker_args+=(
    --publish=5656
  )

  if [ -z "${tls_ca_file}" ]; then
    docker_args+=(
      --env=EDGEDB_SERVER_TLS_CERT_MODE=generate_self_signed
    )
  fi

  if [ -z "${password}" ]; then
    docker_args+=(
      --env=EDGEDB_SERVER_DEFAULT_AUTH_METHOD=Trust
    )
  fi

  while [ $# -gt 0 ]; do
    if [ "$1" == "--" ]; then
      shift
      break
    else
      docker_args+=( "$1" )
      shift
    fi
  done

  while [ $# -gt 0 ]; do
    image_args+=( "$1" )
    shift
  done

  docker run -d --name="${_container}" "${docker_args[@]}" \
    "$image" "${image_args[@]}"

  port=$(docker inspect "${_container}" \
    | jq -r '.[0].NetworkSettings.Ports["5656/tcp"][0].HostPort')

  connect_args=(
    --port="${port}"
    --user="${user}"
    --wait-until-available=120s
  )

  link_args=(
    --non-interactive
  )

  if [ -n "${tls_ca_file}" ]; then
    connect_args+=(
      --tls-ca-file="${tls_ca_file}"
    )
  else
    link_args+=(
      --trust-tls-cert
    )
  fi

  if [ -n "${database}" ]; then
    connect_args+=(
      --database="${database}"
    )
  fi

  if [ -n "${password}" ]; then
    connect_args+=(
      --password-from-stdin
    )
  fi

  if [ -n "${password}" ]; then
    echo "${password}" \
      | edgedb "${connect_args[@]}" \
          instance link "${link_args[@]}" "${_instance}"
  else
    edgedb "${connect_args[@]}" \
      instance link "${link_args[@]}" "${_instance}"
  fi
}


common_teardown() {
  for cont in "${containers[@]}"; do
    echo "--- CONTAINER: $cont ---"
    docker logs "$cont"
  done
  if [[ ${#containers[@]} > 0 ]]; then
    docker rm -f "${containers[@]}" || :
  fi
  for instance in "${instances[@]}"; do
    edgedb instance unlink "${instance}" || :
  done
}
