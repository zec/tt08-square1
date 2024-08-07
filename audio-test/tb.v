`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();


  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  wire snd_out;

  logistic_snd #(
    .N_OSC(8),
    .ITER_LEN(15_361),
    .R_INC(2),
    .FRAC(16),
    .PHASE_BITS(16),
    .FREQ_RES(0)
  ) project_audio (
    .clk(clk),
    .reset(~rst_n),
    .snd(snd_out)
  );

endmodule
