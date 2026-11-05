素材目录（Godot 4.6）

art/：游戏封面、截图和部分示例图。
fonts/：字体及对应授权文件。
models/hardware/：机箱、显示器、键盘、鼠标和桌面 GLB。
models/room/：房间外壳以及按 tables、seating、storage、lighting、decor 分类的家具模型。
shaders/：房间表现和交互视觉相关着色器。
其他 .tres：界面主题与表现资源。

当前家具以 GLB 内置的默认材质、UV 和法线为准；已移除独立的 furniture 材质预设库。
旧模型可能具有外部贴图依赖，不能假设所有 GLB 均完全嵌入贴图。导入前检查依赖，保留相应 PNG 和 *.import 文件。
详见 models/README.txt、../tools/models/README.md 和 ../EDITOR_WORKFLOW.md。
