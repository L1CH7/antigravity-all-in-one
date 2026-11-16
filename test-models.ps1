#Requires -Version 5.1
[CmdletBinding()]
param()

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "      ДИАГНОСТИКА И ТЕСТИРОВАНИЕ КАСТОМНЫХ МОДЕЛЕЙ ANTIGRAVITY" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Проверка процессов
Write-Host "[1/4] Проверка процессов..." -ForegroundColor Yellow

$procAntigravity = Get-Process -Name antigravity -ErrorAction SilentlyContinue
$procManager     = Get-Process -Name "Antigravity.Tools", "antigravity-manager" -ErrorAction SilentlyContinue

if ($procAntigravity) {
    Write-Host "  [OK] Antigravity запущен (PID: $($procAntigravity[0].Id), процессов: $($procAntigravity.Count))" -ForegroundColor Green
} else {
    Write-Host "  [!] Antigravity НЕ запущен. Запустите через .\start.ps1" -ForegroundColor Yellow
}

if ($procManager) {
    Write-Host "  [OK] Antigravity-Manager запущен (PID: $($procManager[0].Id))" -ForegroundColor Green
} else {
    Write-Host "  [!] Antigravity-Manager не обнаружен в процессах" -ForegroundColor Yellow
}

# 2. Проверка сетевых портов
Write-Host ""
Write-Host "[2/4] Проверка портов..." -ForegroundColor Yellow

$managerStatus = 0

# Порт 50999 (Внутренний прокси Antigravity)
$tcpProxy = Test-NetConnection -ComputerName 127.0.0.1 -Port 50999 -WarningAction SilentlyContinue
if ($tcpProxy.TcpTestSucceeded) {
    Write-Host "  [OK] Порт 50999 (Модульный прокси Antigravity): ОТКРЫТ" -ForegroundColor Green
} else {
    Write-Host "  [-] Порт 50999 (Модульный прокси Antigravity): НЕДОСТУПЕН" -ForegroundColor Red
}

# Порт 8045 (Antigravity-Manager)
$tcpManager = Test-NetConnection -ComputerName 127.0.0.1 -Port 8045 -WarningAction SilentlyContinue
if ($tcpManager.TcpTestSucceeded) {
    Write-Host "  [OK] Порт 8045 (Antigravity-Manager): ОТКРЫТ" -ForegroundColor Green
    
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8045/v1beta/models" -Method Get -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        $managerStatus = $resp.StatusCode
        Write-Host "    [OK] Пул аккаунтов активен (HTTP 200 OK)" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response) {
            $managerStatus = [int]$_.Exception.Response.StatusCode
        } else {
            $managerStatus = -1
        }

        if ($managerStatus -eq 503) {
            Write-Host "    [!] Внимание: Менеджер вернул 503 (Proxy service is currently disabled)." -ForegroundColor Yellow
            Write-Host "        Откройте окно Antigravity-Manager и авторизуйте Google-аккаунт!" -ForegroundColor Yellow
        } else {
            Write-Host "    [!] Ответ менеджера: HTTP $managerStatus ($($_.Exception.Message))" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  [-] Порт 8045 (Antigravity-Manager): ЗАКРЫТ" -ForegroundColor Red
}

# 3. Чтение файла конфигурации моделей
Write-Host ""
Write-Host "[3/4] Чтение конфигурации моделей..." -ForegroundColor Yellow

$configPath = Join-Path $env:USERPROFILE ".gemini\antigravity\custom_models.json"
if (-not (Test-Path $configPath)) {
    $configPath = Join-Path $PSScriptRoot "config\custom_models.template.json"
}

if (-not (Test-Path $configPath)) {
    Write-Host "  [-] Файл конфигурации моделей не найден: $configPath" -ForegroundColor Red
    exit 1
}

Write-Host "  Конфигурация: $configPath" -ForegroundColor Gray

try {
    $rawJson = Get-Content -Path $configPath -Raw -Encoding UTF8
    $config = $rawJson | ConvertFrom-Json
    $models = $config.models
    Write-Host "  [OK] Загружено моделей из конфигурации: $($models.Count)" -ForegroundColor Green
} catch {
    Write-Host "  [-] Ошибка парсинга JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Тестирование доступности каждого эндпоинта
Write-Host ""
Write-Host "[4/4] Тестирование доступности моделей..." -ForegroundColor Yellow
Write-Host ""

$results = @()

foreach ($m in $models) {
    $modelName = $m.name
    if ($m.displayName) { $modelName = $m.displayName }
    $apiUrl    = $m.apiUrl
    $provider  = $m.provider
    $status    = "Unknown"
    $detail    = ""

    if ([string]::IsNullOrWhiteSpace($apiUrl)) {
        $status = "[!] Пропущено"
        $detail = "apiUrl не указан"
    } else {
        try {
            $uriObj = [System.Uri]$apiUrl
            $hostName = $uriObj.Host
            $port = $uriObj.Port
            if ($port -le 0) {
                if ($uriObj.Scheme -eq "https") { $port = 443 } else { $port = 80 }
            }
            
            $tcpCheck = Test-NetConnection -ComputerName $hostName -Port $port -WarningAction SilentlyContinue
            if ($tcpCheck.TcpTestSucceeded) {
                if ($hostName -eq "127.0.0.1" -and $port -eq 8045) {
                    if ($managerStatus -eq 503) {
                        $status = "[!] Нужен вход"
                        $detail = "Менеджер доступен, но требует входа в Google-аккаунт (HTTP 503)"
                    } else {
                        $status = "[OK] Готов"
                        $detail = "Локальный менеджер отвечает"
                    }
                } else {
                    $status = "[OK] Доступен"
                    $detail = "Порт $port открыт"
                }
            } else {
                $status = "[-] Недоступен"
                $detail = "Хост $hostName ($port) не отвечает по TCP"
            }
        } catch {
            $status = "[-] Ошибка URL"
            $detail = $_.Exception.Message
        }
    }

    $results += [PSCustomObject]@{
        "Модель"     = $modelName
        "Провайдер"  = $provider
        "Статус"     = $status
        "Примечание" = $detail
    }
}

$results | Format-Table -AutoSize

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "КАК ВЫПОЛНИТЬ ТЕСТОВЫЙ ЗАПРОС:" -ForegroundColor Cyan
Write-Host "  1. В приложении Antigravity откройте окно диалога (чат)." -ForegroundColor Gray
Write-Host "  2. В выпадающем списке выбора модели выберите нужную модель." -ForegroundColor Gray
Write-Host "  3. Отправьте тестовую фразу: 'Привет, напиши 1+1'." -ForegroundColor Gray
Write-Host "  4. Для моделей через Antigravity-Manager (порт 8045) убедитесь," -ForegroundColor Gray
Write-Host "     что в окне Antigravity.Tools выполнен вход в аккаунт Google." -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
