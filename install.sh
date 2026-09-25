#!/usr/bin/env bash
# ==============================================================================
#  Antigravity All-in-One — Единый мастер-установщик и конфигуратор
#  Автоматически собирает и настраивает:
#  1. Git-сабмодули (antigravity-add-model)
#  2. Antigravity-Manager (AppImage из GitHub Releases)
#  3. Antigravity-Unlocker (Linux tar.gz из GitHub Releases)
#  4. Модульный патч и конфигурацию моделей
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

# Цвета для красивого вывода
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "========================================================================"
echo "        🚀 ANTIGRAVITY ALL-IN-ONE — UNIFIED INSTALLER & PATCHER         "
echo "========================================================================"
echo -e "${NC}"

# ─── 1. Инициализация Git-сабмодулей ──────────────────────────────────────────

echo -e "${BOLD}[1/6] 📦 Инициализация и синхронизация Git-сабмодулей...${NC}"
if [ -d "$ROOT_DIR/.git" ]; then
    git -C "$ROOT_DIR" submodule update --init --recursive
    echo -e "${GREEN}✓ Сабмодули успешно синхронизированы.${NC}"
else
    echo -e "${YELLOW}ℹ️ Запуск вне git-репозитория, проверка существующих модулей...${NC}"
fi

# ─── 2. Проверка системных зависимостей ────────────────────────────────────────

echo -e "\n${BOLD}[2/6] 🔍 Проверка системных зависимостей...${NC}"

for cmd in node npm curl git tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}❌ Не найдена необходимая утилита: $cmd${NC}"
        echo "Пожалуйста, установите её перед продолжением (например: sudo apt install $cmd)."
        exit 1
    fi
done

NODE_VERSION=$(node -v | tr -d 'v' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Требуется Node.js версии >= 18 (установлена v$(node -v)).${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Node.js $(node -v), npm $(npm -v), git, curl, tar готовы.${NC}"

# ─── 3. Поиск и выбор целевой установки Antigravity ───────────────────────────

echo -e "\n${BOLD}[3/6] 🔎 Поиск установленных версий Antigravity...${NC}"

TARGET_DIR=""

# Проверка флагов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --path|-p)
            TARGET_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Использование: $0 [--path /path/to/antigravity]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then
    mapfile -t DETECTED_PATHS < <("$ROOT_DIR/scripts/detect-antigravity.sh")
    
    if [ ${#DETECTED_PATHS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️ Автоматически установленные версии Antigravity не найдены.${NC}"
        read -r -p "Введите полный путь к папке установки Antigravity: " USER_INPUT_PATH
        TARGET_DIR="$USER_INPUT_PATH"
    elif [ ${#DETECTED_PATHS[@]} -eq 1 ]; then
        TARGET_DIR="${DETECTED_PATHS[0]}"
        echo -e "${GREEN}✓ Найдена установка: $TARGET_DIR${NC}"
    else
        echo -e "${CYAN}Найдено несколько версий Antigravity в системе:${NC}"
        for i in "${!DETECTED_PATHS[@]}"; do
            echo -e "  [${BOLD}$((i + 1))${NC}] ${DETECTED_PATHS[$i]}"
        done
        echo -e "  [${BOLD}$(( ${#DETECTED_PATHS[@]} + 1 ))${NC}] Ввести путь вручную"
        
        while true; do
            read -r -p "Выберите номер для патчинга [1-$(( ${#DETECTED_PATHS[@]} + 1 ))]: " CHOICE
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DETECTED_PATHS[@]}" ]; then
                TARGET_DIR="${DETECTED_PATHS[$((CHOICE - 1))]}"
                break
            elif [ "$CHOICE" -eq "$(( ${#DETECTED_PATHS[@]} + 1 ))" ]; then
                read -r -p "Введите полный путь к Antigravity: " USER_INPUT_PATH
                TARGET_DIR="$USER_INPUT_PATH"
                break
            else
                echo -e "${RED}Неверный ввод, попробуйте снова.${NC}"
            fi
        done
    fi
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Директория $TARGET_DIR не существует.${NC}"
    exit 1
fi

echo -e "${GREEN}🎯 Выбрана цель: ${BOLD}$TARGET_DIR${NC}"

# ─── 4. Загрузка компонентов экосистемы (Manager + Unlocker) ─────────────────

echo -e "\n${BOLD}[4/6] ⬇️ Загрузка и проверка бинарных компонентов...${NC}"

echo -e "\n${CYAN}--- [4.1] Antigravity-Manager (lbjlaq/Antigravity-Manager) ---${NC}"
"$ROOT_DIR/scripts/download-manager.sh"

echo -e "\n${CYAN}--- [4.2] Antigravity-Unlocker (confeden/Antigravity) ---${NC}"
"$ROOT_DIR/scripts/download-unlocker.sh"

# ─── 5. Сборка и установка модульного патча add-model ─────────────────────────

echo -e "\n${BOLD}[5/6] 🛠️ Сборка и установка модульного загрузчика (antigravity-add-model)...${NC}"
"$ROOT_DIR/scripts/patch-target.sh" "$TARGET_DIR"

# ─── 6. Настройка конфигурации моделей ─────────────────────────────────────────

echo -e "\n${BOLD}[6/6] ⚙️ Проверка конфигурации custom_models.json...${NC}"
CUSTOM_MODELS_DIR="$HOME/.gemini/antigravity"
CUSTOM_MODELS_FILE="$CUSTOM_MODELS_DIR/custom_models.json"

mkdir -p "$CUSTOM_MODELS_DIR"

if [ ! -f "$CUSTOM_MODELS_FILE" ]; then
    echo "📋 Создание шаблона custom_models.json под локальный менеджер..."
    cp "$ROOT_DIR/config/custom_models.template.json" "$CUSTOM_MODELS_FILE"
    echo -e "${GREEN}✓ Файл создан: $CUSTOM_MODELS_FILE${NC}"
else
    echo -e "${GREEN}✓ Существующий custom_models.json сохранен.${NC}"
fi

# Сохраняем путь к целевой установке для скрипта start.sh
echo "$TARGET_DIR" > "$ROOT_DIR/.last_target_path"

# ─── Завершение и краткая памятка ─────────────────────────────────────────────

echo -e "\n${GREEN}${BOLD}========================================================================${NC}"
echo -e "${GREEN}${BOLD}             🎉 УСТАНОВКА И НАСТРОЙКА УСПЕШНО ЗАВЕРШЕНЫ!                ${NC}"
echo -e "${GREEN}${BOLD}========================================================================${NC}\n"

echo -e "${BOLD}📌 Как запустить всю связку в один клик:${NC}"
echo -e "   ${CYAN}./start.sh${NC}"
echo -e "   (Скрипт автоматически запустит в фоне Antigravity-Manager и откроет IDE)\n"

echo -e "${BOLD}🔑 О Telegram-ключе и Unlocker:${NC}"
echo -e "   • ${YELLOW}Antigravity-Manager${NC} управляет ротацией ваших Google-аккаунтов и токенов локально."
echo -e "   • ${YELLOW}ag_unlocker${NC} (в папке ${CYAN}bin/unlocker${NC}) нужен ${BOLD}ТОЛЬКО${NC} если у вас"
echo -e "     нет своего VPN и вы хотите использовать сторонний прокси авторов анлокера."
echo -e "     Если у вас включен собственный VPN или запросы идут через Manager — ключ из Telegram не требуется!\n"

echo -e "${BOLD}📂 Расположение файлов:${NC}"
echo -e "   • Запуск:           ${CYAN}$ROOT_DIR/start.sh${NC}"
echo -e "   • Конфиг моделей:   ${CYAN}$CUSTOM_MODELS_FILE${NC}"
echo -e "   • Менеджер:         ${CYAN}$ROOT_DIR/bin/Antigravity-Manager.AppImage${NC}"
echo -e "   • Анлокер:          ${CYAN}$ROOT_DIR/bin/unlocker/launch.sh${NC}\n"
