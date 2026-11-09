# ============================================================================
# File: Makefile
# Description: Makefile biên dịch RISC-V Bare-Metal cho hệ thống SoC
# ============================================================================

# Khai báo Toolchain Prefix
CROSS_COMPILE ?= C:/Document/riscv-gcc/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-

CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE    = $(CROSS_COMPILE)size

# Cấu hình Flag cho VexRiscv (RV32I + Zicsr, ilp32 ABI)
CFLAGS  = -march=rv32i_zicsr -mabi=ilp32 -O2 -Wall -ffreestanding -nostdlib -fno-builtin
LDFLAGS = -T linker.ld -nostdlib

# Tên file đầu ra
TARGET  = firmware
HEX_OUT = codejpeg.hex

# Danh sách file nguồn và object
SRCS_C   = main.c
SRCS_ASM = crt0.s
OBJS     = $(SRCS_ASM:.s=.o) $(SRCS_C:.c=.o)

# Lệnh xóa tương thích đa nền tảng (Windows / Linux)
ifeq ($(OS),Windows_NT)
    CLEAN_CMD = -del /f /q *.o *.elf *.bin *.dump $(HEX_OUT) 2>nul
else
    CLEAN_CMD = rm -f *.o *.elf *.bin *.dump $(HEX_OUT)
endif

.PHONY: all clean dump size

all: $(HEX_OUT) $(TARGET).dump size

# Biên dịch file Assembly (.s -> .o)
%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

# Biên dịch file C (.c -> .o)
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link các file .o thành file thực thi .elf
$(TARGET).elf: $(OBJS) linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@

# Chuyển .elf thành file nhị phân .bin (LMA bắt đầu từ 0x80000000 của i_ram)
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Tự động chuyển .bin -> codejpeg.hex (Định dạng 32-bit Hex Little-Endian cho Verilog $readmemh)
PYTHON = "C:/Users/Quan/AppData/Local/Programs/Python/Python313/python.exe"

$(HEX_OUT): $(TARGET).bin
	$(PYTHON) bin2hex.py $< $@
	@echo ==================================================
	@echo --> Da tao thanh cong file $(HEX_OUT) cho i_ram!
	@echo ==================================================

# Xuất file Disassembly để đọc/debug mã máy RISC-V sinh ra
$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d $< > $@

# Hiển thị dung lượng RAM/Code đã chiếm dụng
size: $(TARGET).elf
	@echo.
	@echo --- THONG KE DUNG LUONG BO NHO ---
	$(SIZE) $<

# Dọn dẹp các file trung gian
clean:
	$(CLEAN_CMD)
