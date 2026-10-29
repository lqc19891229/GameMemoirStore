自动检查

test_catalog_importer.py：检查 Excel 读取、字段校验、素材解析、资源生成和文件保护。
test_catalog_resources.gd：检查当前游戏资源的字段、图片加载和时间线。
test_catalog_integration.gd：检查资源接入商品页、展示图切换和交易流程。
test_client.gd：检查新版客户端导航、搜索、购买、库和存档。
test_client_windows.gd：检查原生窗口、右键菜单和浏览位置，需要图形环境。
test_store.gd：检查旧版商店、购买和存档流程。
fixtures/：固定测试样本，与正式商店资料分开。
*.gd.uid：Godot 脚本的稳定标识。

Python 检查：python -m unittest discover -s tests -p "test_catalog_importer.py"
Godot 检查：godot --headless --path . --script res://tests/test_client.gd -- --fresh
当前游戏资源相关检查含样例预期；更换表格数据后可能需要同步更新。
