`timescale 1ns/10ps
`include "UART_top.v"
/*-----------------------------------------------------------------------
    Module Name:    UART_top_tb
    Created Time:   2023.11.9
-----------------------------------------------------------------------*/

module UART_top_tb;

parameter DATA_WIDTH = 8;    // valid data width, in default 8 bit
parameter CLK_FREQ = 50;     // clock frequency, in default 50MHz
parameter BPS = 115200;      // baud rate, 9600、14400、19200、38400、57600、115200
parameter PARITY_ON = 0;     // 0: no parity check bit, 1: with parity check bit
parameter PARITY_TYPE = 0;   // 0: even check, 1: odd check 

reg  clk;
reg  rst_n;
reg  in_valid;
reg  [DATA_WIDTH-1 : 0] in_data;
wire tx_done;
wire rx_done;
wire parity_check;
wire [DATA_WIDTH-1 : 0] out_data;

initial clk = 0;
always #10 clk = ~clk;  // clock circle = 20 ns

// variables for test bench
localparam ONE_BIT_TIME = 8680;     // duration of each bit

initial begin
    $dumpfile("UART_top_tb.vcd");
    $dumpvars(0, UART_top_tb);

    rst_n = 0; in_valid = 0; in_data = 0; in_data = 0;

    #10000 rst_n = 1; in_valid = 1; in_data = 8'b0010_1110;

    #ONE_BIT_TIME   // LSB
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME   // MSB

    #ONE_BIT_TIME   // stop bit
    #ONE_BIT_TIME   in_valid = 0;

    #10000

    #10000          in_valid = 1; in_data = 8'b1000_1100;

    #ONE_BIT_TIME   // LSB
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME
    #ONE_BIT_TIME   // MSB

    #ONE_BIT_TIME   // stop bit
    #ONE_BIT_TIME   in_valid = 0;

    #20000

    $finish;
end

UART_top #(.DATA_WIDTH(DATA_WIDTH), .CLK_FREQ(CLK_FREQ), .BPS(BPS), .PARITY_ON(PARITY_ON), .PARITY_TYPE(PARITY_TYPE))
uut(.clk_sys(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data), .tx_done(tx_done), .rx_done(rx_done), 
    .parity_check(parity_check), .out_data(out_data));

endmodule