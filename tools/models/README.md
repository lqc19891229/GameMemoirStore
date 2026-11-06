# 3D 模型制作、导出和验收

**当前约定：GLB 是具备完整默认外观的成品资产。** 设计阶段应准备几何模型、稳定的部件名称、UV、法线、PBR 材质与必要的贴图；导入 Godot 后不依赖额外脚本重新生成家具默认材质。

## 目录

- `assets/models/hardware/`：机箱、显示器、键盘、鼠标和桌面，共九个 GLB。
- `assets/models/room/room_shell.glb`：房间外壳。
- `assets/models/room/{tables,seating,storage,lighting,decor}/`：正式家具模型。
- `scenes/room/<类型>/`：包裹 GLB 的家具场景，维护碰撞、位置和商品对应关系。

## 美术制作标准

1. 单位为米，Godot 使用 Y 轴向上；家具底部和原点要便于摆放。
2. 给座椅、支架、滚轮、包边等部件使用稳定的语义名称；合适的材质分区有利于维护。
3. 完成正确的网格法线、UV、三角形方向和材质纹理密度。
4. 在 GLB 中附带 Base Color、Metallic/Roughness、Normal 等需要的 PBR 通道与贴图。尽量嵌入素材，若使用外部纹理则将文件和引用一起提交。
5. 用 Blender 或其他 glTF 查看器**直接打开 GLB**，确认无需任何 Godot 脚本即可看到默认外观。
6. 导入 Godot 后检查模型体积、朝向、拾取盒、占地和 GL Compatibility 下的实际材质表现。

可参考 `docs/MODEL_QUALITY_STANDARD.md`。注意：部分现有旧模型未完全达到以上规范；本说明定义的是**新资源及后续精修目标**。

## 现有离线工具

### 电脑展示设备

`build_hardware.py` 基于 Blender 3.6.23 LTS 生成九个硬件/桌面 GLB，并生成历史 `assets/models/room/chair.glb`（不是 `chair_gaming.glb`）：

```bash
blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py
```

会覆盖目标 GLB 和 `tools/models/hardware.blend`；如果该文件或 GLB 已被手工精修，运行前须保存备份并审核生成差异。

### 历史房间模型

`build_room.py` 使用 Python 3 和 Pillow，重建 `assets/models/room/` 根目录的历史 `room_shell.glb`、`bookcase.glb`、`lamp.glb`、`rug.glb`、`plant.glb`：

```bash
python -m pip install Pillow
python tools/models/build_room.py
```

当前正式家具已按分类移动。该脚本不会自动维护分类目录下的正式家具版本；**不要把它当作批量重建整个家具目录的工具**。

### 电竞椅 GLB-first 材质烘焙（已恢复）

`bake_chair_gaming_materials.py` 现已采用自包含离线 PBR 参数，不依赖已删除的 `assets/materials/furniture/`。电竞椅的正式 `chair_gaming.glb` 已包含完成审核的默认 PBR 材质；烘焙器对已完成资产具备幂等保护，不会重复附加纹理。**它是电竞椅专项制作工具，不能作为其他家具的自动通用上色工具。**

一般新家具应在 Blender 中完成材质后直接导出成品 GLB，无需额外调用电竞椅脚本。需制作电竞椅候选时可以：

```bash
python -m pip install Pillow
python tools/models/bake_chair_gaming_materials.py --output chair_gaming_review.glb
python -m unittest discover -s tests -p "test_chair_gaming_bake.py" -v
```

如需二次修改电竞椅的成品材质，应从可编辑源模型或明确的烘焙输入重新制作；不得依赖对已发布二进制 GLB 反复累积贴图。审核候选截图后，在独立 PR 中提交变更，并执行 Godot 材质、碰撞、购买和存档回归。

完整的家具制作、入库与商品验收流程参见 [家具制作工作流](../../docs/FURNITURE_PRODUCTION_WORKFLOW.md)。

## Godot 导入与资源登记

1. 将完成的家具 GLB 放在 `assets/models/room/<分类>/` 中。
2. 等待 Godot 自动导入，保留模型和相关纹理的 `.import` 文件。
3. 用编辑器底部 `Furniture Manager` 的「家具导入」生成分类 `.tscn`。
4. 审核 `bounds`、`PickArea/Hit`、模型朝向和可选承载面，再到「家具注册」建立商品条目。
5. 在「家具资源」预览并检查商品是否关联到正确场景。

详见 [家具管理器](../../addons/furniture_manager/README.md) 与 [编辑器指南](../../EDITOR_WORKFLOW.md)。

## 验证

```bash
godot --headless --path . --editor --import
python tools/project_audit.py
python -m unittest discover -s tests -p "test_showcase_models.py" -v
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd -- --fresh
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
```

测试成功只能验证部分结构与兼容性。材质颜色、反光、纹理拉伸和接缝仍需人工观察。
