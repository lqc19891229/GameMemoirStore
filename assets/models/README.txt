3D 模型资源

hardware/：9 个电脑设备与桌面 GLB，包括两款机箱、两款显示器、两套键盘、两只鼠标和桌面。
room/：6 个房间 GLB，包括房间外壳、椅子、书架、落地灯、地毯和绿植。
*.glb.import：Godot 的模型导入配置，应与 GLB 一起保留。

电脑设备源文件与重建脚本位于 tools/models/；房间模型由 build_room.py 离线生成。游戏只加载已提交的 GLB，不需要 Blender，也不在运行时生成模型几何。