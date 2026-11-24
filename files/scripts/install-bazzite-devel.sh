#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

INSTALL_DEVEL="${SCRIPT_DIR}/install-devel.sh"

# Development files matching Bazzite's custom Mesa (terra-mesa).
"${INSTALL_DEVEL}" \
    --repo terra-mesa \
    --pkg-config gbm \
    mesa-libgbm

# Development files matching Bazzite's custom Xwayland (terra-extras, which
# ships it as terra-xorg-x11-server-Xwayland; older images used the
# bazzite-multilib COPR).
"${INSTALL_DEVEL}" \
    --repo terra-extras \
    --repo '*bazzite-multilib*' \
    --pkg-config xwayland \
    xorg-x11-server-Xwayland

# Hyprland development package.
#
# The LionHeartP COPR must already have been enabled by an earlier
# BlueBuild DNF module.
dnf5 -y install hyprland-devel.x86_64

pkg-config --exists hyprland ||
    {
        pkg-config --print-errors --exists hyprland || true
        exit 1
    }
printf 'pkg-config: hyprland %s\n' "$(pkg-config --modversion hyprland)"
