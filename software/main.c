#include <stdint.h>

#define DMA_BASE_ADDR           0x40000000U
#define REG32(addr)             (*(volatile uint32_t *)(uintptr_t)(addr))

#define DMA_READ_ADDR           0x00U
#define DMA_READ_LEN            0x04U
#define DMA_READ_GO             0x08U
#define DMA_WRITE_ADDR          0x0CU
#define DMA_WRITE_LEN           0x10U
#define DMA_WRITE_GO            0x14U
#define DMA_READ_STATUS         0x18U
#define DMA_WRITE_STATUS        0x1CU
#define DMA_IRQ_ACK             0x20U
#define DMA_JPEG_RESET          0x28U

#define IMAGE_COUNT             3U
#define IMAGE_BYTES             0x00009000U
#define DMA_STATUS_DONE         (1U << 0)
#define DMA_STATUS_ERROR_SHIFT  4U
#define DMA_IRQ_READ            (1U << 0)
#define DMA_IRQ_WRITE           (1U << 1)
#define MIE_MEIE                (1U << 11)
#define MSTATUS_MIE             (1U << 3)
#define MCAUSE_INTERRUPT        (1U << 31)
#define MCAUSE_CODE_MASK        0x7FFFFFFFU
#define MCAUSE_MACHINE_EXTERNAL 11U

static volatile uint32_t dma_read_done;
static volatile uint32_t jpeg_write_done;
static volatile uint32_t dma_error_flags;

static inline void enable_external_interrupts(void)
{
    const uint32_t external_irq_mask = MIE_MEIE;
    const uint32_t global_irq_mask = MSTATUS_MIE;

    asm volatile ("csrs mie, %0" :: "r" (external_irq_mask) : "memory");
    asm volatile ("csrs mstatus, %0" :: "r" (global_irq_mask) : "memory");
}

// Called by trap_entry after the interrupted GPR context has been saved.
void machine_trap_handler(void)
{
    uint32_t cause;
    uint32_t read_status;
    uint32_t write_status;
    uint32_t acknowledge = 0U;

    asm volatile ("csrr %0, mcause" : "=r" (cause));
    if (!(cause & MCAUSE_INTERRUPT) ||
        ((cause & MCAUSE_CODE_MASK) != MCAUSE_MACHINE_EXTERNAL)) {
        for (;;)
            asm volatile ("nop");
    }

    read_status = REG32(DMA_BASE_ADDR + DMA_READ_STATUS);
    write_status = REG32(DMA_BASE_ADDR + DMA_WRITE_STATUS);

    if (read_status & DMA_STATUS_DONE) {
        dma_read_done = 1U;
        dma_error_flags |= (read_status >> DMA_STATUS_ERROR_SHIFT) & 0x0FU;
        acknowledge |= DMA_IRQ_READ;
    }

    if (write_status & DMA_STATUS_DONE) {
        jpeg_write_done = 1U;
        dma_error_flags |= ((write_status >> DMA_STATUS_ERROR_SHIFT) & 0x0FU) << 4;
        acknowledge |= DMA_IRQ_WRITE;
    }

    if (acknowledge != 0U)
        REG32(DMA_BASE_ADDR + DMA_IRQ_ACK) = acknowledge;
}

static void wait_for_read_status(void)
{
    while (!dma_read_done) {
        const uint32_t status = REG32(DMA_BASE_ADDR + DMA_READ_STATUS);

        // Successful read completion is not an interrupt source.  Usually the
        // write-completion ISR observes and acknowledges it first; this poll
        // also covers unusual timing where the output finishes first.
        if (status & DMA_STATUS_DONE) {
            dma_read_done = 1U;
            dma_error_flags |= (status >> DMA_STATUS_ERROR_SHIFT) & 0x0FU;
            REG32(DMA_BASE_ADDR + DMA_IRQ_ACK) = DMA_IRQ_READ;
        }
    }
}

int main(void)
{
    REG32(DMA_BASE_ADDR + DMA_IRQ_ACK) = DMA_IRQ_READ | DMA_IRQ_WRITE;
    enable_external_interrupts();

    for (uint32_t image = 0U; image < IMAGE_COUNT; image++) {
        // Compute addresses as immediates.  dBus cannot read iRAM, so avoid
        // const lookup tables that the compiler would place in iRAM .rodata.
        const uint32_t input_addr = image * IMAGE_BYTES;
        const uint32_t output_addr = 0x0001B000U + image * IMAGE_BYTES;

        dma_read_done = 0U;
        jpeg_write_done = 0U;
        dma_error_flags = 0U;

        // Reset all per-frame JPEG state (including the EOF detector) only
        // after the previous output descriptor has completed.
        REG32(DMA_BASE_ADDR + DMA_JPEG_RESET) = 1U;

        REG32(DMA_BASE_ADDR + DMA_WRITE_ADDR) = output_addr;
        REG32(DMA_BASE_ADDR + DMA_WRITE_LEN) = IMAGE_BYTES;
        REG32(DMA_BASE_ADDR + DMA_READ_ADDR) = input_addr;
        REG32(DMA_BASE_ADDR + DMA_READ_LEN) = IMAGE_BYTES;

        // Arm the output before feeding pixels to the JPEG core.
        REG32(DMA_BASE_ADDR + DMA_WRITE_GO) = 1U;
        REG32(DMA_BASE_ADDR + DMA_READ_GO) = 1U;

        while (!jpeg_write_done && (dma_error_flags == 0U))
            asm volatile ("nop");

        if (dma_error_flags != 0U)
            for (;;)
                asm volatile ("nop");

        wait_for_read_status();
        if (dma_error_flags != 0U)
            for (;;)
                asm volatile ("nop");
    }

    for (;;)
        asm volatile ("nop");
}
