# ========================== WORKED EXAMPLE: TẠO FILE JPEG THỬ NGHIỆM Q100 ==========================

import os
import re
import sys

def build_jpg_q100_test(input_hex_file="scan_data_out.hex", output_jpg="dragon_q100_test.jpg"):
    # Bảng lượng tử hóa ép toàn bộ 64 giá trị về 0x01
    q100_table = "01" * 64
    
    # SOF0 cấu hình chuẩn Height = 96 (0x0060), Width = 96 (0x0060)
    sof0_hex = "FFC00011080060006003011100021101031101"

    header_hex = (
        "FFD8FFE000104A46494600010100000100010000"
        f"FFDB004300{q100_table}"
        f"FFDB004301{q100_table}"
        f"{sof0_hex}"
        "FFC4001F0000030101010101010101010000000000000102030405060708090A0B"
        "FFC400B5100002010303020403050504040000017D010203000411051221314106135161072271"
        "14328191A1082342B1C11552D1F02433627282090A161718191A25262728292A343536373839"
        "3A434445464748494A535455565758595A636465666768696A737475767778797A8384858687"
        "88898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9"
        "CAD2D3D4D5D6D7D8D9DAE1E2E3E4E5E6E7E8E9EAF1F2F3F4F5F6F7F8F9FA"
        "FFC4001F0100030101010101010101010000000000000102030405060708090A0B"
        "FFC400B5110002010303020403050504040000017D010203000411051221314106135161072271"
        "14328191A1082342B1C11552D1F02433627282090A161718191A25262728292A343536373839"
        "3A434445464748494A535455565758595A636465666768696A737475767778797A8384858687"
        "88898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9"
        "CAD2D3D4D5D6D7D8D9DAE1E2E3E4E5E6E7E8E9EAF1F2F3F4F5F6F7F8F9FA"
        "FFDA000C03010002110311003F00"
    )

    if not os.path.exists(input_hex_file):
        print(f"Lỗi: Không tìm thấy file '{input_hex_file}'")
        return

    # Lọc bitstream chuẩn, xử lý dòng _PARTIAL_ từ Verilog
    with open(input_hex_file, "r") as f:
        raw_lines = f.readlines()

    clean_hex = ""
    for line in raw_lines:
        line = line.strip()
        if not line:
            continue
        if "_PARTIAL_" in line:
            hex_part, count_str = line.split("_PARTIAL_")
            byte_count = (int(count_str) + 7) // 8
            clean_hex += hex_part[: byte_count * 2]
        else:
            clean_hex += line

    clean_hex = re.sub(r'[^0-9a-fA-F]', '', clean_hex)

    if not clean_hex.upper().endswith("FFD9"):
        clean_hex += "FFD9"

    with open(output_jpg, "wb") as f:
        f.write(bytes.fromhex(header_hex + clean_hex))
        
    print(f"Wrote JPEG image: '{output_jpg}'")

if __name__ == "__main__":
########################################################                                                       
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if len(sys.argv) == 1:
        for index in range(3):
            input_hex = os.path.join(project_dir, f"res/bitstream_from_ram_{index}.hex")
            output_jpg = os.path.join(project_dir, f"res/jpeg_image_{index}.jpg")
            build_jpg_q100_test(input_hex, output_jpg)
    elif len(sys.argv) == 3:
        build_jpg_q100_test(sys.argv[1], sys.argv[2])
    else:
        raise SystemExit("Usage: python generate_jpeg.py [<bitstream_from_ram_N.hex> <output_N.jpg>]")
# With no arguments, convert all three RAM dumps from tb_soc_top.
########################################################

# ========================== END OF WORKED EXAMPLE ==========================

