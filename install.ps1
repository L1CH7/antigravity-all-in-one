<#
.SYNOPSIS
    Antigravity All-in-One — Единый мастер-установщик и конфигуратор для Windows.
.DESCRIPTION
    1. Проверяет системные зависимости (Node.js >= 18, npm, git).
    2. Синхронизирует Git-сабмодули при наличии репозитория.
    3. Автоматически находит целевую установку Antigravity.
    4. Компилирует и накладывает модульный патч и бинарный патч языка.
    5. Безопасно настраивает custom_models.json с сохранением резервных копий.
    6. Связывает каталог регламентов agent-ecosystem через NTFS-соединения (Junctions).
#>

[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Cyan([string]$Text) {
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Green([string]$Text) {
    Write-Host $Text -ForegroundColor Green
}

function Write-Yellow([string]$Text) {
    Write-Host $Text -ForegroundColor Yellow
}

function Write-Red([string]$Text) {
    Write-Host $Text -ForegroundColor Red
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = $scriptDir

Write-Cyan "`n========================================================================"
Write-Cyan "       🚀 ANTIGRAVITY ALL-IN-ONE — УСТАНОВЩИК И ПАТЧЕР ДЛЯ WINDOWS      "
Write-Cyan "========================================================================`n"

# ─── 1. Инициализация Git-сабмодулей ──────────────────────────────────────────
Write-Host "[1/6] 📦 Проверка и синхронизация Git-сабмодулей..." -ForegroundColor White

$addModelPresent = Test-Path -LiteralPath (Join-Path $rootDir 'modules\antigravity-add-model\package.json')
$ecosystemPresent = Test-Path -LiteralPath (Join-Path $rootDir 'modules\agent-ecosystem\rules')

if ($addModelPresent -and $ecosystemPresent) {
    Write-Green "✓ Все необходимые сабмодули уже присутствуют локально."
} else {
    if (Test-Path -LiteralPath (Join-Path $rootDir '.git')) {
        try {
            Write-Host "Синхронизация недостающих модулей через git..." -ForegroundColor DarkGray
            & git -C $rootDir submodule update --init --recursive
            if ($LASTEXITCODE -eq 0) {
                Write-Green "✓ Сабмодули успешно синхронизированы."
            } else {
                Write-Yellow "⚠ Предупреждение: некоторые модули не удалось обновить через git, продолжается работа с локальными файлами."
            }
        } catch {
            Write-Yellow "⚠ Ошибка вызова git submodule: $_"
        }
    } else {
        Write-Host "ℹ Запуск вне git-репозитория, используются локальные файлы модулей." -ForegroundColor DarkGray
    }
}

# ─── 2. Проверка системных зависимостей ────────────────────────────────────────
Write-Host "`n[2/6] 🔍 Проверка системных зависимостей..." -ForegroundColor White

foreach ($cmd in @('node', 'npm', 'git')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Red "❌ Не найдена необходимая утилита: $cmd"
        Write-Host "Пожалуйста, установите её перед продолжением (например, через winget install OpenJS.NodeJS / Git.Git)."
        exit 1
    }
}

try {
    $nodeVerRaw = (& node.exe -v).Trim().TrimStart('v')
    $nodeMajor = [int]($nodeVerRaw.Split('.')[0])
    if ($nodeMajor -lt 18) {
        Write-Red "❌ Требуется Node.js версии >= 18 (установлена v$nodeVerRaw)."
        exit 1
    }
    Write-Green "✓ Node.js v$nodeVerRaw, npm ($((& npm.cmd -v).Trim())), git готовы к работе."
} catch {
    Write-Red "❌ Ошибка при проверке версии Node.js: $_"
    exit 1
}

# ─── 3. Поиск и выбор целевой установки Antigravity ───────────────────────────
Write-Host "`n[3/6] 🔎 Поиск установленных версий Antigravity..." -ForegroundColor White

$targetDir = $Path
$detectScript = Join-Path $rootDir 'scripts\detect-antigravity.ps1'

if (-not $targetDir) {
    $detectedList = [System.Collections.Generic.List[string]]::new()

    if (Test-Path -LiteralPath $detectScript) {
        $psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
        $outputLines = & $psExe -NoProfile -File $detectScript

        foreach ($line in $outputLines) {
            if ($line -and -not [string]::IsNullOrWhiteSpace($line.ToString())) {
                $candidatePath = $line.ToString().Trim()
                if (Test-Path -LiteralPath $candidatePath) {
                    $detectedList.Add($candidatePath)
                }
            }
        }
    }

    $detected = $detectedList.ToArray()

    $lastTargetPathFile = Join-Path $rootDir '.last_target_path'
    $lastTarget = $null
    if (Test-Path -LiteralPath $lastTargetPathFile) {
        $lastTarget = (Get-Content -LiteralPath $lastTargetPathFile -Raw -Encoding utf8).Trim()
    }

    if ($detected.Length -eq 0) {
        Write-Yellow "⚠ Автоматически установленные версии Antigravity не обнаружены."
        $targetDir = Read-Host "Введите полный путь к папке установки Antigravity"
    } elseif ($detected.Length -eq 1) {
        $targetDir = $detected[0]
        Write-Green "✓ Найдена установка: $targetDir"
    } else {
        Write-Cyan "Найдено несколько версий Antigravity в системе:"
        for ($i = 0; $i -lt $detected.Length; $i++) {
            $tag = ""
            if ($lastTarget -and $detected[$i] -eq $lastTarget) {
                $tag = " [предыдущий выбор]"
            }
            Write-Host "  [$($i + 1)] $($detected[$i])$tag" -ForegroundColor White
        }
        Write-Host "  [$($detected.Length + 1)] Ввести собственный путь вручную" -ForegroundColor White

        while ($true) {
            $choice = Read-Host "Выберите номер для патчинга [1-$($detected.Length + 1)]"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $detected.Length) {
                $targetDir = $detected[[int]$choice - 1]
                break
            } elseif ($choice -match '^\d+$' -and [int]$choice -eq ($detected.Length + 1)) {
                $targetDir = Read-Host "Введите полный путь к установке Antigravity"
                break
            } else {
                Write-Red "Некорректный номер, попробуйте снова."
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($targetDir) -or -not (Test-Path -LiteralPath $targetDir)) {
    Write-Red "❌ Каталог '$targetDir' не существует."
    exit 1
}

$targetDir = (Resolve-Path -LiteralPath $targetDir).Path
Write-Green "🎯 Выбрана цель для развертывания: $targetDir"

# ─── 4. Сборка и установка модульного патча add-model ─────────────────────────
Write-Host "`n[4/6] 🛠 Сборка и наложение модульного загрузчика..." -ForegroundColor White

$patchScript = Join-Path $rootDir 'scripts\patch-target.ps1'
if (-not (Test-Path -LiteralPath $patchScript)) {
    Write-Red "❌ Не найден вспомогательный скрипт: $patchScript"
    exit 1
}

$patchParams = @{
    TargetDir = $targetDir
}
if ($Force) { $patchParams['Force'] = $true }

$psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
& $psExe -NoProfile -File $patchScript @patchParams

if ($LASTEXITCODE -ne 0) {
    Write-Red "❌ Ошибка при наложении патча на $targetDir"
    exit $LASTEXITCODE
}

# ─── 5. Безопасная настройка custom_models.json ────────────────────────────────
Write-Host "`n[5/6] ⚙ Настройка конфигурации custom_models.json..." -ForegroundColor White

$customModelsDir = Join-Path $env:USERPROFILE '.gemini\antigravity'
$customModelsFile = Join-Path $customModelsDir 'custom_models.json'
$templateFile = Join-Path $rootDir 'config\custom_models.template.json'

if (-not (Test-Path -LiteralPath $customModelsDir)) {
    New-Item -ItemType Directory -Path $customModelsDir -Force | Out-Null
}

if (Test-Path -LiteralPath $customModelsFile) {
    $existingContent = Get-Content -LiteralPath $customModelsFile -Raw -Encoding utf8
    $modelMatches = [regex]::Matches($existingContent, '"name":')
    $modelCount = $modelMatches.Count

    Write-Green "✓ Файл custom_models.json уже существует (сконфигурировано моделей: $modelCount)."
    Write-Host "В целях информационной безопасности пользовательские настройки не перезаписываются автоматически." -ForegroundColor DarkGray

    $doOverwrite = $false
    if ($Force) {
        $doOverwrite = $true
    } else {
        $ans = Read-Host "Хотите обновить конфигурацию стандартным шаблоном под Antigravity-Manager? [y/N]"
        if ($ans -match '^[YyДд]$') {
            $doOverwrite = $true
        }
    }

    if ($doOverwrite) {
        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $backupFile = "$customModelsFile.bak_$timestamp"
        Copy-Item -LiteralPath $customModelsFile -Destination $backupFile -Force
        Write-Yellow "📦 Создана резервная копия: $backupFile"

        if (Test-Path -LiteralPath $templateFile) {
            Copy-Item -LiteralPath $templateFile -Destination $customModelsFile -Force
            Write-Green "✓ Конфигурация успешно обновлена из шаблона."
        }
    }
} else {
    if (Test-Path -LiteralPath $templateFile) {
        Copy-Item -LiteralPath $templateFile -Destination $customModelsFile -Force
        Write-Green "✓ Создан начальный файл моделей: $customModelsFile"
    } else {
        Write-Yellow "⚠ Шаблон $templateFile не найден, пропуск создания файла."
    }
}

# ─── 6. Подключение регламентов (agent-ecosystem) через NTFS-соединения ───────
Write-Host "`n[6/6] 🌐 Подключение правил и регламентов (agent-ecosystem)..." -ForegroundColor White

$ecosystemRulesSrc = Join-Path $rootDir 'modules\agent-ecosystem\rules'
$geminiConfigDir = Join-Path $env:USERPROFILE '.gemini\config'
$targetRulesJunction = Join-Path $geminiConfigDir 'rules'

if (Test-Path -LiteralPath $ecosystemRulesSrc) {
    if (-not (Test-Path -LiteralPath $geminiConfigDir)) {
        New-Item -ItemType Directory -Path $geminiConfigDir -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $targetRulesJunction)) {
        try {
            # Создаем NTFS Junction (не требует прав администратора на Windows)
            New-Item -ItemType Junction -Path $targetRulesJunction -Target $ecosystemRulesSrc -Force | Out-Null
            Write-Green "✓ Подключено соединение правил: $targetRulesJunction -> $ecosystemRulesSrc"
        } catch {
            Write-Yellow "ℹ Не удалось создать соединение правил: $_"
        }
    } else {
        Write-Green "✓ Регламенты правил уже подключены: $targetRulesJunction"
    }
}

# Сохраняем целевой путь для скрипта запуска
Set-Content -LiteralPath (Join-Path $rootDir '.last_target_path') -Value $targetDir -Encoding utf8 -Force

# ─── Итог и памятка пользователю ──────────────────────────────────────────────
Write-Green "`n========================================================================"
Write-Green "             🎉 УСТАНОВКА И НАСТРОЙКА УСПЕШНО ЗАВЕРШЕНЫ!                "
Write-Green "========================================================================`n"

Write-Host "📌 Запуск связки:" -ForegroundColor White
Write-Cyan "   .\start.ps1   (или запустите start.bat двойным кликом)`n"

Write-Host "🔑 Компоненты экосистемы:" -ForegroundColor White
Write-Host "   • Antigravity-Manager (порт 8045):" -ForegroundColor Yellow
Write-Host "     Запустите инсталлятор 'Antigravity.Tools_5.0.2-beta.2_x64-setup.exe' в родительской папке,"
Write-Host "     авторизуйте ваши Google-аккаунты в интерфейсе программы."
Write-Host "   • Antigravity-Unlocker (AG_2.28.2.exe):" -ForegroundColor Yellow
Write-Host "     Запустите для снятия регионального запрета UNSUPPORTED_LOCATION."
Write-Host "     Ключ из Telegram НЕ ТРЕБУЕТСЯ, если запросы идут локально через менеджер аккаунтов!`n"

Write-Host "📂 Расположение ключевых файлов:" -ForegroundColor White
Write-Host "   • Патч наложен на:  $targetDir" -ForegroundColor DarkGray
Write-Host "   • Конфиг моделей:   $customModelsFile" -ForegroundColor DarkGray
Write-Host "   • Запуск системы:   $rootDir\start.ps1`n" -ForegroundColor DarkGray
