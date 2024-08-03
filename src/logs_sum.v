/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// sets `sum` to the sum of the NADDENDS `addends`

module logs_sum #(
  parameter NBITS    = 3,
  parameter NADDENDS = 6
) (
  input  wire [(NADDENDS-1):0][(NBITS-1):0] addends,  // the numbers to sum
  output wire [(NBITS-1):0]                 sum       // the resulting sum
);
  parameter HALF = NADDENDS / 2;

  generate
    if (NADDENDS == 0)
      assign sum = 0;
    else if (NADDENDS == 1)
      assign sum = addends[0];
    else if (NADDENDS == 2)
      assign sum = addends[0] + addends[1];
    else begin
      wire [(NBITS-1):0] a;
      wire [(NBITS-1):0] b;

      logs_sum #(NBITS, HALF) low (
        .addends(addends[(HALF-1):0]),
        .sum(a)
      );
      logs_sum #(NBITS, (NADDENDS-HALF)) high (
        .addends(addends[(NADDENDS-1):HALF]),
        .sum(b)
      );
      assign sum = a + b;
    end
  endgenerate

endmodule
