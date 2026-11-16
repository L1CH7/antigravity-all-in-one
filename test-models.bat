@echo off
chcp 65001 >nul
title Antigravity - Model Diagnostics
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-models.ps1"
pause
