# 游戏回忆录 · 家具发布器 v1.0

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
