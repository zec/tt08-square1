/*
 * Copyright (c) 2024 Zachary Catlin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// A sonification of the logistic map ()
// as PWM audio.

module logistic_snd #(
  parameter N_OSC = 4,
  parameter FREQ  = 30'd25_200_000, // frequency of clk (Hz)
  parameter LO_F  = 200,
  parameter HI_F  = 1200,
) (
  input  wire clk,   // clock
  input  wire reset, // reset (active HIGH)
  output wire snd,   // PWM audio
);

assign _unused = &{clk, reset};

assign snd = 0;

endmodule
