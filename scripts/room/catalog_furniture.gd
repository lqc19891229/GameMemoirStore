@tool
extends "res://scripts/room/room_furniture.gd"
## Reusable authored 3D furniture families. Each scene fixes its own footprint,
## finish palette and variant, while preserving the stable inventory placement role.
@export_enum("tables","seating","storage","lighting","decor") var family := "tables"
@export_range(0, 4, 1) var variant := 0

func _build_visual() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	match family:
		"tables": _build_table(model)
		"seating": _build_seating(model)
		"storage": _build_storage(model)
		"lighting": _build_lighting(model)
		"decor": _build_decor(model)

func _build_table(model: Node3D) -> void:
	var wood := _material(Color("ae8460"), .67)
	var walnut := _material(Color("765843"), .60)
	var steel := _material(Color("434c52"), .35,.68)
	var brass := _material(Color("bd9a68"), .35,.62)
	var glass := _material(Color(.67,.84,.88,.37),.13,.10)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match variant:
		0: # compact oak side table with a divided lower shelf
			_box(model,"OakTop",Vector3(.74,.07,.67),Vector3(0,.63,0),wood)
			_box(model,"OakLowerShelf",Vector3(.65,.04,.58),Vector3(0,.21,0),walnut)
			for x in [-.29,.29]:
				for z in [-.26,.26]:
					_box(model,"OakLeg",Vector3(.055,.60,.055),Vector3(x,.30,z),wood)
		1: # slim industrial side table and crossed frame
			_box(model,"SteelTop",Vector3(.72,.035,.63),Vector3(0,.73,0),steel)
			_box(model,"TopInlay",Vector3(.63,.008,.54),Vector3(0,.754,0),wood)
			for x in [-.29,.29]:
				_box(model,"SteelLeg",Vector3(.035,.70,.035),Vector3(x,.355,0),steel)
				_box(model,"SteelFoot",Vector3(.08,.025,.54),Vector3(x,.04,0),steel)
			_box(model,"CrossBrace",Vector3(.57,.035,.035),Vector3(0,.37,0),brass)
		2: # circular wood coffee table, round central pedestal
			_cylinder(model,"CoffeeTop",.59,.59,.085,Vector3(0,.47,0),wood)
			_cylinder(model,"Pedestal",.105,.15,.37,Vector3(0,.245,0),walnut)
			_cylinder(model,"DiscBase",.36,.39,.055,Vector3(0,.04,0),steel)
			_cylinder(model,"TopRim",.585,.585,.017,Vector3(0,.52,0),brass)
		3: # glass top with low bronzed metal frame
			_box(model,"GlassTop",Vector3(1.32,.028,.70),Vector3(0,.485,0),glass)
			for x in [-.61,.61]:
				_box(model,"EdgeRail",Vector3(.022,.04,.71),Vector3(x,.48,0),brass)
				for z in [-.29,.29]:
					_box(model,"SlimLeg",Vector3(.037,.45,.037),Vector3(x,.245,z),steel)
			for z in [-.33,.33]:
				_box(model,"EdgeRail",Vector3(1.26,.04,.02),Vector3(0,.48,z),brass)
			_box(model,"LowerFrame",Vector3(1.22,.023,.59),Vector3(0,.13,0),steel)
		4: # freestanding writing desk (not a second equipment tabletop)
			_box(model,"DeskSlab",Vector3(1.43,.075,.70),Vector3(0,.745,0),walnut)
			for x in [-.645,.645]:
				for z in [-.27,.27]:
					_box(model,"TaperedLeg",Vector3(.055,.68,.055),Vector3(x,.34,z),wood)
			_box(model,"DeskDrawer",Vector3(.61,.15,.50),Vector3(-.27,.625,0),wood)
			_box(model,"DrawerPull",Vector3(.14,.016,.023),Vector3(-.27,.61,.266),brass)
			_box(model,"CableChannel",Vector3(.30,.024,.07),Vector3(.40,.79,-.26),steel)

func _build_seating(model: Node3D) -> void:
	var timber := _material(Color("967158"),.67)
	var dark := _material(Color("465053"),.42,.32)
	var fabric := _material(Color("bbc6bc"),.94)
	var cream := _material(Color("e0d7c4"),.93)
	var accent := _material(Color("83999c"),.91)
	match variant:
		0: # lounge chair
			_box(model,"LoungeSeat",Vector3(.88,.20,.76),Vector3(0,.44,.04),fabric)
			_box(model,"LoungeBack",Vector3(.88,.65,.17),Vector3(0,.80,-.30),cream)
			for x in [-.42,.42]:
				_box(model,"LoungeArm",Vector3(.10,.35,.77),Vector3(x,.56,0),timber)
			for x in [-.35,.35]:
				for z in [-.28,.28]:
					_box(model,"LoungeLeg",Vector3(.06,.34,.06),Vector3(x,.17,z),dark)
		1: # breathable mesh office chair
			_box(model,"MeshSeat",Vector3(.60,.16,.56),Vector3(0,.54,0),dark)
			_box(model,"SeatPad",Vector3(.56,.07,.51),Vector3(0,.64,0),fabric)
			_box(model,"MeshBackFrame",Vector3(.60,.56,.07),Vector3(0,.90,-.24),dark)
			_box(model,"MeshCenter",Vector3(.52,.46,.078),Vector3(0,.93,-.24),accent)
			for x in [-.33,.33]:
				_box(model,"Armrest",Vector3(.055,.06,.40),Vector3(x,.78,-.03),dark)
			_cylinder(model,"ChairPost",.048,.052,.47,Vector3(0,.30,0),dark)
			for i in range(5):
				var angle: float = TAU*float(i)/5.0
				_box(model,"WheelSpoke",Vector3(.49,.045,.052),Vector3(0,.075,0),dark,angle)
		2: # wide modular sofa, three independent seat modules
			_box(model,"ModularBase",Vector3(2.08,.28,.83),Vector3(0,.25,0),dark)
			_box(model,"ModularBack",Vector3(2.10,.54,.17),Vector3(0,.73,-.37),fabric)
			for x in [-.70,0.0,.70]:
				_box(model,"SofaCushion",Vector3(.65,.15,.72),Vector3(x,.48,.06),cream)
				_box(model,"SofaPillow",Vector3(.63,.41,.13),Vector3(x,.77,-.25),accent if x==0.0 else fabric)
			for x in [-.96,.96]:
				_box(model,"SofaArm",Vector3(.13,.43,.85),Vector3(x,.49,0),fabric)
			for x in [-.82,.82]:
				for z in [-.29,.29]:
					_cylinder(model,"SofaFoot",.045,.05,.10,Vector3(x,.05,z),timber,12)
		3: # upholstered bench
			_box(model,"BenchCushion",Vector3(1.29,.15,.53),Vector3(0,.53,0),cream)
			_box(model,"BenchRail",Vector3(1.28,.08,.52),Vector3(0,.43,0),timber)
			for x in [-.53,.53]:
				for z in [-.19,.19]:
					_box(model,"BenchLeg",Vector3(.065,.42,.065),Vector3(x,.21,z),dark)
			_box(model,"BenchCrossbar",Vector3(1.12,.04,.055),Vector3(0,.19,0),timber)

func _build_storage(model: Node3D) -> void:
	var frame := _material(Color("ac8465"),.67)
	var shelf := _material(Color("d0b18d"),.72)
	var metal := _material(Color("3c4c53"),.38,.65)
	var door := _material(Color("758a8c"),.54)
	var glass := _material(Color(.66,.81,.86,.32),.12,.04)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match variant:
		0: # low open bookshelf
			for x in [-.66,.66]:
				_box(model,"LowShelfSide",Vector3(.055,.88,.42),Vector3(x,.50,0),frame)
			for y in [.09,.48,.90]:
				_box(model,"LowShelfBoard",Vector3(1.38,.045,.43),Vector3(0,y,0),shelf)
			for i in range(7):
				var h: float = .21+float(i%3)*.035
				_box(model,"BookSpine",Vector3(.095,h,.22),Vector3(-.48+float(i)*.16,.12+h*.5,.02),door if i%3==0 else frame)
		1: # tall ladder display shelf
			for x in [-.46,.46]:
				_box(model,"LadderRail",Vector3(.062,1.85,.06),Vector3(x,.97,-.12),metal)
			for i in range(4):
				var y: float = .28+float(i)*.48
				var depth: float = .44-float(i)*.055
				_box(model,"LadderShelf",Vector3(1.00,.04,depth),Vector3(0,y,.03),shelf)
				_box(model,"ShelfBack",Vector3(.95,.04,.035),Vector3(0,y+.13,-.18),frame)
			_box(model,"DisplayVase",Vector3(.17,.22,.17),Vector3(.28,1.40,0),door)
		2: # closed modern media cabinet
			_box(model,"MediaBody",Vector3(1.78,.48,.50),Vector3(0,.34,0),frame)
			for x in [-.61,0.0,.61]:
				_box(model,"FrontPanel",Vector3(.55,.40,.015),Vector3(x,.34,.26),door if x==0.0 else shelf)
				_box(model,"Handle",Vector3(.17,.018,.022),Vector3(x,.38,.278),metal)
			for x in [-.73,.73]:
				_box(model,"MediaLeg",Vector3(.065,.14,.065),Vector3(x,.08,0),metal)
			_box(model,"ConsoleTop",Vector3(1.80,.04,.52),Vector3(0,.60,0),shelf)
		3: # glass trophy cabinet with lit display spaces
			_box(model,"CabinetBack",Vector3(1.05,1.74,.035),Vector3(0,.96,-.23),frame)
			for x in [-.51,.51]:
				_box(model,"CabinetSide",Vector3(.055,1.76,.47),Vector3(x,.96,0),metal)
			for y in [.18,.65,1.14,1.77]:
				_box(model,"CabinetShelf",Vector3(1.07,.037,.47),Vector3(0,y,0),shelf)
			_box(model,"GlassLeft",Vector3(.48,1.60,.018),Vector3(-.255,1.0,.242),glass)
			_box(model,"GlassRight",Vector3(.48,1.60,.018),Vector3(.255,1.0,.242),glass)
			_box(model,"DoorDivider",Vector3(.027,1.66,.026),Vector3(0,1.0,.255),metal)
			for x in [-.28,.27]:
				_cylinder(model,"DisplayTrophy",.10,.08,.22,Vector3(x,.78,.01),door,16)

func _build_lighting(model: Node3D) -> void:
	var body := _material(Color("c8b9a0"),.73)
	var metal := _material(Color("53585e"),.35,.75)
	var shade := _material(Color("ebe1cf"),.88)
	var glow := _material(Color("fff0c7"),.54)
	glow.emission_enabled = true
	glow.emission = Color("ffe2a7")
	glow.emission_energy_multiplier = .75
	match variant:
		0: # tripod floor light
			for i in range(3):
				var angle: float = TAU*float(i)/3.0
				var leg := _box(model,"TripodLeg",Vector3(.042,1.38,.042),Vector3(sin(angle)*.18,.69,cos(angle)*.18),metal)
				leg.rotation.z = sin(angle)*.09
			_cylinder(model,"TripodShade",.22,.36,.39,Vector3(0,1.49,0),shade)
			_sphere(model,"TripodBulb",Vector3(.23,.14,.23),Vector3(0,1.29,0),glow)
		1: # arc lamp silhouette
			_cylinder(model,"ArcBase",.26,.28,.06,Vector3(-.28,.03,0),metal)
			_cylinder(model,"ArcPost",.030,.032,1.66,Vector3(-.28,.85,0),metal,18)
			_box(model,"UpperArc",Vector3(.70,.035,.045),Vector3(.05,1.79,0),metal)
			_box(model,"DropStem",Vector3(.038,.25,.038),Vector3(.38,1.66,0),metal)
			_cylinder(model,"ArcShade",.18,.27,.30,Vector3(.38,1.45,0),shade)
			_sphere(model,"ArcBulb",Vector3(.17,.10,.17),Vector3(.38,1.29,0),glow)
		2: # upright ambient tube
			_cylinder(model,"LampBase",.21,.23,.06,Vector3(0,.03,0),metal)
			_cylinder(model,"LightColumn",.14,.14,1.08,Vector3(0,.64,0),glow,28)
			_cylinder(model,"DiffusionSleeve",.18,.18,1.06,Vector3(0,.64,0),shade,28)
			for y in [.18,.58,.98]:
				_cylinder(model,"RingTrim",.19,.19,.019,Vector3(0,y,0),body,28)

func _build_decor(model: Node3D) -> void:
	var pot := _material(Color("c09a83"),.81)
	var soil := _material(Color("4f4435"),.99)
	var leaves := _material(Color("5d8464"),.92)
	var sage := _material(Color("86a18a"),.91)
	var textile := _material(Color("acb8b0"),.98)
	var pattern := _material(Color("dfd4bd"),.96)
	match variant:
		0: # sculptural cactus
			_cylinder(model,"ClayPot",.23,.18,.37,Vector3(0,.19,0),pot)
			_cylinder(model,"PotSoil",.21,.21,.022,Vector3(0,.38,0),soil)
			_cylinder(model,"CactusCore",.13,.15,.74,Vector3(0,.78,0),leaves,18)
			for x in [-.22,.22]:
				var side := _cylinder(model,"CactusBranch",.062,.075,.38,Vector3(x,.73,0),sage,14)
				side.rotation.z = -.28 if x<0 else .28
				_sphere(model,"BranchTip",Vector3(.13,.17,.13),Vector3(x,.94,0),sage)
		1: # tall palm with asymmetrical leaf crowns
			_cylinder(model,"PalmPot",.25,.21,.40,Vector3(0,.20,0),pot)
			_cylinder(model,"PalmSoil",.23,.23,.024,Vector3(0,.42,0),soil)
			_cylinder(model,"PalmStem",.042,.052,.97,Vector3(0,.87,0),soil,16)
			for i in range(7):
				var a: float = TAU*float(i)/7.0
				var r: float = .32+float(i%2)*.12
				var at := Vector3(cos(a)*r,1.49+float(i%3)*.06,sin(a)*r)
				var leaf := _sphere(model,"PalmLeaf",Vector3(.40,.10,.14),at,sage if i%2==0 else leaves)
				leaf.rotation.y = -a
		2: # woven geometric rug, thin so it can overlap furniture vertically
			_box(model,"WovenRug",Vector3(2.61,.028,1.66),Vector3(0,.018,0),textile)
			for x in [-1.10,-.55,0.0,.55,1.10]:
				_box(model,"WeaveStripe",Vector3(.035,.006,1.50),Vector3(x,.035,0),pattern)
			for z in [-.69,.69]:
				_box(model,"RugHem",Vector3(2.55,.006,.035),Vector3(0,.036,z),pot)
		3: # circular low-pile rug
			_cylinder(model,"RoundRug",.84,.84,.035,Vector3(0,.02,0),textile,48)
			_cylinder(model,"RingAccent",.73,.73,.005,Vector3(0,.040,0),pattern,48)
			_cylinder(model,"CenterMotif",.46,.46,.007,Vector3(0,.045,0),sage,48)
			for i in range(8):
				var a: float = TAU*float(i)/8.0
				_box(model,"EdgeTassel",Vector3(.09,.008,.024),Vector3(cos(a)*.78,.045,sin(a)*.78),pattern,a)
