#!/usr/bin/env bash
# scripts/download-manager.sh
# Автоматическая загрузка последнего релиза Antigravity-Manager (AppImage) из GitHub Releases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
TARGET_APPIMAGE="$BIN_DIR/Antigravity-Manager.AppImage"

mkdir -p "$BIN_DIR"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Удаляем зависшие временные файлы загрузок
rm -f "$BIN_DIR"/Antigravity-Manager.AppImage.download.* 2>/dev/null || true

DO_DOWNLOAD=true
if [ -s "$TARGET_APPIMAGE" ]; then
    SIZE_HUMAN=$(ls -lh "$TARGET_APPIMAGE" | awk '{print $5}')
    echo -e "${GREEN}✓ Antigravity-Manager.AppImage уже присутствует на диске ($SIZE_HUMAN):${NC}"
    echo "  $TARGET_APPIMAGE"
    
    # Спрашиваем пользователя, нужно ли перекачивать
    read -r -p "Хотите перекачать актуальную версию с GitHub Releases заново? [y/N]: " RE_DOWNLOAD
    RE_DOWNLOAD="${RE_DOWNLOAD:-n}"
    if [[ ! "$RE_DOWNLOAD" =~ ^[YyДд]$ ]]; then
        DO_DOWNLOAD=false
        echo -e "${CYAN}ℹ️ Используем уже загруженный $TARGET_APPIMAGE.${NC}"
    fi
else
    read -r -p "Скачать Antigravity-Manager (AppImage) из GitHub Releases? [Y/n]: " WANT_DOWNLOAD
    WANT_DOWNLOAD="${WANT_DOWNLOAD:-y}"
    if [[ ! "$WANT_DOWNLOAD" =~ ^[YyДд]$ ]]; then
        DO_DOWNLOAD=false
        echo -e "${YELLOW}ℹ️ Загрузка пропущена пользователем.${NC}"
    fi
fi

if [ "$DO_DOWNLOAD" = true ]; then
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            APP_ARCH="amd64"
            ;;
        aarch64|arm64)
            APP_ARCH="aarch64"
            ;;
        *)
            echo "❌ Неподдерживаемая архитектура: $ARCH"
            exit 1
            ;;
    esac

    echo "🔍 Проверка обновлений Antigravity-Manager на GitHub (lbjlaq/Antigravity-Manager)..."

    REPO="lbjlaq/Antigravity-Manager"
    LATEST_RELEASE_JSON=$(curl -sL --connect-timeout 10 "https://api.github.com/repos/$REPO/releases/latest" || true)

    if [ -z "$LATEST_RELEASE_JSON" ] || echo "$LATEST_RELEASE_JSON" | grep -q "API rate limit"; then
        echo "⚠️ Не удалось получить данные через GitHub API (лимит запросов или нет сети)."
        if [ -s "$TARGET_APPIMAGE" ]; then
            echo "ℹ️ Используем существующий $TARGET_APPIMAGE"
            DO_DOWNLOAD=false
        else
            FALLBACK_URL="https://github.com/lbjlaq/Antigravity-Manager/releases/download/v4.8.0/Antigravity.Tools_4.8.0_${APP_ARCH}.AppImage"
            DOWNLOAD_URL="$FALLBACK_URL"
            TAG="v4.8.0"
        fi
    else
        TAG=$(echo "$LATEST_RELEASE_JSON" | grep -E '"tag_name":' | head -n1 | cut -d'"' -f4)
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep -E "browser_download_url.*${APP_ARCH}\.AppImage\"" | head -n1 | cut -d'"' -f4)
    fi

    if [ "$DO_DOWNLOAD" = true ]; then
        if [ -z "${DOWNLOAD_URL:-}" ]; then
            echo "❌ Не найдена ссылка на скачивание AppImage для архитектуры $APP_ARCH."
            exit 1
        fi

        echo "⬇️ Скачивание Antigravity-Manager $TAG ($APP_ARCH)..."
        echo "URL: $DOWNLOAD_URL"

        TEMP_FILE="${TARGET_APPIMAGE}.download.$$"
        if curl -L --progress-bar -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
            mv "$TEMP_FILE" "$TARGET_APPIMAGE"
            chmod +x "$TARGET_APPIMAGE"
            echo -e "${GREEN}✅ Antigravity-Manager успешно сохранен в $TARGET_APPIMAGE${NC}"
        else
            rm -f "$TEMP_FILE"
            echo "❌ Ошибка при скачивании Antigravity-Manager."
            exit 1
        fi
    fi
fi

# ─── Интеграция в систему и $PATH ─────────────────────────────────────────────
if [ -s "$TARGET_APPIMAGE" ]; then
    chmod +x "$TARGET_APPIMAGE"
    
    SYSTEM_BIN_DIR="$HOME/.local/bin"
    APP_LINK="$SYSTEM_BIN_DIR/antigravity-manager"
    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/antigravity-manager.desktop"

    echo -e "\n${BOLD}🔗 Интеграция Antigravity-Manager в систему:${NC}"
    echo "  Бинарник:  $APP_LINK (доступен в терминале через PATH)"
    echo "  Ярлык:     $DESKTOP_FILE (появится в меню приложений)"

    read -r -p "Создать символическую ссылку в ~/.local/bin и ярлык рабочего стола? [Y/n]: " INSTALL_SYSTEM
    INSTALL_SYSTEM="${INSTALL_SYSTEM:-y}"
    if [[ "$INSTALL_SYSTEM" =~ ^[YyДд]$ ]]; then
        mkdir -p "$SYSTEM_BIN_DIR" "$DESKTOP_DIR"
        ln -sfn "$TARGET_APPIMAGE" "$APP_LINK"
        
        # Поиск подходящей иконки
        ICON_PATH="$ROOT_DIR/modules/antigravity-add-model/icon.png"
        [ -f "$ICON_PATH" ] || ICON_PATH="utilities-system-monitor"

        cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Antigravity Manager
GenericName=Account & Proxy Manager
Comment=Менеджер аккаунтов и локальный шлюз для Antigravity
Exec=$APP_LINK
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
EOF
        chmod +x "$DESKTOP_FILE"
        echo -e "${GREEN}✓ Симлинк создан: $APP_LINK${NC}"
        echo -e "${GREEN}✓ Ярлык создан: $DESKTOP_FILE${NC}"
    fi
fi
