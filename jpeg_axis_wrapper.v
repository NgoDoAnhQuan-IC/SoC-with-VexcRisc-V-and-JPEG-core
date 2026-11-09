`timescale 1ns / 1ps
`default_nettype none

module jpeg_axis_wrapper #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8)
)(
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       soft_reset,

    // AXI Stream Slave Interface (RGB Input)
    input  wire [AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0] s_axis_tkeep,
    input  wire                       s_axis_tvalid,
    output wire                       s_axis_tready, 
    input  wire                       s_axis_tlast,

    // AXI Stream Master Interface (JPEG Bitstream Output)
    output wire [AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0] m_axis_tkeep,
    output wire                       m_axis_tvalid,
    input  wire                       m_axis_tready,
    output wire                       m_axis_tlast
);

    wire jpeg_rst = rst | soft_reset;

    // =========================================================================
    // 1. INPUT FIFO (Chống đứt quãng AXI Burst)
    // =========================================================================
    (* ram_style = "block" *) reg [23:0] in_fifo_mem [0:127];
    reg [6:0]  in_fifo_wr_ptr;
    reg [6:0]  in_fifo_rd_ptr;
    reg [7:0]  in_fifo_count;

    wire in_fifo_full  = (in_fifo_count == 128);
    wire in_fifo_empty = (in_fifo_count == 0);
    
    wire in_fifo_wr_en = s_axis_tvalid && s_axis_tready;
    reg  in_fifo_rd_en;

    assign s_axis_tready = !in_fifo_full;

    always @(posedge clk or posedge jpeg_rst) begin
        if (jpeg_rst) begin
            in_fifo_wr_ptr <= 7'd0;
            in_fifo_rd_ptr <= 7'd0;
            in_fifo_count  <= 8'd0;
        end else begin
            case ({in_fifo_wr_en, in_fifo_rd_en})
                2'b10: begin 
                    in_fifo_wr_ptr <= in_fifo_wr_ptr + 1'b1;
                    in_fifo_count  <= in_fifo_count + 1'b1;
                end
                2'b01: begin 
                    in_fifo_rd_ptr <= in_fifo_rd_ptr + 1'b1;
                    in_fifo_count  <= in_fifo_count - 1'b1;
                end
                2'b11: begin 
                    in_fifo_wr_ptr <= in_fifo_wr_ptr + 1'b1;
                    in_fifo_rd_ptr <= in_fifo_rd_ptr + 1'b1;
                end
                default: ; 
            endcase
        end
    end

    // Keep the RAM write port separate from the pointer/count registers so
    // Vivado can infer a block RAM for this FIFO.
    always @(posedge clk) begin
        if (!jpeg_rst && in_fifo_wr_en) begin
            in_fifo_mem[in_fifo_wr_ptr] <= s_axis_tdata[23:0];
        end
    end

    // =========================================================================
    // 2. FSM ĐIỀU KHIỂN JPEG CORE TỪ INPUT FIFO (ĐÃ FIX LỖI LEAKAGE)
    // =========================================================================
    reg         jpeg_eof_signal;
    reg         jpeg_enable;
    
    wire [31:0] jpeg_bitstream;
    wire        jpeg_data_ready;
    wire [4:0]  jpeg_eof_bit_count;
    wire        jpeg_eof_partial_ready;

    reg [1:0]  state_reg, state_next;
    reg [5:0]  pixel_cnt;       
    reg [5:0]  wait_cnt;        
    reg [13:0] total_pixel_cnt; 

    wire in_fifo_prefetch_start = (state_reg == 2'd0) && (in_fifo_count >= 8'd64);
    wire in_fifo_prefetch_next  = (state_reg == 2'd1) && (pixel_cnt != 6'd63);
    wire [6:0] in_fifo_prefetch_addr = in_fifo_prefetch_next ?
                                      (in_fifo_rd_ptr + 7'd1) : in_fifo_rd_ptr;

    // --- BẮT ĐẦU VÙNG CẬP NHẬT ---
    wire [23:0] jpeg_data_in;
    reg  [23:0] hold_pixel;

    // Prefetch one pixel before the JPEG core consumes it. This registers the
    // FIFO read and prevents the FIFO pointer/mux path from reaching the DCT
    // multipliers in the same cycle.
    always @(posedge clk) begin
        if (in_fifo_prefetch_start || in_fifo_prefetch_next) begin
            hold_pixel <= in_fifo_mem[in_fifo_prefetch_addr];
        end
    end

    // The prefetched pixel remains stable through the 33-cycle wait state.
    assign jpeg_data_in = hold_pixel;
    // --- KẾT THÚC VÙNG CẬP NHẬT ---

    localparam STATE_IDLE    = 2'd0,
               STATE_LOAD_64 = 2'd1,
               STATE_WAIT_33 = 2'd2,
               STATE_GAP_1   = 2'd3;

    always @(posedge clk or posedge jpeg_rst) begin
        if (jpeg_rst) begin
            state_reg       <= STATE_IDLE;
            pixel_cnt       <= 6'd0;
            wait_cnt        <= 6'd0;
            total_pixel_cnt <= 14'd0;
        end else begin
            state_reg <= state_next;

            if (state_reg == STATE_LOAD_64) begin
                pixel_cnt       <= pixel_cnt + 1'b1;
                total_pixel_cnt <= total_pixel_cnt + 1'b1;
            end else if (state_reg != STATE_LOAD_64) begin
                pixel_cnt <= 6'd0;
            end

            if (state_reg == STATE_WAIT_33) begin
                wait_cnt <= wait_cnt + 1'b1;
            end else begin
                wait_cnt <= 6'd0;
            end

            if ((state_reg == STATE_IDLE) && (total_pixel_cnt >= 14'd9216)) begin
                total_pixel_cnt <= 14'd0;
            end
        end
    end

    always @* begin
        state_next      = state_reg;
        jpeg_enable     = 1'b0;
        jpeg_eof_signal = 1'b0;
        in_fifo_rd_en   = 1'b0;

        case (state_reg)
            STATE_IDLE: begin
                if (in_fifo_count >= 8'd64) begin
                    state_next = STATE_LOAD_64;
                end
            end

            STATE_LOAD_64: begin
                jpeg_enable   = 1'b1;
                in_fifo_rd_en = 1'b1; 
                
                if ((total_pixel_cnt >= 14'd9152) && (pixel_cnt == 6'd0)) begin
                    jpeg_eof_signal = 1'b1;
                end

                if (pixel_cnt == 6'd63) begin
                    state_next = STATE_WAIT_33;
                end
            end

            STATE_WAIT_33: begin
                jpeg_enable   = 1'b1;
                in_fifo_rd_en = 1'b0; 

                if (wait_cnt == 6'd32) begin
                    state_next = STATE_GAP_1;
                end
            end

            STATE_GAP_1: begin
                jpeg_enable   = 1'b0;
                in_fifo_rd_en = 1'b0;
                state_next = STATE_IDLE; 
            end

            default: state_next = STATE_IDLE;
        endcase
    end

    // =========================================================================
    // 3. INSTANCE CORE JPEG_TOP
    // =========================================================================
    jpeg_top u_jpeg_core (
        .clk                         (clk),
        .rst                         (jpeg_rst),
        .end_of_file_signal          (jpeg_eof_signal),
        .enable                      (jpeg_enable),
        .data_in                     (jpeg_data_in),
        .JPEG_bitstream              (jpeg_bitstream),
        .data_ready                  (jpeg_data_ready),
        .end_of_file_bitstream_count (jpeg_eof_bit_count),
        .eof_data_partial_ready      (jpeg_eof_partial_ready)
    );

    // =========================================================================
    // 4. OUTPUT FIFO (Buffer backpressure cho DMA Write)
    // =========================================================================
    wire        fifo_wr_en;
    wire [32:0] fifo_din;
    wire        fifo_rd_en;
    wire [32:0] fifo_dout;
    wire        fifo_empty;
    wire        fifo_full;

    assign fifo_wr_en = jpeg_data_ready || jpeg_eof_partial_ready;
    assign fifo_din   = {jpeg_eof_partial_ready, jpeg_bitstream};

    reg [32:0] mem [0:127];
    reg [6:0]  wr_ptr;
    reg [6:0]  rd_ptr;
    reg [7:0]  fifo_count;

    always @(posedge clk or posedge jpeg_rst) begin
        if (jpeg_rst) begin
            wr_ptr     <= 7'd0;
            rd_ptr     <= 7'd0;
            fifo_count <= 8'd0;
        end else begin
            case ({fifo_wr_en && !fifo_full, fifo_rd_en && !fifo_empty})
                2'b10: begin 
                    mem[wr_ptr] <= fifo_din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    fifo_count  <= fifo_count + 1'b1;
                end
                2'b01: begin 
                    rd_ptr      <= rd_ptr + 1'b1;
                    fifo_count  <= fifo_count - 1'b1;
                end
                2'b11: begin 
                    mem[wr_ptr] <= fifo_din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                end
                default: ;   
            endcase
        end
    end

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count == 128);
    assign fifo_dout  = mem[rd_ptr];

    assign fifo_rd_en    = m_axis_tvalid && m_axis_tready;
    assign m_axis_tvalid = !fifo_empty;
    assign m_axis_tdata  = fifo_dout[31:0];
    assign m_axis_tlast  = fifo_dout[32];
    assign m_axis_tkeep  = {AXIS_KEEP_WIDTH{1'b1}};

endmodule
`resetall
