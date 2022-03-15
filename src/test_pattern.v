// test_pattern module generates a test picture that looks like the Telefunken FuBK standard: https://fi.wikipedia.org/wiki/Testikuva

module test_pattern #(
  H_RESOLUTION = 640,
  V_RESOLUTION = 480
)
(
  input i_clk,
  input i_disp_enable,
  input [12:0] x,
  input [12:0] y,
  output reg [7:0] o_rgb[2:0]);

  wire [12:0] i_x = x * 13'd2 / 13'd5; // * 256 / H_RESOLUTION
  wire [12:0] i_y = y * 13'd2 / 13'd5; // * 192 / V_RESOLUTION

  localparam signed CIRCLE_X = 13'd130;
  localparam signed CIRCLE_Y = 13'd96;

  reg [16:0] x_grid;
  reg [16:0] y_grid;
  reg [20:0] circle;
  reg grid;
  reg [12:0] xcell;
  reg [12:0] ycell;
  reg [12:0] block5;
  reg [12:0] block10;
  reg outerblock;
  reg yellow;
  reg red;
  reg blue;
  reg spike;
 
  // somewhat ad hoc code to generate the test picture based on image x,y coordinates.
  always @(posedge i_clk) begin
    if (i_disp_enable) begin
      x_grid <= {8'b0, i_x} + 1;
      y_grid <= {8'b0, i_y} + 8;
      circle <= ({8'b0, i_x}-CIRCLE_X)*({8'b0, i_x}-CIRCLE_X) + ({8'b0, i_y}-CIRCLE_Y)*({8'b0, i_y}-CIRCLE_Y);
      xcell <= (i_x - 13'd52) * 13'd2 / 13'd13;
      ycell <= (i_y - 13'd32) / 13'd13;
      block10 <= (i_x - 13'd52) * 13'd2 / 13'd31;
      block5 <= (i_x - 13'd52) / 13'd31;
      outerblock <= (i_x < 52 || i_x > 206 || i_y < 32 || i_y > 160);
      grid <= ((x_grid % 13) == 0 || (y_grid % 13) == 0)
           && outerblock
           || i_y == 96 || (i_x == 129 && i_y > 70 && i_y < 123)
                        || (circle >= 7400 && circle <= 7600)
           || (block5 == 0 || block5 == 4) && (ycell == 5)
           || ycell == 7 && !outerblock
           || (block5 == 1 && ycell >= 3 && ycell <= 4 && i_x % 2 == 0 && (i_x+i_y) % 3 == 0)
           || (block5 == 2 && ycell >= 3 && ycell <= 4 && ((i_x^i_y) & 1) == 0)
           || (block5 == 3 && ycell >= 3 && ycell <= 4 && ((i_x^i_y) & 2) == 0)
           || (block5 == 4 && ycell >= 3 && ycell <= 4)

           || block10-1 < 2 && ycell == 6 && !i_x[2]
           || block10 > 2 && block10 < 5 && ycell == 6 && i_x[1]
           || block10 >= 5 && block10 < 7 && ycell == 6 && i_x[0]

           || (xcell >= 16 && xcell <= 23 && ycell >= 8 && ycell <= 9 && ((i_x^i_y) & 1) == 0)

           || (block10 == 0 && ycell == 6)
           || (i_x > 202 && i_x < 209 && ycell == 6);

      yellow <= (i_x > 160 && i_x <= 202 && ycell == 6);

      red <= ycell == 8
             && ((xcell <= 5)
             || (xcell >= 6 && xcell <= 10 && (i_x^i_y) % 2 == 0));

      blue <= ycell == 9
             && ((xcell <= 5)
             || (xcell >= 6 && xcell <= 10 && (i_x^i_y) % 2 == 0));
      
      spike <= i_x > 126 && i_y > 122 && (i_x*4+i_y < 645);
    end
  end

  // Assign each color bit to individual wires.
  wire r = i_disp_enable & !spike & ((grid || (!outerblock && ycell < 3 && (xcell < 6 || (xcell >= 12 && xcell <= 17)))) || yellow || red);
  wire g = i_disp_enable & !spike & ((grid || (!outerblock && ycell < 3 && xcell < 12)) || yellow);
  wire b = i_disp_enable & !spike & ((grid || (!outerblock && ycell < 3 && xcell % 6 < 3)) || blue);

  // Output 1-bit RGB (no real reason for 1-bit, just the test bench simulator I originally wrote this on only supported 1-bit RGB)
  assign o_rgb   = { {8{b}}, {8{g}}, {8{r}} };

endmodule
