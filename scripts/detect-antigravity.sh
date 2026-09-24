#!/usr/bin/env bash
# scripts/detect-antigravity.sh
# Автоматический поиск установленных версий Antigravity (Agentic и IDE)

set -euo pipefail

find_antigravity_installations() {
    local -a candidates=()
    shopt -s nullglob

    # 1. Поиск по $PATH
    for cmd in antigravity antigravity-ide agy; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local bin_path
            bin_path=$(readlink -f "$(command -v "$cmd")" 2>/dev/null || true)
            if [ -n "$bin_path" ] && [ -f "$bin_path" ]; then
                local app_dir
                app_dir=$(dirname "$bin_path")
                [[ "$app_dir" == */bin ]] && app_dir=$(dirname "$app_dir")
                candidates+=("$app_dir")
            fi
        fi
    done

    # 2. Поиск по ярлыкам .desktop
    for desktop in ~/.local/share/applications/*antigravity*.desktop /usr/share/applications/*antigravity*.desktop; do
        if [ -f "$desktop" ]; then
            local exec_path
            exec_path=$(grep -E "^Exec=" "$desktop" | head -n1 | cut -d= -f2- | awk '{print $1}' | tr -d '"' || true)
            if [ -n "$exec_path" ] && [ -f "$exec_path" ]; then
                local real_exec
                real_exec=$(readlink -f "$exec_path" 2>/dev/null || true)
                local app_dir
                app_dir=$(dirname "$real_exec")
                [[ "$app_dir" == */bin ]] && app_dir=$(dirname "$app_dir")
                candidates+=("$app_dir")
            fi
        fi
    done

    # 3. Поиск по стандартным директориям установки
    for dir in ~/.local/share/antigravity* /opt/antigravity* ~/Applications/antigravity*; do
        if [ -d "$dir" ]; then
            if [ -d "$dir/resources" ] || [ -f "$dir/antigravity" ] || [ -f "$dir/antigravity-ide" ]; then
                candidates+=("$(readlink -f "$dir" 2>/dev/null || echo "$dir")")
            fi
        fi
    done

    shopt -u nullglob

    if [ ${#candidates[@]} -gt 0 ]; then
        printf "%s\n" "${candidates[@]}" | sort -u
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    find_antigravity_installations
fi
