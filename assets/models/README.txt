3D 模型资源（GLB / glTF）

hardware/：9 个硬件和桌面 GLB（机箱、显示器、键盘、鼠标和桌面）。
room/room_shell.glb：房间外壳。
room/tables/：桌类家具。
room/seating/：椅子、游戏椅、沙发与软垫座椅。
room/storage/：书架、展示柜和收纳类家具。
room/lighting/：落地灯等家具。
room/decor/：地毯、绿植和其他装饰家具。

新增家具：完成网格、UV、法线和默认 PBR 材质后再导出 GLB；按分类存放，并用 Furniture Manager 生成场景、审核并注册商品。
GLB 的 *.import 文件应随模型保留；部分模型的贴图 PNG 位于模型旁，移动时必须一起检查引用。
GLB 不等于可售商品：正式商品必须在 data/items/_catalog.tres 中注册并关联独立家具场景。

已移除旧版家具材质库/运行时部件材质系统；chair_gaming.glb 目前仍使用 GLB 内置的默认材质。
模型制作参考 ../../tools/models/README.md；家具导入参考 ../../addons/furniture_manager/README.md。
