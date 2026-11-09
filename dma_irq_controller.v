`timescale 1ns / 1ps

// Latches DMA descriptor completion events until software acknowledges them.
module dma_irq_controller (
    input  wire       clk,
    input  wire       rst,

    input  wire       read_status_valid,
    input  wire [3:0] read_status_error,
    input  wire       write_status_valid,
    input  wire [3:0] write_status_error,

    input  wire [1:0] clear_pending,
    output wire       irq,
    output reg  [1:0] pending,
    output reg  [3:0] read_error,
    output reg  [3:0] write_error
);

    // Successful input completion is retained for software to inspect, but the
    // normal frame interrupt is the JPEG output DMA completion.  A read error
    // still raises an interrupt so software can report a failed frame instead
    // of waiting forever for output that will never arrive.
    assign irq = pending[1] || (pending[0] && (|read_error));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending     <= 2'b00;
            read_error  <= 4'b0000;
            write_error <= 4'b0000;
        end else begin
            // A new completion wins over a simultaneous software clear.
            if (clear_pending[0]) begin
                pending[0]    <= 1'b0;
                read_error    <= 4'b0000;
            end
            if (clear_pending[1]) begin
                pending[1]    <= 1'b0;
                write_error   <= 4'b0000;
            end

            if (read_status_valid) begin
                pending[0] <= 1'b1;
                read_error <= read_status_error;
            end
            if (write_status_valid) begin
                pending[1]  <= 1'b1;
                write_error <= write_status_error;
            end
        end
    end

endmodule

