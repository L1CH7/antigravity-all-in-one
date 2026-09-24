#!/usr/bin/env bash
# scripts/download-manager.sh
# Автоматическая загрузка последнего релиза Antigravity-Manager (AppImage) из GitHub Releases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
TARGET_APPIMAGE="$BIN_DIR/Antigravity-Manager.AppImage"

mkdir -p "$BIN_DIR"

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
    if [ -f "$TARGET_APPIMAGE" ]; then
        echo "ℹ️ Используем существующий $TARGET_APPIMAGE"
        exit 0
    fi
    FALLBACK_URL="https://github.com/lbjlaq/Antigravity-Manager/releases/download/v4.8.0/Antigravity.Tools_4.8.0_${APP_ARCH}.AppImage"
    DOWNLOAD_URL="$FALLBACK_URL"
    TAG="v4.8.0"
else
    TAG=$(echo "$LATEST_RELEASE_JSON" | grep -E '"tag_name":' | head -n1 | cut -d'"' -f4)
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep -E "browser_download_url.*${APP_ARCH}\.AppImage\"" | head -n1 | cut -d'"' -f4)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Не найдена ссылка на скачивание AppImage для архитектуры $APP_ARCH."
    exit 1
fi

echo "⬇️ Скачивание Antigravity-Manager $TAG ($APP_ARCH)..."
echo "URL: $DOWNLOAD_URL"

TEMP_FILE="${TARGET_APPIMAGE}.download.$$"
if curl -L --progress-bar -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
    mv "$TEMP_FILE" "$TARGET_APPIMAGE"
    chmod +x "$TARGET_APPIMAGE"
    echo "✅ Antigravity-Manager успешно загружен в $TARGET_APPIMAGE"
else
    rm -f "$TEMP_FILE"
    echo "❌ Ошибка при скачивании Antigravity-Manager."
    exit 1
fi
