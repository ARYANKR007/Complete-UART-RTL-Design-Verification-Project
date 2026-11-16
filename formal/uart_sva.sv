// Optional SystemVerilog Assertions. Compile with QuestaSim or Synopsys VCS.
// Bind this checker to a testbench instance or instantiate it with DUT signals.
module uart_sva_checker (
    input logic clk, rst_n, tx_serial, tx_busy, tx_done,
    input logic rx_valid
);
    default clocking cb @(posedge clk); endclocking
    property tx_idle_high;
        disable iff (!rst_n) (!tx_busy) |-> tx_serial;
    endproperty
    assert property (tx_idle_high) else $error("UART TX must be high while idle");

    property tx_done_not_busy;
        disable iff (!rst_n) tx_done |-> !tx_busy;
    endproperty
    assert property (tx_done_not_busy) else $error("tx_done and tx_busy overlap");

    property rx_valid_is_pulse;
        disable iff (!rst_n) rx_valid |=> !rx_valid;
    endproperty
    assert property (rx_valid_is_pulse) else $error("rx_valid must be a one-cycle pulse");
endmodule
