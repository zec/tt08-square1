/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// A sonification of the logistic map (https://en.wikipedia.org/wiki/Logistic_map):
//
//         x_(n+1) := r * x_n * (1 - x_n)     (0 < x_n < 1, 1 < r < 4)
//
// as PWM audio.

module logistic_snd #(
  parameter N_OSC = 4,       // number of square-wave generators running

  parameter FREQ  = 30'd25_200_000, // frequency of clk (Hz)
  parameter LO_F  = 200,     // frequency corresponding to x_n = 0 (Hz)
  parameter HI_F  = 1200,    // frequency corresponding to x_n = 1 (Hz)

  parameter FRAC  = 8,       // fractional part of r, x

  parameter PHASE_BITS = 12, // number of bits in phase accumulators
  parameter FREQ_RES   = 0   // approximate frequency resolution
                             // of square-wave generators is 2^FREQ_RES Hz
) (
  input  wire clk,   // clock
  input  wire reset, // reset (active HIGH)
  output wire snd    // PWM audio
);

  // this section implements the logistic map, iterating once a clock,
  // and changing r every 30_000 clocks

  reg [(FRAC-1):0] x;   // the 'x' variable in 0.FRAC fixed-point
  wire [(FRAC-1):0] next_x; // the next value of 'x'

  reg [(2+FRAC-1):0] r; // the 'r' variable in 2.FRAC fixed-point
  wire increment_r;     // should we increment 'r'?

  logs_divider #(.N(30'd30_000)) r_increment_signal(
    .clk(clk),
    .reset(reset),
    .mod_n(increment_r)
  );

  parameter INITIAL_R = (1 << FRAC) | (1 << (FRAC - 4)); // 1.0625

  always @(posedge clk) begin
    if (reset) begin
      r <= INITIAL_R; // initialize 'r' to 1.0625
    end
    else begin
      if (increment_r) begin
        r <= (|r) ? INITIAL_R : r + 1;  // increment, wrapping from 4.0 to INITIAL_R
      end
    end
  end

  logs_iterate_map #(FRAC) iter(
    .x(x),
    .r(r),
    .next_x(next_x)
  );

  always @(posedge clk) begin
    if (reset) begin
      x <= (1 << (FRAC - 4)); // set 'x' to 0.0625
    end
    else begin
      x <= next_x;
    end
  end


  // this section implements the square-wave generators, the frequencies
  // being derived from values of 'x'

  // we make use of the fact that 25_200_000 is divisible by 128
  parameter LOW_FREQUENCY  = (LO_F << (PHASE_BITS + PHASE_DEC - 7)) / (FREQ >> 7);
  parameter HIGH_FREQUENCY = (HI_F << (PHASE_BITS + PHASE_DEC - 7)) / (FREQ >> 7);
  parameter FREQUENCY_INC  = HIGH_FREQUENCY - LOW_FREQUENCY;

  wire [(PHASE_BITS + FRAC - 1):0] low_frequency_w = LOW_FREQUENCY;
  wire [(PHASE_BITS + FRAC - 1):0] frequency_inc_w = FREQUENCY_INC;
  wire [(PHASE_BITS + FRAC - 1):0] x_scaled_product
    = low_frequency_w + (frequency_inc_w * {{(PHASE_BITS){1'b0}}, x});

  wire [(PHASE_BITS-2):0] scaled_x = x_scaled_product[(PHASE_BITS + FRAC - 2):FRAC];

  // the frequency registers for the NCOs
  reg [(PHASE_BITS-2):0] freq [(N_OSC-1):0];

  // which square wave's frequency should we update now?
  reg [($clog2(N_OSC)-1):0] f_counter;

  always @(posedge clk) begin
    f_counter <= (f_counter == (N_OSC-1)) ? 0 : f_counter + 1;
  end

  always @(posedge clk) begin
    freq[f_counter] <= scaled_x;
  end

  // the output of the square-wave generators
  wire [(N_OSC-1):0] osc;

  // log2(slowdown of phase accumulators from clk)
  parameter PHASE_DEC = $clog2(FREQ) - PHASE_BITS - FREQ_RES;

  wire nco_increment;
  logs_divider #(1 << PHASE_DEC) nco_increment_gen(
    .clk(clk),
    .reset(reset),
    .mod_n(nco_increment)
  );

  genvar i;
  generate
    for (i = 0; i < N_OSC; i = i + 1) begin
      logs_nco #(PHASE_BITS) n_c_oh_my(
        .clk(clk),
        .reset(reset),
        .step(nco_increment),
        .freq_in(freq[i]),
        .snd(osc[i])
      );
    end
  endgenerate


  // this section mixes the square waves and output the result!

  logs_mixer #(N_OSC, $clog2(N_OSC + 1)) mixer(
    .clk(clk),
    .reset(reset),
    .audio_in(osc),
    .audio_out(snd)
  );

endmodule
