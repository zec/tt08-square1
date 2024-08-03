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
    = low_frequency + (frequency_inc_w * {{(PHASE_BITS){1'b0}}, x});

  wire [(PHASE_BITS-2):0] scaled_x = x_scaled_product[(PHASE_BITS + FRAC - 2):FRAC];

  // the frequency registers for the NCOs
  reg [(N_OSC-1):0][(PHASE_BITS-2):0] freq;

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
        .snd(osc)
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


// mixer: sums the input lines, then uses that to drive a PWM

module logs_mixer #(
  parameter N = 1,   // number of audio inputs
  parameter K = 2    // PWM effectively divides the output by 2^K
) (
  input           wire clk,      // clock
  input           wire reset,    // reset (active HIGH)
  input [(N-1):0] wire audio_in, // input audio lines
  output          reg  audio_out // output audio line
);
  // PWM counter
  reg [(K-1):0] counter;

  wire [(K-1):0] sum;
  wire [(N-1):0][(K-1):0] sum_inputs;

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin
      assign sum_inputs[i] = {(K-1){1'b0}, audio_in[i]};
    end
  endgenerate

  logs_sum popcount #(
    .NBITS(K),
    .NADDENDS(N)
  ) (
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


// numerically-controlled oscillator: generates a square wave
// of frequency f(clk) * (freq_in / 2^N)

module logs_nco #(
  parameter N = 5   // number of bits in phase accumulator
) (
  input           wire clk,     // clock
  input           wire reset,   // reset (active HIGH)
  input           wire step,    // whether to step our logic
  input [(N-2):0] wire freq_in, // frequency (in units of [frequency of clock] / 2^N)
  output          reg  snd      // square wave out
);

  // our phase accumulator
  reg [(N-1):0] phase;

  always @(posedge clk) begin
    if (reset) begin
      phase <= 0;
      snd <= 0;
    end
    else if (step) begin
      snd <= phase[N-1];
      phase <= phase + {0,freq_in};
    end
  end
endmodule


// generates a pulse once every N clocks

module logs_divider #(
  parameter N = 2
) (
  input  wire clk,    // clock
  input  wire reset,  // reset (active HIGH)
  output reg  mod_n   // output (HIGH once every N clocks)
);

  parameter NBITS = $clog2(N);
  reg [(NBITS-1):0] counter;

  always @(posedge clk) begin
    if (reset) begin
      counter <= 0;
      mod_n <= 0;
    end
    else begin
      mod_n   <= ~|counter; // "counter == 0"
      counter <= (counter >= (N-1)) ? 0 : counter + 1;
    end
  end
);
