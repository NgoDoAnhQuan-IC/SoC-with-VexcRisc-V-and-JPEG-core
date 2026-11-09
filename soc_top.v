`timescale 1ns / 1ps

module soc_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input wire clk,
    input wire reset,

    // ==========================================
    // CÁC CHÂN OUTPUT ĐỂ QUAN SÁT WAVEFORM TỪ ADAPTER
    // ==========================================
    output wire [31:0] test_read_desc_addr,
    output wire [19:0] test_read_desc_len,
    output wire        test_read_desc_valid,
    output wire        test_read_desc_ready, // Dùng quan sát hoặc ép chờ từ TB

    output wire [31:0] test_write_desc_addr,
    output wire [19:0] test_write_desc_len,
    output wire        test_write_desc_valid,
    output wire        test_write_desc_ready, // Dùng quan sát hoặc ép chờ từ TB

    // IRQ/status observability for tb_soc_top and ModelSim
    output wire        test_dma_irq,
    output wire [1:0]  test_dma_irq_pending,
    output wire        test_read_status_valid,
    output wire [3:0]  test_read_status_error,
    output wire        test_write_status_valid,
    output wire [19:0] test_write_status_len,
    output wire [3:0]  test_write_status_error,
    output wire [1:0]  test_dma_irq_clear,
    output wire        test_cpu_interrupt_taken
);

    // ==========================================
    // KHAI BÁO CÁC ĐƯỜNG TÍN HIỆU BUS AXI
    // ==========================================
    wire        iBusAxi_ar_valid, iBusAxi_ar_ready;
    wire [31:0] iBusAxi_ar_payload_addr;
    wire [0:0]  iBusAxi_ar_payload_id;
    wire [3:0]  iBusAxi_ar_payload_region;
    wire [7:0]  iBusAxi_ar_payload_len;
    wire [2:0]  iBusAxi_ar_payload_size;
    wire [1:0]  iBusAxi_ar_payload_burst;
    wire [0:0]  iBusAxi_ar_payload_lock;
    wire [3:0]  iBusAxi_ar_payload_cache;
    wire [3:0]  iBusAxi_ar_payload_qos;
    wire [2:0]  iBusAxi_ar_payload_prot;

    wire        iBusAxi_r_valid, iBusAxi_r_ready;
    wire [31:0] iBusAxi_r_payload_data;
    wire [0:0]  iBusAxi_r_payload_id;
    wire [1:0]  iBusAxi_r_payload_resp;
    wire        iBusAxi_r_payload_last;

    wire        dBusAxi_aw_valid, dBusAxi_aw_ready;
    wire [31:0] dBusAxi_aw_payload_addr;
    wire [0:0]  dBusAxi_aw_payload_id;
    wire [3:0]  dBusAxi_aw_payload_region;
    wire [7:0]  dBusAxi_aw_payload_len;
    wire [2:0]  dBusAxi_aw_payload_size;
    wire [1:0]  dBusAxi_aw_payload_burst;
    wire [0:0]  dBusAxi_aw_payload_lock;
    wire [3:0]  dBusAxi_aw_payload_cache;
    wire [3:0]  dBusAxi_aw_payload_qos;
    wire [2:0]  dBusAxi_aw_payload_prot;

    wire        dBusAxi_w_valid, dBusAxi_w_ready;
    wire [31:0] dBusAxi_w_payload_data;
    wire [3:0]  dBusAxi_w_payload_strb;
    wire        dBusAxi_w_payload_last;

    wire        dBusAxi_b_valid, dBusAxi_b_ready;
    wire [0:0]  dBusAxi_b_payload_id;
    wire [1:0]  dBusAxi_b_payload_resp;

    wire        dBusAxi_ar_valid, dBusAxi_ar_ready;
    wire [31:0] dBusAxi_ar_payload_addr;
    wire [0:0]  dBusAxi_ar_payload_id;
    wire [3:0]  dBusAxi_ar_payload_region;
    wire [7:0]  dBusAxi_ar_payload_len;
    wire [2:0]  dBusAxi_ar_payload_size;
    wire [1:0]  dBusAxi_ar_payload_burst;
    wire [0:0]  dBusAxi_ar_payload_lock;
    wire [3:0]  dBusAxi_ar_payload_cache;
    wire [3:0]  dBusAxi_ar_payload_qos;
    wire [2:0]  dBusAxi_ar_payload_prot;

    wire        dBusAxi_r_valid, dBusAxi_r_ready;
    wire [31:0] dBusAxi_r_payload_data;
    wire [0:0]  dBusAxi_r_payload_id;
    wire [1:0]  dBusAxi_r_payload_resp;
    wire        dBusAxi_r_payload_last;

    wire        ic_s0_awvalid, ic_s0_awready;
    wire [31:0] ic_s0_awaddr;
    wire [8:0]  ic_s0_awid;
    wire [7:0]  ic_s0_awlen;
    wire [2:0]  ic_s0_awsize;
    wire [1:0]  ic_s0_awburst;

    wire        ic_s0_wvalid, ic_s0_wready;
    wire [31:0] ic_s0_wdata;
    wire [3:0]  ic_s0_wstrb;
    wire        ic_s0_wlast;

    wire        ic_s0_bvalid, ic_s0_bready;
    wire [8:0]  ic_s0_bid;
    wire [1:0]  ic_s0_bresp;

    wire        ic_s0_arvalid, ic_s0_arready;
    wire [31:0] ic_s0_araddr;
    wire [8:0]  ic_s0_arid;
    wire [7:0]  ic_s0_arlen;
    wire [2:0]  ic_s0_arsize;
    wire [1:0]  ic_s0_arburst;

    wire        ic_s0_rvalid, ic_s0_rready;
    wire [31:0] ic_s0_rdata;
    wire [8:0]  ic_s0_rid;
    wire [1:0]  ic_s0_rresp;
    wire        ic_s0_rlast;

    wire        ic_s1_awvalid, ic_s1_awready;
    wire [31:0] ic_s1_awaddr;
    wire [8:0]  ic_s1_awid;
    wire [7:0]  ic_s1_awlen;
    wire [2:0]  ic_s1_awsize;
    wire [1:0]  ic_s1_awburst;

    wire        ic_s1_wvalid, ic_s1_wready;
    wire [31:0] ic_s1_wdata;
    wire [3:0]  ic_s1_wstrb;
    wire        ic_s1_wlast;

    wire        ic_s1_bvalid, ic_s1_bready;
    wire [8:0]  ic_s1_bid;
    wire [1:0]  ic_s1_bresp;

    wire        ic_s1_arvalid, ic_s1_arready;
    wire [31:0] ic_s1_araddr;
    wire [8:0]  ic_s1_arid;
    wire [7:0]  ic_s1_arlen;
    wire [2:0]  ic_s1_arsize;
    wire [1:0]  ic_s1_arburst;

    wire        ic_s1_rvalid, ic_s1_rready;
    wire [31:0] ic_s1_rdata;
    wire [8:0]  ic_s1_rid;
    wire [1:0]  ic_s1_rresp;
    wire        ic_s1_rlast;

    // =========================================================================
    // TÍN HIỆU KẾT NỐI AXI MASTER CỦA DMA SUBSYSTEM (BỎ HOÀN TOÀN GÁN CỨNG 1'b0)
    // =========================================================================
    wire [7:0]  dma_m_axi_awid;
    wire [31:0] dma_m_axi_awaddr;
    wire [7:0]  dma_m_axi_awlen;
    wire [2:0]  dma_m_axi_awsize;
    wire [1:0]  dma_m_axi_awburst;
    wire        dma_m_axi_awlock;
    wire [3:0]  dma_m_axi_awcache;
    wire [2:0]  dma_m_axi_awprot;
    wire        dma_m_axi_awvalid;
    wire        dma_m_axi_awready;

    wire [31:0] dma_m_axi_wdata;
    wire [3:0]  dma_m_axi_wstrb;
    wire        dma_m_axi_wlast;
    wire        dma_m_axi_wvalid;
    wire        dma_m_axi_wready;

    wire [7:0]  dma_m_axi_bid;
    wire [1:0]  dma_m_axi_bresp;
    wire        dma_m_axi_bvalid;
    wire        dma_m_axi_bready;

    wire [7:0]  dma_m_axi_arid;
    wire [31:0] dma_m_axi_araddr;
    wire [7:0]  dma_m_axi_arlen;
    wire [2:0]  dma_m_axi_arsize;
    wire [1:0]  dma_m_axi_arburst;
    wire        dma_m_axi_arlock;
    wire [3:0]  dma_m_axi_arcache;
    wire [2:0]  dma_m_axi_arprot;
    wire        dma_m_axi_arvalid;
    wire        dma_m_axi_arready;

    wire [7:0]  dma_m_axi_rid;
    wire [31:0] dma_m_axi_rdata;
    wire [1:0]  dma_m_axi_rresp;
    wire        dma_m_axi_rlast;
    wire        dma_m_axi_rvalid;
    wire        dma_m_axi_rready;

    // ==========================================
    // DÂY NỐI GIỮA ADAPTER VÀ DMA SUBSYSTEM
    // ==========================================
    wire [31:0] ad2sub_read_desc_addr;
    wire [19:0] ad2sub_read_desc_len;
    wire [7:0]  ad2sub_read_desc_tag;
    wire [7:0]  ad2sub_read_desc_id;
    wire [7:0]  ad2sub_read_desc_dest;
    wire [0:0]  ad2sub_read_desc_user;
    wire        ad2sub_read_desc_valid;
    wire        sub2ad_read_desc_ready; // Dây Ready từ Subsystem gửi về Adapter

    wire [31:0] ad2sub_write_desc_addr;
    wire [19:0] ad2sub_write_desc_len;
    wire [7:0]  ad2sub_write_desc_tag;
    wire        ad2sub_write_desc_valid;
    wire        sub2ad_write_desc_ready; // Dây Ready từ Subsystem gửi về Adapter

    wire        dma_read_status_valid;
    wire [3:0]  dma_read_status_error;
    wire        dma_write_status_valid;
    wire [3:0]  dma_write_status_error;
    wire [1:0]  dma_irq_pending;
    wire [3:0]  dma_read_irq_error;
    wire [3:0]  dma_write_irq_error;
    wire [1:0]  dma_irq_clear;
    wire        dma_irq;
    wire        jpeg_soft_reset;
    wire [19:0] dma_write_status_len;

    // Xuất ra cổng Testbench để soi Waveform
    assign test_read_desc_addr   = ad2sub_read_desc_addr;
    assign test_read_desc_len    = ad2sub_read_desc_len;
    assign test_read_desc_valid  = ad2sub_read_desc_valid;
    assign test_read_desc_ready   = sub2ad_read_desc_ready;

    assign test_write_desc_addr  = ad2sub_write_desc_addr;
    assign test_write_desc_len   = ad2sub_write_desc_len;
    assign test_write_desc_valid = ad2sub_write_desc_valid;
    assign test_write_desc_ready  = sub2ad_write_desc_ready;

    assign test_dma_irq             = dma_irq;
    assign test_dma_irq_pending     = dma_irq_pending;
    assign test_read_status_valid   = dma_read_status_valid;
    assign test_read_status_error   = dma_read_status_error;
    assign test_write_status_valid  = dma_write_status_valid;
    assign test_write_status_len    = dma_write_status_len;
    assign test_write_status_error  = dma_write_status_error;
    assign test_dma_irq_clear       = dma_irq_clear;

    dma_irq_controller dma_irq_controller_inst (
        .clk                (clk),
        .rst                (reset),
        .read_status_valid  (dma_read_status_valid),
        .read_status_error  (dma_read_status_error),
        .write_status_valid (dma_write_status_valid),
        .write_status_error (dma_write_status_error),
        .clear_pending      (dma_irq_clear),
        .irq                (dma_irq),
        .pending             (dma_irq_pending),
        .read_error          (dma_read_irq_error),
        .write_error         (dma_write_irq_error)
    );
    

    wire [7:0] cpu_axi_rid;
    wire [7:0] cpu_axi_bid;

    // ==========================================
    // INSTANCE: CPU RISC-V CORE
    // ==========================================
    my_core cpu_inst (
        .clk                     (clk),
        .reset                   (reset),
        .timerInterrupt          (1'b0),
        .externalInterrupt       (dma_irq),
        .cpu_interrupt_taken     (test_cpu_interrupt_taken),
        .iBusAxi_ar_valid        (iBusAxi_ar_valid),
        .iBusAxi_ar_ready        (iBusAxi_ar_ready),
        .iBusAxi_ar_payload_addr (iBusAxi_ar_payload_addr),
        .iBusAxi_ar_payload_id   (iBusAxi_ar_payload_id),
        .iBusAxi_ar_payload_region(iBusAxi_ar_payload_region),
        .iBusAxi_ar_payload_len  (iBusAxi_ar_payload_len),
        .iBusAxi_ar_payload_size (iBusAxi_ar_payload_size),
        .iBusAxi_ar_payload_burst(iBusAxi_ar_payload_burst),
        .iBusAxi_ar_payload_lock (iBusAxi_ar_payload_lock),
        .iBusAxi_ar_payload_cache(iBusAxi_ar_payload_cache),
        .iBusAxi_ar_payload_qos  (iBusAxi_ar_payload_qos),
        .iBusAxi_ar_payload_prot (iBusAxi_ar_payload_prot),
        .iBusAxi_r_valid         (iBusAxi_r_valid),
        .iBusAxi_r_ready         (iBusAxi_r_ready),
        .iBusAxi_r_payload_data  (iBusAxi_r_payload_data),
        .iBusAxi_r_payload_id    (iBusAxi_r_payload_id),
        .iBusAxi_r_payload_resp  (iBusAxi_r_payload_resp),
        .iBusAxi_r_payload_last  (iBusAxi_r_payload_last),
        .dBusAxi_aw_valid        (dBusAxi_aw_valid),
        .dBusAxi_aw_ready        (dBusAxi_aw_ready),
        .dBusAxi_aw_payload_addr (dBusAxi_aw_payload_addr),
        .dBusAxi_aw_payload_id   (dBusAxi_aw_payload_id),
        .dBusAxi_aw_payload_region(dBusAxi_aw_payload_region),
        .dBusAxi_aw_payload_len  (dBusAxi_aw_payload_len),
        .dBusAxi_aw_payload_size (dBusAxi_aw_payload_size),
        .dBusAxi_aw_payload_burst(dBusAxi_aw_payload_burst),
        .dBusAxi_aw_payload_lock (dBusAxi_aw_payload_lock),
        .dBusAxi_aw_payload_cache(dBusAxi_aw_payload_cache),
        .dBusAxi_aw_payload_qos  (dBusAxi_aw_payload_qos),
        .dBusAxi_aw_payload_prot (dBusAxi_aw_payload_prot),
        .dBusAxi_w_valid         (dBusAxi_w_valid),
        .dBusAxi_w_ready         (dBusAxi_w_ready),
        .dBusAxi_w_payload_data  (dBusAxi_w_payload_data),
        .dBusAxi_w_payload_strb  (dBusAxi_w_payload_strb),
        .dBusAxi_w_payload_last  (dBusAxi_w_payload_last),
        .dBusAxi_b_valid         (dBusAxi_b_valid),
        .dBusAxi_b_ready         (dBusAxi_b_ready),
        .dBusAxi_b_payload_id    (dBusAxi_b_payload_id),
        .dBusAxi_b_payload_resp  (dBusAxi_b_payload_resp),
        .dBusAxi_ar_valid        (dBusAxi_ar_valid),
        .dBusAxi_ar_ready        (dBusAxi_ar_ready),
        .dBusAxi_ar_payload_addr (dBusAxi_ar_payload_addr),
        .dBusAxi_ar_payload_id   (dBusAxi_ar_payload_id),
        .dBusAxi_ar_payload_region(dBusAxi_ar_payload_region),
        .dBusAxi_ar_payload_len  (dBusAxi_ar_payload_len),
        .dBusAxi_ar_payload_size (dBusAxi_ar_payload_size),
        .dBusAxi_ar_payload_burst(dBusAxi_ar_payload_burst),
        .dBusAxi_ar_payload_lock (dBusAxi_ar_payload_lock),
        .dBusAxi_ar_payload_cache(dBusAxi_ar_payload_cache),
        .dBusAxi_ar_payload_qos  (dBusAxi_ar_payload_qos),
        .dBusAxi_ar_payload_prot (dBusAxi_ar_payload_prot),
        .dBusAxi_r_valid         (dBusAxi_r_valid),
        .dBusAxi_r_ready         (dBusAxi_r_ready),
        .dBusAxi_r_payload_data  (dBusAxi_r_payload_data),
        .dBusAxi_r_payload_id    (dBusAxi_r_payload_id),
        .dBusAxi_r_payload_resp  (dBusAxi_r_payload_resp),
        .dBusAxi_r_payload_last  (dBusAxi_r_payload_last)
    );

    assign dBusAxi_r_payload_id = cpu_axi_rid[0];
    assign dBusAxi_b_payload_id = cpu_axi_bid[0];

    // ==========================================
    // INSTANCE: INSTRUCTION RAM (i_ram)
    // ==========================================
    axi4_full_ram_slave #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .RAM_DEPTH_BITS(10),
        .BASE_ADDR(32'h8000_0000),
        .INIT_FILE("C:/Document/JPEG/System_Interrupt_Worked_3_Images_Passed/software/codejpeg.hex")
    ) i_ram (
        .clk(clk),
        .reset(reset),
        .s_axi_arvalid(iBusAxi_ar_valid),
        .s_axi_arready(iBusAxi_ar_ready),
        .s_axi_araddr (iBusAxi_ar_payload_addr),
        .s_axi_arid   (iBusAxi_ar_payload_id),
        .s_axi_arlen  (iBusAxi_ar_payload_len),
        .s_axi_arsize (iBusAxi_ar_payload_size),
        .s_axi_arburst(iBusAxi_ar_payload_burst),
        .s_axi_rvalid (iBusAxi_r_valid),
        .s_axi_rready (iBusAxi_r_ready),
        .s_axi_rdata  (iBusAxi_r_payload_data),
        .s_axi_rid    (iBusAxi_r_payload_id),
        .s_axi_rresp  (iBusAxi_r_payload_resp),
        .s_axi_rlast  (iBusAxi_r_payload_last),
        .s_axi_awvalid(1'b0),
        .s_axi_awready(),
        .s_axi_awaddr (32'h0),
        .s_axi_awid   (1'b0),
        .s_axi_awlen  (8'h0),
        .s_axi_awsize (3'h0),
        .s_axi_awburst(2'h0),
        .s_axi_wvalid (1'b0),
        .s_axi_wready (),
        .s_axi_wdata  (32'h0),
        .s_axi_wstrb  (4'h0),
        .s_axi_wlast  (1'b0),
        .s_axi_bvalid (),
        .s_axi_bready (1'b1),
        .s_axi_bid    (),
        .s_axi_bresp  ()
    );

    // ==========================================
    // INSTANCE: AXI CROSSBAR 2x2
    // ==========================================
    axi_crossbar #(
        .S_COUNT(2),
        .M_COUNT(2),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .S_ID_WIDTH(8),                        
        .M_REGIONS(1),
        .M_BASE_ADDR({32'h4000_0000, 32'h0000_0000}), 
        // M0 (d_ram) có 2^16 word x 4 byte = 256 KiB, cần 18 bit địa chỉ.
        // M1 (DMA AXI-Lite adapter) vẫn chỉ cần cửa sổ 64 KiB.
        .M_ADDR_WIDTH({32'd16, 32'd18}),
        .S_THREADS({32'd1, 32'd1}),           
        .S_ACCEPT({32'd1, 32'd1}),             
        .M_ISSUE({32'd1, 32'd1}),              
        .M_CONNECT_READ(4'b1111),             
        .M_CONNECT_WRITE(4'b1111),            
        .M_SECURE(2'b00),
        
        .S_AW_REG_TYPE(4'b0000),
        // Keep the source W channel backpressured until the RAM has accepted
        // the matching AW address. This prevents VexRiscv's split AW/W fork
        // from buffering a write beat before the crossbar knows its target.
        .S_W_REG_TYPE(4'b0000),
        .S_B_REG_TYPE(4'b0000),
        .S_AR_REG_TYPE(4'b0000),
        .S_R_REG_TYPE(4'b0000),
        .M_AW_REG_TYPE(4'b0000),             
        .M_W_REG_TYPE(4'b0010),               
        .M_B_REG_TYPE(4'b0000),              
        .M_AR_REG_TYPE(4'b0000),             
        .M_R_REG_TYPE(4'b0000)               
    ) crossbar_inst (
        .clk(clk),
        .rst(reset),
        .s_axi_awid     ({dma_m_axi_awid,    {7'b0, dBusAxi_aw_payload_id}}),
        .s_axi_awaddr   ({dma_m_axi_awaddr,  dBusAxi_aw_payload_addr}),
        .s_axi_awlen    ({dma_m_axi_awlen,   dBusAxi_aw_payload_len}),
        .s_axi_awsize   ({dma_m_axi_awsize,  dBusAxi_aw_payload_size}),
        .s_axi_awburst  ({dma_m_axi_awburst, dBusAxi_aw_payload_burst}),
        .s_axi_awlock   ({dma_m_axi_awlock,  dBusAxi_aw_payload_lock}),
        .s_axi_awcache  ({dma_m_axi_awcache, dBusAxi_aw_payload_cache}),
        .s_axi_awprot   ({dma_m_axi_awprot,  dBusAxi_aw_payload_prot}),
        .s_axi_awqos    ({4'h0,              dBusAxi_aw_payload_qos}),
        .s_axi_awuser   (2'b00),
        .s_axi_awvalid  ({dma_m_axi_awvalid, dBusAxi_aw_valid}),
        .s_axi_awready  ({dma_m_axi_awready, dBusAxi_aw_ready}),
        .s_axi_wdata    ({dma_m_axi_wdata,   dBusAxi_w_payload_data}),
        .s_axi_wstrb    ({dma_m_axi_wstrb,   dBusAxi_w_payload_strb}),
        .s_axi_wlast    ({dma_m_axi_wlast,   dBusAxi_w_payload_last}),
        .s_axi_wuser    (2'b00),
        .s_axi_wvalid   ({dma_m_axi_wvalid,  dBusAxi_w_valid}),
        .s_axi_wready   ({dma_m_axi_wready,  dBusAxi_w_ready}),
        .s_axi_bid      ({dma_m_axi_bid,     cpu_axi_bid}),
        .s_axi_bresp    ({dma_m_axi_bresp,   dBusAxi_b_payload_resp}),
        .s_axi_buser    (),
        .s_axi_bvalid   ({dma_m_axi_bvalid,  dBusAxi_b_valid}),
        .s_axi_bready   ({dma_m_axi_bready,  dBusAxi_b_ready}),
        .s_axi_arid     ({dma_m_axi_arid,    {7'b0, dBusAxi_ar_payload_id}}),
        .s_axi_araddr   ({dma_m_axi_araddr,  dBusAxi_ar_payload_addr}),
        .s_axi_arlen    ({dma_m_axi_arlen,   dBusAxi_ar_payload_len}),
        .s_axi_arsize   ({dma_m_axi_arsize,  dBusAxi_ar_payload_size}),
        .s_axi_arburst  ({dma_m_axi_arburst, dBusAxi_ar_payload_burst}),
        .s_axi_arlock   ({dma_m_axi_arlock,  dBusAxi_ar_payload_lock}),
        .s_axi_arcache  ({dma_m_axi_arcache, dBusAxi_ar_payload_cache}),
        .s_axi_arprot   ({dma_m_axi_arprot,  dBusAxi_ar_payload_prot}),
        .s_axi_arqos    ({4'h0,              dBusAxi_ar_payload_qos}),
        .s_axi_aruser   (2'b00),
        .s_axi_arvalid  ({dma_m_axi_arvalid, dBusAxi_ar_valid}),
        .s_axi_arready  ({dma_m_axi_arready, dBusAxi_ar_ready}),
        .s_axi_rid      ({dma_m_axi_rid,     cpu_axi_rid}),
        .s_axi_rdata    ({dma_m_axi_rdata,   dBusAxi_r_payload_data}),
        .s_axi_rresp    ({dma_m_axi_rresp,   dBusAxi_r_payload_resp}),
        .s_axi_rlast    ({dma_m_axi_rlast,   dBusAxi_r_payload_last}),
        .s_axi_ruser    (),
        .s_axi_rvalid   ({dma_m_axi_rvalid,  dBusAxi_r_valid}),
        .s_axi_rready   ({dma_m_axi_rready,  dBusAxi_r_ready}),
        .m_axi_awid     ({ic_s1_awid,    ic_s0_awid}),
        .m_axi_awaddr   ({ic_s1_awaddr,  ic_s0_awaddr}),
        .m_axi_awlen    ({ic_s1_awlen,   ic_s0_awlen}),
        .m_axi_awsize   ({ic_s1_awsize,  ic_s0_awsize}),
        .m_axi_awburst  ({ic_s1_awburst, ic_s0_awburst}),
        .m_axi_awlock   (),
        .m_axi_awcache  (),
        .m_axi_awprot   (),
        .m_axi_awqos    (),
        .m_axi_awregion (),
        .m_axi_awuser   (),
        .m_axi_awvalid  ({ic_s1_awvalid, ic_s0_awvalid}),
        .m_axi_awready  ({ic_s1_awready, ic_s0_awready}),
        .m_axi_wdata    ({ic_s1_wdata,   ic_s0_wdata}),
        .m_axi_wstrb    ({ic_s1_wstrb,   ic_s0_wstrb}),
        .m_axi_wlast    ({ic_s1_wlast,   ic_s0_wlast}),
        .m_axi_wuser    (),
        .m_axi_wvalid   ({ic_s1_wvalid,  ic_s0_wvalid}),
        .m_axi_wready   ({ic_s1_wready,  ic_s0_wready}),
        .m_axi_bid      ({ic_s1_bid,     ic_s0_bid}),
        .m_axi_bresp    ({ic_s1_bresp,   ic_s0_bresp}),
        .m_axi_buser    (2'b00),
        .m_axi_bvalid   ({ic_s1_bvalid,  ic_s0_bvalid}),
        .m_axi_bready   ({ic_s1_bready,  ic_s0_bready}),
        .m_axi_arid     ({ic_s1_arid,    ic_s0_arid}),
        .m_axi_araddr   ({ic_s1_araddr,  ic_s0_araddr}),
        .m_axi_arlen    ({ic_s1_arlen,   ic_s0_arlen}),
        .m_axi_arsize   ({ic_s1_arsize,  ic_s0_arsize}),
        .m_axi_arburst  ({ic_s1_arburst, ic_s0_arburst}),
        .m_axi_arlock   (),
        .m_axi_arcache  (),
        .m_axi_arprot   (),
        .m_axi_arqos    (),
        .m_axi_arregion (),
        .m_axi_aruser   (),
        .m_axi_arvalid  ({ic_s1_arvalid, ic_s0_arvalid}),
        .m_axi_arready  ({ic_s1_arready, ic_s0_arready}),
        .m_axi_rid      ({ic_s1_rid,     ic_s0_rid}),
        .m_axi_rdata    ({ic_s1_rdata,   ic_s0_rdata}),
        .m_axi_rresp    ({ic_s1_rresp,   ic_s0_rresp}),
        .m_axi_rlast    ({ic_s1_rlast,   ic_s0_rlast}),
        .m_axi_ruser    (2'b00),
        .m_axi_rvalid   ({ic_s1_rvalid,  ic_s0_rvalid}),
        .m_axi_rready   ({ic_s1_rready,  ic_s0_rready})
    );

    // ==========================================
    // INSTANCE: DATA RAM (d_ram)
    // ==========================================
    axi4_full_ram_slave #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        // Preserve the crossbar's complete low ID field. Bit [8], which
        // identifies the originating master, is latched and restored below.
        .ID_WIDTH(8),
        .RAM_DEPTH_BITS(16),
        .BASE_ADDR(32'h0000_0000),
        // Three consecutive 9216-word frames are stored at 0x00000, 0x09000,
        // and 0x12000 for the sequential-frame test.
        .INIT_FILE("C:/Document/JPEG/System_Interrupt_Worked_3_Images_Passed/image_input_data/image_data.hex")
    ) d_ram (
        .clk(clk),
        .reset(reset),
        .s_axi_arvalid(ic_s0_arvalid),
        .s_axi_arready(ic_s0_arready),
        .s_axi_araddr (ic_s0_araddr),
        .s_axi_arid   (ic_s0_arid[7:0]),  
        .s_axi_arlen  (ic_s0_arlen),
        .s_axi_arsize (ic_s0_arsize),
        .s_axi_arburst(ic_s0_arburst),
        .s_axi_rvalid (ic_s0_rvalid),
        .s_axi_rready (ic_s0_rready),
        .s_axi_rdata  (ic_s0_rdata),
        .s_axi_rid    (ic_s0_rid[7:0]),   
        .s_axi_rresp  (ic_s0_rresp),
        .s_axi_rlast  (ic_s0_rlast),
        .s_axi_awvalid(ic_s0_awvalid),
        .s_axi_awready(ic_s0_awready),
        .s_axi_awaddr (ic_s0_awaddr),
        .s_axi_awid   (ic_s0_awid[7:0]),  
        .s_axi_awlen  (ic_s0_awlen),
        .s_axi_awsize (ic_s0_awsize),
        .s_axi_awburst(ic_s0_awburst),
        .s_axi_wvalid (ic_s0_wvalid),
        .s_axi_wready (ic_s0_wready),
        .s_axi_wdata  (ic_s0_wdata),
        .s_axi_wstrb  (ic_s0_wstrb),
        .s_axi_wlast  (ic_s0_wlast),
        .s_axi_bvalid (ic_s0_bvalid),
        .s_axi_bready (ic_s0_bready),
        .s_axi_bid    (ic_s0_bid[7:0]),   
        .s_axi_bresp  (ic_s0_bresp)
    );

    // assign ic_s0_bid[8] = 1'b0;
    // assign ic_s0_rid[8] = 1'b0;

// =========================================================================
    // LATCH BIT MSB [8] CỦA AXI ID ĐỂ ĐỊNH TUYẾN PHẢN HỒI CHUẨN XÁC CHO CPU HOẶC DMA
    // =========================================================================
    reg ram_rid_msb;
    reg ram_bid_msb;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ram_rid_msb <= 1'b0;
            ram_bid_msb <= 1'b0;
        end else begin
            // Chốt ID của Master khi bắt đầu giao dịch Đọc
            if (ic_s0_arvalid && ic_s0_arready) begin
                ram_rid_msb <= ic_s0_arid[8];
            end
            // Chốt ID của Master khi bắt đầu giao dịch Ghi
            if (ic_s0_awvalid && ic_s0_awready) begin
                ram_bid_msb <= ic_s0_awid[8];
            end
        end
    end

    // Nối đúng Bit MSB đã được Latch trả về cho Crossbar
    assign ic_s0_rid[8] = ram_rid_msb;
    assign ic_s0_bid[8] = ram_bid_msb;
    // ==========================================
    // INSTANCE: DMA ADAPTER
    // ==========================================
    dma_axil_adapter #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .LEN_WIDTH(20),
        .TAG_WIDTH(8)
    ) dma_adapter_inst (
        .clk(clk),
        .rst(reset),

        .s_axi_awaddr (ic_s1_awaddr),
        .s_axi_awvalid(ic_s1_awvalid),
        .s_axi_awready(ic_s1_awready),
        .s_axi_awid   (ic_s1_awid[0]),

        .s_axi_wdata  (ic_s1_wdata),
        .s_axi_wstrb  (ic_s1_wstrb),
        .s_axi_wvalid (ic_s1_wvalid),
        .s_axi_wready (ic_s1_wready),

        .s_axi_bresp  (ic_s1_bresp),
        .s_axi_bvalid (ic_s1_bvalid),
        .s_axi_bready (ic_s1_bready),
        .s_axi_bid    (ic_s1_bid[0]),

        .s_axi_araddr (ic_s1_araddr),
        .s_axi_arvalid(ic_s1_arvalid),
        .s_axi_arready(ic_s1_arready),
        .s_axi_arid   (ic_s1_arid[0]),

        .s_axi_rdata  (ic_s1_rdata),
        .s_axi_rresp  (ic_s1_rresp),
        .s_axi_rvalid (ic_s1_rvalid),
        .s_axi_rready (ic_s1_rready),
        .s_axi_rid    (ic_s1_rid[0]),

        .read_desc_addr  (ad2sub_read_desc_addr),
        .read_desc_len   (ad2sub_read_desc_len),
        .read_desc_tag   (ad2sub_read_desc_tag),
        .read_desc_id    (ad2sub_read_desc_id),
        .read_desc_dest  (ad2sub_read_desc_dest),
        .read_desc_user  (ad2sub_read_desc_user),
        .read_desc_valid (ad2sub_read_desc_valid),
        .read_desc_ready (sub2ad_read_desc_ready), // NỐI VỀ DÂY CỦA SUBSYSTEM

        .irq_pending     (dma_irq_pending),
        .read_irq_error  (dma_read_irq_error),
        .write_irq_error (dma_write_irq_error),
        .irq_clear       (dma_irq_clear),
        .jpeg_soft_reset (jpeg_soft_reset),

        .write_desc_addr (ad2sub_write_desc_addr),
        .write_desc_len  (ad2sub_write_desc_len),
        .write_desc_tag  (ad2sub_write_desc_tag),
        .write_desc_valid(ad2sub_write_desc_valid),
        .write_desc_ready(sub2ad_write_desc_ready), // NỐI VỀ DÂY CỦA SUBSYSTEM

        .dma_read_enable (),
        .dma_write_enable()
    );

    assign ic_s1_bid[8:1] = ic_s1_awid[8:1];
    assign ic_s1_rid[8:1] = ic_s1_arid[8:1];
    // The DMA register block is AXI-Lite (single-beat reads), while the
    // crossbar exposes AXI4 and uses RLAST to retire each read transaction.
    assign ic_s1_rlast = 1'b1;

    // ==========================================
    // INSTANCE: JPEG DMA SUBSYSTEM (Master S01 Crossbar)
    // ==========================================
    jpeg_dma_subsystem #(
        .AXI_DATA_WIDTH(32),
        .AXI_ADDR_WIDTH(32),
        .AXI_ID_WIDTH(8),
        .LEN_WIDTH(20),
        .TAG_WIDTH(8)
    ) u_jpeg_dma_subsystem (
        .clk(clk),
        .rst(reset),
        .jpeg_soft_reset(jpeg_soft_reset),

        // --- Read Descriptor ---
        .s_axis_read_desc_addr (ad2sub_read_desc_addr),
        .s_axis_read_desc_len  (ad2sub_read_desc_len),
        .s_axis_read_desc_tag  (ad2sub_read_desc_tag),
        .s_axis_read_desc_id   (ad2sub_read_desc_id),
        .s_axis_read_desc_dest (ad2sub_read_desc_dest),
        .s_axis_read_desc_user (ad2sub_read_desc_user),
        .s_axis_read_desc_valid(ad2sub_read_desc_valid),
        .s_axis_read_desc_ready(sub2ad_read_desc_ready),

        .m_axis_read_desc_status_tag  (),
        .m_axis_read_desc_status_error(dma_read_status_error),
        .m_axis_read_desc_status_valid(dma_read_status_valid),

        // --- Write Descriptor ---
        .s_axis_write_desc_addr (ad2sub_write_desc_addr),
        .s_axis_write_desc_len  (ad2sub_write_desc_len),
        .s_axis_write_desc_tag  (ad2sub_write_desc_tag),
        .s_axis_write_desc_valid(ad2sub_write_desc_valid),
        .s_axis_write_desc_ready(sub2ad_write_desc_ready),

        .m_axis_write_desc_status_len  (dma_write_status_len),
        .m_axis_write_desc_status_tag  (),
        .m_axis_write_desc_status_id   (),
        .m_axis_write_desc_status_dest (),
        .m_axis_write_desc_status_user (),
        .m_axis_write_desc_status_error(dma_write_status_error),
        .m_axis_write_desc_status_valid(dma_write_status_valid),

        // --- AXI Master Interface (Nối vào Crossbar S01) ---
        .m_axi_awid   (dma_m_axi_awid),
        .m_axi_awaddr (dma_m_axi_awaddr),
        .m_axi_awlen  (dma_m_axi_awlen),
        .m_axi_awsize (dma_m_axi_awsize),
        .m_axi_awburst(dma_m_axi_awburst),
        .m_axi_awlock (dma_m_axi_awlock),
        .m_axi_awcache(dma_m_axi_awcache),
        .m_axi_awprot (dma_m_axi_awprot),
        .m_axi_awvalid(dma_m_axi_awvalid),
        .m_axi_awready(dma_m_axi_awready),

        .m_axi_wdata  (dma_m_axi_wdata),
        .m_axi_wstrb  (dma_m_axi_wstrb),
        .m_axi_wlast  (dma_m_axi_wlast),
        .m_axi_wvalid (dma_m_axi_wvalid),
        .m_axi_wready (dma_m_axi_wready),

        .m_axi_bid    (dma_m_axi_bid),
        .m_axi_bresp  (dma_m_axi_bresp),
        .m_axi_bvalid (dma_m_axi_bvalid),
        .m_axi_bready (dma_m_axi_bready),

        .m_axi_arid   (dma_m_axi_arid),
        .m_axi_araddr (dma_m_axi_araddr),
        .m_axi_arlen  (dma_m_axi_arlen),
        .m_axi_arsize (dma_m_axi_arsize),
        .m_axi_arburst(dma_m_axi_arburst),
        .m_axi_arlock (dma_m_axi_arlock),
        .m_axi_arcache(dma_m_axi_arcache),
        .m_axi_arprot (dma_m_axi_arprot),
        .m_axi_arvalid(dma_m_axi_arvalid),
        .m_axi_arready(dma_m_axi_arready),

        .m_axi_rid    (dma_m_axi_rid),
        .m_axi_rdata  (dma_m_axi_rdata),
        .m_axi_rresp  (dma_m_axi_rresp),
        .m_axi_rlast  (dma_m_axi_rlast),
        .m_axi_rvalid (dma_m_axi_rvalid),
        .m_axi_rready (dma_m_axi_rready)
    );

endmodule
