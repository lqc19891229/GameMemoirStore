extends SceneTree
const State = preload("res://scripts/store_state.gd")
const Data = preload("res://scripts/life/life_data.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i], b[i]): return false
		return true
	return a == b
func _initialize() -> void:
	run.call_deferred()
func frames() -> void:
	for _i in range(5): await process_frame
func run() -> void:
	var game = load("res://scenes/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	var session: MemoirGameSession = game.session
	session.timer.stop()
	var state = session.state
	var id: String = state.catalog[0]["id"]
	check(game.room.visible and not game.desktop.visible, "new game starts in the room")
	game.room.find_child("RoomComputer", true, false).pressed.emit()
	check(game.desktop.visible and not game.room.visible, "computer interaction enters desktop")
	var client = game.desktop.open_app("platform")
	await frames()
	check(client.state == state and client.session == session, "platform shares the root player state")
	check(client.download_timer.is_stopped(), "embedded client does not start a second simulation clock")
	client.open_product(id)
	client.find_child("ProductAdd", true, false).pressed.emit()
	client.navigate({"kind": "cart"})
	client.find_child("ContinuePurchase", true, false).pressed.emit()
	client.find_child("ConfirmPurchase", true, false).pressed.emit()
	check(state.owned.has(id) and state.wallet == 160 - state.price(id), "platform purchases debit the single wallet")
	client.install_game(id)
	session.tick(5)
	await frames()
	check(state.installed.has(id), "shared clock completes installation")
	client.navigate({"kind": "library", "id": id})
	client.find_child("LibraryAction", true, false).pressed.emit()
	await frames()
	check(session.active().get("game_id") == id and game.desktop.windows.has("game"), "library launches persistent play plus a game window")
	var playing = game.desktop.windows["game"].content
	check(playing.find_child("RunningScreenshot", true, false).texture != null, "game view displays the game's screenshot")
	playing.slideshow.timeout.emit()
	check(playing.find_child("RunningScreenshot", true, false).texture == state.definition(id).screenshots[1], "slideshow advances to the next independent screenshot")
	playing.find_child("PlayStream", true, false).pressed.emit()
	check(session.active().get("streaming", false), "game view can start a livestream")
	game.desktop.minimize_app("game")
	game.show_room()
	var before: int = state.wallet
	session.tick(10)
	await frames()
	check(state.play_minutes[id] == 10 and session.active()["minutes"] == 10, "returning to room does not stop or double-count play")
	check(state.wallet == before + 4 and state.life["stream_income"] == 4, "livestream settles once per five simulated minutes")
	check(state.life["achievements"].get(id, []).has("first_memory"), "play unlocks the first achievement")
	check(float(state.life["attributes"]["协作"]) > 10.0, "multiplayer games also grow cooperative ability")
	check(float(state.life["attributes"]["反应"]) > 10.0, "playing grows the matching player ability")
	var browser = game.desktop.open_app("browser")
	await frames()
	before = state.wallet
	browser.find_child("Buy_precise_mouse", true, false).pressed.emit()
	await frames()
	check(state.wallet == before - 28 and state.life["items"].has("precise_mouse"), "web shop spends the same wallet and adds inventory")
	var rate: float = session.challenge_rate(id)
	browser.set_tab("inventory")
	browser.find_child("Equip_precise_mouse", true, false).pressed.emit()
	await frames()
	check(state.life["equipped"]["peripheral"] == "precise_mouse" and session.challenge_rate(id) > rate, "equipping an owned peripheral affects challenge efficiency")
	game.show_room()
	check(game.room.furniture["peripheral"].upgraded, "installed peripheral is reflected in the room")
	game.room.find_child("RoomLayout", true, false).pressed.emit()
	check(state.life["room_layout"] == 1, "room layout can be changed")
	before = state.wallet
	session.buy_item("precise_mouse")
	check(state.wallet == before, "duplicate purchase cannot debit money twice")
	session.equip_item("workstation")
	check(state.life["equipped"]["computer"] == "starter_pc", "unowned equipment cannot be installed")
	before = state.wallet
	session.buy_item("workstation")
	check(state.wallet == before and not state.life["items"].has("workstation"), "over-budget furniture purchase has no partial effects")
	game.desktop.close_app("platform")
	await frames()
	check(session.active().get("kind") == "play", "closing platform does not terminate the game process")
	client = game.desktop.open_app("platform")
	await frames()
	check(client.state == state and state.owned.has(id), "reopened platform retains ownership and the shared state")
	game.desktop.close_app("game")
	await frames()
	check(session.active().is_empty() and state.play_sessions[id] == 1, "closing game ends exactly one play session")
	game.desktop.close_app("game")
	check(state.play_sessions[id] == 1, "closing an already closed game never duplicates play records")
	client.search_box.text = "尚未提交的搜索"
	session.tick(5)
	await frames()
	check(client.search_box.text == "尚未提交的搜索", "background autosave does not rebuild pages or erase unsubmitted search text")
	client.navigate({"kind": "community"})
	client.find_child("WriteGuide_" + id, true, false).pressed.emit()
	check(session.active().get("kind") == "guide", "creation page starts guide writing after sufficient play")
	session.start_play(id)
	check(session.active().get("kind") == "guide", "writing and playing cannot occupy the main activity simultaneously")
	before = state.wallet
	session.tick(20)
	await frames()
	check(session.active().is_empty() and state.life["guides"].has(id) and state.wallet >= before + 20, "guide completes, pays and is published")
	check(state.life["guides"][id]["royalties"] == 0, "new guide does not receive readership royalties immediately on publication")
	game.show_room()
	game.show_cabinet()
	game.cabinet.find_child("Display_" + id + "_first_memory", true, false).pressed.emit()
	await frames()
	check(state.life["displayed"].size() == 1 and game.room.furniture["cabinet"].trophy_count == 1, "unlocked trophy can be displayed in the physical cabinet")
	session.toggle_display(id, "unknown")
	check(state.life["displayed"].size() == 1, "unearned trophy cannot be displayed")
	session.start_play(id)
	session.toggle_stream()
	session.tick(3)
	state.save_path = "user://memoir_life_flow_test.json"
	state.persistence_enabled = true
	check(state.save_state(), "version 3 life state saves")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.wallet == state.wallet and restored.owned == state.owned, "save migration preserves game ownership and money")
	check(equivalent(restored.life, state.life), "life save preserves active play, stream, attributes, items, guides and trophy display")
	var resumed = load("res://scenes/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	resumed.show_desktop()
	var continue_button: Button = resumed.desktop.find_child("DesktopResume", true, false)
	check(not continue_button.disabled, "restored active game is accessible from the desktop")
	continue_button.pressed.emit()
	await frames()
	check(resumed.session.active()["minutes"] == 3 and resumed.session.active()["streaming"] and resumed.desktop.windows.has("game"), "reopening restored game retains session progress and livestream")
	resumed.queue_free()
	await frames()
	var legacy := FileAccess.open(state.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 2, "wallet": 81, "month": 1, "owned": [id], "installed": [id], "play_minutes": {id: 9}}))
	legacy.close()
	var migrated = State.new()
	migrated.save_path = state.save_path
	migrated.load_state()
	check(migrated.wallet == 81 and migrated.owned.has(id) and migrated.installed.has(id) and migrated.life["equipped"]["computer"] == "starter_pc", "version-2 saves gain starter room equipment without losing purchases")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	state.persistence_enabled = false
	session.stop_play()
	# Idle guide readership is finite and cannot issue an unbounded royalty.
	session.tick(700)
	var guide_income: int = state.life["guide_income"]
	session.tick(100)
	check(state.life["guides"][id]["royalties"] == 60 and state.life["guide_income"] == guide_income, "guide residual income has a finite 60-payment budget")
	var bad: Dictionary = Data.clean({"items": ["missing"], "equipped": {"computer": "workstation"}, "attributes": {"反应": 10000}, "displayed": [{"game_id": "missing", "achievement": "fake"}], "active": {"kind": "play", "game_id": "missing"}}, state.owned, state.installed)
	check(bad["equipped"]["computer"] == "starter_pc" and bad["attributes"]["反应"] == 100.0 and bad["active"].is_empty() and bad["displayed"].is_empty(), "invalid saved life data is constrained and cannot grant equipment or achievements")
	game.queue_free()
	await frames()
	print("LIFE_FLOW_CHECKS: %d / %d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
