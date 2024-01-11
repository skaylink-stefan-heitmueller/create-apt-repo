#!/bin/bash

set -e

if [[ -z "${IMPORT_FROM_REPO}" ]]; then
    echo "::notice title=Skipping::Skipping import"
    exit 0
fi

echo "${IMPORT_FROM_REPO}" > /etc/apt/mirror.list
apt-mirror
cp -rv /var/spool/apt-mirror/mirror/*/{dists,pool} .
