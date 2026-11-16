<#
.SYNOPSIS
    Безопасная сборка и наложение модульного патча antigravity-add-model на целевую установку Windows.
.DESCRIPTION
    1. Завершает блокирующие процессы Antigravity и language_server.
    2. Собирает TypeScript в dist/.
    3. Вызывает проверенный транзакционный установщик scripts/deploy.mjs с флагом --patch-language-server.
    4. Фиксирует путь успешной установки.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetDir,

    [switch]$Force,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Цветовое оформление консоли
function Write-StatusHeader([string]$Text) {
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Write-Success([string]$Text) {
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-WarningMsg([string]$Text) {
    Write-Host "⚠ $Text" -ForegroundColor Yellow
}

function Write-ErrorMsg([string]$Text) {
    Write-Host "❌ $Text" -ForegroundColor Red
}

# 1. Валидация входных путей
if (-not (Test-Path -LiteralPath $TargetDir)) {
    Write-ErrorMsg "Указанный целевой каталог не существует: $TargetDir"
    exit 1
}

$resolvedTarget = (Resolve-Path -LiteralPath $TargetDir).Path
$resourcesDir = Join-Path $resolvedTarget 'resources'

if (-not (Test-Path -LiteralPath (Join-Path $resourcesDir 'app.asar'))) {
    if (Test-Path -LiteralPath (Join-Path $resolvedTarget 'app.asar')) {
        $resourcesDir = $resolvedTarget
        $resolvedTarget = Split-Path -Parent $resourcesDir
    } else {
        Write-ErrorMsg "В каталоге $resolvedTarget не обнаружен файл resources\app.asar."
        exit 1
    }
}

Write-StatusHeader "Целевая установка Antigravity: $resolvedTarget"

# 2. Проверка и безопасное завершение активных процессов
$procNames = @('Antigravity', 'language_server')
$activeProcesses = Get-Process -Name $procNames -ErrorAction SilentlyContinue

if ($activeProcesses) {
    Write-WarningMsg "Обнаружены активные процессы Antigravity или language_server ($($activeProcesses.Count) процессов)."
    Write-WarningMsg "В операционной системе Windows открытые исполняемые файлы и архивы блокируются файловой системой."

    $shouldKill = $Force
    if (-not $shouldKill) {
        $choice = Read-Host "Завершить процессы автоматически для безопасного наложения патча? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^[YyДд]$') {
            $shouldKill = $true
        }
    }

    if ($shouldKill) {
        Write-Host "Завершение процессов..." -ForegroundColor Yellow
        foreach ($proc in $activeProcesses) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            } catch {}
        }
        Start-Sleep -Milliseconds 800
        Write-Success "Процессы успешно завершены."
    } else {
        Write-ErrorMsg "Установка прервана. Закройте Antigravity вручную перед продолжением."
        exit 1
    }
}

# 3. Определение расположения сабмодуля antigravity-add-model
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

$addModelCandidates = @(
    (Join-Path $rootDir 'modules\antigravity-add-model'),
    (Join-Path $rootDir 'antigravity-add-model'),
    (Join-Path (Split-Path -Parent $rootDir) 'antigravity-add-model')
)

$addModelDir = $null
foreach ($cand in $addModelCandidates) {
    if (Test-Path -LiteralPath (Join-Path $cand 'package.json')) {
        $addModelDir = (Resolve-Path -LiteralPath $cand).Path
        break
    }
}

if (-not $addModelDir) {
    Write-ErrorMsg "Не найден каталог сабмодуля antigravity-add-model."
    exit 1
}

Write-Host "Используется модуль патча: $addModelDir" -ForegroundColor DarkGray

# 4. Проверка и компиляция TypeScript в dist/
Push-Location -LiteralPath $addModelDir
try {
    $tscBin = Join-Path $addModelDir 'node_modules\.bin\tsc.cmd'
    $tsPackage = Join-Path $addModelDir 'node_modules\typescript\package.json'
    $asarPackage = Join-Path $addModelDir 'node_modules\@electron\asar\package.json'

    $needsInstall = (-not (Test-Path -LiteralPath $tsPackage)) -or `
                    (-not (Test-Path -LiteralPath $asarPackage)) -or `
                    (-not (Test-Path -LiteralPath $tscBin))

    if ($needsInstall) {
        Write-Host "📦 Установка зависимостей Node.js (включая TypeScript и devDependencies)..." -ForegroundColor Cyan
        $env:NODE_ENV = 'development'

        & npm.cmd install --include=dev --ignore-scripts --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) {
            Write-WarningMsg "npm install завершился с кодом $LASTEXITCODE, повторяем через npm ci..."
            & npm.cmd ci --include=dev --ignore-scripts
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorMsg "Не удалось установить зависимости npm."
                exit $LASTEXITCODE
            }
        }
    }

    $distLoader = Join-Path $addModelDir 'dist\loader.js'
    $distMain = Join-Path $addModelDir 'dist\main.js'

    if (-not $SkipBuild -or -not (Test-Path -LiteralPath $distLoader) -or -not (Test-Path -LiteralPath $distMain)) {
        Write-Host "🔨 Компиляция TypeScript в dist/..." -ForegroundColor Cyan

        # Запускаем локальный компилятор tsc напрямую, минуя npx
        if (Test-Path -LiteralPath $tscBin) {
            & "$tscBin"
        } else {
            Write-ErrorMsg "Не найден исполняемый файл компилятора TypeScript: $tscBin"
            Write-Host "Выполните 'npm install --include=dev' в каталоге '$addModelDir'."
            exit 1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Ошибка компиляции TypeScript проекта."
            exit $LASTEXITCODE
        }
        Write-Success "Сборка завершена успешно."
    }

    # 5. Вызов проверенного установщика deploy.mjs
    Write-StatusHeader "Применение патча к ресурсам"
    $deployScript = Join-Path $addModelDir 'scripts\deploy.mjs'

    # Важно: на Windows передаем --modular и обязательный --patch-language-server
    $deployArgs = @(
        $deployScript,
        '--resources', $resourcesDir,
        '--modular',
        '--patch-language-server'
    )

    Write-Host "Выполнение: node $($deployArgs -join ' ')" -ForegroundColor DarkGray
    & node.exe @deployArgs

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Установщик deploy.mjs вернул код ошибки: $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # Сохраняем последний успешный целевой путь
    $lastTargetPathFile = Join-Path $rootDir '.last_target_path'
    Set-Content -LiteralPath $lastTargetPathFile -Value $resolvedTarget -Encoding utf8 -Force

    Write-Success "Модульный патч и фиксация конечной точки успешно установлены в $resolvedTarget."
} finally {
    Pop-Location
}
