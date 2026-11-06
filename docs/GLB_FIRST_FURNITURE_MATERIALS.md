# GLB-first 家具资产制作规范（电竞椅首版）

房间家具采用 **GLB 自带最终 PBR 材质**。游戏内不使用已移除的 Furniture Material Library、逐部件材质覆盖或 MaterialProfile。

## 目前状态

- `chair_gaming.tscn` 已实例化 `assets/models/room/seating/chair_gaming.glb`，其 `bounds` 与拾取体为 `(0.81, 1.25, 0.71)` 米。
- 已有 12 个命名网格、UV、法线及独立家具场景。名称保留，避免破坏资产验证。
- `tools/models/bake_chair_gaming_materials.py` 现在**离线独立**生成贴图，不再读取已经删除的 `assets/materials/furniture`。
- **正式电竞椅 GLB 已经替换为经过 PBR 烘焙与 Godot 检查的版本**（见历史 PR #117）。今后制作其他家具应遵循通用 [家具制作工作流](FURNITURE_PRODUCTION_WORKFLOW.md)，不能机械使用电竞椅专用脚本。

## GitHub Actions 生成候选 GLB

`.github/workflows/chair-glb-material-bake.yml` 在修改制作脚本或此工作流的 PR 上执行烘焙，成功时会上传 `chair-gaming-pbr-candidate` 构建产物（保留 14 天）。下载解压得到 `chair_gaming_finished.glb`，可以在 Blender 或 Godot 中单独导入进行视觉审查；它**尚未写回**仓库原始 GLB。

针对后续电竞椅修改，仍需验证材质视觉、粗糙度、法线方向、纹理接缝、物体尺寸和拾取区域；现有正式 GLB 已完成这一轮接入流程。

## 预览与验收

需要 Python 3.12、Pillow 和当前项目中的真实原始 GLB：

```bash
python -m pip install Pillow
python tools/models/bake_chair_gaming_materials.py --output /tmp/chair_gaming_finished.glb
python -m unittest discover -s tests -p "test_chair_gaming_bake.py" -v
```

烘焙结果带有嵌入式 Base Color、Metallic-Roughness、Normal PNG，且保留原网格、节点及几何 accessor。烘焙器生成可重复的基础微细节，正式电竞椅资产已经历皮革、织物、塑胶、金属和缝线的 Godot 预览审核。之后对参数或源模型的更改仍须重新审查外观，不能仅凭自动测试决定美术质量。

仅当需要**重新发布**电竞椅、且已核对可编辑源模型与烘焙配方时，才允许在独立分支执行：

```bash
python tools/models/bake_chair_gaming_materials.py --in-place
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
```

提交二进制 GLB 时应另外进行 Godot 图形窗口检查、不同光照和近距离材质审查；确认选择碰撞、物件摆放、存档和购买均不回退。

## 通用资产交付要求

每件家具应具备：独立 GLB、稳定节点命名与 UV/法线、内嵌材质贴图、合理的米制尺寸、独立 `.tscn`、包围盒与拾取体、唯一 `item_id`/摆放角色、必要时显式承载面、缩略图和购买-摆放-读档回归。严格区分 **GLB 美术资产** 和 **Godot 游戏摆放元数据**。

## 电竞椅材质精修候选（2026-11-05）

根据 Godot 前后视图的人工反馈，第二版候选调整了以下部分：
- 奶油白皮革：颜色略收敛、roughness 提高、法线细纹幅度降低，防止过曝的塑料感。
- 石墨灰后壳、扶手与底座金属：拉开明度及金属质感；橡胶滚轮维持哑光。
- Godot 预览：降低环境光与两盏方向灯能量，保留亮部细节；灯光仅影响离线验收截图，不改变游戏房间照明。
- Python 测试锁定关键材质颜色与粗糙度参数，烘焙仍保持 12 个网格与原几何/碰撞数据。

本段记录的是当时的候选精修过程；后续已通过视觉验收并在 PR #117 正式替换模型。今后的新家具仍需先看 Godot 预览，再单独提交正式模型。
