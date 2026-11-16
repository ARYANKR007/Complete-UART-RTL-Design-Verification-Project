# Design and verification notes

## UART frame

A frame is transmitted as: idle-high, start-low, `DATA_BITS` payload bits LSB first, optional parity, then one or two high stop bits. Both endpoints must agree on baud rate and frame format.

## Baud timing

The design uses an integer clock divider. For example, 10 MHz / 1 MHz gives 10 clocks per bit in the simulation. For a 50 MHz clock and 115200 baud, integer division gives 434 clocks per bit, corresponding to approximately 115207.4 baud.

## TX FSM

- `IDLE`: wait for `tx_start`, latch payload and parity.
- `START`: hold serial low for one bit interval.
- `DATA`: shift payload LSB first, one bit interval each.
- `PARITY`: emit selected parity bit when enabled.
- `STOP`: hold high for configured stop-bit interval, then pulse `tx_done`.

## RX FSM

- Synchronize asynchronous input through two flip-flops.
- `IDLE`: detect a low start candidate.
- `START`: wait half a bit and reject a false start if line is high.
- `DATA`: sample each payload bit one bit interval apart.
- `PARITY`: sample optional parity.
- `STOP`: check stop level(s), publish payload and pulse `rx_valid`.

## Verification components

The portable testbench acts as a transaction source, drives TX, observes RX, and compares received payload against expected data. Directed patterns include all-zero, all-one and alternating-bit payloads; additional directed and pseudo-random payloads are included. Scenario counters provide a simple coverage summary. `formal/uart_sva.sv` contains optional concurrent assertions for key interface properties.

## Before final defense

- Run the regression on at least one simulator and retain the complete transcript and VCD.
- Run a parameter matrix for all supported data widths, parity modes and stop-bit counts.
- Add external RX error-injection tests for bad parity and low stop bits.
- Run lint and synthesis with the available toolchain; archive logs and record tool versions.
- Update the report with measured results only. The source files alone do not constitute proof of successful simulation or synthesis.
