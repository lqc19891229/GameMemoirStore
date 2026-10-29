@echo off
setlocal
chcp 65001 >nul
title 游戏回忆录 - 导入游戏资料
echo 游戏回忆录 - 导入游戏资料
echo 表格：tools\catalog\game_catalog.xlsx
echo 请先保存 Excel 中的修改；导入使用磁盘上已保存的数据。
echo.

py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto use_py
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto use_python
python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto use_python3

echo [失败] 未找到可用的 Python 3.10 或以上版本。
echo 请安装 Python，并启用 Python Launcher 或勾选 Add Python to PATH，再双击本文件。
set "IMPORT_EXIT=1"
goto finish

:use_py
set "PYTHON_RUN=py -3"
goto run_import

:use_python
set "PYTHON_RUN=python"
goto run_import

:use_python3
set "PYTHON_RUN=python3"

:run_import
%PYTHON_RUN% "%~dp0tools\catalog\import_games.py" --project "%~dp0."
set "IMPORT_EXIT=%errorlevel%"
echo.
if "%IMPORT_EXIT%"=="0" goto success
echo [失败] 游戏资料未能导入，请查看上方错误信息，修正后重新双击。
goto finish

:success
echo [完成] 游戏资源已更新到 data\games。
echo 等待 Godot 扫描完成后，重新运行游戏即可查看。

:finish
echo.
pause
exit /b %IMPORT_EXIT%
