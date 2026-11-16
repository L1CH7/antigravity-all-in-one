@echo off
chcp 65001 >nul
pushd "%~dp0"
set "PS_CMD=powershell.exe"
where pwsh.exe >nul 2>&1
if %errorlevel% equ 0 set "PS_CMD=pwsh.exe"

%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "EXIT_CODE=%errorlevel%"
popd

if %EXIT_CODE% neq 0 (
    echo.
    echo [ERROR] Installation failed with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
