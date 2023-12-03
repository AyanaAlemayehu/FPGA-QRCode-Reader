// ERROR: NEVER FORGET DEFAULT NETTYPE
`timescale 1ns / 1ps
`default_nettype none

module find_mod_size #(parameter MODULES = 14)
    (
        input wire clk_in,
        input wire rst_in,
        input wire [8:0] centers_x [2:0],
        input wire [8:0] centers_y [2:0],
        input wire start_downsample,

        output logic [8:0] mod_size, // oversized by a lot lol
        output logic mod_size_valid
    );

    logic [1:0] center_index; // index 0 is bottom left, 1 is top left, 2 is top right (in post rotated qr code)
    logic [10:0] dividend, divisor;
    logic [10:0] result;
    logic start_divide, finished_divide;

    divider #(.WIDTH(11)) div 
        (.clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(dividend),
        .divisor_in(divisor),
        .data_valid_in(start_divide),
        .quotient_out(result),
        .remainder_out(),
        .data_valid_out(finished_divide),
        .error_out(),
        .busy_out());

    typedef enum {RESET, LOAD, DIVIDE, CALCULATE, FINISHED} fsm_state;
    fsm_state state = RESET;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            center_index <= 2'b0;
            dividend <= 10'b0;
            divisor <= 10'b0;
            start_divide <= 1'b0;
            mod_size <= 8'b0;
            mod_size_valid <= 1'b0;
            state <= RESET;
        end
        else begin
            case (state)
                
                RESET: state <= start_downsample == 1'b1 ? LOAD : RESET;

                LOAD: begin
                    case (center_index)

                        2'b00: begin
                            dividend <= centers_x[1] - centers_x[0];
                            divisor <= MODULES;
                            state <= DIVIDE;
                            start_divide <= 1'b1;
                        end

                        2'b01: begin
                            dividend <= centers_y[2] - centers_y[1];
                            divisor <= MODULES;
                            state <= DIVIDE;
                            start_divide <= 1'b1;
                        end

                        default: begin
                            state <= FINISHED;
                            mod_size_valid <= 1'b1;
                        end

                    endcase
                end

                DIVIDE: begin
                    start_divide <= 1'b0;
                    state <= finished_divide ? CALCULATE : DIVIDE;
                end

                CALCULATE: begin
                    if (!mod_size)  // we havent calculated a module size yet
                        mod_size <= result;
                    else
                        mod_size <= (({1'b0, mod_size} + {1'b0, result})>>1); // takes average without overflow (ofc can just distribute but if it aint broke)
                    center_index <= center_index + 1'b1;
                    state <= LOAD;
                end

                FINISHED: mod_size_valid <= 1'b0;
            endcase
        end

    end



endmodule

`default_nettype wire


// DEBUGGING IDEA: READ counter_black and counter_white 