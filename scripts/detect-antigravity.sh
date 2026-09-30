#!/usr/bin/env bash
# scripts/detect-antigravity.sh
# Автоматический поиск установленных версий Antigravity (Agentic и IDE)

set -euo pipefail

find_antigravity_installations() {
    local -a raw_candidates=()
    shopt -s nullglob

    # 0. Проверяем запущенные процессы Antigravity
    local running_proc
    while IFS= read -r line; do
        if [[ "$line" =~ (/[^[:space:]]+/antigravity) ]]; then
            local proc_bin="${BASH_REMATCH[1]}"
            if [ -x "$proc_bin" ]; then
                local proc_dir
                proc_dir=$(dirname "$(readlink -f "$proc_bin" 2>/dev/null || echo "$proc_bin")")
                [[ "$proc_dir" == */bin ]] && proc_dir=$(dirname "$proc_dir")
                raw_candidates+=("$proc_dir")
            fi
        fi
    done < <(pgrep -fa "antigravity" 2>/dev/null || true)

    # 1. Поиск по ярлыкам .desktop
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
                raw_candidates+=("$app_dir")
            fi
        fi
    done

    # 2. Поиск по стандартным директориям установки
    for dir in /opt/antigravity* /opt/Antigravity* ~/.local/share/antigravity* ~/Applications/antigravity*; do
        if [ -d "$dir" ]; then
            raw_candidates+=("$(readlink -f "$dir" 2>/dev/null || echo "$dir")")
            # Также проверяем подкаталоги вида Antigravity-x64
            for subdir in "$dir"/*; do
                if [ -d "$subdir" ] && [ -d "$subdir/resources" ]; then
                    raw_candidates+=("$(readlink -f "$subdir" 2>/dev/null || echo "$subdir")")
                fi
            done
        fi
    done

    # 3. Поиск по $PATH (с разворачиванием shell-оберток)
    for cmd in antigravity antigravity-ide agy; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local bin_path
            bin_path=$(readlink -f "$(command -v "$cmd")" 2>/dev/null || true)
            if [ -n "$bin_path" ] && [ -f "$bin_path" ]; then
                # Если это скрипт-обертка, извлекаем реальный путь запуска
                if file "$bin_path" | grep -q "text executable"; then
                    local target_in_script
                    target_in_script=$(grep -E "exec [^ ]+" "$bin_path" 2>/dev/null | awk '{print $2}' || true)
                    if [ -n "$target_in_script" ] && [ -f "$target_in_script" ]; then
                        local real_app_dir
                        real_app_dir=$(dirname "$(readlink -f "$target_in_script" 2>/dev/null || echo "$target_in_script")")
                        [[ "$real_app_dir" == */bin ]] && real_app_dir=$(dirname "$real_app_dir")
                        raw_candidates+=("$real_app_dir")
                    fi
                else
                    local app_dir
                    app_dir=$(dirname "$bin_path")
                    [[ "$app_dir" == */bin ]] && app_dir=$(dirname "$app_dir")
                    raw_candidates+=("$app_dir")
                fi
            fi
        fi
    done

    shopt -u nullglob

    # Фильтрация ложных путей (/usr, /usr/local, корня) и валидация наличия ресурсов
    local -a agentic_candidates=()
    local -a other_candidates=()
    local -A seen=()

    for dir in "${raw_candidates[@]}"; do
        [ -z "$dir" ] && continue
        [ -d "$dir" ] || continue
        # Исключаем системные папки
        [[ "$dir" =~ ^(/usr|/usr/local|/|/bin|/sbin)$ ]] && continue
        
        # Проверяем наличие ресурсов Antigravity
        if [ ! -d "$dir/resources" ] && [ ! -d "$dir/../resources" ] && [ ! -f "$dir/antigravity" ] && [ ! -f "$dir/antigravity-ide" ]; then
            continue
        fi

        local norm_dir
        norm_dir=$(readlink -f "$dir" 2>/dev/null || echo "$dir")
        [ -n "${seen[$norm_dir]:-}" ] && continue
        seen[$norm_dir]=1

        # Отдельно выделяем Agentic 2.0 (где лежит app.asar, пригодный для add-model)
        if [ -f "$norm_dir/resources/app.asar" ] || [ -f "$norm_dir/../resources/app.asar" ]; then
            agentic_candidates+=("$norm_dir")
        else
            other_candidates+=("$norm_dir")
        fi
    done

    # Выводим сначала Agentic 2.0 (приоритетные цели для патчинга), затем остальные
    for target in "${agentic_candidates[@]}" "${other_candidates[@]}"; do
        echo "$target"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    find_antigravity_installations
fi
