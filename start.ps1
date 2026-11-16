<#
.SYNOPSIS
    Antigravity All-in-One — Единый мастер-лаунчер для Windows.
.DESCRIPTION
    1. Проверяет активность локального Antigravity-Manager на порту 8045.
    2. При необходимости запускает установленный менеджер.
    3. Находит исполняемый файл Antigravity.exe и запускает его.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AppArgs
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

function Test-PortOpen([string]$HostName, [int]$Port, [int]$TimeoutMs = 1000) {
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        $success = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $success) {
            $client.Close()
            return $false
        }
        $client.EndConnect($asyncResult)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = $scriptDir

Write-Cyan "`n🚀 Запуск Antigravity All-in-One Suite (Windows)..."

# ─── 1. Проверка доступности Antigravity-Manager ──────────────────────────────
$managerPort = 8045
Write-Host "Проверка подключения к менеджеру аккаунтов (порт $managerPort)..." -ForegroundColor DarkGray

$isManagerUp = Test-PortOpen -HostName '127.0.0.1' -Port $managerPort -TimeoutMs 800

if ($isManagerUp) {
    Write-Green "✓ Antigravity-Manager активен и слушает порт $managerPort."
} else {
    Write-Yellow "⚠ Antigravity-Manager не отвечает на порту $managerPort."

    # Поиск установленного бинарника Antigravity.Tools
    $searchLocations = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity.Tools\Antigravity.Tools.exe'),
        (Join-Path $env:ProgramFiles 'Antigravity.Tools\Antigravity.Tools.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Antigravity.Tools\Antigravity.Tools.exe'),
        (Join-Path $env:APPDATA 'Antigravity.Tools\Antigravity.Tools.exe')
    )

    $managerExe = $null
    foreach ($loc in $searchLocations) {
        if (Test-Path -LiteralPath $loc) {
            $managerExe = $loc
            break
        }
    }

    if ($managerExe) {
        Write-Host "⚡ Запуск Antigravity.Tools из $managerExe..." -ForegroundColor Yellow
        Start-Process -FilePath $managerExe -WindowStyle Minimized
        Start-Sleep -Seconds 2

        if (Test-PortOpen -HostName '127.0.0.1' -Port $managerPort -TimeoutMs 1500) {
            Write-Green "✓ Antigravity-Manager успешно запущен."
        } else {
            Write-Yellow "ℹ Приложение запущено, инициализация может занять несколько секунд."
        }
    } else {
        Write-Yellow "ℹ Для работы пула Google-аккаунтов запустите 'Antigravity.Tools' вручную"
        Write-Host "  (Инсталлятор находится в родительской папке: Antigravity.Tools_5.0.2-beta.2_x64-setup.exe)." -ForegroundColor DarkGray
    }
}

# ─── 2. Определение пути к установке Antigravity ──────────────────────────────
$targetDir = $null
$lastTargetPathFile = Join-Path $rootDir '.last_target_path'

if (Test-Path -LiteralPath $lastTargetPathFile) {
    $savedPath = (Get-Content -LiteralPath $lastTargetPathFile -Raw -Encoding utf8).Trim()
    if ($savedPath -and (Test-Path -LiteralPath $savedPath)) {
        $targetDir = $savedPath
    }
}

if (-not $targetDir) {
    $detectScript = Join-Path $rootDir 'scripts\detect-antigravity.ps1'
    if (Test-Path -LiteralPath $detectScript) {
        $psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
        $outputLines = & $psExe -NoProfile -File $detectScript
        foreach ($line in $outputLines) {
            if ($line -and -not [string]::IsNullOrWhiteSpace($line.ToString())) {
                $cand = $line.ToString().Trim()
                if (Test-Path -LiteralPath $cand) {
                    $targetDir = $cand
                    break
                }
            }
        }
    }
}

if (-not $targetDir -or -not (Test-Path -LiteralPath $targetDir)) {
    Write-Red "❌ Не найден путь к пропатченной установке Antigravity."
    Write-Host "Пожалуйста, сначала выполните установку: .\install.ps1" -ForegroundColor Yellow
    exit 1
}

# ─── 3. Поиск исполняемого файла Antigravity.exe ──────────────────────────────
$exeCandidates = @(
    (Join-Path $targetDir 'Antigravity.exe'),
    (Join-Path $targetDir 'antigravity.exe')
)

$targetExe = $null
foreach ($exe in $exeCandidates) {
    if (Test-Path -LiteralPath $exe) {
        $targetExe = $exe
        break
    }
}

if (-not $targetExe) {
    Write-Red "❌ Исполняемый файл Antigravity.exe не найден в каталоге: $targetDir"
    exit 1
}

Write-Green "✨ Запуск Antigravity: $targetExe"

# Отключаем обращения к WSL для работы исключительно в среде Windows
$env:ANTIGRAVITY_WSL_DISTRO = ''

$processParams = @{
    FilePath = $targetExe
}
$launchArgs = @('--wsl-distro=')
if ($AppArgs -and $AppArgs.Count -gt 0) {
    $launchArgs += $AppArgs
}
$processParams['ArgumentList'] = $launchArgs



Start-Process @processParams
Write-Host "Приложение запущено.`n" -ForegroundColor Green
