# Official Dockerfile for EdgeDB Server

The official Docker image for EdgeDB and the EdgeDB CLI.

### [Documentation](https://www.edgedb.com/docs/guides/deployment/docker)

## When to use this image

This image is intended for use in production, or as part of a
development setup that involves multiple containers orchestrated by
Docker Compose or a similar tool. Otherwise, using the `edgedb server`
CLI on the host system is the recommended way to install and run
EdgeDB servers.

## What is EdgeDB?

[EdgeDB](https://www.edgedb.com) is an open-source object-relational database
built on top of PostgreSQL, featuring:

- strict, object-oriented typed schema;
- powerful and expressive query language;
- rich standard library;
- built-in support for schema migrations;
- native GraphQL support.

Try the [quickstart](https://www.edgedb.com/docs/guides/quickstart) or jump into the [docs](https://www.edgedb.com/) to get started with EdgeDB.
