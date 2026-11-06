# 项目专题文档索引

这里收集建筑、资源、视觉规范和历史阶段记录。**现行使用说明以根目录 README、EDITOR_WORKFLOW 和对应子目录 README 为准。** 旧 PR/阶段文档可能仍描述已删除功能，不能直接作为当前操作步骤。

## 当前流程

- [家具默认外观与 GLB 资产规范](../tools/models/README.md)
- [家具编辑器导入/注册](../addons/furniture_manager/README.md)
- [美术模型质量标准](MODEL_QUALITY_STANDARD.md)
- [项目编辑器工作流](../EDITOR_WORKFLOW.md)
- [房间摆放与碰撞](WORKSTATION_LAYOUT.md)
- [资源审计](PROJECT_AUDIT.md)
- [房间艺术方向](ROOM_ART_DIRECTION_P42.md)
- [灯光与相机](ROOM_LIGHTING_CAMERA.md)
- [玩家购物与家具流转](SHOP_ROOM_FLOW.md)

## 历史记录与已停用设计

- [独立家具材质系统移除说明](GLB_ONLY_FURNITURE_MATERIALS.md)：现行状态记录。
- [电竞椅 GLB-first 制作记录](GLB_FIRST_FURNITURE_MATERIALS.md)：保留历史候选过程；正式电竞椅 PBR GLB 已接入，离线烘焙器不再依赖已删除材质库。
- [家具材质槽](FURNITURE_MATERIAL_SLOTS.md) 与 [材质编辑体验](FURNITURE_MATERIAL_UX.md)：**已停用**，原运行时材质库和按部件编辑 UI 已删除。
- [游戏椅 UV 修复记录](CHAIR_GAMING_UV.md)：记录此前对游戏椅网格 UV/法线的改动，与材质编辑功能不同。

不要根据历史文档重新启用已删除的 Furniture Material Library。新增或修复家具，优先直接完善 GLB 本身的材质、UV、法线与贴图。
