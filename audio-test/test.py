# SPDX-FileCopyrightText: © 2024 Tiny Tapeout; © 2024 Zachary Catlin
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import wave

CLOCK_RATE = 25200000
DURATION = 120

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 1 us (1 MHz)
    clock = Clock(dut.clk, 1, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)

    dut.rst_n.value = 1
    dut._log.info("Capture audio")

    w = wave.open('logistic_snd.wav', mode='wb')
    w.setparams((1, 1, CLOCK_RATE, CLOCK_RATE * DURATION, 'NONE', 'not compressed'))

    buf = bytearray()
    n_writes = 0

    for i in range(CLOCK_RATE * DURATION):
      await ClockCycles(dut.clk, 1)
      buf.append(255 if dut.snd_out.value != 0 else 0)

      if len(buf) >= 2097152:
        w.writeframes(buf)
        buf.clear()

        n_writes += 1
        if (n_writes % 12) == 0:
          dut._log.info('...')
