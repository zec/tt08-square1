/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// performs one iteration of the logistic map

module logs_iterate_map #(
  parameter FRAC = 4
) (
  input  [(FRAC-1):0]   wire x,
  input  [(2+FRAC-1):0] wire r,
  output [(FRAC-1):0]   wire next_x
);
  wire [(FRAC-1):0] zero_pad = 0;
  wire [(2*FRAC-1):0] intermediate_product;
  wire [(2*FRAC-1):0] final_product;

  // multiply x with (1 - x)
  assign intermediate_product = {zero_pad, x} * ~{zero_pad, x};

  // now, multiply (x * (1 - x)) with r
  assign final_product = {zero_pad[(FRAC-1):2], r} * {zero_pad, intermediate_product[(2*FRAC-1):FRAC]};

  assign next_x = final_product[(2*FRAC-1):FRAC];
endmodule
