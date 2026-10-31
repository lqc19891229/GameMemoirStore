# 编辑 3D 工作台与 2D 应用界面

固定场景和模型都保存在资源中，运行时不生成家具几何。

| 想编辑的内容 | 打开的文件 |
|---|---|
| 设备位置、旋转、缩放，相机和灯光 | `scenes/computer/computer_desktop.tscn`，选择 3D，展开 Workstation3D |
| 单件设备及默认 / 升级模型 | `scenes/computer/hardware/*.tscn` |
| 模型几何与材质源文件 | `tools/models/hardware.blend` |
| 模型对应库存 ID、尺寸与屏幕位置 | `data/hardware/*.tres` |
| 工作台控制界面、标题栏与按钮 | `scenes/computer/computer_desktop.tscn` 的 HUD/Interface，选择 2D |
| 显示器中的系统、快捷方式、任务栏 | `scenes/computer/ui/desktop_screen.tscn` |
| 应用标题栏与窗口操作 | `scenes/computer/ui/app_window.tscn` |
| 商城页面、游戏列表与卡片 | `scenes/apps/platform/store.tscn`、`scenes/apps/platform/pages/`、`scenes/apps/platform/components/` |
| 购物网页与游玩界面 | `scenes/apps/browser/browser.tscn`、`scenes/apps/game/game_player.tscn` |

## 3D 编辑

直接打开 `computer_desktop.tscn` 即可进入 3D 编辑器。Workstation3D 已启用“可编辑子节点”，其 TableGroup/Equipment 下的 Monitor、Computer、Keyboard、Mouse 是独立 Node3D 实例。直接移动、旋转和缩放；进入检视后返回总览会恢复编辑器保存的摆放。默认模型已经实例化在 Models 下，展开可查看真实网格。选中物体按 F 可聚焦。

KeyLight、FillLight 和 Environment 控制灯光与背景。Camera 是默认总览相机。Pedestal 是单品展示台，默认隐藏；运行时检视设备会显示它。Desk 是加载 GLB 的木质桌面。

显示器的 Screen 是真实 3D 表面。编辑器默认显示玻璃材质；运行时接入实时系统纹理。旧存档可能安装升级型号，因此其外观与编辑器默认型号不同；几何都来自同一套已保存资源。

`computer_desktop.tscn` 使用 Node3D 根节点，Workstation3D 直接在主视口渲染，不再通过 Control / SubViewportContainer 显示 3D。HUD 单独位于 CanvasLayer；只有显示器中的 2D 系统继续使用 DesktopViewport 作为实时纹理。`workstation_3d.tscn` 保留为模型、灯光和默认布局的复用源场景。

玩家进入 ComputerDesktop 后，左键或右键拖动即可绕整个工作台水平旋转、上下调整俯仰，滚轮直接缩放；无需先进入单件检视。单击设备进入商品检视，单击显示器屏幕操作系统。拖动超过 6 个逻辑像素即视为旋转，松开不会误触设备或屏幕。返回总览保留离开前的视角，点击“重置视角”恢复编辑器保存的相机。Workstation3D 的 orbit_target、minimum_distance、maximum_distance 可在检查器中调整。

## 模型与屏幕配置

`MemoirDeviceModel` 资源记录 model（GLB PackedScene）、bounds（米）、screen_size、screen_position。后两项用于显示器表面与镜头取景，详见 `data/hardware/README.md`。设备显示切换现成的默认 / 升级模型，不在运行时用碎片节点生成模型。

完整 Blender 源文件与制作脚本在 `tools/models/`。源目录用 .gdignore 排除自动导入，游戏只需要 GLB；无需安装 Blender 即可运行。修改几何后手动重新导出，Godot 会导入新的模型。

## 保留的 2D 应用

系统仍在同一个 1280×800 DesktopViewport 中。相机射线与 Screen 表面相交后映射到系统坐标，应用、菜单和弹窗都保留在显示器上。切换总览、检视和屏幕操作不会销毁应用或中断会话。

页面预览使用场景中的示例数据，运行时填入真实钱包、游戏和库存。列表按数量实例化已有模板，静态布局不由脚本创建。不要随意重命名带 % 唯一标识的节点。

检查：

```bash
godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh
```

场景按功能分别放在 main/、computer/、apps/platform/、apps/browser/、apps/game/、shared/。购物库存行归属 browser/components，通用按钮位于 shared；不要在旧 life/、client/ 目录另建副本。

## 玩家布置与默认布局

TableGroup 承载桌子及 Equipment，移动桌子可让设备一起跟随。LayoutEditor 导出的桌面尺寸和高度用于玩家布置约束，调整桌子模型时应一起检查。InspectionStage 独立于桌子，单件检视返回后恢复确认布局。

玩家通过“调整布置”保存的位置会覆盖默认摆放；使用 --fresh 可验证纯编辑器默认布局。手柄源场景为 scenes/computer/ui/layout_gizmo.tscn，布置面板在 ComputerDesktop/HUD/Interface/LayoutPanel。完整说明见 docs/WORKSTATION_LAYOUT.md。
