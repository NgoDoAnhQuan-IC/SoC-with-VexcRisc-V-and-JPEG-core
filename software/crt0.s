# ============================================================================
# File: crt0.s
# Description: RISC-V (RV32) Startup Code for Bare-Metal SoC
# ============================================================================

    .section .text.init
    .global _start
    .type _start, @function

_start:
    # ------------------------------------------------------------------------
    # 1. Khởi tạo Con trỏ Ngăn xếp (Stack Pointer - sp)
    # ------------------------------------------------------------------------
    # _stack_top = 0x00040000 (đỉnh cao nhất của d_ram trong soc_top.v)
    # Stack phát triển lùi xuống; vùng DMA test dùng 0x00000000 - 0x00035FFF.
    .option push
    .option norelax
    la      sp, _stack_top
    .option pop

    # Khởi tạo global pointer để truy cập các biến .sbss/.sdata theo ABI RISC-V.
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    # ------------------------------------------------------------------------
    # 2. Xóa vùng nhớ .bss (Uninitialized Global/Static Variables về 0)
    # ------------------------------------------------------------------------
    # Vùng .bss nằm từ 0x0003E000 trong d_ram, phía trên các buffer DMA.
    la      a0, _sbss
    la      a1, _ebss

bss_clear_loop:
    bgeu    a0, a1, bss_clear_done  # Nếu a0 >= a1 (đã xóa xong) -> Thoát vòng lặp
    sw      zero, 0(a0)             # Ghi giá trị 0 vào địa chỉ [a0]
    addi    a0, a0, 4               # Tăng địa chỉ lên 4 Byte (32-bit)
    j       bss_clear_loop

bss_clear_done:

    # ------------------------------------------------------------------------
    # 3. Lưu ý về vùng .data trong kiến trúc SoC hiện tại:
    # ------------------------------------------------------------------------
    # Trong soc_top.v, khối i_ram (0x80000000) chỉ nối với iBusAxi (Instruction
    # Bus) của CPU để fetch lệnh. Cổng dBusAxi (Data Bus) chỉ nối tới d_ram
    # (0x00000000) và dma_adapter (0x40000000) qua Crossbar.
    # Do đó, CPU không thể thực hiện lệnh `lw` từ i_ram để copy sang d_ram.
    # Mọi biến toàn cục nên dùng dưới dạng uninitialized (.bss) hoặc khởi tạo
    # trực tiếp trong mã C (runtime assignment).
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    # 4. Gọi hàm main() trong C
    # ------------------------------------------------------------------------
    call    main

    # ------------------------------------------------------------------------
    # 5. Xử lý khi hàm main() kết thúc (Bẫy vòng lặp vô tận an toàn)
    # ------------------------------------------------------------------------
_exit:
    wfi
    j       _exit

    .size _start, . - _start

    # VexRiscv mtvec được cấu hình direct mode tại 0x80000100.
    # Wrapper lưu toàn bộ thanh ghi GPR có thể bị hàm C làm thay đổi, gọi ISR,
    # khôi phục context và trả về bằng mret.
    .section .trap,"ax",@progbits
    .align 2
    .global trap_entry
    .type trap_entry, @function
trap_entry:
    addi    sp, sp, -128
    sw      ra,   0(sp)
    sw      gp,   4(sp)
    sw      tp,   8(sp)
    sw      t0,  12(sp)
    sw      t1,  16(sp)
    sw      t2,  20(sp)
    sw      s0,  24(sp)
    sw      s1,  28(sp)
    sw      a0,  32(sp)
    sw      a1,  36(sp)
    sw      a2,  40(sp)
    sw      a3,  44(sp)
    sw      a4,  48(sp)
    sw      a5,  52(sp)
    sw      a6,  56(sp)
    sw      a7,  60(sp)
    sw      s2,  64(sp)
    sw      s3,  68(sp)
    sw      s4,  72(sp)
    sw      s5,  76(sp)
    sw      s6,  80(sp)
    sw      s7,  84(sp)
    sw      s8,  88(sp)
    sw      s9,  92(sp)
    sw      s10, 96(sp)
    sw      s11,100(sp)
    sw      t3, 104(sp)
    sw      t4, 108(sp)
    sw      t5, 112(sp)
    sw      t6, 116(sp)

    call    machine_trap_handler

    lw      ra,   0(sp)
    lw      gp,   4(sp)
    lw      tp,   8(sp)
    lw      t0,  12(sp)
    lw      t1,  16(sp)
    lw      t2,  20(sp)
    lw      s0,  24(sp)
    lw      s1,  28(sp)
    lw      a0,  32(sp)
    lw      a1,  36(sp)
    lw      a2,  40(sp)
    lw      a3,  44(sp)
    lw      a4,  48(sp)
    lw      a5,  52(sp)
    lw      a6,  56(sp)
    lw      a7,  60(sp)
    lw      s2,  64(sp)
    lw      s3,  68(sp)
    lw      s4,  72(sp)
    lw      s5,  76(sp)
    lw      s6,  80(sp)
    lw      s7,  84(sp)
    lw      s8,  88(sp)
    lw      s9,  92(sp)
    lw      s10, 96(sp)
    lw      s11,100(sp)
    lw      t3, 104(sp)
    lw      t4, 108(sp)
    lw      t5, 112(sp)
    lw      t6, 116(sp)
    addi    sp, sp, 128
    mret
    .size trap_entry, . - trap_entry
