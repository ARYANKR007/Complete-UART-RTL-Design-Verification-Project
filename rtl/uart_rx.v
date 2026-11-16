`timescale 1ns/1ps
module uart_rx #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer BAUD_RATE = 115200,
    parameter integer DATA_BITS = 8,
    parameter integer PARITY_MODE = 0, // 0:none, 1:even, 2:odd
    parameter integer STOP_BITS = 1
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 rx_serial,
    output reg [DATA_BITS-1:0]  rx_data,
    output reg                  rx_valid,
    output reg                  parity_error,
    output reg                  framing_error
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer COUNT_W = (CLKS_PER_BIT < 2) ? 1 : $clog2(CLKS_PER_BIT + 1);
    localparam integer DATA_COUNT_W = (DATA_BITS < 2) ? 1 : $clog2(DATA_BITS + 1);
    localparam integer STOP_COUNT_W = (STOP_BITS < 2) ? 1 : $clog2(STOP_BITS + 1);
    localparam [2:0] S_IDLE=3'd0, S_START=3'd1, S_DATA=3'd2, S_PARITY=3'd3, S_STOP=3'd4;

    reg rx_meta, rx_sync;
    reg [2:0] state;
    reg [COUNT_W-1:0] baud_count;
    reg [DATA_BITS-1:0] shift_reg;
    reg [DATA_COUNT_W-1:0] bit_count;
    reg [STOP_COUNT_W-1:0] stop_count;
    reg parity_sample;

`ifndef SYNTHESIS
    initial begin
        if (CLK_FREQ <= 0 || BAUD_RATE <= 0 || CLKS_PER_BIT < 2)
            $error("uart_rx: invalid clock/baud configuration");
        if (DATA_BITS < 5 || DATA_BITS > 9) $error("uart_rx: DATA_BITS must be 5..9");
        if (PARITY_MODE < 0 || PARITY_MODE > 2) $error("uart_rx: PARITY_MODE must be 0,1,2");
        if (STOP_BITS < 1 || STOP_BITS > 2) $error("uart_rx: STOP_BITS must be 1 or 2");
    end
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rx_meta <= 1'b1; rx_sync <= 1'b1; end
        else begin rx_meta <= rx_serial; rx_sync <= rx_meta; end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; baud_count <= 0; shift_reg <= 0; bit_count <= 0;
            stop_count <= 0; parity_sample <= 0; rx_data <= 0; rx_valid <= 0;
            parity_error <= 0; framing_error <= 0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    baud_count <= 0; bit_count <= 0; stop_count <= 0;
                    if (!rx_sync) begin state <= S_START; parity_error <= 1'b0; framing_error <= 1'b0; end
                end
                S_START: begin
                    if (baud_count == (CLKS_PER_BIT/2)-1) begin
                        baud_count <= 0;
                        if (!rx_sync) begin state <= S_DATA; bit_count <= 0; end
                        else state <= S_IDLE; // reject a glitch
                    end else baud_count <= baud_count + 1'b1;
                end
                S_DATA: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0; shift_reg[bit_count] <= rx_sync;
                        if (bit_count == DATA_BITS-1) begin
                            if (PARITY_MODE != 0) state <= S_PARITY;
                            else begin state <= S_STOP; stop_count <= 0; end
                        end else bit_count <= bit_count + 1'b1;
                    end else baud_count <= baud_count + 1'b1;
                end
                S_PARITY: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0; parity_sample <= rx_sync; state <= S_STOP; stop_count <= 0;
                    end else baud_count <= baud_count + 1'b1;
                end
                S_STOP: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0;
                        if (!rx_sync) framing_error <= 1'b1;
                        if (stop_count == STOP_BITS-1) begin
                            rx_data <= shift_reg;
                            rx_valid <= 1'b1;
                            if (PARITY_MODE == 1) parity_error <= (parity_sample != (^shift_reg));
                            else if (PARITY_MODE == 2) parity_error <= (parity_sample != (~^shift_reg));
                            else parity_error <= 1'b0;
                            state <= S_IDLE;
                        end else stop_count <= stop_count + 1'b1;
                    end else baud_count <= baud_count + 1'b1;
                end
                default: begin state <= S_IDLE; baud_count <= 0; end
            endcase
        end
    end
endmodule
