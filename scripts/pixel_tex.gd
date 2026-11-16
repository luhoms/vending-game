class_name PixelTex
extends RefCounted
## The cabinet's and room's surfaces: tiny pictures drawn in code and shown with hard pixel edges, for the look of an
## early-2000s console game. Most are shades of grey meant to be tinted by a material's colour, so one tile picture
## serves every fruit and the side art can change colour with the machine. One texel is about 0.21 studs.

static var _cache := {}


static func _cached(key: String, make: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(make.call())
	return _cache[key]


static func _grey(v: float) -> Color:
	return Color(v, v, v, 1.0)


## The plate behind a fruit: a raised square, lighter along the top and left, darker along the bottom and right.
static func tile() -> ImageTexture:
	return _cached("tile", func() -> Image:
		var w := 14
		var h := 16
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var v := 0.84
				if x == 0 or y == 0:
					v = 1.0
				elif x == w - 1 or y == h - 1:
					v = 0.52
				elif x == 1 or y == 1:
					v = 0.93
				elif x == w - 2 or y == h - 2:
					v = 0.68
				elif (x + y) % 2 == 0 and x + y > 20:
					v = 0.76 # a dithered shade toward the bottom right
				image.set_pixel(x, y, _grey(v))
		return image)


## The side art: bands fading down the panel with dithered edges, crossed by diagonal stripes.
static func art() -> ImageTexture:
	return _cached("art", func() -> Image:
		var w := 16
		var h := 79
		var bands := 7
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var k := float(y) / h * bands
				var band := int(k)
				# The last two rows of a band are a checker of this band and the next: an old-fashioned blend.
				if k - band > 0.72 and (x + y) % 2 == 0:
					band += 1
				var v := 0.8 - 0.075 * band
				if (x + y) % 12 < 3:
					v += 0.11
				if x == 0 or x == w - 1:
					v = 0.22
				image.set_pixel(x, y, _grey(clampf(v, 0.0, 1.0)))
		return image)


## Two colours in a 2 x 2 checker (repeat it with a material's UV scale): the floor.
static func checker(a: Color, b: Color) -> ImageTexture:
	return _cached("checker|%s|%s" % [a.to_html(), b.to_html()], func() -> Image:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, a)
		image.set_pixel(1, 1, a)
		image.set_pixel(1, 0, b)
		image.set_pixel(0, 1, b)
		return image)


## A panel with a line along two edges (repeat it for a wall of panels).
static func panel(base: Color, line: Color, lit: Color) -> ImageTexture:
	return _cached("panel|%s|%s" % [base.to_html(), line.to_html()], func() -> Image:
		var n := 16
		var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var color := base
				if x == 0 or y == 0:
					color = line
				elif x == 1 or y == 1:
					color = lit
				image.set_pixel(x, y, color)
		return image)


## Dark lines across a screen (repeat it down the display).
static func scanlines() -> ImageTexture:
	return _cached("scanlines", func() -> Image:
		var image := Image.create(1, 2, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, _grey(1.0))
		image.set_pixel(0, 1, _grey(0.62))
		return image)


## The marquee: a pale plate with a two-pixel coloured rim and nicked corners.
static func marquee(face: Color, rim: Color) -> ImageTexture:
	return _cached("marquee|%s|%s" % [face.to_html(), rim.to_html()], func() -> Image:
		var w := 64
		var h := 8
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
				var corner := (x <= 1 or x >= w - 2) and (y <= 1 or y >= h - 2)
				var color := face
				if edge or corner:
					color = rim
				elif y == h - 2:
					color = face.darkened(0.14)
				image.set_pixel(x, y, color)
		return image)


## A keypad: three columns of four keys.
static func keypad() -> ImageTexture:
	return _cached("keypad", func() -> Image:
		var w := 13
		var h := 17
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		image.fill(Color8(26, 28, 40))
		for row in 4:
			for column in 3:
				for y in 3:
					for x in 3:
						var color := Color8(150, 156, 180) if y < 2 else Color8(96, 100, 124)
						image.set_pixel(1 + column * 4 + x, 1 + row * 4 + y, color)
		return image)


## The delivery hatch: a dark flap with a pale rim and a row of arrows pointing down.
static func hatch() -> ImageTexture:
	return _cached("hatch", func() -> Image:
		var w := 48
		var h := 10
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var color := Color8(20, 22, 34)
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					color = Color8(214, 216, 226)
				elif x == 1 or y == 1 or x == w - 2 or y == h - 2:
					color = Color8(60, 64, 88)
				else:
					# Arrows: a "v" every eight pixels, three rows deep.
					var u := (x - 4) % 8
					var row := y - 3
					if row >= 0 and row < 3 and x > 5 and x < w - 6 and (u == row or u == 4 - row):
						color = Color8(120, 126, 156)
				image.set_pixel(x, y, color)
		return image)


## A heart, for the life lamps (white with a clear background: tint it).
static func heart() -> ImageTexture:
	return PixelUi.icon(PixelUi.HEART)


static func clear_cache() -> void:
	_cache.clear()
