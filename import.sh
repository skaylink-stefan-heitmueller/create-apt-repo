#!/bin/bash

set -e

if [[ -z "${IMPORT_FROM_REPO}" ]]; then
    echo "::notice title=Skipping::Skipping import"
    exit 0
fi

(
    echo "set base_path /tmp/apt-mirror"
    echo "${IMPORT_FROM_REPO}"
) > /tmp/mirror.list
apt-mirror /tmp/mirror.list
cp -rv /tmp/apt-mirror/mirror/*/{dists,pool} .
