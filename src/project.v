/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_zec_demo (
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

  // basic Munching Squares demo
  reg [8:0] frame_no;
  always @(posedge vsync) begin
    frame_no <= frame_no + 9'd1;
  end

  wire [8:0] x_plot = vpos[8:0] ^ frame_no;
  wire [8:0] x_plot2 = vpos[8:0] ^ (frame_no - 9'd5);
  wire [8:0] x_plot3 = vpos[8:0] ^ (frame_no - 9'd10);

  assign R = ((vpos < 480) & (hpos < 512)) ? (hpos[8:0] == x_plot) ? 2'b11 : (hpos[8:0] == x_plot2) ? 2'b10 : (hpos[8:0] == x_plot3) ? 2'b01 : 2'b00 : 2'b00;
  assign G = ((vpos < 480) & (hpos < 512)) ? (hpos[8:0] == x_plot) ? 2'b11 : (hpos[8:0] == x_plot2) ? 2'b10 : (hpos[8:0] == x_plot3) ? 2'b01 : 2'b00 : 2'b00;
  assign B = ((vpos < 480) & (hpos < 512)) ? (hpos[8:0] == x_plot) ? 2'b11 :  2'b00 : 2'b00;

endmodule
