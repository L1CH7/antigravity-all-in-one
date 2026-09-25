#!/usr/bin/env bash
# scripts/download-unlocker.sh
# Автоматическая загрузка последнего релиза Antigravity Unlocker из GitHub Releases (confeden/Antigravity)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
UNLOCKER_DIR="$BIN_DIR/unlocker"

mkdir -p "$BIN_DIR" "$UNLOCKER_DIR"

echo "🔍 Проверка обновлений Antigravity Unlocker на GitHub (confeden/Antigravity)..."

REPO="confeden/Antigravity"
LATEST_RELEASE_JSON=$(curl -sL --connect-timeout 10 "https://api.github.com/repos/$REPO/releases/latest" || true)

if [ -z "$LATEST_RELEASE_JSON" ] || echo "$LATEST_RELEASE_JSON" | grep -q "API rate limit"; then
    echo "⚠️ Не удалось получить данные через GitHub API (лимит запросов или нет сети)."
    if [ -f "$UNLOCKER_DIR/ag_unlocker" ]; then
        echo "ℹ️ Используем существующий $UNLOCKER_DIR/ag_unlocker"
        exit 0
    fi
    FALLBACK_URL="https://github.com/confeden/Antigravity/releases/download/v2.15.1.3/AG_2.15.1.3_linux.tar.gz"
    DOWNLOAD_URL="$FALLBACK_URL"
    TAG="v2.15.1.3"
else
    TAG=$(echo "$LATEST_RELEASE_JSON" | grep -E '"tag_name":' | head -n1 | cut -d'"' -f4)
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep -E 'browser_download_url.*_linux\.tar\.gz"' | head -n1 | cut -d'"' -f4)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Не найдена ссылка на скачивание Linux tar.gz для Antigravity Unlocker."
    exit 1
fi

TEMP_ARCHIVE="${BIN_DIR}/unlocker_latest.tar.gz"

echo "⬇️ Скачивание Antigravity Unlocker $TAG..."
echo "URL: $DOWNLOAD_URL"

if curl -L --progress-bar -o "$TEMP_ARCHIVE" "$DOWNLOAD_URL"; then
    echo "📦 Распаковка Unlocker в $UNLOCKER_DIR..."
    tar -xzf "$TEMP_ARCHIVE" -C "$UNLOCKER_DIR" --strip-components=1 2>/dev/null || tar -xzf "$TEMP_ARCHIVE" -C "$UNLOCKER_DIR"
    rm -f "$TEMP_ARCHIVE"
    chmod +x "$UNLOCKER_DIR/ag_unlocker" "$UNLOCKER_DIR/launch.sh" "$UNLOCKER_DIR/install.sh" 2>/dev/null || true
    echo "✅ Antigravity Unlocker успешно установлен в $UNLOCKER_DIR"
else
    rm -f "$TEMP_ARCHIVE"
    echo "❌ Ошибка при скачивании Antigravity Unlocker."
    exit 1
fi
