3D 模型资源

hardware/：电脑机箱、显示器、键鼠和桌面 GLB，及相应 Godot 导入配置。
room/：不断增加的房间家具、装饰品与房间资产 GLB，不再只有早期的六款模型。
*.glb.import：Godot 导入配置，随 GLB 提交。

模型遵守米制、Y 向上和底部原点等约定，详见 tools/models/README.md、docs/MODEL_QUALITY_STANDARD.md、docs/FURNITURE_GLB_ASSETS.md。
电脑设备制作可使用 tools/models/build_hardware.py；房间模型制作见 tools/models/ 中的离线脚本。
并非全部房间家具都必须是 GLB：scenes/room/wall_sconce.tscn 使用 Godot 自带 MeshInstance3D 和 OmniLight3D。
游戏正常运行直接加载提交的资源和场景，不执行 Blender 或离线生成脚本。
