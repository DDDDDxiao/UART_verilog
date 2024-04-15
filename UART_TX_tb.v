`timescale 1ns/10ps
`include "UART_TX.v"
/*---------------------------------------
    Module Name: UART_TX_tb
    Created Time:   2023.11.8
---------------------------------------*/

module UART_TX_tb;

parameter DATA_WIDTH = 8;    // valid data width, in default 8 bit
parameter CLK_FREQ = 50;     // clock frequency, in default 50MHz
parameter BPS = 115200;      // baud rate, 9600、14400、19200、38400、57600、115200
parameter PARITY_ON = 1;     // 0: no parity check bit, 1: with parity check bit
parameter PARITY_TYPE = 1;   // 0: even check, 1: odd check

reg clk;
reg rst_n;
reg tx_valid;
reg [DATA_WIDTH-1 : 0] tx_data;
wire uart_tx;
wire tx_done;

initial clk = 0;
always #10 clk = ~clk;  // clock circle = 20 ns

// variables for test bench
localparam ONE_BIT_TIME = 8680;     // duration of each bit

initial begin
    $dumpfile("UART_TX_tb.vcd");
    $dumpvars(0, UART_TX_tb);
    $monitor("rst_n = %b, tx_valid = %b, tx_data = %b, curr_state = %b, uart_tx = %b",
              rst_n, tx_valid, tx_data, uut.curr_state, uart_tx);
    rst_n = 0; tx_valid = 0; tx_data = 0;

    #6000 rst_n = 1; tx_valid = 1; tx_data = 8'b1100_1001;

    #ONE_BIT_TIME   // LSB
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME   // MSB
    #ONE_BIT_TIME   // parity bit

    #ONE_BIT_TIME   // stop bit

    #ONE_BIT_TIME   tx_valid = 0;
    #10000

    // 再验证一下parity check的部分

    $finish;
end


UART_TX #(.BPS(BPS), .PARITY_ON(PARITY_ON), .PARITY_TYPE(PARITY_TYPE))
uut(.clk_sys(clk), .rst_n(rst_n), .tx_valid(tx_valid), .tx_data(tx_data), .uart_tx(uart_tx), .tx_done(tx_done));
endmodule