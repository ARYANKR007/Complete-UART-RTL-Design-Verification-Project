#!/usr/bin/env python3
"""
Interactive Demo & Verification Runner for Complete-UART-RTL-Design-Verification-Project
Place this file in the root of Complete-UART-RTL-Design-Verification-Project and run:
    python3 demo.py
"""

import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RTL_FILES = [
    ROOT / "rtl" / "uart_tx.v",
    ROOT / "rtl" / "uart_rx.v",
    ROOT / "rtl" / "uart_top.v",
]
BUILD_DIR = ROOT / "build"


def check_tool(name: str) -> bool:
    return shutil.which(name) is not None


def run_cmd(cmd, capture=False):
    if capture:
        return subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    return subprocess.run(cmd, cwd=ROOT)


def parse_user_payload(raw: str):
    """Parse ASCII text or space-separated hex bytes (e.g. '0x55 0xAA')."""
    tokens = raw.strip().split()
    if tokens and all(re.fullmatch(r"0[xX][0-9a-fA-F]{1,2}", t) for t in tokens):
        return [int(t, 16) for t in tokens]
    return [ord(ch) & 0xFF for ch in raw]


def generate_loopback_tb(payload_bytes, baud_rate=115200, parity_mode=0, stop_bits=1):
    """Write a self-checking Verilog loopback testbench for uart_top."""
    BUILD_DIR.mkdir(exist_ok=True)
    tb_path = BUILD_DIR / "demo_uart_tb.v"
    vcd_path = BUILD_DIR / "demo_uart.vcd"

    byte_array_init = "\n".join(
        f"        tx_buf[{i}] = 8'h{b:02X};" for i, b in enumerate(payload_bytes)
    )

    tb_code = f"""`timescale 1ns/1ps
module demo_uart_tb;
    localparam integer CLK_FREQ    = 50_000_000;
    localparam integer BAUD_RATE   = {baud_rate};
    localparam integer DATA_BITS   = 8;
    localparam integer PARITY_MODE = {parity_mode};
    localparam integer STOP_BITS   = {stop_bits};

    reg clk = 0;
    reg rst_n = 0;
    reg tx_start = 0;
    reg [DATA_BITS-1:0] tx_data = 0;
    wire tx_serial;
    wire rx_serial = tx_serial; // Loopback TX -> RX
    wire [DATA_BITS-1:0] rx_data;
    wire tx_busy;
    wire tx_done;
    wire rx_valid;
    wire parity_error;
    wire framing_error;

    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_serial(tx_serial),
        .rx_serial(rx_serial),
        .rx_data(rx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_valid(rx_valid),
        .parity_error(parity_error),
        .framing_error(framing_error)
    );

    always #10 clk = ~clk; // 50 MHz

    reg [7:0] tx_buf [0:{max(len(payload_bytes) - 1, 0)}];
    integer i;
    integer errors = 0;

    initial begin
        $dumpfile("{vcd_path.as_posix()}");
        $dumpvars(0, demo_uart_tb);
{byte_array_init}
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;

        for (i = 0; i < {len(payload_bytes)}; i = i + 1) begin
            wait(!tx_busy);
            @(posedge clk);
            tx_data <= tx_buf[i];
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;

            @(posedge rx_valid);
            #1;
            if (rx_data === tx_buf[i] && !parity_error && !framing_error) begin
                $display("BYTE_OK idx=%0d tx=0x%02X rx=0x%02X", i, tx_buf[i], rx_data);
            end else begin
                $display("BYTE_ERR idx=%0d tx=0x%02X rx=0x%02X perr=%b ferr=%b",
                         i, tx_buf[i], rx_data, parity_error, framing_error);
                errors = errors + 1;
            end
            wait(!tx_busy);
            #200;
        end

        if (errors == 0)
            $display("DEMO_RESULT=PASS total=%0d", {len(payload_bytes)});
        else
            $display("DEMO_RESULT=FAIL errors=%0d total=%0d", errors, {len(payload_bytes)});
        $finish;
    end
endmodule
"""
    tb_path.write_text(tb_code, encoding="utf-8")
    return tb_path, vcd_path


def interactive_loopback_demo():
    if not (check_tool("iverilog") and check_tool("vvp")):
        print("Error: 'iverilog' and 'vvp' are required. Install with: sudo apt install iverilog")
        return

    if not (ROOT / "rtl" / "uart_top.v").exists():
        print("Error: Could not find rtl/uart_top.v. Run demo.py from the repository root.")
        return

    raw = input("\nEnter ASCII message or hex bytes (e.g. HELLO or 0x55 0xAA): ").strip()
    if not raw:
        raw = "UART_OK"
    payload = parse_user_payload(raw)

    tb_path, vcd_path = generate_loopback_tb(payload)
    vvp_out = BUILD_DIR / "demo_uart.vvp"

    compile_cmd = ["iverilog", "-g2012", "-o", str(vvp_out)] + [str(f) for f in RTL_FILES] + [str(tb_path)]
    comp = run_cmd(compile_cmd, capture=True)
    if comp.returncode != 0:
        print("Compilation failed:\n", comp.stderr)
        return

    sim = run_cmd(["vvp", str(vvp_out)], capture=True)
    print("\n--- UART Loopback Simulation Output (115200 baud, 8N1) ---")
    for line in sim.stdout.splitlines():
        if line.startswith("BYTE_OK"):
            m = re.search(r"idx=(\d+) tx=(0x[0-9A-Fa-f]+) rx=(0x[0-9A-Fa-f]+)", line)
            if m:
                ch = chr(int(m.group(3), 16))
                printable = ch if 32 <= ord(ch) <= 126 else "."
                print(f"  [PASS] Byte {m.group(1)}: TX={m.group(2)} -> RX={m.group(3)} ('{printable}')")
        elif line.startswith("BYTE_ERR") or line.startswith("DEMO_RESULT="):
            print(" ", line)
    print(f"Waveform saved to: {vcd_path}")


def generate_architecture():
    if not check_tool("yosys"):
        print("Error: 'yosys' is not installed or not in PATH.")
        return
    BUILD_DIR.mkdir(exist_ok=True)
    yosys_script = (
        "read_verilog rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v; "
        "hierarchy -check -top uart_top; "
        "proc; opt; "
        "show -format svg -prefix build/uart_arch uart_top; "
        "stat"
    )
    print("\nRunning Yosys to generate build/uart_arch.svg...")
    res = run_cmd(["yosys", "-p", yosys_script])
    if res.returncode == 0 and (BUILD_DIR / "uart_arch.svg").exists():
        print(f"Architecture SVG created: {BUILD_DIR / 'uart_arch.svg'}")
        if check_tool("xdg-open"):
            subprocess.Popen(["xdg-open", str(BUILD_DIR / "uart_arch.svg")],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_full_verification():
    print("\nRunning repository simulation (make sim)...")
    run_cmd(["make", "sim"])
    matrix = ROOT / "scripts" / "run_matrix.sh"
    if matrix.exists():
        ans = input("Run full 30-configuration verification matrix? [y/N]: ").strip().lower()
        if ans == "y":
            run_cmd(["bash", str(matrix)])


def open_waveform():
    if not check_tool("gtkwave"):
        print("Error: 'gtkwave' is not installed. Install with: sudo apt install gtkwave")
        return
    for candidate in (BUILD_DIR / "demo_uart.vcd", BUILD_DIR / "uart_system.vcd"):
        if candidate.exists():
            print(f"Launching GTKWave on {candidate}...")
            subprocess.Popen(["gtkwave", str(candidate)],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
    print("No .vcd waveform found in build/. Run option [1] or [2] first.")


def main():
    while True:
        print("\n==========================================")
        print("  UART RTL Design & Verification Demo")
        print("==========================================")
        print("  1. Live UART Loopback Demo (Text / Hex)")
        print("  2. Run Repo Verification (make sim / matrix)")
        print("  3. Generate Architecture Schematic (Yosys)")
        print("  4. Open Waveform Viewer (GTKWave)")
        print("  5. Quit")
        choice = input("\nSelect an option [1-5]: ").strip()

        if choice == "1":
            interactive_loopback_demo()
        elif choice == "2":
            run_full_verification()
        elif choice == "3":
            generate_architecture()
        elif choice == "4":
            open_waveform()
        elif choice == "5":
            break
        else:
            print("Invalid choice, enter 1-5.")


if __name__ == "__main__":
    main()
