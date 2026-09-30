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

run_npm() {
    if npm -v >/dev/null 2>&1; then
        npm "$@"
    else
        # Fallback обертка для обхода бага сломанного semver в Arch Linux
        node -e '
            process.argv = [process.argv[0], "/usr/bin/npm", ...process.argv.slice(1)];
            const Module = require("module");
            const orig = Module._resolveFilename;
            Module._resolveFilename = function(req, p, m, o) {
                if (req.startsWith("semver")) return orig.call(this, "/usr/lib/node_modules/semver" + req.slice(6), p, m, o);
                return orig.apply(this, arguments);
            };
            require("/usr/lib/node_modules/npm/bin/npm-cli.js");
        ' "$@"
    fi
}

# 1. Проверяем наличие и инициализируем сабмодуль, если нужно
if [ ! -f "$ADD_MODEL_DIR/package.json" ]; then
    echo "📦 Инициализация сабмодуля antigravity-add-model..."
    git -C "$ROOT_DIR" submodule update --init --recursive modules/antigravity-add-model || true
fi

if [ ! -f "$ADD_MODEL_DIR/package.json" ]; then
    echo "❌ Ошибка: файлы сабмодуля antigravity-add-model не найдены."
    exit 1
fi

echo "📦 Подготовка и сборка модульного патча antigravity-add-model..."
cd "$ADD_MODEL_DIR"

if [ ! -d "node_modules" ]; then
    echo "⬇️ Установка зависимостей Node.js..."
    run_npm ci || run_npm install
fi

if [ ! -f "dist/main.js" ]; then
    echo "🔨 Компиляция TypeScript в dist/..."
    run_npm run build
fi

if pgrep -fa "antigravity" >/dev/null 2>&1; then
    echo -e "\033[1;33m⚠️ Внимание: Antigravity сейчас запущен. Закройте и откройте приложение заново после применения патча.\033[0m"
fi

echo "🚀 Установка модульного загрузчика в $RESOURCES_DIR..."
node scripts/deploy.mjs --resources "$RESOURCES_DIR"

echo "$TARGET_DIR" > "$ROOT_DIR/.last_target_path"
echo -e "\033[0;32m✅ Патч успешно наложен на $TARGET_DIR\033[0m"
