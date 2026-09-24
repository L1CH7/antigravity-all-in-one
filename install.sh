#!/usr/bin/env bash
# ==============================================================================
#  Antigravity Suite — Единый мастер-установщик и конфигуратор
#  Включает: antigravity-add-model + Antigravity-Manager + antigravity-unlocker
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
echo "          🚀 ANTIGRAVITY SUITE — UNIFIED INSTALLER & PATCHER            "
echo "========================================================================"
echo -e "${NC}"

# ─── 1. Проверка системных зависимостей ────────────────────────────────────────

echo -e "${BOLD}[1/5] 🔍 Проверка системных зависимостей...${NC}"

for cmd in node npm curl git; do
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
echo -e "${GREEN}✓ Node.js $(node -v), npm $(npm -v), git, curl найдены.${NC}"

# ─── 2. Поиск и выбор целевой установки Antigravity ───────────────────────────

echo -e "\n${BOLD}[2/5] 🔎 Поиск установленных версий Antigravity...${NC}"

TARGET_DIR=""

# Проверка флага --path
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
    mapfile -t DETECTED_PATHS < <("$SCRIPT_DIR/scripts/detect-antigravity.sh")
    
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

# ─── 3. Загрузка / проверка Antigravity-Manager ────────────────────────────────

echo -e "\n${BOLD}[3/5] ⬇️ Проверка и загрузка Antigravity-Manager (AppImage)...${NC}"
"$SCRIPT_DIR/scripts/download-manager.sh"

# ─── 4. Сборка и установка модульного патча add-model ─────────────────────────

echo -e "\n${BOLD}[4/5] 🛠️ Установка модульного загрузчика (antigravity-add-model)...${NC}"
"$SCRIPT_DIR/scripts/patch-target.sh" "$TARGET_DIR"

# ─── 5. Настройка конфигурации моделей ─────────────────────────────────────────

echo -e "\n${BOLD}[5/5] ⚙️ Проверка конфигурации custom_models.json...${NC}"
CUSTOM_MODELS_DIR="$HOME/.gemini/antigravity"
CUSTOM_MODELS_FILE="$CUSTOM_MODELS_DIR/custom_models.json"

mkdir -p "$CUSTOM_MODELS_DIR"

if [ ! -f "$CUSTOM_MODELS_FILE" ]; then
    echo "📋 Создание шаблона custom_models.json под локальный менеджер..."
    cp "$SCRIPT_DIR/config/custom_models.template.json" "$CUSTOM_MODELS_FILE"
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
echo -e "   • ${YELLOW}ag_unlocker${NC} (в папке ${CYAN}modules/antigravity-unlocker${NC}) нужен ${BOLD}ТОЛЬКО${NC} если у вас"
echo -e "     нет своего VPN и вы хотите использовать сторонний прокси авторов анлокера."
echo -e "     Если у вас включен собственный VPN или запросы идут через Manager — ключ из Telegram не требуется!\n"

echo -e "${BOLD}📂 Полезные файлы:${NC}"
echo -e "   • Запуск:  ${CYAN}$ROOT_DIR/start.sh${NC}"
echo -e "   • Конфиг моделей: ${CYAN}$CUSTOM_MODELS_FILE${NC}"
echo -e "   • Менеджер: ${CYAN}$ROOT_DIR/bin/Antigravity-Manager.AppImage${NC}"
echo -e "   • Анлокер:  ${CYAN}$ROOT_DIR/modules/antigravity-unlocker/launch.sh${NC}\n"
