`timescale 1ns / 1ps

module tb_soc_top;

    reg clk;
    reg reset;

    wire [31:0] test_read_desc_addr;
    wire [19:0] test_read_desc_len;
    wire        test_read_desc_valid;
    wire        test_read_desc_ready;
    wire [31:0] test_write_desc_addr;
    wire [19:0] test_write_desc_len;
    wire        test_write_desc_valid;
    wire        test_write_desc_ready;
    wire        test_dma_irq;
    wire [1:0]  test_dma_irq_pending;
    wire        test_read_status_valid;
    wire [3:0]  test_read_status_error;
    wire        test_write_status_valid;
    wire [19:0] test_write_status_len;
    wire [3:0]  test_write_status_error;
    wire [1:0]  test_dma_irq_clear;
    wire        test_cpu_interrupt_taken;

    integer ram_out_file [0:2];
    integer ram_write_count [0:2];
    integer read_status_count;
    integer write_status_count;
    integer write_desc_count;
    integer irq_rise_count;
    integer cpu_interrupt_count;
    integer read_irq_ack_count;
    integer write_irq_ack_count;
    integer tb_error_count;
    integer active_frame;
    integer word_index;
    integer capture_addr;
    integer expected_word_count;
    reg [31:0] capture_word;
    reg     write_desc_seen;
    reg     previous_irq;
    reg     frame_partial_seen;
    reg [4:0] frame_partial_count;
    reg [31:0] write_desc_base;
    reg [31:0] write_desc_end;

    wire        jpeg_data_ready = uut.u_jpeg_dma_subsystem.u_jpeg_wrapper.u_jpeg_core.data_ready;
    wire [31:0] jpeg_bitstream = uut.u_jpeg_dma_subsystem.u_jpeg_wrapper.u_jpeg_core.JPEG_bitstream;
    wire        jpeg_partial_ready = uut.u_jpeg_dma_subsystem.u_jpeg_wrapper.u_jpeg_core.eof_data_partial_ready;
    wire [4:0]  jpeg_partial_count = uut.u_jpeg_dma_subsystem.u_jpeg_wrapper.u_jpeg_core.end_of_file_bitstream_count;
    wire        jpeg_axis_valid = uut.u_jpeg_dma_subsystem.axis_jpeg2wr_tvalid;
    wire        jpeg_axis_ready = uut.u_jpeg_dma_subsystem.axis_jpeg2wr_tready;
    wire        jpeg_axis_last = uut.u_jpeg_dma_subsystem.axis_jpeg2wr_tlast;

    soc_top uut (
        .clk(clk),
        .reset(reset),
        .test_read_desc_addr(test_read_desc_addr),
        .test_read_desc_len(test_read_desc_len),
        .test_read_desc_valid(test_read_desc_valid),
        .test_read_desc_ready(test_read_desc_ready),
        .test_write_desc_addr(test_write_desc_addr),
        .test_write_desc_len(test_write_desc_len),
        .test_write_desc_valid(test_write_desc_valid),
        .test_write_desc_ready(test_write_desc_ready),
        .test_dma_irq(test_dma_irq),
        .test_dma_irq_pending(test_dma_irq_pending),
        .test_read_status_valid(test_read_status_valid),
        .test_read_status_error(test_read_status_error),
        .test_write_status_valid(test_write_status_valid),
        .test_write_status_len(test_write_status_len),
        .test_write_status_error(test_write_status_error),
        .test_dma_irq_clear(test_dma_irq_clear),
        .test_cpu_interrupt_taken(test_cpu_interrupt_taken)
    );

    always #5 clk = ~clk;

    initial begin
        ram_out_file[0] = $fopen("C:/Document/JPEG/System_Interrupt_Worked_3_Images_Passed/res/bitstream_from_ram_0.hex", "w");
        ram_out_file[1] = $fopen("C:/Document/JPEG/System_Interrupt_Worked_3_Images_Passed/res/bitstream_from_ram_1.hex", "w");
        ram_out_file[2] = $fopen("C:/Document/JPEG/System_Interrupt_Worked_3_Images_Passed/res/bitstream_from_ram_2.hex", "w");
        if (ram_out_file[0] == 0 || ram_out_file[1] == 0 || ram_out_file[2] == 0) begin
            $display("[TB ERROR] Could not create the three RAM bitstream dumps.");
            $finish;
        end

        clk = 1'b0;
        reset = 1'b1;
        #100;
        reset = 1'b0;
        $display("[%0t ps] Starting three-frame DMA/JPEG/IRQ test.", $time);

        fork
            begin : wait_for_three_frames
                wait ((write_status_count == 3) &&
                      (read_status_count == 3) &&
                      (write_desc_count == 3) &&
                      (irq_rise_count == 3) &&
                      (cpu_interrupt_count == 3) &&
                      (read_irq_ack_count == 3) &&
                      (write_irq_ack_count == 3) &&
                      (test_dma_irq_pending == 2'b00));
                #100;
                if ((tb_error_count == 0) &&
                    (ram_write_count[0] != 0) &&
                    (ram_write_count[1] != 0) &&
                    (ram_write_count[2] != 0)) begin
                    $display("[TB PASS] 3 frames completed; one CPU interrupt per frame; 3 output RAM ranges captured.");
                end else begin
                    $display("[TB FAIL] Frame/error/data checks failed: errors=%0d RAM writes=[%0d,%0d,%0d]",
                             tb_error_count, ram_write_count[0], ram_write_count[1], ram_write_count[2]);
                end
                close_dump_files();
                $finish;
            end
            begin : simulation_watchdog
                #2000000;
                $display("[TB FAIL] Watchdog expired: read_status=%0d write_status=%0d IRQ_edges=%0d CPU_traps=%0d read_ACK=%0d write_ACK=%0d pending=%b",
                         read_status_count, write_status_count, irq_rise_count,
                         cpu_interrupt_count, read_irq_ack_count,
                         write_irq_ack_count, test_dma_irq_pending);
                close_dump_files();
                $finish;
            end
        join
    end

    task close_dump_files;
        begin
            if (ram_out_file[0] != 0) $fclose(ram_out_file[0]);
            if (ram_out_file[1] != 0) $fclose(ram_out_file[1]);
            if (ram_out_file[2] != 0) $fclose(ram_out_file[2]);
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            read_status_count <= 0;
            write_status_count <= 0;
            write_desc_count <= 0;
            irq_rise_count <= 0;
            cpu_interrupt_count <= 0;
            read_irq_ack_count <= 0;
            write_irq_ack_count <= 0;
            tb_error_count <= 0;
            active_frame <= -1;
            write_desc_seen <= 1'b0;
            previous_irq <= 1'b0;
            frame_partial_seen <= 1'b0;
            frame_partial_count <= 5'd0;
            write_desc_base <= 32'd0;
            write_desc_end <= 32'd0;
            ram_write_count[0] <= 0;
            ram_write_count[1] <= 0;
            ram_write_count[2] <= 0;
        end else begin
            previous_irq <= test_dma_irq;

            if (test_read_status_valid) begin
                read_status_count = read_status_count + 1;
                $display("[%0t ps] DMA read complete, error=%h", $time, test_read_status_error);
                if (test_read_status_error != 0) begin
                    tb_error_count = tb_error_count + 1;
                    $display("[TB ERROR] DMA read error on frame %0d: %h", read_status_count, test_read_status_error);
                end
            end

            if (test_write_desc_valid && test_write_desc_ready) begin
                active_frame = write_desc_count;
                write_desc_count = write_desc_count + 1;
                write_desc_seen = 1'b1;
                write_desc_base = test_write_desc_addr;
                write_desc_end = test_write_desc_addr + test_write_desc_len;
                frame_partial_seen = 1'b0;
                frame_partial_count = 5'd0;
                $display("[%0t ps] Output frame %0d buffer: %08X..%08X",
                         $time, active_frame, test_write_desc_addr,
                         test_write_desc_addr + test_write_desc_len);
            end

            if (jpeg_partial_ready) begin
                frame_partial_seen = 1'b1;
                frame_partial_count = jpeg_partial_count;
            end

            if (test_write_status_valid) begin
                write_status_count = write_status_count + 1;
                $display("[%0t ps] DMA write complete for frame %0d, bytes=%0d, error=%h",
                         $time, active_frame, test_write_status_len,
                         test_write_status_error);

                if ((active_frame < 0) || (active_frame > 2)) begin
                    tb_error_count = tb_error_count + 1;
                    $display("[TB ERROR] Write completion has no matching output descriptor.");
                end else if ((test_write_status_len == 0) || (test_write_status_len > 20'h09000)) begin
                    tb_error_count = tb_error_count + 1;
                    $display("[TB ERROR] Invalid output length on frame %0d: %0d",
                             active_frame, test_write_status_len);
                end else begin
                    expected_word_count = (test_write_status_len + 3) / 4;
                    if (ram_write_count[active_frame] != expected_word_count) begin
                        tb_error_count = tb_error_count + 1;
                        $display("[TB ERROR] RAM write count mismatch on frame %0d: saw %0d, expected %0d",
                                 active_frame, ram_write_count[active_frame], expected_word_count);
                    end
                    for (word_index = 0; word_index < expected_word_count; word_index = word_index + 1) begin
                        capture_addr = (write_desc_base >> 2) + word_index;
                        if (capture_addr[15]) begin
                            capture_word = uut.d_ram.ram_inst.gen_banked_64k.mem_bank1[capture_addr[14:0]];
                        end else begin
                            capture_word = uut.d_ram.ram_inst.gen_banked_64k.mem_bank0[capture_addr[14:0]];
                        end

                        if (frame_partial_seen && (word_index == expected_word_count - 1)) begin
                            $fdisplay(ram_out_file[active_frame], "%08X_PARTIAL_%0d",
                                      capture_word,
                                      frame_partial_count);
                        end else begin
                            $fdisplay(ram_out_file[active_frame], "%08X",
                                      capture_word);
                        end
                    end
                end

                if (test_write_status_error != 0) begin
                    tb_error_count = tb_error_count + 1;
                    $display("[TB ERROR] DMA write error on frame %0d: %h", active_frame, test_write_status_error);
                end
            end

            if (test_dma_irq && !previous_irq)
                irq_rise_count = irq_rise_count + 1;
            if (test_cpu_interrupt_taken)
                cpu_interrupt_count = cpu_interrupt_count + 1;
            if (test_dma_irq_clear[0] && test_dma_irq_pending[0])
                read_irq_ack_count = read_irq_ack_count + 1;
            if (test_dma_irq_clear[1] && test_dma_irq_pending[1])
                write_irq_ack_count = write_irq_ack_count + 1;

            if (write_desc_seen && (active_frame >= 0) && (active_frame < 3) &&
                (uut.d_ram.ram_we === 1'b1) &&
                (uut.d_ram.w_addr >= write_desc_base) &&
                (uut.d_ram.w_addr < write_desc_end) &&
                (uut.d_ram.ram_inst.strb != 4'b0000)) begin
                ram_write_count[active_frame] = ram_write_count[active_frame] + 1;
            end

            if (jpeg_axis_valid && jpeg_axis_ready && jpeg_axis_last)
                $display("[%0t ps] JPEG AXI-Stream TLAST accepted for frame %0d", $time, active_frame);
        end
    end
endmodule

