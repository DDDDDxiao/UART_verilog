`include "UART_TX.v"
`include "UART_RX.v"
/*-----------------------------------------------------------------------
    Module Name:    UART_top
    Created Time:   2023.11.9
    Remark:         UART: Universal Asynchronous Receiver/Transmitter
-----------------------------------------------------------------------*/

module UART_top
#(
    parameter DATA_WIDTH = 8,    // valid data width, in default 8 bit
    parameter CLK_FREQ = 50,     // clock frequency, in default 50MHz
    parameter BPS = 9600,        // baud rate, 9600、14400、19200、38400、57600、115200
    parameter PARITY_ON = 0,     // 0: no parity check bit, 1: with parity check bit
    parameter PARITY_TYPE = 0    // 0: even check, 1: odd check 
)
(
    input clk_sys,
    input rst_n,
    input in_valid,
    input [DATA_WIDTH-1 : 0] in_data,
    output tx_done,
    output rx_done,
    output parity_check,
    output [DATA_WIDTH-1 : 0] out_data
);

wire uart_tx_rx;

UART_TX #(.DATA_WIDTH(DATA_WIDTH), .CLK_FREQ(CLK_FREQ), .BPS(BPS), .PARITY_ON(PARITY_ON), .PARITY_TYPE(PARITY_TYPE))
tx(.clk_sys(clk_sys), .rst_n(rst_n), .tx_valid(in_valid), .tx_data(in_data), .tx_done(tx_done), .uart_tx(uart_tx_rx));

UART_RX #(.DATA_WIDTH(DATA_WIDTH), .CLK_FREQ(CLK_FREQ), .BPS(BPS), .PARITY_ON(PARITY_ON), .PARITY_TYPE(PARITY_TYPE))
rx(.clk_sys(clk_sys), .rst_n(rst_n), .uart_rx(uart_tx_rx), .o_rx_data(out_data), .parity_check(parity_check), .rx_done(rx_done));
    
endmodule