# GameMemoirStore 项目结构与维护审计

检查基线：main 分支，2026-10-31。
项目：Godot 4.6，GDScript，Compatibility 渲染器。

## 审计摘要

本次整理基于仓库递归文件树、核心场景、主要脚本、全部层级 README、导入器和现有测试定义进行。基线目录包含 261 个文件、39 个目录和 47 个场景；包含 15 个 GLB（9 个电脑硬件模型、6 个房间模型）、12 个 Godot 测试脚本和 1 个 Python 导入器测试脚本。基线中有 25 份 README 文件。

本次只计划删除根目录重复的 README.txt，并更新说明、审计脚本、忽略规则和 CI；不删除运行时场景、模型、脚本、存档兼容代码或测试素材。

注意：静态仓库检查不等于 Godot 实际运行验证。本次编辑过程没有在本机启动 Godot，因此不会把仓库已有的历史测试统计描述为本次复测结果。新建的 GitHub Actions 工作流会在 Pull Request 和 main 分支 push 时运行自动检查。

## 当前运行结构

| 目录 | 内容 |
|---|---|
| scenes/main/ | game_root.tscn，主入口与共享会话 |
| scenes/computer/ | 原生 3D 电脑工作台、设备、显示器系统、窗口壳和布置手柄 |
| scenes/room/ | 房间外壳、椅子、书架、落地灯、地毯和绿植 |
| scenes/apps/ | 游戏平台、购物网页和游玩 / 直播界面 |
| scenes/shared/ | 跨应用复用组件 |
| scripts/life/ | GameSession、桌面、窗口、设备、活动、收入和布置逻辑 |
| scripts/room/ | 房间外观、灯光、墙体遮挡和家具拾取 |
| data/games/ | Excel 导入生成的正式游戏资源 |
| data/hardware/ | 电脑设备模型映射、碰撞尺寸和屏幕校准 |
| assets/models/hardware/ | 9 个电脑硬件 GLB |
| assets/models/room/ | 6 个房间与家具 GLB |
| tests/fixtures/ | 固定测试数据，不加入正式商店 |
| tools/ | Excel 导入、资源审计和模型制作工具 |

主场景为 scenes/main/game_root.tscn。GameSession 是唯一玩家状态和模拟活动时钟的所有者。ComputerDesktop 承载 Workstation3D、DesktopViewport 和 HUD。Workstation3D 内包含 Room、TableGroup、Equipment、LayoutEditor、Camera、Lights 和 PixelPass。

## 本次整理

| 项目 | 处理 |
|---|---|
| README 文档 | 逐级更新根目录、assets、data、scenes、scripts、tests、tools 下的 README；同步生成器模板与 data/games/README.txt |
| 过期结构说明 | 更新 CLIENT_STRUCTURE.md 和 EDITOR_WORKFLOW.md，移除“房间功能已删除”等旧描述 |
| 素材记录 | 更新 ASSET_CREDITS.md，记录电脑硬件和房间 GLB；CTA3 来源待发布前补充 |
| 资源审计 | 扩展 tools/project_audit.py，增加 GDScript class_name 引用识别，并把未引用脚本和 Resource 纳入人工复核候选 |
| 忽略规则 | 补充 Python 缓存、系统垃圾文件、临时文件和本地构建目录；保留 Godot .import sidecar |
| CI | 新增 .github/workflows/project-validation.yml，运行 Python、Godot Headless、资源审计和 Xvfb 图形测试 |
| 重复说明 | 删除根目录 README.txt；完整项目说明以 README.md 为准 |

## 文件保留原则

以下文件不可因“看起来像缓存或旧文件”而直接删除：

- *.gd.uid：Godot 脚本稳定资源标识。
- *.import：GLB、PNG 和字体的导入设置，随原始素材提交。
- assets/models/hardware/ 与 assets/models/room/：当前运行时模型。
- scenes/room/、scripts/room/：当前房间系统。
- tools/models/hardware.blend、build_hardware.py 和 build_room.py：模型编辑与离线生成来源。
- tests/fixtures/：旧版游戏目录和表格行样本，用于稳定的导入、购买、筛选与存档回归。
- assets/art/ 中的旧演示封面：固定测试样本仍会引用。
- life_data.gd 中历史家具商品、旧布局字段和存档清理逻辑：用于兼容旧玩家数据。

未引用候选仅供人工复核，审计脚本不会自动删除任何文件。

## 审计工具范围

运行：

    python tools/project_audit.py

工具检查 res:// 静态与动态资源路径、脚本 UID、导入 sidecar、GLB 文件头和外部依赖、重复素材，以及未引用场景、GDScript、TRES 和图片 / 模型 / 字体 / shader 候选。对于 class_name 脚本，会在其他 GDScript、场景、Resource 和项目配置中检查类名引用。测试脚本和手动执行的 Python 工具不作为未引用删除候选。

路径、UID、导入配置或 GLB 结构问题会使命令返回非零；未引用候选只报告，不自动删除。审计仍属于静态检查，不能代替 Godot 导入和运行测试。

## 验证命令

Python 与资源检查：

    python -m unittest discover -s tests -p "test_catalog_importer.py" -v
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
    godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_collision.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_pixel_room.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_audit_regressions.gd -- --fresh

test_client_windows.gd 需要图形环境；Linux 可通过 xvfb-run -a 执行。--fresh 禁止测试读写正常玩家存档。

GitHub Actions 工作流会在 push、Pull Request 和 workflow_dispatch 时执行上述自动化检查。工作流状态是本次修改是否通过运行验证的依据；本报告不预先填写尚未完成的 CI 结果。

## 后续注意事项

1. CTA3 素材公开发布前应补充来源和授权说明。
2. 增加或替换家具模型时，检查 room_furniture.bounds 与 LayoutEditor 碰撞尺寸。
3. 增加硬件型号时，同步模型、设备场景、data/hardware/_catalog.tres 和 life_data.gd。
4. 新增 Excel 字段时，同步工作簿、schema.json、import_games.py 和相关测试。
5. 变更存档字段时，保留版本 1、2、3 的迁移与历史字段清理逻辑。