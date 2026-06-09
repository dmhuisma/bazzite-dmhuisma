audio-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"
    mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
    yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3" || true
    yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/CLAP" || true
    yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins" || true
    yabridgectl sync

audio-wineasio-register prefix:
    wineasio-register-prefix "{{ prefix }}"

audio-wineasio-run prefix command *args:
    wineasio-run "{{ prefix }}" "{{ command }}" {{ args }}

audio-buffer-64:
    pw-metadata -n settings 0 clock.force-quantum 64
    pw-metadata -n settings 0 clock.force-rate 48000

audio-buffer-128:
    pw-metadata -n settings 0 clock.force-quantum 128
    pw-metadata -n settings 0 clock.force-rate 48000

audio-buffer-256:
    pw-metadata -n settings 0 clock.force-quantum 256
    pw-metadata -n settings 0 clock.force-rate 48000

audio-buffer-reset:
    pw-metadata -n settings 0 clock.force-quantum 0
    pw-metadata -n settings 0 clock.force-rate 0

audio-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> User groups"
    id
    echo
    echo "==> Realtime limits"
    echo "rtprio: $(ulimit -r)"
    echo "memlock: $(ulimit -l)"
    echo
    echo "==> PipeWire forced settings"
    pw-metadata -n settings 0 clock.force-quantum || true
    pw-metadata -n settings 0 clock.force-rate || true
    echo
    echo "==> Scarlett devices"
    wpctl status | grep -i -A3 -B3 'scarlett\|focusrite' || true

audio-restart:
    systemctl --user restart pipewire pipewire-pulse wireplumber

audio-enable-kargs:
    #!/usr/bin/env bash
    set -euo pipefail
    current="$(rpm-ostree kargs)"
    args=()
    [[ "${current}" == *"threadirqs"* ]] || args+=(--append=threadirqs)
    [[ "${current}" == *"preempt=full"* ]] || args+=(--append=preempt=full)
    if [[ "${#args[@]}" -eq 0 ]]; then
        echo "threadirqs and preempt=full are already present."
        exit 0
    fi
    sudo rpm-ostree kargs "${args[@]}"
    echo "Reboot to use the updated kernel arguments."
