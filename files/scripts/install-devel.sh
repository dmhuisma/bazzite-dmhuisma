#!/usr/bin/env bash

set -euo pipefail

# Bazzite replaces some Fedora packages with its own builds (e.g. Mesa from
# terra-mesa, Xwayland from terra-extras) and version-locks them. Their -devel
# packages must come from exactly the same build, so the -devel package is
# derived from whatever is actually installed in the base image rather than
# from a hard-coded package name or repository.

usage() {
    cat <<'USAGE'
Usage:
  install-devel.sh [options] RUNTIME [RUNTIME ...]

RUNTIME is an installed package name or capability (e.g. mesa-libgbm or
xorg-x11-server-Xwayland). The package providing it is looked up, and
<name>-devel is installed at exactly the same version.

If that exact build is no longer published (the repository moved on after the
base image was built), every installed package built from the same source
package is upgraded together to the newest build, its version locks are
refreshed, and the matching -devel package is installed.

Options:
  -r, --repo REPO_GLOB       Temporarily enable a repository; repeatable.
  -p, --pkg-config MODULE    Verify a pkg-config module after installation;
                             repeatable.
  -h, --help                 Show this help.

Examples:
  install-devel.sh \
      --repo terra-mesa \
      --pkg-config gbm \
      mesa-libgbm

  install-devel.sh \
      --repo terra-extras \
      --pkg-config xwayland \
      xorg-x11-server-Xwayland
USAGE
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

repos=()
pkg_config_modules=()
runtimes=()

while (($#)); do
    case "$1" in
        -r|--repo|--enable-repo)
            (($# >= 2)) || die "$1 requires a value"
            repos+=("$2")
            shift 2
            ;;

        -p|--pkg-config)
            (($# >= 2)) || die "$1 requires a value"
            pkg_config_modules+=("$2")
            shift 2
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        --)
            shift
            runtimes+=("$@")
            break
            ;;

        -*)
            die "unknown option: $1"
            ;;

        *)
            runtimes+=("$1")
            shift
            ;;
    esac
done

((${#runtimes[@]} > 0)) || {
    usage >&2
    exit 2
}

command -v dnf5 >/dev/null ||
    die "dnf5 is not installed"

command -v pkg-config >/dev/null ||
    die "pkg-config is not installed"

arch="$(rpm --eval '%{_arch}')"

repo_args=()

for repo in "${repos[@]}"; do
    repo_args+=("--enable-repo=${repo}")
done

# Prints "NAME EPOCH:VERSION-RELEASE SOURCERPM" for the native-arch package
# that provides the given capability.
installed_provider() {
    rpm -q --whatprovides "$1" \
        --queryformat '%{name} %{epochnum}:%{version}-%{release} %{arch} %{sourcerpm}\n' \
        2>/dev/null |
        awk -v arch="$arch" '$3 == arch { print $1, $2, $4; exit }'
}

is_available() {
    [[ -n "$(
        dnf5 -q -y "${repo_args[@]}" repoquery --available "$1" 2>/dev/null || true
    )" ]]
}

is_versionlocked() {
    dnf5 -q versionlock list 2>/dev/null |
        grep -Eq "^Package name: $1\$"
}

# Upgrades every installed package built from the given source RPM in one
# transaction, keeping any version locks Bazzite placed on them.
upgrade_family() {
    local srpm="$1"
    local family=()
    local names=()
    local locked=()
    local name

    mapfile -t family < <(
        rpm -qa --queryformat '%{name}.%{arch} %{sourcerpm}\n' |
            awk -v srpm="$srpm" '$2 == srpm { print $1 }' |
            sort -u
    )
    mapfile -t names < <(printf '%s\n' "${family[@]%.*}" | sort -u)

    for name in "${names[@]}"; do
        if is_versionlocked "$name"; then
            locked+=("$name")
        fi
    done

    echo "Upgrading packages built from ${srpm}:"
    printf '  %s\n' "${family[@]}"

    if ((${#locked[@]} > 0)); then
        dnf5 -y versionlock delete "${locked[@]}"
    fi

    dnf5 -y "${repo_args[@]}" upgrade "${family[@]}"

    if ((${#locked[@]} > 0)); then
        dnf5 -y versionlock add "${locked[@]}"
    fi
}

devel_packages=()

for runtime in "${runtimes[@]}"; do
    read -r name evr srpm < <(installed_provider "$runtime") ||
        die "no installed ${arch} package provides: ${runtime}"

    devel="${name}-devel-${evr}.${arch}"
    echo "${runtime} is provided by ${name}-${evr}.${arch}"

    if ! is_available "$devel"; then
        echo "${devel} is no longer published; resyncing with the newest build."
        upgrade_family "$srpm"

        read -r name evr srpm < <(installed_provider "$runtime") ||
            die "no installed ${arch} package provides: ${runtime}"

        devel="${name}-devel-${evr}.${arch}"
        is_available "$devel" ||
            die "no matching development package available: ${devel}"
    fi

    devel_packages+=("$devel")
done

echo
echo "Installing:"
printf '  %s\n' "${devel_packages[@]}"

dnf5 -y \
    "${repo_args[@]}" \
    install \
    "${devel_packages[@]}"

echo
echo "Installed packages:"

for package in "${devel_packages[@]}"; do
    rpm -q "$package" >/dev/null ||
        die "could not verify installed package: $package"

    printf '  %s\n' "$package"
done

if ((${#pkg_config_modules[@]} > 0)); then
    echo
    echo "pkg-config modules:"

    for module in "${pkg_config_modules[@]}"; do
        if ! pkg-config --exists "$module"; then
            pkg-config --print-errors --exists "$module" || true
            die "pkg-config module not found: $module"
        fi

        version="$(pkg-config --modversion "$module")"
        printf '  %s %s\n' "$module" "$version"
    done
fi
