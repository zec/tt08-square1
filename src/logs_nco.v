/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// numerically-controlled oscillator: generates a square wave
// of frequency f(step) * (freq_in / 2^N)

module logs_nco #(
  parameter N = 5,  // number of bits in phase accumulator
  parameter I = 0   // index of oscillator
) (
  input  wire clk,     // clock
  input  wire reset,   // reset (active HIGH)
  input  wire step,    // whether to step our logic
  input  wire [(N-2):0] freq_in, // frequency (in units of [frequency of clock] / 2^N)
  output reg  snd      // square wave out
);

  // our phase accumulator
  reg [(N-1):0] phase;

  // pseudo-random number; initial value is the seed
  integer initial_phase = 32'hd1bd_81eb;
  integer j;

  // iterate through Marsaglia's xorshift32 to get the value of initial_phase
  // for oscillator I
  initial begin
    for (j = 0; j < I; j = j + 1) begin
      initial_phase = (initial_phase ^ (initial_phase << 13)) & 32'hffff_ffff;
      initial_phase = (initial_phase ^ (initial_phase >> 17)) & 32'hffff_ffff;
      initial_phase = (initial_phase ^ (initial_phase << 5)) & 32'hffff_ffff;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      phase <= initial_phase[(N-1):0];
      snd <= 0;
    end
    else if (step) begin
      snd <= phase[N-1];
      phase <= phase + {1'b0,freq_in};
    end
  end
endmodule
