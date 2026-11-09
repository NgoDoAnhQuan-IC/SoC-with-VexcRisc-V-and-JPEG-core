// Dual-port RAM for simultaneous DMA reads and writes.
// The synchronous read port allows Vivado to infer Block RAM.
module ram_dp_byte_en #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter INIT_FILE  = ""
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    input  wire [DATA_WIDTH-1:0] din,
    input  wire [DATA_WIDTH/8-1:0] strb,
    output wire [DATA_WIDTH-1:0] dout
);

    localparam NUM_BYTES = DATA_WIDTH / 8;

    // A 64K-deep x32 inferred RAM can be implemented as cascaded RAMB36E1
    // cells. Split this case into two 32K banks so ADDR[15] selects the bank
    // in fabric and is not used by a BRAM cascade.
    generate
        if (ADDR_WIDTH == 16) begin : gen_banked_64k
            localparam BANK_ADDR_WIDTH = 15;
            localparam BANK_DEPTH = 2**BANK_ADDR_WIDTH;

            (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem_bank0 [0:BANK_DEPTH-1];
            (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem_bank1 [0:BANK_DEPTH-1];
            reg [DATA_WIDTH-1:0] dout_bank0;
            reg [DATA_WIDTH-1:0] dout_bank1;
            reg                  rd_bank_sel;
            integer i;

            initial begin
                // The current image initialization file contains the input
                // frames at addresses 0..27647, all within bank 0.
                if (INIT_FILE != "") begin
                    $readmemh(INIT_FILE, mem_bank0);
                end
            end

            always @(posedge clk) begin
                rd_bank_sel <= rd_addr[15];
                if (rd_addr[15]) begin
                    dout_bank1 <= mem_bank1[rd_addr[BANK_ADDR_WIDTH-1:0]];
                end else begin
                    dout_bank0 <= mem_bank0[rd_addr[BANK_ADDR_WIDTH-1:0]];
                end

                if (we) begin
                    for (i = 0; i < NUM_BYTES; i = i + 1) begin
                        if (strb[i]) begin
                            if (wr_addr[15]) begin
                                mem_bank1[wr_addr[BANK_ADDR_WIDTH-1:0]][(i*8) +: 8] <= din[(i*8) +: 8];
                            end else begin
                                mem_bank0[wr_addr[BANK_ADDR_WIDTH-1:0]][(i*8) +: 8] <= din[(i*8) +: 8];
                            end
                        end
                    end
                end
            end

            assign dout = rd_bank_sel ? dout_bank1 : dout_bank0;
        end else begin : gen_single_bank
            (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH)-1:0];
            reg [DATA_WIDTH-1:0] dout_reg;
            integer i;

            initial begin
                if (INIT_FILE != "") begin
                    $readmemh(INIT_FILE, mem);
                end
            end

            always @(posedge clk) begin
                dout_reg <= mem[rd_addr];

                if (we) begin
                    for (i = 0; i < NUM_BYTES; i = i + 1) begin
                        if (strb[i]) begin
                            mem[wr_addr][(i*8) +: 8] <= din[(i*8) +: 8];
                        end
                    end
                end
            end

            assign dout = dout_reg;
        end
    endgenerate

endmodule
