# GLB-first 家具资产制作规范（电竞椅首版）

房间家具采用 **GLB 自带最终 PBR 材质**。游戏内不使用已移除的 Furniture Material Library、逐部件材质覆盖或 MaterialProfile。

## 目前状态

- `chair_gaming.tscn` 已实例化 `assets/models/room/seating/chair_gaming.glb`，其 `bounds` 与拾取体为 `(0.81, 1.25, 0.71)` 米。
- 已有 12 个命名网格、UV、法线及独立家具场景。名称保留，避免破坏资产验证。
- `tools/models/bake_chair_gaming_materials.py` 现在**离线独立**生成贴图，不再读取已经删除的 `assets/materials/furniture`。
- **当前仓库中的 GLB 尚未替换为烘焙结果**。本次只修复可重复生产和验证工具，不宣称美术成品已完成。

## 预览与验收

需要 Python 3.12、Pillow 和当前项目中的真实原始 GLB：

```bash
python -m pip install Pillow
python tools/models/bake_chair_gaming_materials.py --output /tmp/chair_gaming_finished.glb
python -m unittest discover -s tests -p "test_chair_gaming_bake.py" -v
```

烘焙结果带有嵌入式 Base Color、Metallic-Roughness、Normal PNG，且保留原网格、节点及几何 accessor。当前纹理是可重复生成的**基础微细节占位美术**，仍需在 Blender 中审查皮革、织物、塑胶、金属、缝线颜色和粗糙度，不能仅凭自动测试决定最终风格。

人工确认之后才允许执行：

```bash
python tools/models/bake_chair_gaming_materials.py --in-place
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
```

提交二进制 GLB 时应另外进行 Godot 图形窗口检查、不同光照和近距离材质审查；确认选择碰撞、物件摆放、存档和购买均不回退。

## 通用资产交付要求

每件家具应具备：独立 GLB、稳定节点命名与 UV/法线、内嵌材质贴图、合理的米制尺寸、独立 `.tscn`、包围盒与拾取体、唯一 `item_id`/摆放角色、必要时显式承载面、缩略图和购买-摆放-读档回归。严格区分 **GLB 美术资产** 和 **Godot 游戏摆放元数据**。
