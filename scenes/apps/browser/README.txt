购物网页场景

browser.tscn：商城与“我的物品”库存标签。由 ComputerDesktop 挂载，并接收共享 GameSession。
components/inventory_row.tscn：购物与库存共用的商品行，显示名称、说明、价格和操作按钮。
脚本：scripts/life/browser.gd。

通过电脑桌面进入时，购买、安装和钱包更新都写入共享玩家状态。单独预览场景时保留示例节点；没有共享会话时不执行交易。购买按钮余额不足时会禁用并显示所差点数；钱包余额位于商品滚动列表上方。家具可“购买”入库或“购买并摆放”进入房间编辑模式。
