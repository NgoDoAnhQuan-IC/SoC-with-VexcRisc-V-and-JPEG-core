`timescale 1ns / 1ps

module dma_axil_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter LEN_WIDTH  = 20,
    parameter TAG_WIDTH  = 8
)(
    input wire clk,
    input wire rst,

    // AXI4-Lite slave interface
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [0:0]            s_axi_awid,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output wire [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,
    output reg  [0:0]            s_axi_bid,
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    input  wire [0:0]            s_axi_arid,
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,
    output reg  [0:0]            s_axi_rid,

    // DMA descriptor interface
    output reg  [ADDR_WIDTH-1:0] read_desc_addr,
    output reg  [LEN_WIDTH-1:0]  read_desc_len,
    output wire [TAG_WIDTH-1:0]  read_desc_tag,
    output wire [7:0]            read_desc_id,
    output wire [7:0]            read_desc_dest,
    output wire [0:0]            read_desc_user,
    output reg                   read_desc_valid,
    input  wire                  read_desc_ready,
    output reg  [ADDR_WIDTH-1:0] write_desc_addr,
    output reg  [LEN_WIDTH-1:0]  write_desc_len,
    output wire [TAG_WIDTH-1:0]  write_desc_tag,
    output reg                   write_desc_valid,
    input  wire                  write_desc_ready,

    // Sticky interrupt status supplied by dma_irq_controller
    input  wire [1:0]            irq_pending,
    input  wire [3:0]            read_irq_error,
    input  wire [3:0]            write_irq_error,
    output reg  [1:0]            irq_clear,
    output reg                   jpeg_soft_reset,

    output wire                  dma_read_enable,
    output wire                  dma_write_enable
);

    localparam [5:0] REG_READ_ADDR   = 6'h00;
    localparam [5:0] REG_READ_LEN    = 6'h04;
    localparam [5:0] REG_READ_GO     = 6'h08;
    localparam [5:0] REG_WRITE_ADDR  = 6'h0C;
    localparam [5:0] REG_WRITE_LEN   = 6'h10;
    localparam [5:0] REG_WRITE_GO    = 6'h14;
    localparam [5:0] REG_READ_STATUS = 6'h18;
    localparam [5:0] REG_WRITE_STATUS= 6'h1C;
    localparam [5:0] REG_IRQ_ACK     = 6'h20;
    localparam [5:0] REG_IRQ_PENDING = 6'h24;
    localparam [5:0] REG_JPEG_RESET  = 6'h28;

    reg                  aw_latched;
    reg                  w_latched;
    reg [ADDR_WIDTH-1:0] latched_awaddr;
    reg [DATA_WIDTH-1:0] latched_wdata;
    reg [STRB_WIDTH-1:0] latched_wstrb;

    reg [31:0] reg_read_addr;
    reg [31:0] reg_read_len;
    reg [31:0] reg_write_addr;
    reg [31:0] reg_write_len;
    reg [31:0] s_axi_rdata_reg;
    reg [31:0] read_data_mux;

    wire [31:0] selected_wdata = w_latched ? latched_wdata : s_axi_wdata;
    wire [STRB_WIDTH-1:0] selected_wstrb = w_latched ? latched_wstrb : s_axi_wstrb;
    wire [31:0] selected_wmask = {
        {8{selected_wstrb[3]}}, {8{selected_wstrb[2]}},
        {8{selected_wstrb[1]}}, {8{selected_wstrb[0]}}
    };

    assign dma_read_enable  = 1'b1;
    assign dma_write_enable = 1'b1;

    assign read_desc_tag  = {TAG_WIDTH{1'b0}};
    assign read_desc_id   = 8'h00;
    assign read_desc_dest = 8'h00;
    assign read_desc_user = 1'b0;
    assign write_desc_tag = {TAG_WIDTH{1'b0}};

    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;
    assign s_axi_rdata = s_axi_rdata_reg;

    assign s_axi_awready = !aw_latched && !s_axi_bvalid;
    assign s_axi_wready  = !w_latched  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    // Capture read data when AR is accepted so RDATA remains stable under backpressure.
    always @* begin
        read_data_mux = 32'h00000000;
        case (s_axi_araddr[5:0])
            REG_READ_ADDR:    read_data_mux = reg_read_addr;
            REG_READ_LEN:     read_data_mux = reg_read_len;
            REG_WRITE_ADDR:   read_data_mux = reg_write_addr;
            REG_WRITE_LEN:    read_data_mux = reg_write_len;
            REG_READ_STATUS:  read_data_mux = {24'b0, read_irq_error, 3'b000, irq_pending[0]};
            REG_WRITE_STATUS: read_data_mux = {24'b0, write_irq_error, 3'b000, irq_pending[1]};
            REG_IRQ_PENDING:  read_data_mux = {30'b0, irq_pending};
            default:          read_data_mux = 32'h00000000;
        endcase
    end

    // AXI-Lite write path: latch AW and W independently, then apply the register write.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s_axi_bvalid     <= 1'b0;
            s_axi_bid        <= 1'b0;
            aw_latched       <= 1'b0;
            w_latched        <= 1'b0;
            latched_awaddr   <= {ADDR_WIDTH{1'b0}};
            latched_wdata    <= {DATA_WIDTH{1'b0}};
            latched_wstrb    <= {STRB_WIDTH{1'b0}};
            reg_read_addr    <= 32'h00000000;
            reg_read_len     <= 32'h00000000;
            reg_write_addr   <= 32'h00000000;
            reg_write_len    <= 32'h00000000;
            read_desc_addr   <= {ADDR_WIDTH{1'b0}};
            read_desc_len    <= {LEN_WIDTH{1'b0}};
            read_desc_valid  <= 1'b0;
            write_desc_addr  <= {ADDR_WIDTH{1'b0}};
            write_desc_len   <= {LEN_WIDTH{1'b0}};
            write_desc_valid <= 1'b0;
            irq_clear        <= 2'b00;
            jpeg_soft_reset  <= 1'b0;
        end else begin
            irq_clear <= 2'b00;
            jpeg_soft_reset <= 1'b0;

            if (read_desc_valid && read_desc_ready)
                read_desc_valid <= 1'b0;
            if (write_desc_valid && write_desc_ready)
                write_desc_valid <= 1'b0;

            if (s_axi_awvalid && s_axi_awready) begin
                aw_latched     <= 1'b1;
                latched_awaddr <= s_axi_awaddr;
                s_axi_bid      <= s_axi_awid;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                w_latched    <= 1'b1;
                latched_wdata <= s_axi_wdata;
                latched_wstrb <= s_axi_wstrb;
            end

            if ((aw_latched || (s_axi_awvalid && s_axi_awready)) &&
                (w_latched  || (s_axi_wvalid  && s_axi_wready)) && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;

                case (aw_latched ? latched_awaddr[5:0] : s_axi_awaddr[5:0])
                    REG_READ_ADDR:
                        reg_read_addr <= (reg_read_addr & ~selected_wmask) | (selected_wdata & selected_wmask);
                    REG_READ_LEN:
                        reg_read_len <= (reg_read_len & ~selected_wmask) | (selected_wdata & selected_wmask);
                    REG_READ_GO: begin
                        if (selected_wdata[0] && selected_wstrb[0]) begin
                            read_desc_addr  <= reg_read_addr;
                            read_desc_len   <= reg_read_len[LEN_WIDTH-1:0];
                            read_desc_valid <= 1'b1;
                        end
                    end
                    REG_WRITE_ADDR:
                        reg_write_addr <= (reg_write_addr & ~selected_wmask) | (selected_wdata & selected_wmask);
                    REG_WRITE_LEN:
                        reg_write_len <= (reg_write_len & ~selected_wmask) | (selected_wdata & selected_wmask);
                    REG_WRITE_GO: begin
                        if (selected_wdata[0] && selected_wstrb[0]) begin
                            write_desc_addr  <= reg_write_addr;
                            write_desc_len   <= reg_write_len[LEN_WIDTH-1:0];
                            write_desc_valid <= 1'b1;
                        end
                    end
                    REG_IRQ_ACK: begin
                        if (selected_wstrb[0])
                            irq_clear <= selected_wdata[1:0];
                    end
                    REG_JPEG_RESET: begin
                        if (selected_wstrb[0] && selected_wdata[0])
                            jpeg_soft_reset <= 1'b1;
                    end
                    default: begin
                    end
                endcase
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_latched   <= 1'b0;
                w_latched    <= 1'b0;
            end
        end
    end

    // AXI-Lite read path. Status registers are read-only; software acknowledges
    // their sticky bits by writing the corresponding mask to REG_IRQ_ACK.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s_axi_rvalid    <= 1'b0;
            s_axi_rid       <= 1'b0;
            s_axi_rdata_reg <= 32'h00000000;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid    <= 1'b1;
                s_axi_rid       <= s_axi_arid;
                s_axi_rdata_reg <= read_data_mux;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
