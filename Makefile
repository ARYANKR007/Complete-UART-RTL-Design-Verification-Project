IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
RTL = rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v
TB = tb/uart_system_tb.sv

.PHONY: all sim lint clean
all: sim

sim:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s uart_system_tb -o build/uart_sim $(RTL) $(TB)
	$(VVP) build/uart_sim

lint:
	$(VERILATOR) --lint-only -Wall -Wno-fatal --top-module uart_top $(RTL)

clean:
	rm -rf build
