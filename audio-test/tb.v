`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can convert it to audio later.
  initial begin
    $dumpfile("logistic_snd.vcd");
    $dumpvars(0, snd_out);
  end

  // Wire up the inputs and outputs:
  reg clk = 0;
  reg rst_n = 0;
  wire snd_out;

  initial begin
    clk = 0;
    while (1) begin
      #1
      clk = ~clk;
    end
  end

  initial begin
    rst_n = 0;
    #9.5
    rst_n = 1;
  end

  integer n = 0;
  initial begin
    while (n < 120) begin
      $display("t = %d", n);
      #25200000
      $display(".");
      #25200000
      n = n + 1;
    end
    $finish;
  end

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
