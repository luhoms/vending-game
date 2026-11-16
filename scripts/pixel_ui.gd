class_name PixelUi
extends RefCounted
## The HUD's look: chunky pixels. Boxes are tiny pictures drawn in code (an outline with nicked corners, a highlight
## along the top, a shade along the bottom, and for buttons a dark lip underneath) stretched as nine-patches; icons are
## little bitmaps written out as text. One "pixel" is UNIT canvas units across.

const UNIT := 4

# The palette.
const INK := Color8(9, 10, 18)
const PANEL := Color8(22, 24, 44)
const PANEL_EDGE := Color8(58, 64, 112)
const CHIP := Color8(38, 42, 76)
const TEAL := Color8(26, 110, 120)
const TEXT := Color8(244, 241, 232)
const SOFT := Color8(143, 150, 196)
const CYAN := Color8(70, 225, 210)
const GOLD := Color8(255, 205, 60)
const PINK := Color8(255, 95, 200)
const RED := Color8(255, 70, 80)

const HEART := [
	".##...##.",
	"####.####",
	"#########",
	"#########",
	".#######.",
	"..#####..",
	"...###...",
	"....#....",
]
const BARS := [
	"......##.",
	"......##.",
	"...##.##.",
	"...##.##.",
	"##.##.##.",
	"##.##.##.",
	"##.##.##.",
	"##.##.##.",
]
const SPEAKER := [
	"....#......",
	"...##...#..",
	"#####....#.",
	"#####.#..#.",
	"#####.#..#.",
	"#####....#.",
	"...##...#..",
	"....#......",
]
const SPEAKER_OFF := [
	"....#......",
	"...##......",
	"#####.#...#",
	"#####..#.#.",
	"#####...#..",
	"#####..#.#.",
	"...##.#...#",
	"....#......",
]

static var _cache := {}


## A box as a nine-patch. `lip` = rows of dark edge under it (a button's depth; 0 for a pressed button or a panel).
static func box(fill: Color, outline: Color, lip := 0) -> StyleBoxTexture:
	var key := "box|%s|%s|%d" % [fill.to_html(), outline.to_html(), lip]
	if not _cache.has(key):
		var size := 8
		var image := Image.create((size) * UNIT, (size + lip) * UNIT, false, Image.FORMAT_RGBA8)
		var light := fill.lightened(0.22)
		var shade := fill.darkened(0.28)
		var under := outline.darkened(0.55)
		for y in size + lip:
			for x in size:
				var corner := (x == 0 or x == size - 1) and (y == 0 or y == size - 1 + lip)
				var color := fill
				if corner:
					color = Color(0, 0, 0, 0)
				elif y >= size:
					color = under
				elif x == 0 or x == size - 1 or y == 0 or y == size - 1:
					# The bottom corners of the face stay open when there is a lip, so it reads as one block.
					color = under if (lip > 0 and y == size - 1 and (x == 0 or x == size - 1)) else outline
				elif y == 1:
					color = light
				elif y == size - 2:
					color = shade
				image.fill_rect(Rect2i(x * UNIT, y * UNIT, UNIT, UNIT), color)
		var style := StyleBoxTexture.new()
		style.texture = ImageTexture.create_from_image(image)
		style.texture_margin_left = 3 * UNIT
		style.texture_margin_right = 3 * UNIT
		style.texture_margin_top = 3 * UNIT
		style.texture_margin_bottom = (3 + lip) * UNIT
		style.content_margin_left = 3 * UNIT
		style.content_margin_right = 3 * UNIT
		style.content_margin_top = 2 * UNIT
		style.content_margin_bottom = (2 + lip) * UNIT
		_cache[key] = style
	return _cache[key]


## An icon from a bitmap of '#' and '.', white (tint it with modulate).
static func icon(rows: Array) -> ImageTexture:
	var key := "icon|" + "".join(rows)
	if not _cache.has(key):
		var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				image.set_pixel(x, y, Color.WHITE if row[x] == "#" else Color(0, 0, 0, 0))
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


static func clear_cache() -> void:
	_cache.clear()
