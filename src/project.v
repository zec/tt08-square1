/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_zec_square1 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out[7] = 0;
  assign uio_out[6:0] = 7'b0;
  assign uio_oe  = 8'b1000_0000;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in};

  wire [1:0] R; // red component
  wire [1:0] G; // green component
  wire [1:0] B; // blue component
  wire vsync;   // VSync
  wire hsync;   // HSync

  wire [9:0] hpos; // X coordinate in frame
  wire [9:0] vpos; // Y coordinate in frame
  wire in_frame;

  hvsync_generator sync_gen(
      .clk(clk),
      .reset(~rst_n),
      .vsync(vsync),
      .hsync(hsync),
      .hpos(hpos),
      .vpos(vpos),
      .display_on(in_frame)
  );

  // Pinout of Tiny VGA Pmod:
  assign uo_out[0] = R[1];
  assign uo_out[1] = G[1];
  assign uo_out[2] = B[1];
  assign uo_out[3] = vsync;
  assign uo_out[4] = R[0];
  assign uo_out[5] = G[0];
  assign uo_out[6] = B[0];
  assign uo_out[7] = hsync;

/*
  wire [2:0] xyzzy;

  // The primitive polynomials used here for LSFR taps
  // are from Zierler and Brillhart,
  // "On primitive trinomials (mod 2)", Information and Control, 13, 541 (1968);
  // https://www.sciencedirect.com/science/article/pii/S001999586890973X
  // https://core.ac.uk/download/pdf/82424278.pdf

  lsfr #(22, 22'h20_0001) lsfr22(
    .clk(clk),
    .rst_n(rst_n),
    .random(xyzzy[0])
  );
  lsfr #(25, 25'h100_0004) lsfr25(
    .clk(clk),
    .rst_n(rst_n),
    .random(xyzzy[1])
  );
  lsfr #(21, 21'h10_0002) lsfr21(
    .clk(clk),
    .rst_n(rst_n),
    .random(xyzzy[2])
  );
*/

  // frame counter
  reg [8:0] frame_no;
  always @(posedge vsync) begin
    frame_no <= frame_no + 9'd1;
  end

  `define N_LAG 15

  wire [2:0] color_controls [(`N_LAG-1):0];
  assign color_controls[0]  = 3'b0_11;
  assign color_controls[1]  = 3'b1_11;
  assign color_controls[2]  = 3'b1_11;
  assign color_controls[3]  = 3'b1_10;
  assign color_controls[4]  = 3'b1_10;
  assign color_controls[5]  = 3'b1_10;
  assign color_controls[6]  = 3'b1_10;
  assign color_controls[7]  = 3'b1_01;
  assign color_controls[8]  = 3'b1_01;
  assign color_controls[9]  = 3'b1_01;
  assign color_controls[10] = 3'b1_01;
  assign color_controls[11] = 3'b1_01;
  assign color_controls[12] = 3'b1_01;
  assign color_controls[13] = 3'b1_01;
  assign color_controls[14] = 3'b1_01;

  wire [2:0] color_maybe [(`N_LAG-1):0];


  genvar i;

  generate
    for (i = 0; i < `N_LAG; i = i + 1) begin
      wire [8:0] delay = i;
      assign color_maybe[i] = (hpos[8:0] == (vpos[8:0] ^ (frame_no - delay))) ? color_controls[i] : 3'b0_00;
    end
  endgenerate

  wire [2:0] color;
/*
  genvar j;
  generate
    for (j = 0; j < 3; j = j + 1) begin
      assign color[j] = |{color_maybe[(`N_LAG-1):0][j]};
    end
  endgenerate
*/
  assign color[0] = color_maybe[0][0] | color_maybe[1][0] | color_maybe[2][0] | color_maybe[3][0] | color_maybe[4][0] | color_maybe[5][0] | color_maybe[6][0] | color_maybe[7][0] | color_maybe[8][0] | color_maybe[9][0] | color_maybe[10][0] | color_maybe[11][0] | color_maybe[12][0] | color_maybe[13][0] | color_maybe[14][0];
  assign color[1] = color_maybe[0][1] | color_maybe[1][1] | color_maybe[2][1] | color_maybe[3][1] | color_maybe[4][1] | color_maybe[5][1] | color_maybe[6][1] | color_maybe[7][1] | color_maybe[8][1] | color_maybe[9][1] | color_maybe[10][1] | color_maybe[11][1] | color_maybe[12][1] | color_maybe[13][1] | color_maybe[14][1];
  assign color[2] = color_maybe[0][2] | color_maybe[1][2] | color_maybe[2][2] | color_maybe[3][2] | color_maybe[4][2] | color_maybe[5][2] | color_maybe[6][2] | color_maybe[7][2] | color_maybe[8][2] | color_maybe[9][2] | color_maybe[10][2] | color_maybe[11][2] | color_maybe[12][2] | color_maybe[13][2] | color_maybe[14][2];
/*
  assign color[1] = |{color_maybe[(`N_LAG-1):0][1]};
  assign color[2] = |{color_maybe[(`N_LAG-1):0][2]};
*/


  assign R = ((vpos < 480) & (hpos < 512)) ? color[1:0] & {2{color[2]}} : 2'b00;
  assign G = ((vpos < 480) & (hpos < 512)) ? color[1:0] : 2'b00;
  assign B = ((vpos < 480) & (hpos < 512)) ? color[1:0] & {2{~color[2]}} : 2'b00;

endmodule
