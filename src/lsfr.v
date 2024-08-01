/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


// A standard Fibonacci linear-feedback shift register (LSFR)
// for pseudo-random number generation.

module lsfr #(
  parameter BITS = 3,   // length of shift register
  parameter TAPS = 3'h5 // taps (non-constant terms of primitive polynomial of order BITS in GF(2))
) (
  input  wire clk,    // clock
  input  wire rst_n,  // reset (active LOW)
  output wire random  // random bits, one per clock cycle
);

reg [(BITS-1):0] shf_reg; // the shift register

// we don't care what the initial contents of shf_reg are,
// so long as they aren't all zero, so apart from
// shf_reg[0], we don't bother initializing.

always @(posedge clk) begin
  shf_reg[(BITS-1):1] <= shf_reg[(BITS-2):0];
  shf_reg[0] <= (rst_n) ? ^(shf_reg & TAPS) : 1;
end

assign random = shf_reg[BITS-1];

endmodule
