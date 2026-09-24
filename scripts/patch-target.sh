#!/usr/bin/env bash
# scripts/patch-target.sh
# Сборка и установка патча antigravity-add-model на целевую установку

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADD_MODEL_DIR="$ROOT_DIR/modules/antigravity-add-model"

TARGET_DIR="${1:-}"

if [ -z "$TARGET_DIR" ]; then
    echo "❌ Ошибка: не указан путь к установке Antigravity."
    echo "Использование: $0 /path/to/antigravity"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Ошибка: директория $TARGET_DIR не существует."
    exit 1
fi

RESOURCES_DIR="$TARGET_DIR/resources"
if [ ! -d "$RESOURCES_DIR" ]; then
    if [ -d "$TARGET_DIR/app" ] && [ -d "$TARGET_DIR/../resources" ]; then
        RESOURCES_DIR="$(readlink -f "$TARGET_DIR/../resources")"
    else
        echo "❌ Ошибка: папка resources не найдена внутри $TARGET_DIR"
        exit 1
    fi
fi

echo "📦 Подготовка и сборка модульного патча antigravity-add-model..."
cd "$ADD_MODEL_DIR"

if [ ! -d "node_modules" ]; then
    echo "⬇️ Установка зависимостей Node.js..."
    npm install --silent
fi

echo "🔨 Компиляция TypeScript в dist/..."
npm run build --silent

echo "🚀 Установка модульного загрузчика в $RESOURCES_DIR..."
node scripts/deploy.mjs --resources "$RESOURCES_DIR"

echo "✅ Патч успешно наложен на $TARGET_DIR"
