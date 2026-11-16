`timescale 1ns/1ps
module uart_system_tb #(
    parameter integer CLK_FREQ=10_000_000,
    parameter integer BAUD_RATE=1_000_000,
    parameter integer DATA_BITS=8,
    parameter integer PARITY_MODE=1, // 0:none, 1:even, 2:odd
    parameter integer STOP_BITS=2
);
    // Fast simulation defaults; override parameters for the configuration matrix.
    localparam integer CLKS_PER_BIT=CLK_FREQ/BAUD_RATE;

    reg clk=0, rst_n=0, tx_start=0;
    reg [DATA_BITS-1:0] tx_data=0;
    wire tx_serial, tx_busy, tx_done;
    wire [DATA_BITS-1:0] rx_data;
    wire rx_valid, parity_error, framing_error;
    reg [DATA_BITS-1:0] expected;
    integer tests=0, passes=0, failures=0;
    integer zero_seen=0, ones_seen=0, alternating_seen=0, random_seen=0;

    always #5 clk=~clk;

    uart_top #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .DATA_BITS(DATA_BITS),
               .PARITY_MODE(PARITY_MODE), .STOP_BITS(STOP_BITS)) dut (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start), .tx_data(tx_data),
        .tx_serial(tx_serial), .rx_serial(tx_serial), .rx_data(rx_data),
        .tx_busy(tx_busy), .tx_done(tx_done), .rx_valid(rx_valid),
        .parity_error(parity_error), .framing_error(framing_error)
    );

`ifdef ENABLE_SVA
    uart_sva_checker sva_i (
        .clk(clk), .rst_n(rst_n), .tx_serial(tx_serial), .tx_busy(tx_busy),
        .tx_done(tx_done), .rx_valid(rx_valid)
    );
`endif

    task automatic send_and_check(input [DATA_BITS-1:0] value);
        begin
            wait(!tx_busy);
            @(negedge clk); tx_data=value; tx_start=1'b1;
            @(negedge clk); tx_start=1'b0;
            expected=value;
            tests=tests+1;
            if (value==0) zero_seen=zero_seen+1;
            if (&value) ones_seen=ones_seen+1;
            if (value==({DATA_BITS{1'b1}} & 8'hAA) || value==({DATA_BITS{1'b1}} & 8'h55)) alternating_seen=alternating_seen+1;
            if (!(value==0 || (&value) || value==({DATA_BITS{1'b1}} & 8'hAA) || value==({DATA_BITS{1'b1}} & 8'h55))) random_seen=random_seen+1;
            wait(rx_valid);
            #1;
            if (rx_data !== expected || parity_error || framing_error) begin
                $display("FAIL test=%0d sent=%h received=%h parity_err=%b frame_err=%b", tests, expected, rx_data, parity_error, framing_error);
                failures=failures+1;
            end else begin
                $display("PASS test=%0d data=%h", tests, rx_data);
                passes=passes+1;
            end
            @(negedge clk);
        end
    endtask

    integer i;
    reg [DATA_BITS-1:0] rand_value;
    initial begin
        $dumpfile("build/uart_system.vcd");
        $dumpvars(0, uart_system_tb);
        repeat(5) @(negedge clk); rst_n=1'b1;
        repeat(5) @(negedge clk);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'hAA);
        send_and_check(8'h55);
        send_and_check(8'hA5);
        send_and_check(8'h3C);
        for (i=0;i<24;i=i+1) begin
            rand_value=$urandom;
            send_and_check(rand_value);
        end
        repeat(5) @(negedge clk);
        $display("\n---- UART REGRESSION SUMMARY ----");
        $display("Tests=%0d Pass=%0d Fail=%0d", tests, passes, failures);
        $display("Coverage bins: zero=%0d all_ones=%0d alternating=%0d other_random=%0d", zero_seen, ones_seen, alternating_seen, random_seen);
        if (failures==0 && tests==passes && zero_seen>0 && ones_seen>0 && alternating_seen>0 && random_seen>0)
            $display("OVERALL: PASS (functional bins exercised)");
        else $display("OVERALL: FAIL");
        $finish;
    end

    // Portable immediate checks; full SVA properties are in formal/uart_sva.sv.
    always @(posedge clk) begin
        if (rst_n && rx_valid) begin
            if (parity_error) $display("NOTE: parity error asserted on received frame");
        end
    end
endmodule
