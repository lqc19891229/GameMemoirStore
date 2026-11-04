开发、导入与资产维护工具

catalog/：游戏 Excel 工作簿、字段规范和导入器；详情见 catalog/README.md。
models/：Blender 硬件模型源文件、导出脚本、房间家具 GLB 制作流程；详情见 models/README.md。
project_audit.py：排查资源路径、Godot UID、导入配置、GLB 引用和未使用资源候选。

在仓库根目录运行：

    python tools/catalog/import_games.py --project . --validate-only
    python tools/catalog/import_games.py --project . --check
    python tools/project_audit.py

Windows 也可双击 import_games.bat。导入器需要 Python 3.10 或更高，依赖标准库；不同离线模型脚本可能需要 Blender 或 Pillow，见各自说明。

模型生成只用于离线制作，正常游戏直接加载提交的 GLB 和 Godot 原生场景。壁灯等原生 MeshInstance3D 场景不要求转换成 GLB。
房间自由装修、不使用工作/游戏/休息功能区或用途灯光预设；相关蓝图与 UI 位于 scripts/room/ 和 scripts/life/。
资源审计的未引用文件仅是人工检查候选，不自动删除。
