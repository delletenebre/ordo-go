extends SceneTree
## Repackage the committed artwork; no network or image generation required.
## godot --headless --path . --script res://tools/icons/build_icons.gd

const ROOT := "res://assets/icons/"
const BACKGROUND := Color("182633")
const IOS_SIZES := [20, 29, 40, 58, 60, 76, 80, 87, 114, 120, 128, 136, 152, 167, 180, 192, 1024]

func _init() -> void:
	var source := Image.load_from_file(ROOT + "source/medallion.png")
	var mono := Image.load_from_file(ROOT + "source/flame-monochrome.png")
	assert(source != null and mono != null)
	assert(source.detect_alpha() != Image.ALPHA_NONE)
	source = source.get_region(source.get_used_rect())
	mono = mono.get_region(mono.get_used_rect())
	var master := place(source, 1024, 900, BACKGROUND)
	master.convert(Image.FORMAT_RGB8)
	save(master, "app-icon.png")
	for size in [16, 32, 48, 64, 128, 256, 512, 1024]:
		save(scaled(master, size), "desktop/icon-%d.png" % size)
	write_ico(master)
	write_icns(master)
	for size in [48, 72, 96, 144, 192]:
		save(scaled(master, size), "android/launcher-%d.png" % size)
	save(scaled(master, 512), "android/play-store-512.png")
	# 64 dp artwork within the 66 dp safe circle on a 108 dp layer, at xxxhdpi.
	save(place(source, 432, 256, Color.TRANSPARENT), "android/adaptive-foreground-432.png")
	save(canvas(432, BACKGROUND), "android/adaptive-background-432.png")
	save(place(mono, 432, 228, Color.TRANSPARENT), "android/adaptive-monochrome-432.png")
	for size in IOS_SIZES:
		save(scaled(master, size), "ios/icon-%d.png" % size)
		if size not in [114, 128, 136, 192]:
			save(scaled(master, size), "ios/catalog/AppIcon.appiconset/icon-%d.png" % size)
	var ignore := FileAccess.open(ROOT + "ios/catalog/.gdignore", FileAccess.WRITE)
	ignore.close()
	write_catalog()
	for size in [32, 180, 192, 512]:
		save(scaled(master, size), "web/icon-%d.png" % size)
	print("ORDO icons generated: PNG, ICO, ICNS, Android layers and iOS AppIcon catalog.")
	quit()

func canvas(size: int, color: Color) -> Image:
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(color)
	return result

func place(source: Image, size: int, content_size: int, background: Color) -> Image:
	var result := canvas(size, background)
	var artwork := source.duplicate() as Image
	var factor := float(content_size) / maxi(source.get_width(), source.get_height())
	# Premultiplication prevents dark fringes when downsampling transparent edges.
	artwork.premultiply_alpha()
	artwork.resize(roundi(source.get_width() * factor), roundi(source.get_height() * factor), Image.INTERPOLATE_LANCZOS)
	# Image.blend_rect expects straight alpha.
	for y in artwork.get_height():
		for x in artwork.get_width():
			var pixel := artwork.get_pixel(x, y)
			if pixel.a > 0.0:
				artwork.set_pixel(x, y, Color(pixel.r / pixel.a, pixel.g / pixel.a, pixel.b / pixel.a, pixel.a))
	var offset := (Vector2i(size, size) - artwork.get_size()) / 2
	result.blend_rect(artwork, Rect2i(Vector2i.ZERO, artwork.get_size()), offset)
	return result

func scaled(source: Image, size: int) -> Image:
	var result := source.duplicate() as Image
	result.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return result

func save(img: Image, relative_path: String) -> void:
	var path := ROOT + relative_path
	assert(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK)
	assert(img.save_png(path) == OK)

func write_ico(master: Image) -> void:
	var sizes := [16, 24, 32, 48, 64, 128, 256]
	var entries: Array[PackedByteArray] = []
	for size in sizes:
		var frame := scaled(master, size)
		frame.convert(Image.FORMAT_RGBA8)
		entries.append(frame.save_png_to_buffer())
	var file := FileAccess.open(ROOT + "desktop/ordo.ico", FileAccess.WRITE)
	file.store_16(0)
	file.store_16(1)
	file.store_16(sizes.size())
	var offset := 6 + 16 * sizes.size()
	for index in sizes.size():
		file.store_8(sizes[index] % 256)
		file.store_8(sizes[index] % 256)
		file.store_16(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(entries[index].size())
		file.store_32(offset)
		offset += entries[index].size()
	for entry in entries:
		file.store_buffer(entry)

func write_icns(master: Image) -> void:
	var types := {"icp4": 16, "icp5": 32, "icp6": 64, "ic07": 128, "ic08": 256, "ic09": 512, "ic10": 1024}
	var entries: Dictionary = {}
	var length := 8
	for type in types:
		entries[type] = scaled(master, types[type]).save_png_to_buffer()
		length += 8 + entries[type].size()
	var file := FileAccess.open(ROOT + "desktop/ordo.icns", FileAccess.WRITE)
	file.big_endian = true
	file.store_buffer("icns".to_ascii_buffer())
	file.store_32(length)
	for type in entries:
		file.store_buffer(type.to_ascii_buffer())
		file.store_32(8 + entries[type].size())
		file.store_buffer(entries[type])

func write_catalog() -> void:
	var images: Array = []
	for idiom in ["iphone", "ipad"]:
		var points := [20.0, 29.0, 40.0, 60.0] if idiom == "iphone" else [20.0, 29.0, 40.0, 76.0, 83.5]
		for point in points:
			var scales := [2, 3] if idiom == "iphone" else ([2] if point == 83.5 else [1, 2])
			for scale in scales:
				images.append({"idiom": idiom, "size": "%sx%s" % [point, point], "scale": "%dx" % scale, "filename": "icon-%d.png" % roundi(point * scale)})
	images.append({"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "filename": "icon-1024.png"})
	var file := FileAccess.open(ROOT + "ios/catalog/AppIcon.appiconset/Contents.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"images": images, "info": {"author": "xcode", "version": 1}}, "\t") + "\n")
