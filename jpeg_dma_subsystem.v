`timescale 1ns / 1ps
`default_nettype none

module jpeg_dma_subsystem #(
    parameter AXI_DATA_WIDTH    = 32,
    parameter AXI_ADDR_WIDTH    = 16,
    parameter AXI_STRB_WIDTH    = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH      = 8,
    parameter AXI_MAX_BURST_LEN = 16,
    parameter AXIS_DATA_WIDTH   = AXI_DATA_WIDTH,
    parameter AXIS_KEEP_WIDTH   = (AXIS_DATA_WIDTH/8),
    parameter LEN_WIDTH         = 20,
    parameter TAG_WIDTH         = 8
)(
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       jpeg_soft_reset,

    // =========================================================
    // AXI Read Descriptor Input (Điều khiển DMA đọc RAM)
    // =========================================================
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_read_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_read_desc_tag,
    input  wire [7:0]                 s_axis_read_desc_id,
    input  wire [7:0]                 s_axis_read_desc_dest,
    input  wire [0:0]                 s_axis_read_desc_user,
    input  wire                       s_axis_read_desc_valid,
    output wire                       s_axis_read_desc_ready,

    // AXI Read Descriptor Status Output
    output wire [TAG_WIDTH-1:0]       m_axis_read_desc_status_tag,
    output wire [3:0]                 m_axis_read_desc_status_error,
    output wire                       m_axis_read_desc_status_valid,

    // =========================================================
    // AXI Write Descriptor Input (Điều khiển DMA ghi RAM)
    // =========================================================
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_write_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_write_desc_tag,
    input  wire                       s_axis_write_desc_valid,
    output wire                       s_axis_write_desc_ready,

    // AXI Write Descriptor Status Output
    output wire [LEN_WIDTH-1:0]       m_axis_write_desc_status_len,
    output wire [TAG_WIDTH-1:0]       m_axis_write_desc_status_tag,
    output wire [7:0]                 m_axis_write_desc_status_id,
    output wire [7:0]                 m_axis_write_desc_status_dest,
    output wire [0:0]                 m_axis_write_desc_status_user,
    output wire [3:0]                 m_axis_write_desc_status_error,
    output wire                       m_axis_write_desc_status_valid,

    // =========================================================
    // AXI Master Interface (Nối trực tiếp vào Bus Memory / RAM)
    // =========================================================
    // Write Address Channel
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    // Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    // Write Response Channel
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    // Read Address Channel
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    // Read Data Channel
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready
);

    // Đường dây nối nội bộ AXI Stream
    wire [AXIS_DATA_WIDTH-1:0] axis_rd2jpeg_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] axis_rd2jpeg_tkeep;
    wire                       axis_rd2jpeg_tvalid;
    wire                       axis_rd2jpeg_tready;
    wire                       axis_rd2jpeg_tlast;
    wire [7:0]                 axis_rd2jpeg_tid;
    wire [7:0]                 axis_rd2jpeg_tdest;
    wire [0:0]                 axis_rd2jpeg_tuser;

    wire [AXIS_DATA_WIDTH-1:0] axis_jpeg2wr_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] axis_jpeg2wr_tkeep;
    wire                       axis_jpeg2wr_tvalid;
    wire                       axis_jpeg2wr_tready;
    wire                       axis_jpeg2wr_tlast;

    // Instance AXI DMA Core
    axi_dma #(
        .AXI_DATA_WIDTH    (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH),
        .AXI_STRB_WIDTH    (AXI_STRB_WIDTH),
        .AXI_ID_WIDTH      (AXI_ID_WIDTH),
        .AXI_MAX_BURST_LEN (AXI_MAX_BURST_LEN),
        .AXIS_DATA_WIDTH   (AXIS_DATA_WIDTH),
        .AXIS_KEEP_ENABLE  (1),
        .AXIS_KEEP_WIDTH   (AXIS_KEEP_WIDTH),
        .AXIS_LAST_ENABLE  (1),
        .AXIS_ID_ENABLE    (0),
        .AXIS_DEST_ENABLE  (0),
        .AXIS_USER_ENABLE  (0),
        .LEN_WIDTH         (LEN_WIDTH),
        .TAG_WIDTH         (TAG_WIDTH),
        .ENABLE_SG         (0),
        .ENABLE_UNALIGNED  (0)
    ) u_axi_dma (
        .clk(clk),
        .rst(rst),

        // Read Descriptor
        .s_axis_read_desc_addr        (s_axis_read_desc_addr),
        .s_axis_read_desc_len         (s_axis_read_desc_len),
        .s_axis_read_desc_tag         (s_axis_read_desc_tag),
        .s_axis_read_desc_id          (s_axis_read_desc_id),
        .s_axis_read_desc_dest        (s_axis_read_desc_dest),
        .s_axis_read_desc_user        (s_axis_read_desc_user),
        .s_axis_read_desc_valid       (s_axis_read_desc_valid),
        .s_axis_read_desc_ready       (s_axis_read_desc_ready),

        // Read Status
        .m_axis_read_desc_status_tag  (m_axis_read_desc_status_tag),
        .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
        .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),

        // AXI Stream Output (Đọc RAM -> Wrapper)
        .m_axis_read_data_tdata       (axis_rd2jpeg_tdata),
        .m_axis_read_data_tkeep       (axis_rd2jpeg_tkeep),
        .m_axis_read_data_tvalid      (axis_rd2jpeg_tvalid),
        .m_axis_read_data_tready      (axis_rd2jpeg_tready),
        .m_axis_read_data_tlast       (axis_rd2jpeg_tlast),
        .m_axis_read_data_tid         (axis_rd2jpeg_tid),
        .m_axis_read_data_tdest       (axis_rd2jpeg_tdest),
        .m_axis_read_data_tuser       (axis_rd2jpeg_tuser),

        // Write Descriptor
        .s_axis_write_desc_addr       (s_axis_write_desc_addr),
        .s_axis_write_desc_len        (s_axis_write_desc_len),
        .s_axis_write_desc_tag        (s_axis_write_desc_tag),
        .s_axis_write_desc_valid      (s_axis_write_desc_valid),
        .s_axis_write_desc_ready      (s_axis_write_desc_ready),

        // Write Status
        .m_axis_write_desc_status_len (m_axis_write_desc_status_len),
        .m_axis_write_desc_status_tag (m_axis_write_desc_status_tag),
        .m_axis_write_desc_status_id  (m_axis_write_desc_status_id),
        .m_axis_write_desc_status_dest(m_axis_write_desc_status_dest),
        .m_axis_write_desc_status_user(m_axis_write_desc_status_user),
        .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
        .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),

        // AXI Stream Input (Wrapper -> Ghi RAM)
        .s_axis_write_data_tdata      (axis_jpeg2wr_tdata),
        .s_axis_write_data_tkeep      (axis_jpeg2wr_tkeep),
        .s_axis_write_data_tvalid     (axis_jpeg2wr_tvalid),
        .s_axis_write_data_tready     (axis_jpeg2wr_tready),
        .s_axis_write_data_tlast      (axis_jpeg2wr_tlast),
        .s_axis_write_data_tid        (8'd0),
        .s_axis_write_data_tdest      (8'd0),
        .s_axis_write_data_tuser      (1'b0),

        // Master AXI Interface
        .m_axi_awid                   (m_axi_awid),
        .m_axi_awaddr                 (m_axi_awaddr),
        .m_axi_awlen                  (m_axi_awlen),
        .m_axi_awsize                 (m_axi_awsize),
        .m_axi_awburst                (m_axi_awburst),
        .m_axi_awlock                 (m_axi_awlock),
        .m_axi_awcache                (m_axi_awcache),
        .m_axi_awprot                 (m_axi_awprot),
        .m_axi_awvalid                (m_axi_awvalid),
        .m_axi_awready                (m_axi_awready),
        .m_axi_wdata                  (m_axi_wdata),
        .m_axi_wstrb                  (m_axi_wstrb),
        .m_axi_wlast                  (m_axi_wlast),
        .m_axi_wvalid                 (m_axi_wvalid),
        .m_axi_wready                 (m_axi_wready),
        .m_axi_bid                    (m_axi_bid),
        .m_axi_bresp                  (m_axi_bresp),
        .m_axi_bvalid                 (m_axi_bvalid),
        .m_axi_bready                 (m_axi_bready),
        .m_axi_arid                   (m_axi_arid),
        .m_axi_araddr                 (m_axi_araddr),
        .m_axi_arlen                  (m_axi_arlen),
        .m_axi_arsize                 (m_axi_arsize),
        .m_axi_arburst                (m_axi_arburst),
        .m_axi_arlock                 (m_axi_arlock),
        .m_axi_arcache                (m_axi_arcache),
        .m_axi_arprot                 (m_axi_arprot),
        .m_axi_arvalid                (m_axi_arvalid),
        .m_axi_arready                (m_axi_arready),
        .m_axi_rid                    (m_axi_rid),
        .m_axi_rdata                  (m_axi_rdata),
        .m_axi_rresp                  (m_axi_rresp),
        .m_axi_rlast                  (m_axi_rlast),
        .m_axi_rvalid                 (m_axi_rvalid),
        .m_axi_rready                 (m_axi_rready),

        .read_enable                  (1'b1),
        .write_enable                 (1'b1),
        .write_abort                  (1'b0)
    );

    // Instance JPEG Wrapper
    jpeg_axis_wrapper #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)
    ) u_jpeg_wrapper (
        .clk          (clk),
        .rst          (rst),
        .soft_reset   (jpeg_soft_reset),

        .s_axis_tdata (axis_rd2jpeg_tdata),
        .s_axis_tkeep (axis_rd2jpeg_tkeep),
        .s_axis_tvalid(axis_rd2jpeg_tvalid),
        .s_axis_tready(axis_rd2jpeg_tready),
        .s_axis_tlast (axis_rd2jpeg_tlast),

        .m_axis_tdata (axis_jpeg2wr_tdata),
        .m_axis_tkeep (axis_jpeg2wr_tkeep),
        .m_axis_tvalid(axis_jpeg2wr_tvalid),
        .m_axis_tready(axis_jpeg2wr_tready),
        .m_axis_tlast (axis_jpeg2wr_tlast)
    );

endmodule
`resetall
