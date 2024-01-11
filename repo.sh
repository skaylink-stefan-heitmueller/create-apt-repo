#!/bin/bash

set -ex

tmpdir="$(mktemp -d)"

repo_name="${REPO_NAME}"
scan_dir="${SCAN_DIR:-${PWD}}"
keyring_name="${KEYRING_NAME:-${repo_name}-keyring}"
origin="${ORIGIN:-${repo_name}}"
suite="${SUITE:-${repo_name}}"
label="${LABEL:-${repo_name}}"
codename="${CODENAME:-${repo_name}}"
component="${COMPONENT:-main}"
architectures="${ARCHITECTURES:-amd64}"
limit="${LIMIT:-0}"
reprepro_basedir="reprepro -b ${tmpdir}/.repo/${repo_name}"
reprepro="${reprepro_basedir} -C ${component}"

sudo gem install fpm --no-doc

gpg --import <<<"${SIGNING_KEY}" 2>&1 | tee /tmp/gpg.log
mapfile -t fingerprints < <(grep -o "key [0-9A-Z]*:" /tmp/gpg.log | sort -u | grep -o "[0-9A-Z]*" | tail -n1)
keyring_version=0
keyring_files=""
for fingerprint in "${fingerprints[@]}"; do
    IFS=':' read -r -a pub < <(gpg --list-keys --with-colons "${fingerprint}" | grep pub --color=never)
    creation_date="${pub[5]}"
    keyring_version=$(( "${keyring_version}" + "${creation_date}" ))
    gpg --export "${fingerprint}" >"${keyring_name}-${creation_date}.gpg"
    keyring_files+="${keyring_name}-${creation_date}.gpg "
done

# shellcheck disable=SC2086
fpm \
    --log error \
    --force \
    --input-type dir \
    --output-type deb \
    --architecture all \
    --name "${keyring_name}" \
    --version "${keyring_version}" \
    --prefix /etc/apt/trusted.gpg.d \
    ${keyring_files}

mkdir -p "${tmpdir}/.repo/${repo_name}/conf"
(
    echo "Origin: ${origin}"
    echo "Suite: ${suite}"
    echo "Label: ${label}"
    echo "Codename: ${codename}"
    echo "Components: ${component}"
    echo "Architectures: ${architectures}"
    echo "SignWith: ${fingerprints[*]}"
    echo "Limit: ${limit}"
    echo ""
) >>"${tmpdir}/.repo/${repo_name}/conf/distributions"

if ! grep -q "^Components:.*${component}" "${tmpdir}/.repo/${repo_name}/conf/distributions"; then
    sed -i "s,^Components: \(.*\),Components: \1 ${component}, " "${tmpdir}/.repo/${repo_name}/conf/distributions"
fi

# export key for curl, configure reprepro (sign w/ multiple keys)
test -f "${tmpdir}/.repo/gpg.key" || gpg --export --armor "${fingerprints[@]}" >"${tmpdir}/.repo/gpg.key"
sed -i 's,##SIGNING_KEY_ID##,'"${fingerprints[*]}"',' "${tmpdir}/.repo/${repo_name}/conf/distributions"
mkdir -p "${scan_dir}/build-${codename}-dummy-dir-for-find-to-succeed"

# add packages
mapfile -t packages < <(find "${scan_dir}" -type f -name "*.deb")

includedebs=()

for package in "${packages[@]}"; do
    package_name="$(dpkg -f "${package}" Package)"
    package_version="$(dpkg -f "${package}" Version)"
    package_arch="$(dpkg -f "${package}" Architecture)"
    printf "\e[1;36m[%s %s] Checking for package %s %s (%s) in current repo cache ...\e[0m " "${codename}" "${component}" "${package_name}" "${package_version}" "${package_arch}"
    case "${package_arch}" in
    "all")
        # shellcheck disable=SC2016
        filter='Package (=='"${package_name}"'), $Version (=='"${package_version}"')'
        ;;
    *)
        # shellcheck disable=SC2016
        filter='Package (=='"${package_name}"'), $Version (=='"${package_version}"'), $Architecture (=='"${package_arch}"')'
        ;;
    esac
    if [ -d "${tmpdir}/.repo/${repo_name}/db" ]; then
        if $reprepro listfilter "${codename}" "${filter}" | grep -q '.*'; then
            printf "\e[0;32mOK\e[0m\n"
            continue
        fi
    fi
    if grep -q "${package##*/}" <<<"${includedebs[@]}"; then
        printf "\e[0;32mOK\e[0m\n"
        continue
    fi
    printf "\e\033[0;38;5;166mAdding\e[0m\n"
    includedebs+=("${package}")
done

# shellcheck disable=SC2128
if [ -n "${includedebs}" ]; then
    $reprepro \
        -vvv \
        includedeb \
        "${codename}" \
        "${includedebs[@]}"
fi

if ! $reprepro_basedir -v checkpool fast |& tee /tmp/missing; then
    printf "\e[0;36mStarting repo cache cleanup ...\e[0m\n"
    mapfile -t missingfiles < <(grep "Missing file" /tmp/log | grep --color=never -o "/.*\.deb")
    for missingfile in "${missingfiles[@]}"; do
        missingfile="${missingfile##*/}"
        name="$(cut -d'_' -f 1 <<<"${missingfile}")"
        version="$(cut -d'_' -f 2 <<<"${missingfile}")"
        echo "cleanup missing file ${missingfile} from repo"
        $reprepro \
            -v \
            remove \
            "${codename}" \
            "${name}=${version}"
    done
fi
