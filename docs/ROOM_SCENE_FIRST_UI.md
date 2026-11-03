# P25 · 参考 My Dream Setup 的场景优先交互

## 设计原则

本阶段专注 **UI 操作逻辑**，暂停开发“房间作品保存与展示”。参考 My Dream Setup 的左侧分类商品抽屉、场景物品直接操作和贴近选中物体的按钮布局，但保留本项目独立的经济系统、电脑浏览器商店、库存 UID 和 Godot 场景结构。

房间编辑的默认布局现在以 **3D 房间画面** 为中心：顶部一行精简模式图标，左侧紧凑分类图标，目录仅按需从左侧展开；选中家具后，显示浮动的移动、旋转、改色、复制和收纳快捷操作。高阶坐标与碰撞设置并未删除，只是移到「精细」按钮。

## 操作表

| 操作 | 鼠标/快捷键 | 生效范围 |
| --- | --- | --- |
| 打开库存家具 | 左上「物品」或 `B` | 房间编辑 |
| 切换家具分类 | 左侧图标分类条（全部/桌子/座椅/收纳/灯具/装饰/设备） | 房间编辑 |
| 选择家具 | 场景直接点击物体 | 已拥有且已摆放的物品 |
| 移动家具 | 直接拖动；浮动「移动」切换细调轴 | 已摆放家具 |
| 旋转家具 | Shift＋拖动、Q/E、浮动「旋转」手柄；新家具还可 Ctrl/Shift＋滚轮 | 已摆放/预览中的家具 |
| 单件改色 | 选中后浮动调色板中的 9 种材质 | 单件 UID，只有保存布局才持久化 |
| 复制家具 | 选中后「复制」或 Ctrl＋D | 必须还有一个未摆放的同款库存 UID |
| 收纳家具 | 选中后「收纳」或 Delete | 不退款，不删除已有购买记录 |
| 切换房屋蓝图 | `Tab` 或上方「建造」 | 房间编辑 |
| 撤销/重做 | 顶部图标或 Ctrl＋Z / Ctrl＋Y | 草稿编辑历史 |
| 关闭面板/取消 | Esc 先关闭调色板、家具目录；若正在摆放则取消预览，最终退出编辑 | 不会静默写入存档 |
| 展开坐标/高级辅助 | 「精细」按钮 | 编辑器，不影响玩家游戏界面 |

## 原游戏和本项目的差异

My Dream Setup 官方介绍主打自由无网格摆放，并允许在物体旁立即移动、改色、复制和删除。**本项目继续保留购买与库存限制**：未拥有商品不能凭 UI 直接凭空生成。现有购物网页仍负责实际购买，房间设计只摆放已拥有家具。继续使用已有的 `workstation_layout`、`placements`、`furniture_colors` 存档字段；不新增作品保存/相册/展示业务。

## 技术边界

- `scripts/life/room_minimal_ui.gd`：保留原节点、分类筛选、布局/蓝图切换、商品控制和高级面板，仅替换默认显示层级和尺寸。
- `scripts/life/room_scene_actions.gd`：新的图标分类条、选中家具浮动快捷按钮和材质选项；对布局的操作全部调用原有 `MemoirWorkstationLayout` API。
- `scripts/life/room_furniture_cards.gd`：缩窄成适配左侧滚动抽屉的小卡片，仍复用共享 GLB 离屏缩略图。
- `tests/life/test_room_minimal_ui.gd` 和 `tests/life/test_furniture_direct_interaction.gd`：验证不同视口、真实家具选中、分类、浮动操作、Undo/Redo 可访问性、键盘快捷键、取消编辑和存档安全。

参考：<https://store.steampowered.com/app/2200780/My_Dream_Setup/>，<https://steamcommunity.com/sharedfiles/filedetails/?id=2936731063>。


## 真实点击验证

无界面 Godot 的 Root Window 只有约 64×64 物理像素，1280×800 房间 UI 在 headless 测试中会被压缩到约 5%，鼠标坐标与视觉控件矩形并不一一对应。因此常规 headless 自动化只验证控件构建、动作信号与场景数据；新增 `test_room_scene_actions_clicks.gd` 在 `xvfb-run` 图形窗口中用真正的 `Viewport.push_input()` 事件依次点击物体旁颜色、色块、旋转、移动，避免把 headless 的缩放错判为产品 GUI 故障。完整 Godot CI 同时运行两类测试。
