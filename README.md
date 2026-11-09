# RISC-V VexRiscv JPEG Accelerator SoC with DMA

Hệ thống **System-on-Chip (SoC)** hoàn chỉnh phục vụ nén ảnh tĩnh chuẩn **JPEG Baseline (ISO/IEC 10918-1)**. Thiết kế tích hợp lõi xử lý **RISC-V 32-bit (VexRiscv)**, bộ tăng tốc phần cứng **JPEG Encoder**, kênh truyền **AXI4 DMA 2 kênh** và cơ chế **ngắt phần cứng (Hardware Interrupt)** giúp giải phóng CPU hoàn toàn khỏi việc polling từng pixel.

---

## 👥 Thành viên & Hướng dẫn
- **Sinh viên:** Ngô Đỗ Anh Quân (23521257), Lê Nhật Quang (23521283)
- **GVHD:** ThS. Tạ Tri Đức
- **Đơn vị:** Khoa Kỹ thuật Máy tính, Trường Đại học Công nghệ Thông tin, ĐHQG-HCM (UIT)

---

## 🚀 Đặc điểm nổi bật
- **Lõi CPU:** VexRiscv (RV32I + Zicsr), 5-stage pipeline, sinh từ SpinalHDL, giao tiếp bus AXI4.
- **DMA Subsystem 2 kênh:**
  - **Read Channel:** Tự động đọc pixel từ RAM và đẩy sang JPEG Core qua **AXI4-Stream**.
  - **Write Channel:** Tự động thu bitstream nén từ JPEG Core qua AXI4-Stream và ghi về RAM.
- **Bộ tăng tốc JPEG Baseline:** Pipeline tính toán song song gồm chuyển đổi `RGB2YCbCr`, biến đổi 2D-DCT, bảng lượng tử hóa (Quantization) và mã hóa Huffman Entropy (`ff_checker` chèn `0xFF00` chuẩn xác).
- **Cơ chế ngắt (IRQ):** Báo hoàn thành khung ảnh hoặc lỗi bus về CPU (`dma_irq` -> `MCAUSE_MACHINE_EXTERNAL`), loại bỏ hoàn toàn vòng lặp polling.
- **Kiểm thử đa khung:** Testbench mô phỏng kiểm tra và nén thành công **3 ảnh liên tiếp** với 0 lỗi DMA/Bus.

---

## 🏗 Kiến trúc hệ thống & Luồng xử lý

![SoC Architecture](./M%C3%B4%20h%C3%ACnh%20SoC%20-%20chuy%C3%AAn%20nghi%E1%BB%87p.png)

```text
[ VexRiscv CPU ] ──(AXI4)──┐
                           ├──> [ AXI Crossbar ] ──┬──> [ System RAM (0x0000_0000) ]
[ DMA Controller ] ──(AXI4)─┘                      └──> [ DMA Registers (0x4000_0000) ]
        │
   (AXI-Stream)
        ▼
[ JPEG Accelerator ] ──> (RGB2YCbCr -> 2D-DCT -> Quantizer -> Huffman -> Bitstream)
```

### Bản đồ thanh ghi DMA (`Base: 0x4000_0000`)
| Offset | Tên thanh ghi | Chức năng |
| :---: | :--- | :--- |
| `0x00` | `DMA_READ_ADDR` | Địa chỉ nguồn ảnh đầu vào trong RAM |
| `0x04` | `DMA_READ_LEN` | Kích thước ảnh đầu vào (byte) |
| `0x08` | `DMA_READ_GO` | Kích hoạt DMA kênh đọc |
| `0x0C` | `DMA_WRITE_ADDR` | Địa chỉ đích lưu bitstream nén trong RAM |
| `0x10` | `DMA_WRITE_LEN` | Kích thước bộ đệm đầu ra tối đa |
| `0x14` | `DMA_WRITE_GO` | Kích hoạt DMA kênh ghi |
| `0x18` | `DMA_READ_STATUS` | Trạng thái kênh đọc (`Done`, `Error`) |
| `0x1C` | `DMA_WRITE_STATUS`| Trạng thái kênh ghi (`Done`, `Error`) |
| `0x20` | `DMA_IRQ_ACK` | Xóa cờ ngắt sau khi CPU phục vụ ISR |
| `0x28` | `DMA_JPEG_RESET` | Soft-reset khối JPEG giữa các frame |

---

## 📁 Cấu trúc thư mục

```text
├── JPEG/                                    # Dự án Xilinx Vivado (JPEG.xpr)
├── JPEG_SoC.qpf / .mpf                      # Dự án Intel Quartus & ModelSim
├── System_Interrupt_Worked_3_Images_Passed/ # Mã nguồn chính
│   ├── soc_top.v                            # Top-level SoC Verilog
│   ├── tb_soc_top.v                         # Testbench mô phỏng 3 ảnh
│   ├── my_core.v                            # Lõi VexRiscv RISC-V
│   ├── jpeg_dma_subsystem.v                 # Phân hệ DMA & Điều khiển ngắt
│   ├── jpeg_top.v                           # Khối nén phần cứng JPEG
│   ├── software/                            # Firmware C Bare-metal (main.c, crt0.s, Makefile)
│   ├── sim/sim.txt                          # Script chạy sóng ModelSim
│   └── python_script/                       # Scripts chuyển đổi & tái tạo ảnh JPG
└── _doc_work/                               # Báo cáo kỹ thuật
```

---

## 🛠 Hướng dẫn chạy

### 1. Biên dịch Firmware C (RISC-V Bare-metal)
```bash
cd System_Interrupt_Worked_3_Images_Passed/software
make all
# Tạo ra file codejpeg.hex để nạp vào iRAM mô phỏng
```

### 2. Chạy mô phỏng trên ModelSim
1. Khởi động **ModelSim / QuestaSim**, đặt thư mục làm việc tại `System_Interrupt_Worked_3_Images_Passed`.
2. Chạy script mô phỏng:
   ```tcl
   do sim/sim.txt
   ```
3. Quan sát thông báo kiểm thử thành công:
   ```text
   [TB PASS] 3 frames completed; one CPU interrupt per frame; 3 output RAM ranges captured.
   ```

### 3. Khôi phục ảnh nén từ Bitstream (Python)
```bash
cd System_Interrupt_Worked_3_Images_Passed/python_script
python generate_jpeg.py
# File JPG kết quả sẽ nằm tại thư mục res/
```

---

## 📊 Tài nguyên phần cứng (Xilinx Artix-7 `xc7a200t`)

| Tài nguyên | Đã dùng | Khả dụng | Tỷ lệ (%) |
| :--- | :---: | :---: | :---: |
| **LUT** | 30.639 | 134.600 | 22.76 % |
| **FF** | 42.745 | 269.200 | 15.88 % |
| **BRAM Tile** | 67.5 | 365 | 18.49 % |
| **DSP Slices** | 408 | 740 | 55.14 % |
