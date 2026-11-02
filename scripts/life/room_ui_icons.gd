extends RefCounted
## Lightweight vector line icons for the room editor. No imported icon fonts.
const STROKES := {
	"furniture": '<path d="M4 12V7a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v5M4 13h16M4 13v6m16-6v6M7 9v4m10-4v4M4 18h16"/>',
	"decor": '<path d="M4 19h16M7 17l10-10 3 3-10 10H7zM14 10l3 3M5 6h4M7 4v4"/>',
	"lighting": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/>',
	"build": '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 11h16M11 11v9M11 4v7"/>',
	"catalog": '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
	"advanced": '<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2" fill="#f4f5f0"/><circle cx="16" cy="12" r="2" fill="#f4f5f0"/><circle cx="10" cy="18" r="2" fill="#f4f5f0"/>',
	"undo": '<path d="M9 8 4 12l5 4M4 12h10a6 6 0 0 1 6 6"/>',
	"redo": '<path d="m15 8 5 4-5 4m5-4H10a6 6 0 0 0-6 6"/>',
	"desk": '<path d="M3 9h18v3H3zM5 12v9M19 12v9"/>',
	"monitor": '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M12 17v4m-5 0h10"/>',
	"computer": '<rect x="7" y="3" width="10" height="18" rx="2"/><circle cx="12" cy="16" r="1"/><path d="M10 7h4"/>',
	"keyboard": '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M6 10h1m3 0h1m3 0h1m3 0h1M6 13h12"/>',
	"mouse": '<rect x="7" y="3" width="10" height="18" rx="5"/><path d="M12 3v7"/>'
}
static var _cached: Dictionary = {}

static func texture(symbol: String) -> Texture2D:
	if _cached.has(symbol): return _cached[symbol]
	if not STROKES.has(symbol): return null
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#344a3a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + str(STROKES[symbol]) + '</svg>'
	var img := Image.new()
	if img.load_svg_from_buffer(svg.to_utf8_buffer()) != OK: return null
	var tex := ImageTexture.create_from_image(img)
	_cached[symbol] = tex
	return tex
