#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
vcs -full64 -sverilog +define+ENABLE_SVA -debug_access+all \
  rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v \
  tb/uart_system_tb.sv formal/uart_sva.sv \
  -top uart_system_tb -o build/simv
./build/simv
