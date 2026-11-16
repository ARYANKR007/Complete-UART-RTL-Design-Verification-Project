transcript on
if {[file exists work]} {vdel -lib work -all}
vlib work
vlog -sv +define+ENABLE_SVA ../rtl/uart_tx.v ../rtl/uart_rx.v ../rtl/uart_top.v ../tb/uart_system_tb.sv ../formal/uart_sva.sv
vsim -voptargs=+acc work.uart_system_tb
add wave -r /*
run -all
