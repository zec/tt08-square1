# SPDX-FileCopyrightText: © 2024 Tiny Tapeout; © 2024 Zachary Catlin
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

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

    for i in range(DURATION):
      await ClockCycles(dut.clk, CLOCK_RATE)
      dut._log.info('...')
