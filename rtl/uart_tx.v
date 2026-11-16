`timescale 1ns/1ps
module uart_tx #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer BAUD_RATE = 115200,
    parameter integer DATA_BITS = 8,
    parameter integer PARITY_MODE = 0, // 0:none, 1:even, 2:odd
    parameter integer STOP_BITS = 1
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  tx_start,
    input  wire [DATA_BITS-1:0]  tx_data,
    output reg                   tx_serial,
    output reg                   tx_busy,
    output reg                   tx_done
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer COUNT_W = (CLKS_PER_BIT < 2) ? 1 : $clog2(CLKS_PER_BIT + 1);
    localparam integer DATA_COUNT_W = (DATA_BITS < 2) ? 1 : $clog2(DATA_BITS + 1);
    localparam integer STOP_COUNT_W = (STOP_BITS < 2) ? 1 : $clog2(STOP_BITS + 1);
    localparam [2:0] S_IDLE=3'd0, S_START=3'd1, S_DATA=3'd2, S_PARITY=3'd3, S_STOP=3'd4;

    reg [2:0] state;
    reg [COUNT_W-1:0] baud_count;
    reg [DATA_BITS-1:0] shift_reg;
    reg [DATA_COUNT_W-1:0] bit_count;
    reg [STOP_COUNT_W-1:0] stop_count;
    reg parity_bit;

`ifndef SYNTHESIS
    initial begin
        if (CLK_FREQ <= 0 || BAUD_RATE <= 0 || CLKS_PER_BIT < 2)
            $error("uart_tx: invalid clock/baud configuration");
        if (DATA_BITS < 5 || DATA_BITS > 9) $error("uart_tx: DATA_BITS must be 5..9");
        if (PARITY_MODE < 0 || PARITY_MODE > 2) $error("uart_tx: PARITY_MODE must be 0,1,2");
        if (STOP_BITS < 1 || STOP_BITS > 2) $error("uart_tx: STOP_BITS must be 1 or 2");
    end
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; baud_count <= 0; shift_reg <= 0;
            bit_count <= 0; stop_count <= 0; parity_bit <= 0;
            tx_serial <= 1'b1; tx_busy <= 1'b0; tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                S_IDLE: begin
                    tx_serial <= 1'b1; tx_busy <= 1'b0; baud_count <= 0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        parity_bit <= (PARITY_MODE == 1) ? ^tx_data : ~^tx_data;
                        bit_count <= 0; stop_count <= 0;
                        tx_busy <= 1'b1; tx_serial <= 1'b0; state <= S_START;
                    end
                end
                S_START: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0; tx_serial <= shift_reg[0]; state <= S_DATA;
                    end else baud_count <= baud_count + 1'b1;
                end
                S_DATA: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0;
                        if (bit_count == DATA_BITS-1) begin
                            if (PARITY_MODE != 0) begin tx_serial <= parity_bit; state <= S_PARITY; end
                            else begin tx_serial <= 1'b1; state <= S_STOP; end
                        end else begin
                            shift_reg <= shift_reg >> 1;
                            bit_count <= bit_count + 1'b1;
                            tx_serial <= shift_reg[1];
                        end
                    end else baud_count <= baud_count + 1'b1;
                end
                S_PARITY: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0; tx_serial <= 1'b1; state <= S_STOP;
                    end else baud_count <= baud_count + 1'b1;
                end
                S_STOP: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0;
                        if (stop_count == STOP_BITS-1) begin
                            state <= S_IDLE; tx_busy <= 1'b0; tx_done <= 1'b1; tx_serial <= 1'b1;
                        end else begin
                            stop_count <= stop_count + 1'b1; tx_serial <= 1'b1;
                        end
                    end else baud_count <= baud_count + 1'b1;
                end
                default: begin state <= S_IDLE; tx_serial <= 1'b1; tx_busy <= 1'b0; baud_count <= 0; end
            endcase
        end
    end
endmodule
