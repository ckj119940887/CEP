//
// Copyright (C) 2019 Massachusetts Institute of Technology
//
// From the GPS transmitter's perspective
module gps(
           gps_clk_fast,
           gps_clk_slow,
           sync_rst_in,
           sv_num,
           startRound,
           ca_code,
           p_code,
           l_code,
           l_code_valid
       );

input gps_clk_fast;
input gps_clk_slow;
input  sync_rst_in;
input [5:0] sv_num;
input startRound;
output reg [12:0] ca_code;
output [127:0] p_code;
output [127:0] l_code;
output l_code_valid;

wire rst_combined = sync_rst_in;

// Look for rising edge of start
reg startRound_r;
wire startRoundPosEdge = ~startRound_r & startRound;
always @(posedge gps_clk_fast)
    begin
        if(rst_combined)
            begin
                startRound_r <= 0;
            end
        else
            begin
                startRound_r <= startRound;
            end
    end

// Control code generators
reg code_gen_en;
reg [3:0] ca_bit_count;
reg [7:0] p_bit_count;
always @(posedge gps_clk_fast)
    begin
        if(rst_combined | startRoundPosEdge)
            begin
                code_gen_en <= startRoundPosEdge;
            end
        else if(p_bit_count == 8'd128 && ca_bit_count == 4'd13)
            begin
                code_gen_en <= 1'b0;
            end
    end

// Generate C/A code
wire ca_code_bit;
cacode ca(
           gps_clk_slow,
           rst_combined,
           sv_num,
           code_gen_en,
           ca_code_bit
       );

// Deal with clock differences by using code gen edge for slow clock
reg code_gen_en_r;
wire codeGenPosEdge = ~code_gen_en_r & code_gen_en;
always @(posedge gps_clk_slow)
    begin
        if(rst_combined)
            begin
                code_gen_en_r <= 0;
            end
        else
            begin
                code_gen_en_r <= code_gen_en;
            end
    end

// Save 13 ca-code bits
always @(posedge gps_clk_slow)
    begin
        if(rst_combined | codeGenPosEdge)
            begin
                ca_bit_count <= 0;
            end
        else
            begin
                if(ca_bit_count < 4'd13)
                    begin
                        ca_bit_count <= ca_bit_count + 1;
                        ca_code <= {ca_code[11:0], ca_code_bit};
                    end
            end
    end

// Generate P-code
wire p_code_bit;
pcode p(
          gps_clk_fast,
          rst_combined,
          code_gen_en,
          sv_num,
          p_code_bit
      );

// Save 128 p-code bits, encrypt and send as l_code
reg [127:0] p_pt;
always @(posedge gps_clk_fast)
    begin
        if(rst_combined | startRoundPosEdge)
            begin
                p_bit_count <= 0;
            end
        else
            begin
                if(p_bit_count < 8'd128)
                    begin
                        p_bit_count <= p_bit_count + 1;
                        p_pt <= {p_pt [126:0], p_code_bit};
                    end
            end
    end

assign p_code = p_pt;

reg encrypt;
always @(posedge gps_clk_fast)
    begin
        encrypt <= 0;
        if(p_bit_count == 8'd127)
            encrypt <= 1'b1;
    end

  aes_192 aes_192_inst (
    .clk        (gps_clk_fast),
    .rst        (rst_combined),
    .start      (encrypt),
    .state      (p_pt),
    .key        (192'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA),
    .out        (l_code),
    .out_valid  (l_code_valid)
  );

endmodule
