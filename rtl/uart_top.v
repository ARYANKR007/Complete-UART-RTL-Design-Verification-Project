`timescale 1ns/1ps
module uart_top #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer BAUD_RATE = 115200,
    parameter integer DATA_BITS = 8,
    parameter integer PARITY_MODE = 0, // 0:none, 1:even, 2:odd
    parameter integer STOP_BITS = 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tx_start,
    input  wire [DATA_BITS-1:0] tx_data,
    output wire tx_serial,
    input  wire rx_serial,
    output wire [DATA_BITS-1:0] rx_data,
    output wire tx_busy,
    output wire tx_done,
    output wire rx_valid,
    output wire parity_error,
    output wire framing_error
);
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .DATA_BITS(DATA_BITS),
              .PARITY_MODE(PARITY_MODE), .STOP_BITS(STOP_BITS)) u_tx (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start), .tx_data(tx_data),
        .tx_serial(tx_serial), .tx_busy(tx_busy), .tx_done(tx_done)
    );
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .DATA_BITS(DATA_BITS),
              .PARITY_MODE(PARITY_MODE), .STOP_BITS(STOP_BITS)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx_serial(rx_serial), .rx_data(rx_data),
        .rx_valid(rx_valid), .parity_error(parity_error), .framing_error(framing_error)
    );
endmodule
