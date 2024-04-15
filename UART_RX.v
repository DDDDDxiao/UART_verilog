/*---------------------------------------
    Module Name: UART_RX
    Created Time:   2023.11.5
---------------------------------------*/

module UART_RX 
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
    input   uart_rx,
    output  reg [DATA_WIDTH-1 : 0] o_rx_data,
    output  reg parity_check,    // high level means parity check right
    output  reg rx_done
);

    // input synchronization
    reg sync_uart_rx;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            sync_uart_rx <= 1'b1;   // uart_rx is high level when no input signal
        else
            sync_uart_rx <= uart_rx;
    end


    // FSM definition
    reg [3:0] curr_state;
    reg [3:0] next_state;

    localparam STATE_IDLE   = 4'b0000;
    localparam STATE_START  = 4'b0001;
    localparam STATE_DATA   = 4'b0011;
    localparam STATE_PARITY = 4'b0111;  // optional
    localparam STATE_STOP   = 4'b1111;

    // the number of clock cycles required to receive 1 bit
    localparam BIT_CYCLE = CLK_FREQ * 1000000 / BPS;    // unit: clk/bit

    // continuously detected 8 low level, receive_start == 8'b0000_0000
    // consider that data is transmitted from UART
    // eliminate misjudgments caused by burr noise
    reg [7:0] receive_start;
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)
            receive_start <= 8'b1111_1111;
        else
            receive_start <= {receive_start[6:0], sync_uart_rx};
    end

    reg baud_clk_cnt_valid;     // flag to start baud_clk_cnt

    reg [15:0] baud_clk_cnt;    // counter of clock number for 1 bit
    reg baud_center_pulse;      // pulse to sample 1 bit data on data cable

    reg [3:0] receive_bits_cnt; // the number of bits received
    reg [DATA_WIDTH-1 : 0] inter_data_receive;    // intermediate variables: data received from sync_uart_rx

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
        case(curr_state)
            STATE_IDLE:  begin
                if(baud_clk_cnt_valid == 1'b1 && receive_bits_cnt == 4'd0)
                    next_state <= STATE_START;
                else
                    next_state <= STATE_IDLE;
            end
            STATE_START: begin
                if(baud_clk_cnt_valid == 1'b1 && (baud_clk_cnt == BIT_CYCLE - 1))
                    next_state <= STATE_DATA;
                else if(baud_clk_cnt_valid == 1'b0)
                    next_state <= STATE_IDLE;       // if previous detection was wrong, back to IDLE state
                else
                    next_state <= STATE_START;
            end
            STATE_DATA:  begin
                if(receive_bits_cnt == DATA_WIDTH && (baud_clk_cnt == BIT_CYCLE - 1))
                begin
                    if(PARITY_ON == 1'b1)   // with parity check
                        next_state <= STATE_PARITY;
                    else
                        next_state <= STATE_STOP;
                end 
                else
                    next_state <= STATE_DATA;
            end
            STATE_PARITY:begin
                if(baud_clk_cnt == BIT_CYCLE - 1)
                    next_state <= STATE_STOP;
                else
                    next_state <= STATE_PARITY;
            end
            STATE_STOP:  begin
                if(baud_clk_cnt == BIT_CYCLE - 1)
                    next_state <= STATE_IDLE;
                else
                    next_state <= STATE_STOP;
            end
            default ;
        endcase
    end

    // FSM-seg3: output logic
    always @(posedge clk_sys or negedge rst_n) begin
        if(!rst_n)begin
            // intermediate register
            baud_clk_cnt_valid  <= 1'b0;
            receive_bits_cnt    <= 4'd0;    // no data received
            inter_data_receive  <=  'd0;    // bit width not sure   
            number_of_ones      <= 1'b0;
            // module output
            parity_check        <= 1'b0;    // parity check: not right
            o_rx_data           <=  'd0;    // output is 0
            rx_done             <= 1'b0;
        end
        else
            case (curr_state)
                STATE_IDLE:  begin
                    if(receive_start == 8'b0000_0000)   // continuously detected 8 low level
                        baud_clk_cnt_valid <= 1'b1;     // start to count for clock
                    else
                        baud_clk_cnt_valid <= 1'b0;
                    // reset the intermediate registers
                    receive_bits_cnt    <= 4'd0;
                    inter_data_receive  <=  'd0;
                    number_of_ones      <= 1'b0;
                    // module output
                    o_rx_data           <=  'd0;
                    parity_check        <= 1'b0;
                    rx_done             <= 1'b0;
                end
                STATE_START: begin
                    // when sampling pulse comes, detect again  if sync_uart_rx == 0 ?
                    if(baud_center_pulse == 1'b1 && sync_uart_rx != 1'b0 )
                        baud_clk_cnt_valid <= 1'b0;     // if not, previous detection was wrong
                                                        // reset baud_clk_cnt_valid to zero
                end
                STATE_DATA:  begin
                    if(baud_center_pulse == 1'b1) begin
                        receive_bits_cnt    <= receive_bits_cnt + 1'b1;    // cnt++
                        inter_data_receive  <= {sync_uart_rx, inter_data_receive[DATA_WIDTH-1 : 1]};
                        number_of_ones      <= number_of_ones + sync_uart_rx;
                    end
                end
                STATE_PARITY:begin
                    if(baud_center_pulse) begin
                        if(number_of_ones + sync_uart_rx == PARITY_TYPE)
                            parity_check <= 1'b1;
                        else
                            parity_check <= 1'b0;
                    end
                    else                                // if no pulse signal in parity check stage
                        parity_check <= parity_check;   // parity check retains
                end
                STATE_STOP:  begin
                    if(baud_center_pulse) begin
                        // output data received
                        if(PARITY_ON == 0) begin            // no parity check
                            o_rx_data <= inter_data_receive;
                            rx_done   <= 1'b1;
                        end
                        else if(parity_check == 1'b1) begin // with parity check && check right
                            o_rx_data <= inter_data_receive;
                            rx_done   <= 1'b1;
                        end
                        else begin                          // wrong data received
                            o_rx_data <=  'dx;
                            rx_done   <= 1'b0;
                        end
                    end
                    else
                        o_rx_data <= o_rx_data;             // signal retain
                        // rx_done   <= rx_done;            // can not wirte this line // but why?
                end
                default: ;
            endcase
    end

    
endmodule



/*------------------------------------------------------------------------------
    Reference:
    https://blog.csdn.net/qq_38812860/article/details/119940848
------------------------------------------------------------------------------*/