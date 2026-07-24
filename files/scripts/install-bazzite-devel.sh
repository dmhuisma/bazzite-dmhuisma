#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

INSTALL_DEVEL="${SCRIPT_DIR}/install-devel.sh"

# Development files matching Bazzite's custom Mesa.
"${INSTALL_DEVEL}" \
    --repo terra-mesa \
    --pkg-config gbm \
    mesa-libgbm-devel.x86_64

# Development files matching Bazzite's custom Xwayland.
"${INSTALL_DEVEL}" \
    --repo '*bazzite-multilib*' \
    --pkg-config xwayland \
    xorg-x11-server-Xwayland-devel.x86_64

# Hyprland development package.
#
# The LionHeartP COPR must already have been enabled by an earlier
# BlueBuild DNF module.
"${INSTALL_DEVEL}" \
    --repo 'copr:copr.fedorainfracloud.org:lionheartp:Hyprland' \
    --pkg-config hyprland \
    hyprland-devel.x86_64