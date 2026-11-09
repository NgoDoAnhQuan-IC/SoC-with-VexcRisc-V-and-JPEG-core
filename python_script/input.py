from PIL import Image

def generate_input_pixels(image_path="bocau_128x128.png", output_hex="input_pixels.hex"):
    img = Image.open(image_path).convert("RGB")
    width, height = img.size
    
    # Kiểm tra kích thước chia hết cho 8
    assert width % 8 == 0 and height % 8 == 0, "Kích thước ảnh phải chia hết cho 8!"
    
    hex_lines = []
    
    # Duyệt qua từng Block 8x8 (từ trái qua phải, trên xuống dưới)
    for block_y in range(0, height, 8):
        for block_x in range(0, width, 8):
            # Duyệt 64 pixels trong block 8x8 (Row-major inside block)
            for py in range(8):
                for px in range(8):
                    r, g, b = img.getpixel((block_x + px, block_y + py))
                    # Theo Spec: Blue [23:16], Green [15:8], Red [7:0]
                    val_24bit = (b << 16) | (g << 8) | r
                    hex_lines.append(f"{val_24bit:06X}")
                    
    with open(output_hex, "w") as f:
        f.write("\n".join(hex_lines))
        
    print(f"Đã tạo thành công {len(hex_lines)} pixels ({len(hex_lines)//64} blocks) vào '{output_hex}'")

generate_input_pixels("ja.tif", "ja.hex")