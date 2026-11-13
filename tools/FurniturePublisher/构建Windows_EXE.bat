@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  echo 请先安装 Python 3.10 或更新版本并启用 py 启动器
  pause
  exit /b 1
)
py -3 -m pip install --upgrade pyinstaller
if errorlevel 1 goto error
py -3 -m PyInstaller --noconfirm --onefile --windowed --name FurniturePublisher --add-data "bridge.gd;." --add-data "hardware_bridge.gd;." app.py
if errorlevel 1 goto error
echo 构建完成: dist\FurniturePublisher.exe
pause
exit /b 0
:error
echo 构建失败，请查看上方信息
pause
exit /b 1
