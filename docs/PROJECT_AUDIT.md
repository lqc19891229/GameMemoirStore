# GameMemoirStore 项目结构与维护审计

检查基线：main 分支，commit `9cb2bfdc824ba4ea3331edac47d01b89dba81eea`，2026-10-31。
项目：Godot 4.6，GDScript，Compatibility 渲染器。

## 审计摘要

当前仓库递归文件树包含 267 个文件、41 个目录和 47 个 Godot 场景；包含 15 个 GLB（9 个电脑硬件模型、6 个房间模型）、13 个 Godot 测试脚本、2 个 Python 测试脚本和 24 份 README。项目另有 35 个 GDScript、6 个 Python 源文件。

本报告区分静态资源审计与实际运行验证。资源路径、UID、导入 sidecar 和 GLB 结构检查不能代替 Godot 场景运行；完整验证状态以对应提交的 GitHub Actions 工作流为准。

## 当前运行结构

| 目录 | 内容 |
|---|---|
| scenes/main/ | game_root.tscn，主入口与共享会话 |
| scenes/computer/ | 原生 3D 电脑工作台、设备、显示器系统、窗口壳和布置手柄 |
| scenes/room/ | 房间外壳、椅子、书架、落地灯、地毯和绿植 |
| scenes/apps/ | 游戏平台、购物网页和游玩 / 直播界面 |
| scenes/shared/ | 跨应用复用组件 |
| scripts/life/ | GameSession、桌面、窗口、设备、活动、收入、布置与 RGB 灯光逻辑 |
| scripts/room/ | 房间外观、空间灯光、墙体遮挡和家具拾取 |
| data/games/ | Excel 导入生成的正式游戏资源 |
| data/hardware/ | 电脑设备模型映射、碰撞尺寸和屏幕校准 |
| assets/models/hardware/ | 9 个电脑硬件 GLB |
| assets/models/room/ | 6 个房间与家具 GLB |
| tests/fixtures/ | 固定测试数据，不加入正式商店 |
| tools/ | Excel 导入、资源审计和模型制作工具 |

主场景为 `scenes/main/game_root.tscn`。GameSession 是唯一玩家状态和模拟活动时钟的所有者。ComputerDesktop 承载 Workstation3D、DesktopViewport 和 HUD。Workstation3D 内包含 Room、TableGroup、Equipment、LayoutEditor、Lighting、Camera、Lights 和 PixelPass。

## 本轮维护

| 项目 | 修正 |
|---|---|
| 房间回归测试 | 将墙面、地板、空间灯光断言更新为完整六字段 room_style，避免 RGB 默认字段导致字典整体比较误报 |
| 布置与灯光文档 | 补充 RGB 七色、亮度、灯效、辅助灯、旧存档默认值和灯光测试说明 |
| 项目审计统计 | 同步当前文件、目录、场景、模型、测试脚本和 README 数量 |
| CI 权限 | 验证任务只保留 contents: read，关闭 checkout 凭据持久化，不再从 PR 自动向分支推送提交 |
| 模型验证 | Blender / Pillow 重建和 GLB 检查覆盖 push、Pull Request 与手动触发；比较生成 GLB 与已提交资产；有差异时警告并上传模型构建产物 |

本轮不修改玩家存档结构，不删除运行时场景、模型、脚本、存档兼容代码或测试素材。CTA3 图片的来源和授权仍需素材提供者确认，不能由代码审计推断。

## 此前整理记录

| 项目 | 处理 |
|---|---|
| README 文档 | 逐级更新根目录、assets、data、scenes、scripts、tests、tools 下的 README；同步生成器模板与 data/games/README.txt |
| 过期结构说明 | 更新 CLIENT_STRUCTURE.md 和 EDITOR_WORKFLOW.md，移除“房间功能已删除”等旧描述 |
| 素材记录 | 记录电脑硬件和房间 GLB；CTA3 来源待发布前补充 |
| 资源审计 | 扩展 tools/project_audit.py，增加 GDScript class_name 引用识别，并把未引用脚本和 Resource 纳入人工复核候选 |
| 忽略规则 | 补充 Python 缓存、系统垃圾文件、临时文件和本地构建目录；保留 Godot .import sidecar |
| CI | 建立 GitHub Actions，运行 Python、Godot Headless、资源审计和 Xvfb 图形测试 |
| 重复说明 | 删除根目录重复 README.txt；完整项目说明以 README.md 为准 |

## 文件保留原则

以下文件不可因“看起来像缓存或旧文件”而直接删除：

- `*.gd.uid`：Godot 脚本稳定资源标识。
- `*.import`：GLB、PNG 和字体的导入设置，随对应素材一起保留。
- `assets/models/hardware/` 与 `assets/models/room/`：当前运行时模型。
- `scenes/room/`、`scripts/room/`：当前房间系统。
- `tools/models/hardware.blend`、`build_hardware.py` 和 `build_room.py`：模型编辑与离线生成来源。
- `tests/fixtures/`：旧版游戏目录和表格行样本，用于稳定的导入、购买、筛选与存档回归。
- `assets/art/` 中的旧演示封面：固定测试样本仍会引用。
- `life_data.gd` 中历史家具商品、旧布局字段和存档清理逻辑：用于兼容旧玩家数据。

未引用候选仅供人工复核，审计脚本不会自动删除任何文件。

## 审计工具范围

运行：

    python tools/project_audit.py

工具检查 res:// 静态与动态资源路径、脚本 UID、导入 sidecar、GLB 文件头和外部依赖、重复素材，以及未引用场景、GDScript、TRES 和图片 / 模型 / 字体 / shader 候选。对于 class_name 脚本，会在其他 GDScript、场景、Resource 和项目配置中检查类名引用。测试脚本和手动执行的 Python 工具不作为未引用删除候选。

路径、UID、导入配置或 GLB 结构问题会使命令返回非零；未引用候选只报告，不自动删除。审计仍属于静态检查，不能代替 Godot 导入和运行测试。

## 验证命令

Python 与资源检查：

    python -m unittest discover -s tests -p "test_catalog_importer.py" -v
    python -m unittest discover -s tests -p "test_showcase_models.py" -v
    python tools/catalog/import_games.py --project . --check
    python tools/project_audit.py
    godot --headless --path . --editor --import

Godot Headless：

    godot --headless --path . --script res://tests/test_catalog_resources.gd -- --fresh
    godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh
    godot --headless --path . --script res://tests/test_client.gd -- --fresh
    godot --headless --path . --script res://tests/test_store.gd -- --fresh
    godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_life_flow.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_lighting.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_collision.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_pixel_room.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_audit_regressions.gd -- --fresh

`test_client_windows.gd` 需要图形环境；Linux CI 使用 Xvfb 执行。所有 Godot 回归使用 `--fresh`，避免正常玩家存档被测试读写。

GitHub Actions 在 push、Pull Request 和 workflow_dispatch 时执行模型重建、全部 GLB 结构检查、生成文件差异提示与 artifact 上传、Python 测试、Godot 资源导入、静态审计、Headless 回归和 Xvfb 图形测试。Godot 回归前会恢复已提交的模型文件，确保运行测试针对仓库实际资源。工作流只需要读取仓库，不会自动向分支提交生成文件。

## 后续注意事项

1. CTA3 素材公开发布前应补充来源和授权说明。
2. 增加或替换家具模型时，检查 room_furniture.bounds 与 LayoutEditor 碰撞尺寸。
3. 增加硬件型号时，同步模型、设备场景、data/hardware/_catalog.tres 和 life_data.gd。
4. 新增 Excel 字段时，同步工作簿、schema.json、import_games.py 和相关测试。
5. 变更存档字段时，保留版本 1、2、3 的迁移与历史字段清理逻辑。
