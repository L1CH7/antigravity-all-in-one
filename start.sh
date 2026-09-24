#!/usr/bin/env bash
# ==============================================================================
#  Antigravity Suite — Единый мастер-лаунчер
#  Запускает Antigravity-Manager в фоне (если не запущен) и стартует IDE
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}🚀 Запуск Antigravity Suite...${NC}"

# 1. Проверяем / запускаем Antigravity-Manager
MANAGER_APPIMAGE="$ROOT_DIR/bin/Antigravity-Manager.AppImage"

is_manager_running() {
    pgrep -f "antigravity-manager|Antigravity.Tools|antigravity-tools" >/dev/null 2>&1
}

if is_manager_running; then
    echo -e "${GREEN}✓ Antigravity-Manager уже работает в фоновом режиме.${NC}"
else
    if [ -f "$MANAGER_APPIMAGE" ]; then
        echo -e "${YELLOW}⚡ Запуск Antigravity-Manager в фоне...${NC}"
        chmod +x "$MANAGER_APPIMAGE"
        nohup "$MANAGER_APPIMAGE" >/dev/null 2>&1 &
        sleep 2
        echo -e "${GREEN}✓ Antigravity-Manager запущен.${NC}"
    else
        echo -e "${YELLOW}⚠️ $MANAGER_APPIMAGE не найден. Запустите ./install.sh для его загрузки.${NC}"
    fi
fi

# 2. Определяем путь к Antigravity
TARGET_DIR=""
if [ -f "$ROOT_DIR/.last_target_path" ]; then
    TARGET_DIR=$(cat "$ROOT_DIR/.last_target_path")
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    mapfile -t DETECTED_PATHS < <("$ROOT_DIR/scripts/detect-antigravity.sh")
    if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
        TARGET_DIR="${DETECTED_PATHS[0]}"
    fi
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Не найдена целевая установка Antigravity. Запустите ./install.sh.${NC}"
    exit 1
fi

# 3. Находим исполняемый файл
EXE=""
for candidate in "$TARGET_DIR/antigravity" "$TARGET_DIR/antigravity-ide" "$TARGET_DIR/bin/antigravity-ide"; do
    if [ -x "$candidate" ]; then
        EXE="$candidate"
        break
    fi
done

if [ -z "$EXE" ]; then
    echo -e "${RED}❌ Исполняемый файл Antigravity не найден в $TARGET_DIR.${NC}"
    exit 1
fi

echo -e "${GREEN}✨ Запуск IDE: ${BOLD}$EXE${NC}"
exec "$EXE" "$@"
