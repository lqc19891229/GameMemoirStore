开发辅助工具

catalog/：Excel 游戏资料表、字段规范和 Python 导入器。

Windows 双击项目根目录 import_games.bat，即可将已保存的表格导入 data/games。
需要 Python 3.10 或以上版本；详细规则见 catalog/README.md。

project_audit.py：检查资源路径、动态场景模板、导入配置、脚本 UID、GLB 依赖及未引用/重复素材候选。运行 python tools/project_audit.py。
models/：Blender 设备模型源文件和生成脚本，游戏直接加载 assets/models 中的 GLB。
