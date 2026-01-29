class_name QRCode
extends RefCounted

# QR Code Generator for Godot 4.x
# Implements QR Code Model 2
# Supports Byte mode encoding

const MODE_NUMERIC = 1
const MODE_ALPHANUMERIC = 2
const MODE_BYTE = 4
const MODE_KANJI = 8

const ECC_L = 1
const ECC_M = 0
const ECC_Q = 3
const ECC_H = 2

# Error correction level (M is a good balance)
var error_correction_level = ECC_M

func generate_image(text: String, module_size: int = 4) -> Image:
	var qr = _encode_text(text, error_correction_level)
	if qr == null:
		push_error("Failed to generate QR code")
		return null
	
	var size = qr.get_module_count()
	var quiet_zone = 4
	var total_size = size + 2 * quiet_zone
	var img_size = total_size * module_size
	
	var image = Image.create(img_size, img_size, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	
	for y in range(size):
		for x in range(size):
			if qr.is_dark(y, x):
				var rect = Rect2i((x + quiet_zone) * module_size, (y + quiet_zone) * module_size, module_size, module_size)
				image.fill_rect(rect, Color.BLACK)
				
	return image

# --- Internal QR Code Logic ---

class QRData:
	var modules = [] # 2D array of bools (true = black/dark)
	var module_count = 0
	
	func _init(size, data):
		module_count = size
		modules = data

	func get_module_count():
		return module_count
		
	func is_dark(row, col):
		if row < 0 or module_count <= row or col < 0 or module_count <= col:
			return false
		return modules[row][col]

func _encode_text(text: String, ec_level: int) -> QRData:
	var data = text.to_utf8_buffer()
	
	# 1. Determine version
	var version = _get_version_for_data_length(ec_level, MODE_BYTE, data.size())
	if version < 1 or version > 40:
		push_error("Data too long for QR Code")
		return null
		
	# 2. Create data bits
	var bits = BitBuffer.new()
	
	# Mode indicator (Byte)
	bits.put(MODE_BYTE, 4)
	
	# Character count indicator
	var char_count_bits = _get_char_count_bits(version, MODE_BYTE)
	bits.put(data.size(), char_count_bits)
	
	# Data
	for b in data:
		bits.put(b, 8)
		
	# Terminator
	var capacity = _get_num_data_codewords(version, ec_level) * 8
	var terminator_len = min(4, capacity - bits.length)
	bits.put(0, terminator_len)
	
	# Pad to byte
	bits.pad_to_byte()
	
	# Pad bytes
	var pad_bytes_needed = (capacity - bits.length) / 8
	for i in range(pad_bytes_needed):
		bits.put(0xEC if i % 2 == 0 else 0x11, 8)
		
	# 3. Error Correction Coding
	var data_codewords = bits.get_bytes()
	var ec_codewords = _generate_ec_codewords(data_codewords, version, ec_level)
	
	var final_message = _interleave_blocks(data_codewords, ec_codewords, version, ec_level)
	
	# 4. Module Placement
	var matrix = _make_matrix(version, final_message, ec_level)
	
	return QRData.new(matrix.size(), matrix)

# --- Helpers ---

class BitBuffer:
	var buffer = []
	var length = 0
	
	func put(num: int, length_bits: int):
		for i in range(length_bits):
			var bit = (num >> (length_bits - 1 - i)) & 1
			put_bit(bit == 1)
			
	func put_bit(bit: bool):
		if length == buffer.size() * 8:
			buffer.append(0)
		if bit:
			buffer[int(length / 8)] |= (0x80 >> (length % 8))
		length += 1
		
	func pad_to_byte():
		while length % 8 != 0:
			put_bit(false)
			
	func get_bytes():
		return buffer

func _get_version_for_data_length(ec_level, mode, length):
	for v in range(1, 41):
		var capacity = _get_num_data_codewords(v, ec_level) * 8
		var header_len = 4 + _get_char_count_bits(v, mode) # Mode + Count
		if header_len + length * 8 <= capacity:
			return v
	return 41 # Too big

func _get_char_count_bits(version, mode):
	if mode == MODE_BYTE:
		if version <= 9: return 8
		elif version <= 26: return 16
		else: return 16
	return 0 # Only Byte mode supported here

func _get_num_data_codewords(version, ec_level):
	var total_codewords = _get_total_codewords(version)
	var ec_codewords = _get_total_ec_codewords(version, ec_level)
	return total_codewords - ec_codewords

func _get_total_codewords(version):
	return _CODEWORDS_TABLE[version - 1]

func _get_total_ec_codewords(version, ec_level):
	return _EC_CODEWORDS_TABLE[ec_level][version - 1]

func _generate_ec_codewords(data_codewords, version, ec_level):
	var num_blocks = _get_num_blocks(version, ec_level)
	var ec_per_block = int(_get_total_ec_codewords(version, ec_level) / num_blocks)
	
	# Split data into blocks
	var data_len = data_codewords.size()
	var short_block_len = int(data_len / num_blocks)
	var num_short_blocks = num_blocks - (data_len % num_blocks)
	
	var offset = 0
	var ec_result = []
	
	for i in range(num_blocks):
		var count = short_block_len
		if i >= num_short_blocks:
			count += 1
		var block_data = data_codewords.slice(offset, offset + count)
		offset += count
		
		# Calculate EC for this block
		var ec = _reed_solomon_encode(block_data, ec_per_block)
		ec_result.append(ec)
		
	return ec_result

func _reed_solomon_encode(data, ec_count):
	var generator = _get_rs_generator_poly(ec_count)
	var message = []
	message.resize(data.size() + ec_count)
	message.fill(0)
	
	for i in range(data.size()):
		message[i] = data[i]
		
	# Polynomial division
	for i in range(data.size()):
		var coef = message[i]
		if coef != 0:
			for j in range(generator.size()):
				if generator[j] != -1:
					message[i + j] ^= _gexp(generator[j] + _glog(coef))
				
	return message.slice(data.size())

# Galois Field Math
var _exp_table = []
var _log_table = []
var _tables_initialized = false

func _init_tables():
	if _tables_initialized: return
	_exp_table.resize(256)
	_log_table.resize(256)
	var x = 1
	for i in range(255):
		_exp_table[i] = x
		_log_table[x] = i
		x = x * 2
		if x >= 256:
			x = x ^ 0x11D
	_exp_table[255] = _exp_table[0] 
	_tables_initialized = true

func _glog(n):
	if not _tables_initialized: _init_tables()
	if n == 0: return -1 # Error
	return _log_table[n]

func _gexp(n):
	if not _tables_initialized: _init_tables()
	while n < 0: n += 255
	while n >= 255: n -= 255
	return _exp_table[n]

func _get_rs_generator_poly(degree):
	if not _tables_initialized: _init_tables()
	
	var g = [1]
	for i in range(degree):
		# Multiply g by (x + alpha^i)
		var next_g = []
		next_g.resize(g.size() + 1)
		next_g.fill(0)
		
		for j in range(g.size()):
			# term 1: g[j] * alpha^i
			var term1 = 0
			if g[j] != 0:
				term1 = _gexp(_glog(g[j]) + i)
			
			next_g[j] ^= g[j]
			next_g[j+1] ^= term1
			
		g = next_g
		
	var g_log = []
	for val in g:
		if val == 0: g_log.append(-1)
		else: g_log.append(_glog(val))
	return g_log

func _interleave_blocks(data_codewords, ec_codewords, version, ec_level):
	var num_blocks = _get_num_blocks(version, ec_level)
	var result = []
	
	# Interleave data
	var data_len = data_codewords.size()
	var short_block_len = int(data_len / num_blocks)
	var num_short_blocks = num_blocks - (data_len % num_blocks)
	
	# Split data again
	var d_blocks = []
	var offset = 0
	for i in range(num_blocks):
		var count = short_block_len
		if i >= num_short_blocks: count += 1
		d_blocks.append(data_codewords.slice(offset, offset + count))
		offset += count
		
	# Interleave data bytes
	var max_len = 0
	for b in d_blocks: max_len = max(max_len, b.size())
	
	for i in range(max_len):
		for j in range(num_blocks):
			if i < d_blocks[j].size():
				result.append(d_blocks[j][i])
				
	# Interleave EC bytes
	var ec_len = ec_codewords[0].size()
	for i in range(ec_len):
		for j in range(num_blocks):
			result.append(ec_codewords[j][i])
			
	return result

func _make_matrix(version, data_bits, ec_level):
	var size = 17 + 4 * version
	var matrix = []
	for i in range(size):
		var row_arr = []
		row_arr.resize(size)
		row_arr.fill(null) # null = unset
		matrix.append(row_arr)
		
	# Finder patterns
	_add_finder_pattern(matrix, 0, 0)
	_add_finder_pattern(matrix, size - 7, 0)
	_add_finder_pattern(matrix, 0, size - 7)
	
	# Alignment patterns
	var align_coords = _get_alignment_coords(version)
	for r in align_coords:
		for c in align_coords:
			if matrix[r][c] == null:
				_add_alignment_pattern(matrix, r - 2, c - 2)
				
	# Timing patterns
	for i in range(8, size - 8):
		if matrix[6][i] == null: matrix[6][i] = (i % 2 == 0)
		if matrix[i][6] == null: matrix[i][6] = (i % 2 == 0)
		
	# Dark module
	matrix[size - 8][8] = true
	
	# Reserve format/version areas
	for i in range(9):
		if matrix[8][i] == null: matrix[8][i] = false # Reserve
		if matrix[i][8] == null: matrix[i][8] = false
	for i in range(8):
		if matrix[8][size - 1 - i] == null: matrix[8][size - 1 - i] = false
		if matrix[size - 1 - i][8] == null: matrix[size - 1 - i][8] = false
		
	if version >= 7:
		for i in range(6):
			for j in range(3):
				matrix[size - 11 + j][i] = false
				matrix[i][size - 11 + j] = false
				
	# Place data and apply mask
	var bit_idx = 0
	var dir = -1 # up
	var row = size - 1
	var col = size - 1
	
	# Mask 0: (row + col) % 2 == 0
	var mask_pattern = 0
	
	while col > 0:
		if col == 6: col -= 1
		
		while row >= 0 and row < size:
			for c in range(2):
				var x = col - c
				if matrix[row][x] == null:
					var bit = false
					if bit_idx < data_bits.size() * 8:
						var byte_val = data_bits[int(bit_idx / 8)]
						bit = (byte_val >> (7 - (bit_idx % 8))) & 1 == 1
					bit_idx += 1
					
					# Apply mask
					if (row + x) % 2 == 0:
						bit = not bit
						
					matrix[row][x] = bit
			row += dir
		row -= dir
		dir = -dir
		col -= 2
		
	# Format info
	var format_bits = _get_format_bits(ec_level, mask_pattern)
	for i in range(15):
		var bit = (format_bits >> i) & 1 == 1
		# Vertical
		if i < 6: matrix[i][8] = bit
		elif i < 8: matrix[i + 1][8] = bit
		else: matrix[size - 15 + i][8] = bit
		
		# Horizontal
		if i < 8: matrix[8][size - 1 - i] = bit
		elif i < 9: matrix[8][15 - 1 - i + 1] = bit
		else: matrix[8][15 - 1 - i] = bit
		
	# Version info
	if version >= 7:
		var ver_bits = _get_version_bits(version)
		for i in range(18):
			var bit = (ver_bits >> i) & 1 == 1
			var r = int(i / 3)
			var c = i % 3
			matrix[size - 11 + c][r] = bit
			matrix[r][size - 11 + c] = bit
			
	# Finalize: convert nulls to false (white)
	for r in range(size):
		for c in range(size):
			if matrix[r][c] == null: matrix[r][c] = false
			
	return matrix

func _add_finder_pattern(matrix, r, c):
	for y in range(7):
		for x in range(7):
			if r+y < matrix.size() and c+x < matrix.size():
				if y == 0 or y == 6 or x == 0 or x == 6 or (y >= 2 and y <= 4 and x >= 2 and x <= 4):
					matrix[r+y][c+x] = true
				else:
					matrix[r+y][c+x] = false
					
	# Separator (white around finder)
	_fill_rect(matrix, r-1, c-1, 9, 9, false)

func _fill_rect(matrix, r, c, w, h, val):
	for y in range(h):
		for x in range(w):
			var ry = r + y
			var cx = c + x
			if ry >= 0 and ry < matrix.size() and cx >= 0 and cx < matrix.size():
				# Don't overwrite finder patterns if we are drawing separators
				if matrix[ry][cx] == null:
					matrix[ry][cx] = val

func _add_alignment_pattern(matrix, r, c):
	for y in range(5):
		for x in range(5):
			if y == 0 or y == 4 or x == 0 or x == 4 or (y == 2 and x == 2):
				matrix[r+y][c+x] = true
			else:
				matrix[r+y][c+x] = false

func _get_alignment_coords(version):
	if version == 1: return []
	
	# Hardcoded for low versions to ensure correctness
	if version == 2: return [6, 18]
	if version == 3: return [6, 22]
	if version == 4: return [6, 26]
	if version == 5: return [6, 30]
	if version == 6: return [6, 34]
	if version == 7: return [6, 22, 38]
	
	var coords = [6]
	var size = 17 + 4 * version
	var d = size - 7
	while d > 6:
		coords.append(d)
		d -= 28 # Rough step
	coords.sort()
	return coords

func _get_format_bits(ec_level, mask):
	var data = ec_level << 3 | mask 
	
	var d = data << 10
	var g = 0x537
	for i in range(5): # 14 down to 10
		if (d >> (14 - i)) & 1:
			d ^= (g << (4 - i))
			
	return ((data << 10) | (d & 0x3FF)) ^ 0x5412

func _get_version_bits(version):
	# BCH (18, 6)
	var d = version << 12
	var g = 0x1F25
	for i in range(6):
		if (d >> (17 - i)) & 1:
			d ^= (g << (5 - i))
	return ((version << 12) | (d & 0xFFF))

func _get_num_blocks(version, ec_level):
	return _BLOCKS_TABLE[ec_level][version - 1]

# --- Tables ---
# Total codewords per version
const _CODEWORDS_TABLE = [
	26, 44, 70, 100, 134, 172, 196, 242, 292, 346,
	404, 466, 532, 581, 655, 733, 815, 901, 991, 1085,
	1156, 1258, 1364, 1474, 1588, 1706, 1828, 1921, 2051, 2185,
	2323, 2465, 2611, 2761, 2876, 3034, 3196, 3362, 3532, 3706
]

# Total EC codewords per version for [M, L, H, Q] -> remapped to [M, L, H, Q]
# My constants: M=0, L=1, H=2, Q=3
const _EC_CODEWORDS_TABLE = [
	# M
	[10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
	# L
	[7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	# H
	[17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 28, 24, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
	# Q
	[13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
]

# Number of blocks
const _BLOCKS_TABLE = [
	# M
	[1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
	# L
	[1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
	# H
	[1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
	# Q
	[1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68]
]
