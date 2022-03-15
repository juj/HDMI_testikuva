// display_signal module converts a pixel clock into a hsync+vsync+disp_enable+x+y structure.

module display_signal #(
  H_RESOLUTION    = 640,
  V_RESOLUTION    = 480,
  H_FRONT_PORCH   = 16,
  H_SYNC          = 96,
  H_BACK_PORCH    = 48,
  V_FRONT_PORCH   = 10,
  V_SYNC          = 2,
  V_BACK_PORCH    = 33,
  H_SYNC_POLARITY = 0,   // 0: neg, 1: pos
  V_SYNC_POLARITY = 0    // 0: neg, 1: pos
)
(
  input  i_pixel_clk,
  input  i_reset,               // reset is active high
  output [2:0] o_hvesync,       // { display_enable, vsync, hsync} . hsync is active at desired H_SYNC_POLARITY and vsync is active at desired V_SYNC_POLARITY, display_enable is active high, low in blanking
  output o_frame_start,         // momentarily high during the first clock of a frame (when inside blanking/front porches)
  output reg signed [12:0] o_x, // horizontal beam position (including blanking)
  output reg signed [12:0] o_y  // vertical beam position (including blanking)
);

  localparam signed H_START       = -H_FRONT_PORCH - H_SYNC - H_BACK_PORCH;
  localparam signed HSYNC_START   = H_START + H_FRONT_PORCH;
  localparam signed HSYNC_END     = HSYNC_START + H_SYNC;
  localparam signed HACTIVE_START = 0;
  localparam signed HACTIVE_END   = H_RESOLUTION - 1;
  localparam signed V_START       = -V_FRONT_PORCH - V_SYNC - V_BACK_PORCH;
  localparam signed VSYNC_START   = V_START + V_FRONT_PORCH;
  localparam signed VSYNC_END     = VSYNC_START + V_SYNC;
  localparam signed VACTIVE_START = 0;
  localparam signed VACTIVE_END   = V_RESOLUTION - 1;

  // generate display_enable, vsync and hsync signals with desired polarity
  assign o_hvesync = { o_x >= 0 && o_y >= 0, // display enable is high when in visible picture area
                       1'(V_SYNC_POLARITY) ^ (o_y > VSYNC_START && o_y <= VSYNC_END),
                       1'(H_SYNC_POLARITY) ^ (o_x > HSYNC_START && o_x <= HSYNC_END) };

  // high for one pixel clock at the beginning of a new frame (inside hblank and vblank)
  assign o_frame_start = (o_y == V_START && o_x == H_START);

  always @(posedge i_pixel_clk) begin
    if (i_reset) begin
      o_x <= H_START;
      o_y <= V_START;
    end else begin
      if (o_x == HACTIVE_END) begin
        o_x <= H_START;
        o_y <= o_y == VACTIVE_END ? 13'(V_START) : o_y + 13'b1;
      end else
        o_x <= o_x + 13'b1;
    end
  end
endmodule
