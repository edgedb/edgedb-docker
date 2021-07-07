# Official Dockerfile for EdgeDB Server

## What is EdgeDB?

EdgeDB is an **open-source** object-relational database built on top of
PostgreSQL. The goal of EdgeDB is to _empower_ its users to build safe
and efficient software with less effort.

EdgeDB features:

- strict, strongly typed schema;
- powerful and expressive query language;
- rich standard library;
- built-in support for schema migrations;
- native GraphQL support.

See [edgedb.com](https://www.edgedb.com/) and the
[documentation](https://www.edgedb.com/docs/) for more information about
EdgeDB and how to get started. This README contains information specifically
on how to use the EdgeDB server Docker image.

## When to use this image

This image is primarily intended to be used directly when there is a
requirement to use Docker containers, such as in production, or in a
development setup that involves multiple containers orchestrated by
Docker Compose or a similar tool. Otherwise, using the `edgedb server`
CLI on the host system is the recommended way to install and run
EdgeDB servers.

## How to use this image

The simplest way to run the image (without data persistence) is this:

```shell
$ docker run --name edgedb -e EDGEDB_SERVER_PASSWORD=secret -d edgedb/edgedb
```

See the [Customization](#customization) section below for the meaning of
the `EDGEDB_SERVER_PASSWORD` variable and other options.

Now, to open an interactive shell to the database instance run this:

```
$ docker run -it --rm --link=edgedb edgedb/edgedb-cli -H edgedb --password
```

When the CLI prompts for a password, enter the value passed in the
`EDGEDB_SERVER_PASSWORD` variable when starting the server container.

## Data Persistence

If you want the contents of the database to survive container restarts,
you must mount a persistent volume at the path specified by
`EDGEDB_SERVER_DATADIR` (`/var/lib/edgedb/data`) by default.  For example:

```shell
$ docker run \
    --name edgedb -e EDGEDB_SERVER_PASSWORD=secret \
    -v /my/data/directory:/var/lib/edgedb/data \
    -d edgedb/edgedb
```

Note that on Windows you must use a Docker volume instead:

```shell
$ docker volume create --name=edgedb-data
$ docker run \
    --name edgedb -e EDGEDB_SERVER_PASSWORD=secret \
    -v edgedb-data:/var/lib/edgedb/data \
    -d edgedb/edgedb
```

It is also possible to run an `edgedb` container on a remote PostgreSQL
cluster specified by `EDGEDB_SERVER_POSTGRES_DSN`.  See below for details.

## Schema Migrations

A derived image may include application schema and migrations in
`/dbschema`, in which case the container will attempt to apply the
schema migrations found in `/dbschema/migrations`, unless
the `EDGEDB_SERVER_SKIP_MIGRATIONS` environment variable is set.

## Customization

The behavior of the `edgedb` image can be customized via environment
variables and initialization scripts.

### Initial container setup

When an `edgedb` container starts on the specified data directory or remote
Postgres cluster for the first time, initial instance setup is performed.
This is called the _bootstrap phase_.

The following environment variables affect the bootstrap only and have no
effect on subsequent container runs. The `_FILE` variants of the variables
allow passing the value via a file mounted inside a container.

#### `EDGEDB_SERVER_PASSWORD`, `EDGEDB_SERVER_PASSWORD_FILE`

Determines the password used for the default superuser account.

#### `EDGEDB_SERVER_PASSWORD_HASH`, `EDGEDB_SERVER_PASSWORD_HASH_FILE`

A variant of `EDGEDB_SERVER_PASSWORD`, where the specified value is a hashed
password verifier instead of plain text.

#### `EDGEDB_SERVER_USER`, `EDGEDB_SERVER_USER_FILE`

Optionally specifies the name of the default superuser account. Defaults to
`edgedb` if not specified.

#### `EDGEDB_SERVER_DATABASE`, `EDGEDB_SERVER_DATABASE_FILE`

Optionally specifies the name of a default database that is created during
bootstrap. Defaults to `edgedb` if not specified.

#### `EDGEDB_SERVER_AUTH_METHOD`

Optionally specifies the authentication method used by the server instance.
Supported values are `"scram"` (the default) and `"trust"`.  When set to
`"trust"`, the database will allow complete unauthenticated access for all
who have access to the database port.  In this case the `EDGEDB_SERVER_PASSWORD`
(or equivalent) setting is not required.

Use at your own risk and only for testing.

#### `EDGEDB_SERVER_BOOTSTRAP_COMMAND`, `EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE`

Specifies one or more EdgeQL statements to run at bootstrap. If specified,
overrides `EDGEDB_SERVER_PASSWORD`, `EDGEDB_SERVER_PASSWORD_HASH`,
`EDGEDB_SERVER_USER` and `EDGEDB_SERVER_DATABASE`. Useful to fine-tune initial
user and database creation, and other initial setup. If neither the
`EDGEDB_SERVER_BOOTSTRAP_COMMAND` variable or the
`EDGEDB_SERVER_BOOTSTRAP_SCRIPT_FILE` are explicitly specified, the container
will look for the presence of `/edgedb-bootstrap.edgeql` in the container
(which can be placed in a derived image).

#### Custom scripts in `/edgedb-bootstrap.d/

To perform additional initialization, a derived image may include one ore
more `*.edgeql`, or `*.sh` scripts, which are executed in addition to and
_after_ the initialization specified by the environment variables above
or the `/edgedb-bootstrap.edgeql` script.

### Runtime Options

Unlike options listed in the [Initial container setup](#initial-container-setup)
section above, the configuration documented below applies to all container
invocations.  It can be specified either as environment variables or
command-line arguments.

#### `EDGEDB_SERVER_PORT`, `--port`

Specifies the network port on which EdgeDB will listen inside the container.
The default is `5656`.  This usually doesn't need to be changed unless you
run in `host` networking mode.

#### `EDGEDB_SERVER_BIND_ADDRESS`, `--bind-address`

Specifies the network interface on which EdgeDB will listen inside the
container.  The default is `0.0.0.0`, which means all interfaces.  This
usually doesn't need to be changed unless you run in `host` networking mode.

#### `EDGEDB_SERVER_DATADIR`, `--data-dir`

Specifies a path within the container in which the database files are located.
Defaults to `/var/run/edgedb/data`.  The container needs to be able to
change the ownership of the mounted directory to `edgedb`.  Cannot be specified
at the same time with `EDGEDB_SERVER_POSTGRES_DSN`.

#### `EDGEDB_SERVER_POSTGRES_DSN`, `EDGEDB_SERVER_POSTGRES_DSN_FILE`, `--postgres-dsn`

Specifies a PostgreSQL connection string in the
[URI format](https://www.postgresql.org/docs/13/libpq-connect.html#id-1.7.3.8.3.6).
If set, the PostgreSQL cluster specified by the URI is used instead of the
builtin PostgreSQL server.  Cannot be specified at the same time with
`EDGEDB_SERVER_DATADIR`.

#### `EDGEDB_SERVER_RUNSTATE_DIR`, `--runstate-dir`

Specifies a path within the container in which EdgeDB will place its Unix
socket and other transient files.

#### `EDGEDB_SERVER_EXTRA_ARGS`, `--extra-arg, ...`

Extra arguments to be passed to EdgeDB server.

#### Custom scripts in `/docker-entrypoint.d/`

To perform additional initialization, a derived image may include one ore
more executable files in `/docker-entrypoint.d/`, which will get executed
by the container entrypoint _before_ any other processing takes place.
