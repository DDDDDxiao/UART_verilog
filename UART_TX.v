/*---------------------------------------
    Module Name: UART_TX
    Created Time:   2023.11.7
---------------------------------------*/

module UART_TX 
#(
    parameter DATA_WIDTH = 8,    // valid data width, in default 8 bit
    parameter CLK_FREQ = 50,     // clock frequency, in default 50MHz
    parameter BPS = 9600,        // baud rate, 9600、14400、19200、38400、57600、115200
    parameter PARITY_ON = 0,     // 0: no parity check bit, 1: with parity check bit
    parameter PARITY_TYPE = 0    // 0: even check, 1: odd check
)
(
    input   clk_sys,
    input   rst_n,
    input   tx_valid,           // input valid
    input   [DATA_WIDTH-1 : 0] tx_data,
    output  reg uart_tx,        // output data
    output  reg tx_done         // transmit complete
);

    // FSM definition
    reg [3:0] curr_state;
    reg [3:0] next_state;

    localparam STATE_IDLE   = 4'b0000;
    localparam STATE_START  = 4'b0001;
    localparam STATE_DATA   = 4'b0011;
    localparam STATE_PARITY = 4'b0111;  // optional
    localparam STATE_STOP   = 4'b1111;

    // the number of clock cycles required to transmit 1 bit
    localparam BIT_CYCLE = CLK_FREQ * 1000000 / BPS;    // unit: clk/bit

    reg baud_clk_cnt_valid;     // flag to start baud_clk_cnt

    reg [15:0] baud_clk_cnt;    // counter of clock number for 1 bit
    reg baud_center_pulse;      // pulse to transmit 1 bit data on data cable

    reg [3:0] transmit_bits_cnt; // the number of bits transmited
    reg [DATA_WIDTH-1 : 0] inter_data_transmit;    // intermediate variables: data will be transmited to uart_tx

    reg number_of_ones;         // for parity check

    // description of [15:0] baud_clk_cnt
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)
            baud_clk_cnt <= 16'd0;
        else if(baud_clk_cnt_valid == 1'b0)
            baud_clk_cnt <= 16'd0;
        else if(baud_clk_cnt == BIT_CYCLE - 1)
            baud_clk_cnt <= 16'd0;
        else
            baud_clk_cnt <= baud_clk_cnt + 1'b1;
    end

    // description of baud_center_pulse
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)
            baud_center_pulse <= 1'b0;
        else if(baud_clk_cnt == BIT_CYCLE/2 - 1)
            baud_center_pulse <= 1'b1;  // count to the center of 1 bit, time to sample the data
        else
            baud_center_pulse <= 1'b0;
    end

    // FSM-seg1: state conversion
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)
            curr_state <= STATE_IDLE;
        else
            curr_state <= next_state;
    end

    // FSM-seg2: condition for state concersion
    always @(*) begin
        case (curr_state)
            STATE_IDLE:   begin
                if(baud_clk_cnt_valid == 1'b1 && (baud_clk_cnt == BIT_CYCLE - 1))
                    next_state <= STATE_START;
                else
                    next_state <= STATE_IDLE;
            end
            STATE_START:  begin
                if(baud_clk_cnt_valid == 1'b1 && (baud_clk_cnt == BIT_CYCLE - 1))
                    next_state <= STATE_DATA;
                else
                    next_state <= STATE_START;
            end
            STATE_DATA:   begin
                if(transmit_bits_cnt == DATA_WIDTH && (baud_clk_cnt == BIT_CYCLE - 1))
                begin
                    if(PARITY_ON == 1'b1)
                        next_state <= STATE_PARITY;
                    else
                        next_state <= STATE_STOP;
                end
                else
                    next_state <= STATE_DATA;
            end
            STATE_PARITY: begin
                if(baud_clk_cnt == BIT_CYCLE - 1)
                    next_state <= STATE_STOP;
                else
                    next_state <= STATE_PARITY;
            end
            STATE_STOP:   begin
                if(baud_clk_cnt == BIT_CYCLE - 1)
                    next_state <= STATE_IDLE;
                else
                    next_state <= STATE_STOP;
            end
            default: ;
        endcase
    end

    // FSM-seg3: output logic
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)begin
            // intermediate register
            baud_clk_cnt_valid <= 1'b0;
            transmit_bits_cnt  <= 4'd0;
            inter_data_transmit<=  'd0;
            // module output
            uart_tx <= 1'b1;        // idle bit == 1
            tx_done <= 1'b0;
        end
        else
            case (curr_state)
                STATE_IDLE:   begin
                    // intermediate register
                    transmit_bits_cnt  <= 4'd0;
                    inter_data_transmit<=  'd0;
                    number_of_ones     <= 1'b0;         // how many 1s tramsmited
                    // module output
                    uart_tx <= 1'b1;                    // idle bit == 1
                    tx_done <= 1'b0;

                    if(tx_valid == 1'b1) begin
                        baud_clk_cnt_valid <= 1'b1;     // start to count
                    end
                    else
                        baud_clk_cnt_valid <= 1'b0;
                end
                STATE_START:  begin
                    // intermediate register
                    transmit_bits_cnt  <= 4'd0;
                    if(baud_center_pulse == 1'b1)begin
                        inter_data_transmit <= tx_data;  // put the input data into register
                        // module output
                        uart_tx <= 1'b0;                 // start bit == 0
                        tx_done <= 1'b0;
                    end
                end
                STATE_DATA:   begin
                    if(baud_center_pulse == 1'b1) begin
                        transmit_bits_cnt   <= transmit_bits_cnt + 1'b1;  // cnt++
                        inter_data_transmit <= {1'b0, inter_data_transmit[DATA_WIDTH-1 : 1]};   // transmit from LSB
                        uart_tx             <= inter_data_transmit[0];
                        number_of_ones      <= number_of_ones + inter_data_transmit[0];

                    end
                    if(transmit_bits_cnt == DATA_WIDTH)
                            tx_done <= 1'b1;
                    else
                        tx_done <= 1'b0;
                end
                STATE_PARITY: begin
                    if(baud_center_pulse == 1'b1) begin
                        if(PARITY_TYPE == 1'b0)         // even check
                            uart_tx <= number_of_ones;
                        else                            // odd check
                            uart_tx <= number_of_ones + 1'b1;
                    end
                end
                STATE_STOP:   begin
                    if(baud_center_pulse == 1'b1) begin
                        uart_tx <= 1'b1;                // stop bit == 1
                    end
                end
                default: ;
            endcase
    end
    
endmodule



/*------------------------------------------------------------------------------
    Reference:
    https://blog.csdn.net/qq_38812860/article/details/119940848
------------------------------------------------------------------------------*/