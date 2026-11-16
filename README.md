# Configurable UART RTL Design & Verification

A synthesizable, modular UART transmitter/receiver written in Verilog HDL, with a portable self-checking SystemVerilog testbench and optional SVA checker.

## Features

- Separate TX and RX RTL modules and a top-level integration wrapper.
- Compile-time configurable clock frequency, baud rate, data width (5–9), parity (none/even/odd), and stop bits (1 or 2).
- LSB-first UART framing; idle/stop high and start low.
- Two-flop synchronizer on the asynchronous RX input.
- RX start-bit qualification at the half-bit point and data sampling at bit centers.
- Parity and framing error flags; `rx_valid` and `tx_done` are one-clock pulses.
- Portable directed plus pseudo-random loopback regression, scoreboard comparison, and scenario counters.
- Optional SystemVerilog Assertions for QuestaSim/VCS.

## RTL parameters

| Parameter | Meaning | Default |
|---|---|---:|
| `CLK_FREQ` | Input clock frequency in Hz | 50,000,000 |
| `BAUD_RATE` | UART baud rate in bits/s | 115,200 |
| `DATA_BITS` | Payload width, valid range 5..9 | 8 |
| `PARITY_MODE` | 0=None, 1=Even, 2=Odd | 0 |
| `STOP_BITS` | Stop-bit count, valid values 1 or 2 | 1 |

The integer divider is `CLKS_PER_BIT = CLK_FREQ / BAUD_RATE`. The actual baud rate is therefore `CLK_FREQ / floor(CLK_FREQ/BAUD_RATE)`; choose clock/baud combinations with acceptably small divider error. `CLKS_PER_BIT` must be at least 2.

## Interface summary

- TX: pulse `tx_start` for one rising edge while `tx_busy=0`; present `tx_data` at that edge. `tx_serial` idles high; `tx_done` pulses after the stop interval.
- RX: connect serial input to `rx_serial`. `rx_valid` pulses when a complete frame is received; `rx_data` holds the payload. `parity_error` and `framing_error` describe the most recently completed frame and clear when a new start is detected.
- Reset: active-low asynchronous `rst_n`.

## Quick start: open-source flow

Install Icarus Verilog and GTKWave, then from this directory:

```sh
make sim
# or
./scripts/run_iverilog.sh

# Full 30-configuration sweep (width 5..9, parity none/even/odd, stop bits 1/2)
./scripts/run_matrix.sh

# Open waveform after simulation
 gtkwave build/uart_system.vcd
```

The testbench uses a 10 MHz clock and 1 Mbaud to keep simulation short. It instantiates an 8-data-bit, even-parity, two-stop-bit configuration. Change the localparams in `tb/uart_system_tb.sv` to exercise other supported frame formats.

## Commercial simulator flows

### QuestaSim / ModelSim

From the `scripts` directory, run:

```tcl
do run_questa.do
```

### Synopsys VCS

From the project root:

```sh
./scripts/run_vcs.sh
```

The `formal/uart_sva.sv` checker is enabled by the supplied commercial-simulator scripts using `ENABLE_SVA`; it uses standard concurrent assertions. If your simulator/license configuration separates assertion support, compile it as a separate verification step.

## Suggested regression matrix

| Test | Data / condition | Expected result |
|---|---|---|
| Reset | Assert/deassert reset | TX idle high; no valid RX |
| Basic | `00`, `FF`, `AA`, `55` | Exact data match |
| Directed | `A5`, `3C` | Exact data match |
| Random | At least 24 random payloads | Exact data match |
| Parity | Run with `PARITY_MODE=0/1/2` | No parity error for legal frame |
| Width | Run with `DATA_BITS=5..9` | Correct payload width and value |
| Stop bits | Run with `STOP_BITS=1/2` | Valid frame completion |
| Back-to-back | Consecutive TX requests | No lost frame |
| Error injection | Corrupt parity or stop bit on an external RX stimulus | Corresponding error flag |

The included loopback regression directly checks the selected default test configuration. The matrix script runs all 30 combinations of supported payload width, parity mode and stop-bit count. External RX error-injection tests are still required before claiming full verification sign-off.

## Important engineering notes / known scope

1. This is a compact educational UART IP baseline, not a bus-mapped peripheral. FIFO, interrupt, RTS/CTS, programmable runtime registers and 16x majority-vote oversampling are not included.
2. TX and RX use the same compile-time clock/baud parameters. For two physically independent endpoints, instantiate each endpoint with its own local clock/baud settings.
3. RX synchronizes the asynchronous pin and samples near bit centers; it does not implement majority voting. Validate tolerance against the target clock error and baud mismatch.
4. The testbench contains portable scenario counters rather than IEEE covergroups, because Icarus Verilog does not implement all commercial SystemVerilog coverage features. Add covergroups in a simulator-supported extension if required.
5. Do not report simulation, synthesis, timing closure, or FPGA implementation as completed until the corresponding tool logs and results have actually been generated.

## Project tree

```text
rtl/       uart_tx.v, uart_rx.v, uart_top.v
tb/        uart_system_tb.sv
formal/    uart_sva.sv
scripts/   open-source, QuestaSim, and VCS run scripts
docs/      design and verification notes
```

## External learning references

See `docs/references.md`. Third-party repositories are learning references; this implementation is independently structured and should be reviewed, simulated, and adapted by the project team.
