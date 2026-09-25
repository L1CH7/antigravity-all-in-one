# 🚀 Antigravity All-in-One Suite

Единый монолитный инструмент автоматической сборки, установки и управления экосистемой **Google Antigravity** (Agentic 2.0 и IDE) на Linux.

Связывает воедино 3 ключевых компонента:
1. **`antigravity-add-model`** (модульный TypeScript-загрузчик, оффлайн-кэш и локальный gRPC/HTTP прокси).
2. **`Antigravity-Manager`** (локальный пул аккаунтов Google, балансировка квот и sticky sessions).
3. **`Antigravity-Unlocker`** (локальный патч eligibility и региональный прокси-маршрут).

---

## ⚡ Быстрый старт (в 1 команду)

```bash
# 1. Клонировать репозиторий вместе с сабмодулями
git clone --recursive https://github.com/L1CH7/antigravity-all-in-one.git
cd antigravity-all-in-one

# 2. Установка и автоматический патчинг (с автопоиском путей Antigravity)
./install.sh

# 3. Запуск всей связки (Менеджер в фоне + IDE)
./start.sh
```

---

## 🏗️ Архитектура связки

```text
┌────────────────────────────────────────────────────────┐
│             Antigravity IDE (Electron UI)              │
│       (Выбор моделей в чате, поддержка нативных имён)   │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│             Модульный Loader & Proxy                   │
│             (modules/antigravity-add-model)            │
│  • Не затирает файлы Google (100% стабильность)        │
│  • Оффлайн-кэш (защита от "No models available")       │
│  • Перехват Cloud Code и нативных запросов             │
└──────────────┬───────────────────────────┬─────────────┘
               │                           │
               │ (Кастомные модели)        │ (Нативные запросы)
               ▼                           ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│     Antigravity-Manager      │ │     Antigravity-Unlocker     │
│  (bin/Antigravity-Manager)   │ │       (bin/unlocker/)        │
│ • Пул Google-аккаунтов       │ │ • Патч eligibility           │
│ • Ротация лимитов и квот     │ │ • Региональный прокси (опция)│
│ • Sticky sessions & Thinking │ └──────────────────────────────┘
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│     Google Gemini API        │
└──────────────────────────────┘
```

---

## 📦 Компоненты и их источники

| Компонент | Как поставляется | Источник | Расположение в проекте |
|---|---|---|---|
| **`antigravity-add-model`** | Git Submodule | [`L1CH7/antigravity-add-model`](https://github.com/L1CH7/antigravity-add-model) | `modules/antigravity-add-model/` |
| **`Antigravity-Manager`** | Автозагрузка (AppImage) | [`lbjlaq/Antigravity-Manager`](https://github.com/lbjlaq/Antigravity-Manager/releases/latest) | `bin/Antigravity-Manager.AppImage` |
| **`Antigravity-Unlocker`** | Автозагрузка (Linux tar.gz) | [`confeden/Antigravity`](https://github.com/confeden/Antigravity/releases/latest) | `bin/unlocker/` |
| **`custom_models.json`** | Конфигурационный шаблон | Встроен в проект | `~/.gemini/antigravity/custom_models.json` |

---

## 🔑 Частые вопросы

### Зачем в Unlocker просится ключ из Telegram? Нужен ли он?
* **Для чего ключ авторам:** Автор `ag_unlocker` держит свои удаленные Egress-серверы в ЕС/США для пользователей без собственного VPN. Ключ из Telegram — это авторизация на сервере авторов.
* **Нужен ли он вам:** **НЕТ!** Если у вас работает `Antigravity-Manager` с собственными аккаунтами или включен локальный VPN — запросы идут локально или через ваш VPN, и сторонний сервер/ключ не требуются. От анлокера нужен только локальный патч eligibility бинарника `language_server`.

### Где хранятся настройки моделей?
Конфигурационный файл находится по пути:
`~/.gemini/antigravity/custom_models.json`

В него автоматически прописываются все модели Gemini Native (`gemini-3.8-flash-high`, `gemini-3.7-flash-high` и др.), направленные на локальный порт менеджера `http://127.0.0.1:3000/v1beta`.

---

## 🛠️ Вспомогательные скрипты (`scripts/`)

```bash
# Автоматический поиск всех установленных версий Antigravity в системе
./scripts/detect-antigravity.sh

# Загрузка свежего AppImage менеджера с GitHub Releases
./scripts/download-manager.sh

# Загрузка свежего архива Unlocker с GitHub Releases
./scripts/download-unlocker.sh

# Сборка и наложение патча add-model на конкретную директорию
./scripts/patch-target.sh ~/.local/share/antigravity-agentic-2.17.0
```
