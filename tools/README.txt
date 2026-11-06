离线制作、数据导入与项目维护

catalog/：游戏 Excel 目录及导入器，详见 catalog/README.md。
models/：Blender 硬件源文件、GLB 离线生成与模型制作规范，详见 models/README.md。
project_audit.py：检查 res:// 引用、UID、导入配置及可疑未使用资产。
migrate_furniture_folders.py：历史家具路径分类迁移工具（当前已迁移完成，无需重复执行）。

Windows 可运行根目录 import_games.bat 导入游戏资料；Python 版本要求见 catalog/README.md。
运行资源审计：python tools/project_audit.py

家具默认材质应在 GLB 中制作。原 Furniture Material Library 已删除；models/bake_chair_gaming_materials.py 现可用于电竞椅专项离线、幂等 PBR 烘焙，不是任意家具的通用材质工具。
FurniturePublisher/：外部 Windows 桌面家具发布器（Python + Tkinter，非预编译 EXE），输入成品 GLB 和商品信息后调用现有导入及注册器。详见 FurniturePublisher/README.md。

工具只在开发阶段使用；正常游戏运行不执行 Blender、模型生成器或 Python 导入器。
