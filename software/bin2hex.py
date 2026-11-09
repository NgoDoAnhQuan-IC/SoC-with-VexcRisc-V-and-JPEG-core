import sys

if len(sys.argv) < 3:
    sys.exit(1)

bin_file = sys.argv[1]
hex_file = sys.argv[2]

with open(bin_file, 'rb') as f:
    data = f.read()

# Pad thêm byte 0x00 nếu chưa chia hết cho 4
pad_len = (4 - len(data) % 4) % 4
data += b'\x00' * pad_len

# Ghi ra file .hex định dạng 32-bit (Little-Endian)
with open(hex_file, 'w') as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], 'little')
        f.write(f"{word:08x}\n")