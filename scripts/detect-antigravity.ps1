<#
.SYNOPSIS
    Автоматический поиск и валидация установленных версий Google Antigravity в Windows.
.DESCRIPTION
    Сканирует активные процессы, стандартные каталоги AppData/Program Files и ярлыки меню «Пуск».
    Проверяет целостность структуры и наличие ресурсов (resources\app.asar).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Resolve-ShortcutTarget {
    param([string]$ShortcutPath)
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($ShortcutPath)
        return $shortcut.TargetPath
    } catch {
        return $null
    }
}

$rawCandidates = [System.Collections.Generic.List[string]]::new()

# 1. Проверка активных процессов Antigravity
try {
    $runningProcesses = Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue
    foreach ($proc in $runningProcesses) {
        try {
            $mainModulePath = $proc.MainModule.FileName
            if ($mainModulePath -and (Test-Path -LiteralPath $mainModulePath)) {
                $rawCandidates.Add((Split-Path -Parent $mainModulePath))
            }
        } catch {
            # Доступ к MainModule может быть ограничен при повышенных правах
        }
    }
} catch {}

# 2. Стандартные каталоги установки Windows (локальный профиль пользователя)
$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) {
    $localAppData = Join-Path $env:USERPROFILE 'AppData\Local'
}

$standardUserPaths = @(
    (Join-Path $localAppData 'Programs\antigravity'),
    (Join-Path $localAppData 'Programs\Antigravity'),
    (Join-Path $localAppData 'Programs\Antigravity IDE'),
    (Join-Path $localAppData 'Programs\antigravity-ide')
)

foreach ($p in $standardUserPaths) {
    if (Test-Path -LiteralPath $p) {
        $rawCandidates.Add($p)
    }
}

# 3. Общесистемные каталоги установки (Program Files)
$programFilesDirs = @(
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)}
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

foreach ($pf in $programFilesDirs) {
    $candidates = @(
        (Join-Path $pf 'Antigravity'),
        (Join-Path $pf 'antigravity'),
        (Join-Path $pf 'Antigravity IDE')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            $rawCandidates.Add($c)
        }
    }
}

# 4. Поиск через ярлыки меню «Пуск» и рабочего стола
$shortcutFolders = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
    ([System.Environment]::GetFolderPath('Desktop')),
    ([System.Environment]::GetFolderPath('CommonDesktop'))
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

foreach ($folder in $shortcutFolders) {
    try {
        $shortcuts = Get-ChildItem -Path $folder -Filter "*antigravity*.lnk" -Recurse -File -ErrorAction SilentlyContinue
        foreach ($lnk in $shortcuts) {
            $target = Resolve-ShortcutTarget -ShortcutPath $lnk.FullName
            if ($target -and (Test-Path -LiteralPath $target)) {
                $rawCandidates.Add((Split-Path -Parent $target))
            }
        }
    } catch {}
}

# 5. Валидация и фильтрация дубликатов
$validatedInstallations = [System.Collections.Generic.List[string]]::new()
$seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($candidate in $rawCandidates) {
    if (-not $candidate) { continue }

    try {
        $resolved = (Resolve-Path -LiteralPath $candidate).Path
    } catch {
        continue
    }

    if ($seenPaths.Contains($resolved)) { continue }

    # Проверяем наличие ресурсов (app.asar)
    $hasAsarInSubdir = Test-Path -LiteralPath (Join-Path $resolved 'resources\app.asar')
    $hasAsarDirect = Test-Path -LiteralPath (Join-Path $resolved 'app.asar')
    $hasExe = (Test-Path -LiteralPath (Join-Path $resolved 'Antigravity.exe')) -or (Test-Path -LiteralPath (Join-Path $resolved 'antigravity.exe'))

    if ($hasAsarInSubdir -and $hasExe) {
        $seenPaths.Add($resolved) | Out-Null
        $validatedInstallations.Add($resolved)
    } elseif ($hasAsarDirect) {
        $parentDir = Split-Path -Parent $resolved
        if (-not $seenPaths.Contains($parentDir)) {
            $seenPaths.Add($parentDir) | Out-Null
            $validatedInstallations.Add($parentDir)
        }
    }
}

return $validatedInstallations
