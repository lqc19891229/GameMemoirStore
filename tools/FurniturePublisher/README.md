# 游戏回忆录 · 资产发布器 v2.0

这是一个**外部 Windows 桌面程序（Python + Tkinter GUI）**，不用打开 Godot 编辑器进行手动商品注册。选择已经制作好的 GLB，填写信息，点击检查和确认后，它会调用 GameMemoirStore 的原有安全导入/注册接口，完成以下操作：

1. 检查 GLB 格式和外部贴图依赖；拒绝重复商品 ID、同名资源和无效分类。
2. 备份原来的 `data/items/_catalog.tres` 到用户目录 `~/.gamememoir_furniture_publisher/backups/`。
3. 拷贝 GLB 到 `assets/models/room/<分类>/<id>.glb`。
4. 自动启动 Godot 4.6（headless）导入模型。
5. 调用项目现有 `furniture_importer.gd` 创建独立场景、测量模型尺寸、生成 PickArea/Hit。
6. 如填写了承载面，配置到新家具场景。
7. 调用项目现有 `furniture_catalog_registrar.gd` 校验商品 ID、摆放角色、类别、价格和场景，保存并重新加载唯一商品目录。
8. 核对新场景、目录和注册结果，在日志中报告状态。

## 安装

Windows 10/11：安装 **Python 3.10 或更高版本**（勾选“Add Python to PATH”），以及 **Godot 4.6**。程序本身没有额外 Python 包依赖（Tkinter 是标准库的一部分）。

解压程序 ZIP 到任意文件夹，双击 `启动家具发布器.bat`。也可运行 `python app.py`。

如果希望生成不依赖 Python 的单文件 Windows 程序，可在 Windows 上双击 `构建Windows_EXE.bat`（首次需要网络下载 PyInstaller），完成后使用 `dist\FurniturePublisher.exe`。当前提供的是 Python 源码与启动器，**并未预编译或签名 Windows EXE**。

## 使用

- 选择 `GameMemoirStore` 本地项目根目录（包含 `project.godot`）。
- 选择 Godot 4.6 的 `.exe`，或在 PATH 中使用 `godot` 命令。
- 选择已完成默认 PBR 材质和纹理的 `.glb` 文件。
- 输入唯一英文小写下划线商品 ID（例如 `gaming_desk_01`），中文名称，五大类、二级类型、售价、说明。
- 小摆件允许摆到桌/书架上时勾选「可放到其他家具承载面」。
- **桌/书架本身**提供承载面时，可以填入可选 JSON，例如：

```json
[{"id":"top","x":0,"y":0.75,"z":0,"width":1.0,"depth":0.5}]
```

其中 `center` 坐标是家具本地坐标（单位米）：`x/y/z` 是承载面中心，`width` 是 X 宽度，`depth` 是 Z 深度。没有承载面直接使用 `[]`，不要将“可以摆到别人上面”与“自己提供摆放层板”混淆。

- 点击「检查 / 预览改动」，核对路径、商品价格和来源 GLB。
- 关闭正在运行的 Godot 编辑器和游戏，勾选确认后，点击「确认并自动导入上架」。
- 运行结束后在 Godot 中打开生成的 `.tscn`，检查模型方向、贴图、坐标、包围盒、碰撞、承载面；再在游戏里测试商店购买与摆放。**不能以自动化导入代替人工 3D 验收。**

## 资产发布器 v2.1：家具 / 电脑设备并列页面

启动发布器后，主窗口顶部有并列的 **「家具」** 与 **「电脑设备」** 标签：

- **家具**：显示完整的新增家具界面，包括 GLB 选择、商品 ID、商城名称、价格、一级/二级分类、承载面、预检与发布。
- **电脑设备**：包含 **「单个设备」** 和 **「批量设备」** 两个子标签。单设备可以更新现有型号与屏幕参数；批量设备从同目录的 `model_specs.json` 自动识别文件和尺寸。
- 批量模式可在读取清单后使用 Ctrl / Shift **选择本次需要导入的设备**，默认全部选中。支持清单中仅含 1、2、3 或 4 件基础电脑设备；不再要求始终具有四件。按钮统一显示「检查所选设备」「导入所选设备」，只改选中的设备文件，失败只恢复该批受影响的文件。
- 原有 `schema_version: 2` 的四设备 JSON **不必修改**。例如只想重做鼠标，可继续使用包含四件的 JSON，在界面里只选择 `mouse`，其他三个设备保持不变。

## 批量导入启航 2000（自动读取 model_specs.json）

将本次需要导入的设备 GLB 和 `model_specs.json` 放在同一个文件夹中。启动发布器，切换到 **「电脑设备」→「批量设备」**，选择模型文件夹、读取设备清单，选择需要的型号，点击「检查所选设备」确认映射，再点击「导入所选设备」。

规格文件使用 `schema_version: 2`，`models` 数组可包含 1～4 个不同设备槽位（`monitor`、`computer`、`keyboard`、`mouse`），对应现有基础设备 ID：`starter_monitor`、`starter_pc`、`starter_mouse`、`starter_mouse`。每条至少包括同目录的 `file`、`role`、`item_id`、`expected_size_m`（宽、高、深）及 `actual_mesh_bounds_m`（最小点、最大点）。显示器还要填写 `screen_size_m` 和 `screen_position_m`。缺文件、参数异常、跨目录引用或重复槽位会直接阻止发布。

一次批量操作统一备份全部四个 GLB、TRES 和对应硬件场景，统一执行 GLB 导入，再逐个让 Godot 保存并回读配置。任一中途失败，会恢复整个批次的 12 个原始文件；之后可能需要用 Godot 重新导入以刷新资源缓存。**发布器不能替代游戏内视觉验收**，特别是 CRT 屏幕纹理、键鼠位置及机箱落地情况。批量模式只替换已有设备的外观和参数，不新增 SKU 或修改存档。

## 电脑设备：替换现有基础款或升级款

主窗口顶部点击 **「电脑设备模型发布 / 替换现有型号…」**，使用同一个项目和 Godot 路径。新窗口选择完成 PBR 材质的 GLB，然后选择设备类型与已有商品 ID，填写真实外包围尺寸（**X 宽、Y 高、Z 深，单位米**）；显示器还必须填写屏幕 Quad 的宽、高与本地中心 X/Y/Z。

- **现阶段只支持替换已注册型号**：显示器 `starter_monitor` / `lcd_monitor`、机箱 `starter_pc` / `workstation`、键盘和鼠标 `starter_mouse` / `precise_mouse`。键盘与鼠标分别替换，但保留原来共用的套装 SKU。
- 程序用 Godot 既有设备映射定位目标 `assets/models/hardware/*.glb`、`data/hardware/*.tres` 和 `scenes/computer/hardware/*.tscn`，**不会创建家具商品，不会修改玩家存档、电脑逻辑或现有库存 ID**。
- 每次操作先把以上三个原文件复制到用户目录 `~/.gamememoir_furniture_publisher/backups/hardware_*/`，替换 GLB 并将对应 `DefaultModel` / `UpgradeModel` 的历史缩放设置为 1（真实尺寸模型无需额外缩放）。
- 自动运行 Godot 导入、更新设备 `bounds`，显示器还更新 `screen_size`、`screen_position`，确认结果才报告成功；失败时恢复 GLB、设备配置、场景的原始字节，Godot 缓存可能需要再次导入。
- **模型必须以底部中心为原点、Y 向上、+Z 朝设备正面**。屏幕参数描述独立的 Godot 屏幕 Quad，建议屏幕网格与 GLB 的玻璃面重合，避免漂浮或被外壳遮挡。
- 验收：用 Godot 查看外观和尺寸，再进入游戏点击显示器、移动键鼠与机箱、切换升级型号，检查拾取、碰撞和读档。

新增完全独立的**新设备商品 ID** 需要同时扩展硬件目录和物品目录，不在本版一键替换模式范围内。现有家具功能完全不变。

## 限制和安全规则

- **仅新增家具**：不会覆盖已有 GLB、场景、商品 ID，也不会擅自改名或迁移玩家存档。升级已上架家具应通过独立资产替换流程。
- **不会制作模型材质**：输入必须是已经完成默认外观的 GLB；支持检查是否存在外部贴图 URI，不能替代 Blender 视觉审核。
- **不会自动修改玩家钱包或存档**，不会在游戏里真正下单；自动上架后会被已有商店/库存/摆放逻辑识别。
- 失败时可能保留部分新模型或新场景用于排障；原商品目录还会保留备份，程序不自动清除潜在有价值的制作数据。
- 程序以仓库内 `tools/FurniturePublisher/bridge.gd` 为模板，在项目 `tools/` 下临时生成 `_furniture_publish_*.gd` 执行脚本与 `_furniture_publish_*.json` 清单，执行结束后清理。使用期间不要运行其他编辑器插件注册同一个商品。
- 为确保不会误写入其他 Godot 项目，必须使用具有 `addons/furniture_manager` 相应接口的 GameMemoirStore 版本。
- 无需接入云服务，不会自动上传源 GLB；完成后可用 Git 管理新资产并提交 PR。

## 下一版可扩展

批量上架、选择或编辑已有商品、可视化承载面编辑、真实 3D 预览、自动化导入回归及打包为无需 Python 的 Windows EXE。
