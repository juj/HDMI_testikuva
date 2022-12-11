// top: Generates a test picture on HDMI output.

module top(
  input clk,
  input reset_button,

  // HDMI output pins: ch0, ch1, ch2 and clock
  output [3:0] hdmi_tx_n,
  output [3:0] hdmi_tx_p
);

  wire hdmi_clk;                   // 25.2MHz. (HDMI pixel clock for 640x480@60Hz would ideally be 25.175MHz)
  wire hdmi_clk_5x;                // 126MHz. 5x pixel clock for 10:1 DDR serialization
  wire hdmi_clk_lock;              // true when PLL lock has been established

  // Produce a 5x HDMI clock for pixel serialization (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  // CLKOUT frequency=(FCLKIN*(FBDIV_SEL+1))/(IDIV_SEL+1) = 27*(13+1)/(2+1) = 126 MHz
  rPLL #(
    .FCLKIN("27"),
    .FBDIV_SEL(13),
    .IDIV_SEL(2)
  )hdmi_pll(/*unused pins:*/
	    .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(), 
	    .RESET(1'b0), .RESET_P(1'b0), 
	    .CLKFB(1'b0), 
	    .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), 
	    .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
	
	    /* used pins*/
	    .CLKIN(clk),
	    .CLKOUT(hdmi_clk_5x),
	    .LOCK(hdmi_clk_lock)
  );

  // Divide the 5x HDMI clock to produce the 1x HDMI clock (Gowin FPGA Designer/Sipeed Tang Nano 4K specific module)
  CLKDIV #(.DIV_MODE("5"), .GSREN("false")) hdmi_clock_div(.CLKOUT(hdmi_clk), .HCLKIN(hdmi_clk_5x), .RESETN(hdmi_clk_lock), .CALIB(1'b1));

  wire reset = ~hdmi_clk_lock | ~reset_button;
  wire signed [12:0] x, y;        // horizontal and vertical screen position (signed), -4096 - +4095
  wire [2:0] hve_sync;            // pack the image sync signals to one vector: { display enable, vsync, hsync }

  // Generate a display sync signal on top of the HDMI pixel clock.
  display_signal #(               // 640x480  800x600 1280x720 1920x1080
      .H_RESOLUTION(640),         //     640      800     1280      1920
      .V_RESOLUTION(480),         //     480      600      720      1080
      .H_FRONT_PORCH(16),         //      16       40      110        88
      .H_SYNC(96),                //      96      128       40        44
      .H_BACK_PORCH(48),          //      48       88      220       148
      .V_FRONT_PORCH(10),         //      10        1        5         4
      .V_SYNC(2),                 //       2        4        5         5
      .V_BACK_PORCH(33),          //      33       23       20        36
      .H_SYNC_POLARITY(0),        //       0        1        1         1
      .V_SYNC_POLARITY(0)         //       0        1        1         1
  )ds(
    .i_pixel_clk(hdmi_clk),
    .i_reset(reset),
    .o_hvesync(hve_sync),
    .o_frame_start(),
    .o_x(x),
    .o_y(y)
  );

  wire [23:0] rgb; // rgb[7:0] is red, rgb[23:16] is blue.

  // Generate a test picture pattern
  test_pattern t(
    .i_clk(hdmi_clk),
    .i_disp_enable(hve_sync[2]),
    .x(x),
    .y(y),
    .o_rgb(rgb));

  // Produce HDMI output
  hdmi hdmi_out(
    .reset(reset),
    .hdmi_clk(hdmi_clk),
    .hdmi_clk_5x(hdmi_clk_5x),
    .hve_sync(hve_sync),
    .rgb(rgb),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_tx_p(hdmi_tx_p));

endmodule
