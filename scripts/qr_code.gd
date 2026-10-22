class_name QrCode
extends RefCounted

# Compact QR Model 2 encoder for short LAN URLs. It emits Version 3-L symbols
# (29x29, up to 53 UTF-8 bytes) using mask 0 and Reed-Solomon error correction.
const VERSION := 3
const SIZE := 29
const DATA_CODEWORDS := 55
const ECC_CODEWORDS := 15


static func texture_for_text(text: String, scale := 7, border := 4) -> Texture2D:
	var bytes := text.to_utf8_buffer()
	if bytes.size() > 53:
		return null
	var codewords := _make_codewords(bytes)
	var modules := _new_matrix(false)
	var functions := _new_matrix(false)
	_draw_function_patterns(modules, functions)
	_draw_codewords(modules, functions, codewords)
	_apply_mask_zero(modules, functions)
	_draw_format_bits(modules, functions, 0)
	var pixel_size := (SIZE + border * 2) * scale
	var image := Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in SIZE:
		for x in SIZE:
			if modules[y][x]:
				for py in scale:
					for px in scale:
						image.set_pixel((x + border) * scale + px, (y + border) * scale + py, Color.BLACK)
	return ImageTexture.create_from_image(image)


static func _make_codewords(input: PackedByteArray) -> PackedByteArray:
	var bits: Array[int] = []
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, input.size(), 8)
	for value in input:
		_append_bits(bits, value, 8)
	var capacity := DATA_CODEWORDS * 8
	_append_bits(bits, 0, mini(4, capacity - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)
	var data := PackedByteArray()
	for index in range(0, bits.size(), 8):
		var value := 0
		for offset in 8:
			value = (value << 1) | bits[index + offset]
		data.append(value)
	var pad := 0xEC
	while data.size() < DATA_CODEWORDS:
		data.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	var divisor := _reed_solomon_divisor(ECC_CODEWORDS)
	var remainder := _reed_solomon_remainder(data, divisor)
	data.append_array(remainder)
	return data


static func _append_bits(target: Array[int], value: int, length: int) -> void:
	for index in range(length - 1, -1, -1):
		target.append((value >> index) & 1)


static func _reed_solomon_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for _index in degree:
		for j in degree:
			result[j] = _gf_multiply(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_multiply(root, 0x02)
	return result


static func _reed_solomon_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for value in data:
		var factor := value ^ result[0]
		for index in range(result.size() - 1):
			result[index] = result[index + 1]
		result[result.size() - 1] = 0
		for index in divisor.size():
			result[index] ^= _gf_multiply(divisor[index], factor)
	return result


static func _gf_multiply(x: int, y: int) -> int:
	var z := 0
	for index in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> index) & 1) * x
	return z


static func _new_matrix(default_value: bool) -> Array:
	var result := []
	for _y in SIZE:
		var row := []
		row.resize(SIZE)
		row.fill(default_value)
		result.append(row)
	return result


static func _draw_function_patterns(modules: Array, functions: Array) -> void:
	for index in SIZE:
		_set_function(modules, functions, 6, index, index % 2 == 0)
		_set_function(modules, functions, index, 6, index % 2 == 0)
	_draw_finder(modules, functions, 3, 3)
	_draw_finder(modules, functions, SIZE - 4, 3)
	_draw_finder(modules, functions, 3, SIZE - 4)
	_draw_alignment(modules, functions, 22, 22)
	_draw_format_bits(modules, functions, 0)


static func _draw_finder(modules: Array, functions: Array, center_x: int, center_y: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x := center_x + dx
			var y := center_y + dy
			if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
				var distance := maxi(absi(dx), absi(dy))
				_set_function(modules, functions, x, y, distance != 2 and distance != 4)


static func _draw_alignment(modules: Array, functions: Array, center_x: int, center_y: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_function(modules, functions, center_x + dx, center_y + dy, maxi(absi(dx), absi(dy)) != 1)


static func _draw_format_bits(modules: Array, functions: Array, mask: int) -> void:
	var data := (1 << 3) | mask # Error correction level L has format bits 01.
	var remainder := data
	for _index in 10:
		remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537)
	var bits := ((data << 10) | remainder) ^ 0x5412
	for index in range(0, 6):
		_set_function(modules, functions, 8, index, _bit(bits, index))
	_set_function(modules, functions, 8, 7, _bit(bits, 6))
	_set_function(modules, functions, 8, 8, _bit(bits, 7))
	_set_function(modules, functions, 7, 8, _bit(bits, 8))
	for index in range(9, 15):
		_set_function(modules, functions, 14 - index, 8, _bit(bits, index))
	for index in range(0, 8):
		_set_function(modules, functions, SIZE - 1 - index, 8, _bit(bits, index))
	for index in range(8, 15):
		_set_function(modules, functions, 8, SIZE - 15 + index, _bit(bits, index))
	_set_function(modules, functions, 8, SIZE - 8, true)


static func _draw_codewords(modules: Array, functions: Array, data: PackedByteArray) -> void:
	var bit_index := 0
	var right := SIZE - 1
	var upward := true
	while right >= 1:
		if right == 6:
			right -= 1
		for vertical in SIZE:
			var y := SIZE - 1 - vertical if upward else vertical
			for offset in 2:
				var x := right - offset
				if not functions[y][x] and bit_index < data.size() * 8:
					modules[y][x] = _bit(data[bit_index >> 3], 7 - (bit_index & 7))
					bit_index += 1
		upward = not upward
		right -= 2


static func _apply_mask_zero(modules: Array, functions: Array) -> void:
	for y in SIZE:
		for x in SIZE:
			if not functions[y][x] and (x + y) % 2 == 0:
				modules[y][x] = not modules[y][x]


static func _set_function(modules: Array, functions: Array, x: int, y: int, value: bool) -> void:
	modules[y][x] = value
	functions[y][x] = true


static func _bit(value: int, index: int) -> bool:
	return ((value >> index) & 1) != 0
