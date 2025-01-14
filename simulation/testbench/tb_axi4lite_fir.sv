//
// Copyright (C) 2019 Massachusetts Institute of Technology
//
// File         : tb_axi4lite_fir.v
// Project      : Common Evaluation Platform (CEP)
// Description  : Unit test bench for the AXI4-lite based FIR cores
//
// Derived from : https://github.com/pulp-platform/axi.git
// 
// Licensing info can be found in the root directory of the CEP in licenseLog.txt
//

`include "axi/assign.svh"

// Used for the various levels of debug (higher levels define lower levels)
`ifdef DEBUG5
    `define DEBUG4
    `define DEBUG3
    `define DEBUG2
    `define DEBUG1
`elsif DEBUG4
    `define DEBUG3
    `define DEBUG2
    `define DEBUG1
`elsif DEBUG3
    `define DEBUG2
    `define DEBUG1
`elsif DEBUG2
    `define DEBUG1
`endif

import axi_test_extended::*;

module tb_axi4lite_fir;

    parameter [DW-1:0] exp_1[32]= '{
        32'h00000006,
        32'h0000000c,
        32'h00000012,
        32'h00000018,
        32'h0000001e,
        32'h00000025,
        32'h0000002c,
        32'h00000031,
        32'h00000039,
        32'h0000003f,
        32'h00000045,
        32'h0000004d,
        32'h00000052,
        32'h0000005a,
        32'h00000060,
        32'h00000067,
        32'h0000006c,
        32'h00000075,
        32'h0000007a,
        32'h00000081,
        32'h00000088,
        32'h0000008e,
        32'h00000095,
        32'h0000009b,
        32'h000000a2,
        32'h000000a8,
        32'h000000af,
        32'h000000b4,
        32'h000000b1,
        32'h0000009f,
        32'h0000007a,
        32'h00000049
    };

    logic clk = 0;
    logic rst = 1;
    logic done = 0;
    logic pass = 1;

    AXI_LITE_DV #(
        .AXI_ADDR_WIDTH(AW),
        .AXI_DATA_WIDTH(DW)
    ) axi_lite_dv(clk);

    AXI_LITE #(
        .AXI_ADDR_WIDTH(AW),
        .AXI_DATA_WIDTH(DW)
    ) axi_lite();

    `AXI_LITE_ASSIGN(axi_lite, axi_lite_dv);

    // Instantiate the DUT
    fir_top_axi4lite fir_top_axi4lite_inst (
        .clk_i          ( clk               ),
        .rst_ni         ( rst               ),

        .o_axi_awready  ( axi_lite.aw_ready ),
        .i_axi_awaddr   ( axi_lite.aw_addr  ), 
        .i_axi_awcache  ( 4'b0000           ), 
        .i_axi_awprot   ( 3'b000            ), 
        .i_axi_awvalid  ( axi_lite.aw_valid ),

        .o_axi_wready   ( axi_lite.w_ready  ), 
        .i_axi_wdata    ( axi_lite.w_data   ), 
        .i_axi_wstrb    ( axi_lite.w_strb   ), 
        .i_axi_wvalid   ( axi_lite.w_valid  ),

        .o_axi_bresp    ( axi_lite.b_resp   ), 
        .o_axi_bvalid   ( axi_lite.b_valid  ), 
        .i_axi_bready   ( axi_lite.b_ready  ),

        .o_axi_arready  ( axi_lite.ar_ready ),
        .i_axi_araddr   ( axi_lite.ar_addr  ),
        .i_axi_arcache  ( 4'b0000           ),
        .i_axi_arprot   ( 3'b000            ),
        .i_axi_arvalid  ( axi_lite.ar_valid ),

        .o_axi_rresp    ( axi_lite.r_resp   ),
        .o_axi_rvalid   ( axi_lite.r_valid  ),
        .o_axi_rdata    ( axi_lite.r_data   ),
        .i_axi_rready   ( axi_lite.r_ready  )
    );

    // Create a new AXI4 lite object
    axi_test_extended::axi_lite_driver_plus #(.AW(AW), .DW(DW)) axi_lite_drv = new(axi_lite_dv);

    // Reset the Device under Test
    task reset_dut();
        repeat (4) #tCK;
        rst <= 0;
        repeat (4) #tCK;
        rst <= 1;
        #tCK;
    endtask : reset_dut

    // Clock is always running
    initial begin
        while (!done) begin
            clk <= 1;
            #(tCK/2);
            clk <= 0;
            #(tCK/2);
        end
        $stop;
    end

    initial begin
        automatic logic [AW-1:0]    addr;
        automatic logic [DW-1:0]    data;
        automatic logic [DW/8-1:0]  strb;
        automatic axi_pkg::resp_t   resp;

        automatic logic [15:0]      y_results[0:3];

         // Reset the system
        axi_lite_drv.reset_master();
        reset_dut();
        @(posedge clk);

        // Wait a few cycles
        repeat (4) @(posedge clk);

        // Load the inputs
        for (int i = 0; i < 32; i++)
            axi_lite_drv.fir_setInData(i, i * 4);

        // Command the IIR core to start
        axi_lite_drv.axi_lite_slave_write(  .addr(32'(FIR_START)),
                                            .data(32'h0000_0001),
                                            .strb('1),
                                            .resp(resp));
        axi_lite_drv.axi_lite_slave_write(  .addr(32'(FIR_START)),
                                            .data(32'h0000_0000),
                                            .strb('1),
                                            .resp(resp));

        // Poll the AES Core to see when it has completed operations
        do begin
            axi_lite_drv.axi_lite_slave_read(   .addr(32'(FIR_DONE)), 
                                                .data(data), 
                                                .resp(resp));
        end 
        while (data[0] == 1'b0);

        // Check the outputs
        for (int i = 0; i < 32; i++) begin
            axi_lite_drv.fir_getOutData(i, data);

            if (data !== exp_1[i]) begin
                $error("tb_axi_lite_fir: Bad output exp/act (32'h%8h/32'h%8h)", exp_1[i], data);
                pass = 0;
            end // if (data !== exp_1[i])

        end // for (int i = 0; i < 32; i++)

        // Wait a few cycles
        repeat (4) @(posedge clk);

        // Display test results
        if (pass) begin
            $display("");
            $display("===================================================================================");
            $display("                             ALL TEST VECTORS PASSED");
            $display("===================================================================================");
            $display("");
        end else begin
            $display("");
            $display("===================================================================================");
            $error  ("                                  TEST FAILED");
            $display("===================================================================================");
            $display("");
        end

        // Tell the simulation to complete
        done = 1;
         
    end // end of perform the test

endmodule
