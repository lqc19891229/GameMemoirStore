# P43 游戏房间收藏装饰（首批六件）

本批内容明确面向 **游戏收藏房间与小型生活装饰**，不是家具批量布置功能。六件货品均走原有玩家购买 → 获得独立 UID → 房间摆放 → 旋转/改色 → 存档恢复流程，不免费出现在初始房间。

| 商品 ID | 物品 | 分类 | 基础摆放 | 资产 |
|---|---|---|---|---|
| room_vinyl_crate | 黑胶唱片收纳箱 | 装饰 | 地面 | assets/models/room/catalog/vinyl_crate.glb |
| room_collectible_podium | 游戏收藏品展示座 | 装饰 | 地面 | assets/models/room/catalog/collectible_podium.glb |
| room_poster_floor_frame | 落地游戏主题画框 | 装饰 | 地面 | assets/models/room/catalog/poster_floor_frame.glb |
| room_game_display_shelf | 游戏收藏展示架 | 储物 | 地面 | assets/models/room/catalog/game_display_shelf.glb |
| room_lounge_cushion_pair | 双拼休闲坐垫 | 座椅 | 地面 | assets/models/room/catalog/lounge_cushion_pair.glb |
| room_retro_speaker_tower | 复古落地游戏音箱 | 装饰 | 地面 | assets/models/room/catalog/retro_speaker_tower.glb |

## 美术方向
- 每套 glTF 包含 8～38 个独立命名的 3D mesh，使用金属度与粗糙度 PBR，而非单张纹理或二维卡面。为兼容现有玩法，这一轮采用有限的低多边形几何细节，并由 Godot 直接导入。
- 主题配色继续沿用暖橡木、鼠尾草绿、米白、灰蓝、胡桃木和少量黄铜；保留造型可读性，适合俯视/等距镜头。
- 游戏展示架中的书籍、盒装游戏和小手柄为 **固定造型细节**，不构成可独立移动的桌面子物品。

## 尚未完成的独立系统
真正的墙面挂画、桌面/架上小物需要为房间物品增加 `placement_surface` 类型、家具表面锚点、分层碰撞与高度/父对象保存。不将“落地画框”冒充为墙上悬挂装饰，本阶段先完成六件可真正购买与摆放的资产，再设计更复杂的分层摆放。