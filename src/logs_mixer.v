/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// mixer: sums the input lines, then uses that to drive a PWM

module logs_mixer #(
  parameter N = 1,   // number of audio inputs
  parameter K = 2    // PWM effectively divides the output by 2^K
) (
  input  wire clk,      // clock
  input  wire reset,    // reset (active HIGH)
  input  wire [(N-1):0] audio_in, // input audio lines
  output reg  audio_out // output audio line
);
  // PWM counter
  reg [(K-1):0] counter;

  wire [(K-1):0] sum;
  wire [(K-1):0] sum_inputs [(N-1):0];

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin
      assign sum_inputs[i] = {{(K-1){1'b0}}, audio_in[i]};
    end
  endgenerate

  logs_sum #(
    .NBITS(K),
    .NADDENDS(N)
  ) popcount (
    .addends(sum_inputs),
    .sum(sum)
  );

  always @(posedge clk) begin
    if (reset) begin
      audio_out <= 0;
      counter <= 0;
    end
    else begin
      audio_out <= (sum < counter);
      counter <= counter + 1;
    end
  end
endmodule
