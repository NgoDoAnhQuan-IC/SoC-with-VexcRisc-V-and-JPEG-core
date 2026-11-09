from PIL import Image

# Đọc ảnh bất kỳ (PNG, JPG, v.v.)
img = Image.open("../b.jpg")

# Chuyển về định dạng RGB 8-bit chuẩn
img = img.convert("RGB")

# Lưu thành file .tif nguyên bản không nén (Uncompressed)
img.save("b.tif", compression="raw")

print("Đã tạo xong file b.tif làm dữ liệu thô chuẩn!")