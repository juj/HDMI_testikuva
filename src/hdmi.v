// hdmi module implements HDMI output using the DVI-backwards compatible bitstream.

module hdmi(
  input hdmi_clk,
  input hdmi_clk_5x,
  input [2:0] hve_sync, // Image sync signals: { display_enable, vsync, hsync }
  input [7:0] rgb[2:0],
  input reset,

  output [3:0] hdmi_tx_n,
  output [3:0] hdmi_tx_p
);
  // Encode vsync, hsync, blanking and rgb data to Transition-minimized differential signaling (TMDS) format.
  wire [9:0] tmds_ch0, tmds_ch1, tmds_ch2;
  tmds_encoder encode_ch0(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[2]), .i_ctrl(hve_sync[1:0]), .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch0));
  tmds_encoder encode_ch1(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[1]), .i_ctrl(2'b00),         .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch1));
  tmds_encoder encode_ch2(.i_hdmi_clk(hdmi_clk), .i_reset(reset), .i_data(rgb[0]), .i_ctrl(2'b00),         .i_display_enable(hve_sync[2]), .o_tmds(tmds_ch2));

  // Serialize the three 10-bit TMDS channels to four serial 1-bit TMDS streams. (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  wire serial_tmds[4];
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c0(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[0]), .D0(tmds_ch0[0]), .D1(tmds_ch0[1]), .D2(tmds_ch0[2]), .D3(tmds_ch0[3]), .D4(tmds_ch0[4]), .D5(tmds_ch0[5]), .D6(tmds_ch0[6]), .D7(tmds_ch0[7]), .D8(tmds_ch0[8]), .D9(tmds_ch0[9]));
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c1(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[1]), .D0(tmds_ch1[0]), .D1(tmds_ch1[1]), .D2(tmds_ch1[2]), .D3(tmds_ch1[3]), .D4(tmds_ch1[4]), .D5(tmds_ch1[5]), .D6(tmds_ch1[6]), .D7(tmds_ch1[7]), .D8(tmds_ch1[8]), .D9(tmds_ch1[9]));
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c2(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[2]), .D0(tmds_ch2[0]), .D1(tmds_ch2[1]), .D2(tmds_ch2[2]), .D3(tmds_ch2[3]), .D4(tmds_ch2[4]), .D5(tmds_ch2[5]), .D6(tmds_ch2[6]), .D7(tmds_ch2[7]), .D8(tmds_ch2[8]), .D9(tmds_ch2[9]));
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c3(.PCLK(hdmi_clk), .FCLK(hdmi_clk_5x), .RESET(reset), .Q(serial_tmds[3]), .D0(1'b1),        .D1(1'b1),        .D2(1'b1),        .D3(1'b1),        .D4(1'b1),        .D5(1'b0),        .D6(1'b0),        .D7(1'b0),        .D8(1'b0),        .D9(1'b0));

  // Encode the 1-bit serial TMDS streams to Low-voltage differential signaling (LVDS) HDMI output pins. (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  TLVDS_OBUF OBUFDS_clock(.I(serial_tmds[3]), .O(hdmi_tx_p[3]), .OB(hdmi_tx_n[3]));
  TLVDS_OBUF OBUFDS_red  (.I(serial_tmds[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  TLVDS_OBUF OBUFDS_green(.I(serial_tmds[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  TLVDS_OBUF OBUFDS_blue (.I(serial_tmds[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
endmodule
