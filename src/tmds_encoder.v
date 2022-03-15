// tmds_encoder performs Transition-minimized differential signaling (TMDS) encoding of
// 8-bits of pixel data and 2-bits of control data to a 10-bit TMDS encoded format.
// Requires synthesizing with System Verilog 2017.
module tmds_encoder(
  input i_hdmi_clk,         // HDMI pixel clock
  input i_reset,            // reset (active high)
  input [7:0] i_data,       // Input 8-bit color
  input [1:0] i_ctrl,       // control data (vsync and hsync)
  input i_display_enable,   // high=pixel data active. low=display is in blanking area
  output reg [9:0] o_tmds   // encoded 10-bit TMDS data
);
  wire [1:0] ctrl = {2{~i_reset}} & i_ctrl; // Clear control data if in reset state
  wire blank = i_reset | ~i_display_enable; // If high, send blank data (in reset or in image blank)
  wire parity = {$countones(i_data), !i_data[0]} > 8;

  wire [7:0] enc; // intermediate encoded data packet
  assign enc[0] = i_data[0];
  assign enc[1] = parity ^ enc[0] ^ i_data[1];
  assign enc[2] = parity ^ enc[1] ^ i_data[2];
  assign enc[3] = parity ^ enc[2] ^ i_data[3];
  assign enc[4] = parity ^ enc[3] ^ i_data[4];
  assign enc[5] = parity ^ enc[4] ^ i_data[5];
  assign enc[6] = parity ^ enc[5] ^ i_data[6];
  assign enc[7] = parity ^ enc[6] ^ i_data[7];

  wire [3:0] ones = $countones(enc);
  wire [3:0] zeros = 4'b1000 - ones[3:0];

  // current 1 vs 0 balance, and bias of previously sent data
  wire signed [4:0] balance = $signed({1'b0,ones}) - $signed({1'b0,zeros});
  reg signed [4:0] bias;
  wire bias_vs_balance = bias[4] == balance[4]; // track if balance is going away or towards bias

  always @(posedge i_hdmi_clk) begin
    if (blank) begin
      o_tmds <= {~ctrl[1], 9'b101010100} ^ {10{ctrl[0]}};
      bias <= 0;
    end else begin // encode pixel colour data with at most 5 bit 0<->1 transitions
      if (bias == 0 || balance == 0) begin
        o_tmds <= {10{parity}} ^ {2'b01, enc};
        bias <= parity ? bias - balance : bias + balance;
      end else begin
        o_tmds <= {bias_vs_balance, ~parity, {8{bias_vs_balance}} ^ enc};
        bias <= bias + ({5{bias_vs_balance}} ^ balance) + {3'b0, bias_vs_balance^parity, bias_vs_balance};
      end
    end
  end
endmodule
