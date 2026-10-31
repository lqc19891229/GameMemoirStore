开发与资源维护工具

catalog/：Excel 游戏资料工作簿、字段规范、Python 导入器和详细说明。
models/：电脑硬件 Blender 源文件、硬件导出脚本、房间 GLB 生成脚本和模型制作说明。
project_audit.py：检查 res:// 路径、动态资源模板、UID、导入配置、GLB 外部依赖、未引用场景/脚本/Resource/素材候选和重复素材。

Windows 双击项目根目录 import_games.bat，可将已保存的表格导入 data/games。需要 Python 3.10 或以上版本；导入器本身只使用 Python 标准库。

运行资源审计：
    python tools/project_audit.py

审计输出中的未引用文件只是人工复核候选，不会自动删除。模型生成脚本只用于离线制作；游戏运行直接加载 assets/models/ 中已提交的 GLB。