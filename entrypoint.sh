#!/bin/bash

set -e

if [[ "$1" != "unitd" && "$1" != "unitd-debug" ]]; then
    # with direct run of command in docker container just execute command
    /usr/local/bin/docker-entrypoint.sh "$@"
    exit 0
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
