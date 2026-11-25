@echo off
chcp 65001 >nul
setlocal
set "DIR=%~dp0"
if not exist "%DIR%install.ps1" (
  echo [*] 首次运行，正在获取 install.ps1 ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Sakura-you/vscode-zh-cn-enhanced/main/install.ps1' -OutFile '%DIR%install.ps1' -UseBasicParsing } catch { exit 1 }"
  if not exist "%DIR%install.ps1" (
    echo [x] 无法自动获取 install.ps1，请手动下载 install.ps1 放到本目录后重试。
    pause
    exit /b 1
  )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%install.ps1" %*
if errorlevel 1 pause
endlocal
