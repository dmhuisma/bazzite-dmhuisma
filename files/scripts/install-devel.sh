#!/usr/bin/env bash

set -euo pipefail

# this is needed due to Bazzite's package replacements

usage() {
    cat <<'USAGE'
Usage:
  install-devel.sh [options] PACKAGE [PACKAGE ...]

Options:
  -r, --repo REPO_GLOB       Temporarily enable a repository; repeatable.
  -p, --pkg-config MODULE    Verify a pkg-config module after installation;
                             repeatable.
  -h, --help                 Show this help.

Examples:
  install-devel.sh \
      --repo terra-mesa \
      --pkg-config gbm \
      mesa-libgbm-devel.x86_64

  install-devel.sh \
      --repo '*bazzite-multilib*' \
      --pkg-config xwayland \
      xorg-x11-server-Xwayland-devel.x86_64
USAGE
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

repos=()
pkg_config_modules=()
packages=()

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
            packages+=("$@")
            break
            ;;

        -*)
            die "unknown option: $1"
            ;;

        *)
            packages+=("$1")
            shift
            ;;
    esac
done

((${#packages[@]} > 0)) || {
    usage >&2
    exit 2
}

command -v dnf5 >/dev/null ||
    die "dnf5 is not installed"

command -v pkg-config >/dev/null ||
    die "pkg-config is not installed"

repo_args=()

for repo in "${repos[@]}"; do
    repo_args+=("--enable-repo=${repo}")
done

echo "Available package candidates:"

for package in "${packages[@]}"; do
    candidates="$(
        dnf5 -q "${repo_args[@]}" repoquery \
            --available \
            --queryformat '%{name}-%{evr}.%{arch} [%{repoid}]' \
            "$package" 2>/dev/null || true
    )"

    if [[ -n "$candidates" ]]; then
        while IFS= read -r candidate; do
            printf '  %s\n' "$candidate"
        done <<<"$candidates"
    else
        printf '  %s: no available candidate found\n' "$package"
    fi
done

echo
echo "Installing:"
printf '  %s\n' "${packages[@]}"

dnf5 -y \
    "${repo_args[@]}" \
    install \
    "${packages[@]}"

echo
echo "Installed packages:"

for package in "${packages[@]}"; do
    installed="$(
        dnf5 -q repoquery \
            --installed \
            --queryformat '%{name}-%{evr}.%{arch}' \
            "$package" 2>/dev/null || true
    )"

    [[ -n "$installed" ]] ||
        die "could not verify installed package: $package"

    while IFS= read -r match; do
        printf '  %s\n' "$match"
    done <<<"$installed"
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