`timescale 1ns / 1ps

module axi4_full_ram_slave #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter ID_WIDTH       = 1,
    parameter RAM_DEPTH_BITS = 10,         // 1024 words = 4KB RAM
    parameter BASE_ADDR      = 32'h8000_0000,
    parameter INIT_FILE      = ""
)(
    input wire clk,
    input wire reset,

    // --- AXI4 Write Address Channel (AW) ---
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [ID_WIDTH-1:0]   s_axi_awid,
    input  wire [7:0]            s_axi_awlen,
    input  wire [2:0]            s_axi_awsize,
    input  wire [1:0]            s_axi_awburst,

    // --- AXI4 Write Data Channel (W) ---
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                  s_axi_wlast,

    // --- AXI4 Write Response Channel (B) ---
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,
    output reg  [ID_WIDTH-1:0]   s_axi_bid,
    output reg  [1:0]            s_axi_bresp,

    // --- AXI4 Read Address Channel (AR) ---
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [ID_WIDTH-1:0]   s_axi_arid,
    input  wire [7:0]            s_axi_arlen,
    input  wire [2:0]            s_axi_arsize,
    input  wire [1:0]            s_axi_arburst,

    // --- AXI4 Read Data Channel (R) ---
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,
    output wire  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [ID_WIDTH-1:0]   s_axi_rid,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rlast
);

    // ==========================================
    // KHAI BÁO BIẾN DÙNG CHO CHANNEL WRITE (GHI)
    // ==========================================
    reg [ADDR_WIDTH-1:0] w_addr;
    reg [7:0]            w_len;
    reg [2:0]            w_size;
    reg [1:0]            w_burst;
    reg                  w_active;

    // ==========================================
    // KHAI BÁO BIẾN DÙNG CHO CHANNEL READ (ĐỌC)
    // ==========================================
    reg [ADDR_WIDTH-1:0] r_addr;
    reg [7:0]            r_len;
    reg [2:0]            r_size;
    reg [1:0]            r_burst;
    reg [7:0]            r_cnt;
    reg                  r_active;

    // ==========================================
    // TÍN HIỆU KẾT NỐI VỚI RAM NỘI BỘ
    // ==========================================
    wire                      ram_we;
    wire [DATA_WIDTH-1:0]     ram_dout;

    // Khoảng cách dịch địa chỉ theo byte-offset (32-bit width -> shift 2 bit)
    wire [RAM_DEPTH_BITS-1:0] w_ram_index = (w_addr - BASE_ADDR) >> 2;
    wire [RAM_DEPTH_BITS-1:0] r_ram_index = (r_addr - BASE_ADDR) >> 2;

    // RAM có cổng đọc và ghi độc lập để DMA đọc pixel và ghi bitstream đồng thời.
    // Chỉ phát write-enable khi beat W thực sự được handshake sau khi đã nhận AW.
    assign ram_we = w_active && s_axi_wvalid && s_axi_wready;

    // Instantiation RAM dual-port: đọc từ r_ram_index, ghi vào w_ram_index.
    ram_dp_byte_en #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(RAM_DEPTH_BITS),
        .INIT_FILE(INIT_FILE)
    ) ram_inst (
        .clk(clk),
        .we(ram_we),
        .wr_addr(w_ram_index),
        .rd_addr(r_ram_index),
        .din(s_axi_wdata),
        .strb(s_axi_wstrb),
        .dout(ram_dout)
    );

    // Hàm hỗ trợ tính địa chỉ tiếp theo theo AXI Burst Type (INCR, FIXED, WRAP)
    function [ADDR_WIDTH-1:0] get_next_addr(
        input [ADDR_WIDTH-1:0] current_addr,
        input [2:0]            size,
        input [1:0]            burst,
        input [7:0]            len
    );
        reg [ADDR_WIDTH-1:0] number_bytes;
        reg [ADDR_WIDTH-1:0] wrap_mask;
        reg [4:0]            wrap_log2_beats;
        reg                  wrap_len_valid;
        begin
            number_bytes = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size;

            // AXI4 WRAP bursts are 2, 4, 8, or 16 beats. Decode len+1
            // directly so this address path does not infer a variable divider
            // and multiplier for the wrap boundary.
            wrap_len_valid = 1'b1;
            case (len)
                8'd1:    wrap_log2_beats = 5'd1;
                8'd3:    wrap_log2_beats = 5'd2;
                8'd7:    wrap_log2_beats = 5'd3;
                8'd15:   wrap_log2_beats = 5'd4;
                default: begin
                    wrap_log2_beats = 5'd0;
                    wrap_len_valid  = 1'b0;
                end
            endcase

            wrap_mask = {ADDR_WIDTH{1'b0}};
            case (burst)
                2'b00: get_next_addr = current_addr; // FIXED burst
                2'b01: get_next_addr = current_addr + number_bytes; // INCR burst
                2'b10: begin // WRAP burst
                    if (wrap_len_valid) begin
                        wrap_mask = ({{(ADDR_WIDTH-1){1'b0}}, 1'b1} << (size + wrap_log2_beats)) - 1'b1;
                        // Preserve the upper address bits and wrap the low
                        // burst-address bits modulo the legal power-of-two size.
                        get_next_addr = (current_addr & ~wrap_mask) |
                                        ((current_addr + number_bytes) & wrap_mask);
                    end else begin
                        // Invalid AXI WRAP lengths are treated as INCR.
                        get_next_addr = current_addr + number_bytes;
                    end
                end
                default: get_next_addr = current_addr + number_bytes;
            endcase
        end
    endfunction

    // ==========================================
    // LOGIC CHANNEL GHI (WRITE LOGIC) - ĐÃ CẬP NHẬT
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s_axi_awready <= 1'b1;
            // Chờ nhận AW trước; tránh handshake/rơi beat W trước khi có địa chỉ.
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00; // OKAY
            s_axi_bid     <= {ID_WIDTH{1'b0}};
            w_active      <= 1'b0;
            w_addr        <= {ADDR_WIDTH{1'b0}};
            w_len         <= 8'b0;
            w_size        <= 3'b0;
            w_burst       <= 2'b0;
        end else begin
            
            // 1. Nhận địa chỉ ghi (AW Handshake)
            if (s_axi_awvalid && s_axi_awready) begin
                w_addr        <= s_axi_awaddr;
                w_len         <= s_axi_awlen;
                w_size        <= s_axi_awsize;
                w_burst       <= s_axi_awburst;
                s_axi_bid     <= s_axi_awid;
                w_active      <= 1'b1;
                s_axi_awready <= 1'b0; // Bận xử lý burst hiện tại
                s_axi_wready  <= 1'b1; // Mở kênh W sau khi đã chốt địa chỉ burst
            end

            // 2. Nhận dữ liệu ghi (W Handshake)
            if (s_axi_wvalid && s_axi_wready) begin
                if (s_axi_wlast) begin
                    w_active     <= 1'b0;
                    s_axi_bvalid <= 1'b1; // Bật cờ hoàn tất BVALID
                    s_axi_wready <= 1'b0; // Ngừng nhận W DATA cho đến khi hoàn tất Write Response
                end else begin
                    w_addr <= get_next_addr(w_addr, w_size, w_burst, w_len);
                end
            end

            // 3. Phản hồi ghi (B Handshake)
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1; // Mở lại AWREADY nhận giao dịch mới
                s_axi_wready  <= 1'b0; // Chỉ mở WREADY sau AW handshake kế tiếp
            end
        end
    end

    // ==========================================
    // LOGIC CHANNEL ĐỌC (READ LOGIC)
    // ==========================================
    reg read_stage; // Pipeline stage để khớp latency đọc của Block RAM

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rlast   <= 1'b0;
            s_axi_rresp   <= 2'b00; // OKAY
            s_axi_rid     <= {ID_WIDTH{1'b0}};
            r_active      <= 1'b0;
            r_cnt         <= 8'b0;
            read_stage    <= 1'b0;
            r_addr        <= {ADDR_WIDTH{1'b0}};
            r_len         <= 8'b0;
            r_size        <= 3'b0;
            r_burst       <= 2'b0;
            // s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        end else begin
            // 1. Nhận địa chỉ đọc (AR Handshake)
            if (s_axi_arvalid && s_axi_arready) begin
                r_addr        <= s_axi_araddr;
                r_len         <= s_axi_arlen;
                r_size        <= s_axi_arsize;
                r_burst       <= s_axi_arburst;
                s_axi_rid     <= s_axi_arid;
                s_axi_arready <= 1'b0; // Bận xử lý đọc burst
                r_cnt         <= 8'b0;
                r_active      <= 1'b1;
                read_stage    <= 1'b1; // Kích hoạt chu kỳ đọc đầu tiên từ RAM
            end

            // 2. Chờ 1 chu kỳ clock để dữ liệu từ RAM sẵn sàng đưa ra Bus (R Channel)
            if (read_stage) begin
                read_stage   <= 1'b0;
                s_axi_rvalid <= 1'b1;
                s_axi_rlast  <= (r_cnt == r_len);
            end

            // 3. Đưa dữ liệu lên kênh R (R Handshake)
            if (s_axi_rvalid && s_axi_rready) begin
                if (s_axi_rlast) begin
                    s_axi_rvalid  <= 1'b0;
                    s_axi_rlast   <= 1'b0;
                    s_axi_arready <= 1'b1; // Giải phóng Adapter nhận lệnh đọc mới
                    r_active      <= 1'b0;
                end else begin
                    r_cnt        <= r_cnt + 1'b1;
                    r_addr       <= get_next_addr(r_addr, r_size, r_burst, r_len);
                    read_stage   <= 1'b1; // Yêu cầu đọc beat tiếp theo từ RAM
                    s_axi_rvalid <= 1'b0;
                end
            end

            // Cập nhật RDATA từ đầu ra của BRAM khi RVALID sẵn sàng
            // if (read_stage || (s_axi_rvalid && !s_axi_rready)) begin
            //     s_axi_rdata <= ram_dout;
            // end
        end
    end
    assign s_axi_rdata = ram_dout; // Cập nhật RDATA từ đầu ra của BRAM khi RVALID sẵn sàng

endmodule


