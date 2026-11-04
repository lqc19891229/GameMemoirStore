美术与素材目录

art/：正式游戏封面、展示图片及固定测试封面，详见 art/README.txt。
fonts/：界面字体与授权文件，详见 fonts/README.txt。
models/hardware/：电脑设备和桌面 GLB；models/room/：持续扩充的家具及房间 GLB，详见 models/README.txt。
client_theme.tres / room_minimal_theme.tres：游戏客户端与房间 UI 主题。
shaders/：房间画面处理与布置选择轮廓等着色器。

除了 GLB，部分家具（例如 scenes/room/wall_sconce.tscn 壁灯）由 Godot 原生网格、碰撞体和实际 OmniLight3D 节点构成。
模型制作源文件和脚本见 tools/models/；模型规范见 docs/MODEL_QUALITY_STANDARD.md。
*.import 与源资产配套保留，运行游戏不需要 Blender。
