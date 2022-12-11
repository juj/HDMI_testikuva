// tmds_encoder performs Transition-minimized differential signaling (TMDS) encoding of
// 8-bits of pixel data and 2-bits of control data to a 10-bit TMDS encoded format.
// Requires synthesizing with System Verilog 2017.
// For details of DVI, see https://glenwing.github.io/docs/DVI-1.0.pdf
module tmds_encoder(
  input i_hdmi_clk,         // HDMI pixel clock
  input i_reset,            // reset (active high)
  input [7:0] i_data,       // Input 8-bit color
  input [1:0] i_ctrl,       // control data (vsync and hsync)
  input i_display_enable,   // high=pixel data active. low=display is in blanking area
  output reg [9:0] o_tmds   // encoded 10-bit TMDS data
);
  wire [1:0] ctrl = {2{~i_reset}} & i_ctrl; // clear control data if in reset state
  wire blank = i_reset | ~i_display_enable; // if high, send blank data (in reset or in image blank)

  wire parity = {$countones(i_data), !i_data[0]} > 8;                 // calculate a xor value based on if ones dominate the input, break ties on lowest bit.
  wire [7:0] enc = {{7{parity}} ^ enc[6:0] ^ i_data[7:1], i_data[0]}; // intermediate encode step

  wire signed [4:0] balance = {4'($countones(enc)),1'b0} - 5'b01000; // calculate # of ones vs # of zeros bit balance
  reg signed [4:0] bias;                                             // keep a record of bit bias of previously sent data
  wire bias_vs_balance = (bias[4] == balance[4]);                    // track from sign bits if balance is going away or towards bias

  // encode pixel color data with at most 5 bit 0<->1 transitions, and update bias count.
  always @(posedge i_hdmi_clk) begin
    o_tmds <= blank ? {~ctrl[1], 9'b101010100} ^ {10{ctrl[0]}} : {bias_vs_balance, ~parity, {8{bias_vs_balance}} ^ enc};
    bias <= blank ? 0 : 5'(bias + ({5{bias_vs_balance}} ^ balance) + {3'b0, bias_vs_balance^parity, bias_vs_balance});
  end
endmodule

// hdmi module implements HDMI output using the DVI-backwards compatible bitstream.
module hdmi(
  input hdmi_clk,
  input hdmi_clk_5x,
  input [2:0] hve_sync, // Image sync signals: { display_enable, vsync, hsync }
  input [23:0] rgb,
  input reset,

  output [3:0] hdmi_tx_n,
  output [3:0] hdmi_tx_p
);
  // Encode vsync, hsync, blanking and rgb data to Transition-minimized differential signaling (TMDS) format.
  wire [9:0] tmds_ch0, tmds_ch1, tmds_ch2;
  tmds_encoder encode_b(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[23:16]), .i_ctrl(hve_sync[1:0]), .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch0));
  tmds_encoder encode_g(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[15:8]),  .i_ctrl(2'b00),         .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch1));
  tmds_encoder encode_r(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[7:0]),   .i_ctrl(2'b00),         .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch2));

  // Serialize the three 10-bit TMDS channels to three serial 1-bit TMDS streams. (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  wire serial_tmds[3];
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c0(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[0]), .D0(tmds_ch0[0]), .D1(tmds_ch0[1]), .D2(tmds_ch0[2]), .D3(tmds_ch0[3]), .D4(tmds_ch0[4]), .D5(tmds_ch0[5]), .D6(tmds_ch0[6]), .D7(tmds_ch0[7]), .D8(tmds_ch0[8]), .D9(tmds_ch0[9]));
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c1(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[1]), .D0(tmds_ch1[0]), .D1(tmds_ch1[1]), .D2(tmds_ch1[2]), .D3(tmds_ch1[3]), .D4(tmds_ch1[4]), .D5(tmds_ch1[5]), .D6(tmds_ch1[6]), .D7(tmds_ch1[7]), .D8(tmds_ch1[8]), .D9(tmds_ch1[9]));
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c2(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[2]), .D0(tmds_ch2[0]), .D1(tmds_ch2[1]), .D2(tmds_ch2[2]), .D3(tmds_ch2[3]), .D4(tmds_ch2[4]), .D5(tmds_ch2[5]), .D6(tmds_ch2[6]), .D7(tmds_ch2[7]), .D8(tmds_ch2[8]), .D9(tmds_ch2[9]));

  // Encode the 1-bit serial TMDS streams to Low-voltage differential signaling (LVDS) HDMI output pins. (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  // To understand TMDS and LVDS, see e.g. https://www.youtube.com/watch?v=3xZsTBEUkFI
  ELVDS_OBUF OBUFDS_clock(.I(hdmi_clk),       .O(hdmi_tx_p[3]), .OB(hdmi_tx_n[3]));
  ELVDS_OBUF OBUFDS_red  (.I(serial_tmds[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  ELVDS_OBUF OBUFDS_green(.I(serial_tmds[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  ELVDS_OBUF OBUFDS_blue (.I(serial_tmds[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
endmodule
