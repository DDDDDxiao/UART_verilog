`timescale 1ns/10ps
`include "UART_RX.v"
/*---------------------------------------
    Module Name: UART_RX_tb
    Created Time:   2023.11.5
---------------------------------------*/

module UART_RX_tb;

parameter DATA_WIDTH = 8;
parameter CLK_FREQ = 50;
parameter BPS = 115200;     // to make BIT_CYCLE smaller (≈434), easy to simulate
parameter PARITY_ON = 1;    // 1: parity check enable
parameter PARITY_TYPE = 0;  // 0: even check, 1: odd check

reg clk;
reg rst_n;
reg uart_rx;

wire [DATA_WIDTH-1 : 0] o_rx_data;
wire parity_check;
wire rx_done;

initial clk = 0;
always #5 clk = ~clk;   // clock circle = 10 ns

// variables for test bench
localparam ONE_BIT_TIME = 4340;     // duration of each bit

initial begin
    $dumpfile("UART_RX_tb.vcd");
    $dumpvars(0, UART_RX_tb);
    rst_n = 0; uart_rx = 0;

    #20 rst_n = 1; uart_rx = 1; // idle bit == 1

    #8000 uart_rx = 0;          // start bit
    #1000 uart_rx = 1;          // previous detection of start bit was wrong

    #8000 uart_rx = 0;

    #ONE_BIT_TIME uart_rx = 1;
    #ONE_BIT_TIME uart_rx = 0;
    #ONE_BIT_TIME uart_rx = 0;
    #ONE_BIT_TIME uart_rx = 1;

    #ONE_BIT_TIME uart_rx = 1;
    #ONE_BIT_TIME uart_rx = 0;
    #ONE_BIT_TIME uart_rx = 0;
    #ONE_BIT_TIME uart_rx = 1;

    #ONE_BIT_TIME uart_rx = 0;  // parity check bit

    #ONE_BIT_TIME uart_rx = 1;  // stop bit

    #8000

    $finish;
end

UART_RX #(.BPS(BPS), .PARITY_ON(PARITY_ON), .PARITY_TYPE(PARITY_TYPE)) 
      uut(.clk_sys(clk), .rst_n(rst_n), .uart_rx(uart_rx),
          .o_rx_data(o_rx_data), .parity_check(parity_check), .rx_done(rx_done));

endmodule