
`timescale 1ns / 1ps
`default_nettype none

module bounds #(parameter HEIGHT = 480,
                parameter WIDTH = 480,
                parameter OFFSET = 10)
    (
        input wire clk_in,
        input wire rst_in,
        input wire [479:0] horz_patterns,
        input wire [479:0] vert_patterns,
        input wire start_bound,

        output logic [8:0] bound_x [1:0],
        output logic [8:0] bound_y [1:0],
        output logic valid_bound
    );


    typedef enum {RESET, BOUNDS_X, BOUNDS_Y, FINISHED} fsm_state;
    fsm_state state = RESET;

    logic [8:0] x,y;

    logic [1:0] bounds_x_index; 
    logic [1:0] bounds_y_index; 

    logic old_pixel;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= RESET;
            x <= 9'b0;
            y <= 9'b0;
            old_pixel <= 1'b0;
            bounds_x_index <= 2'b0;
            bounds_y_index <= 2'b0;
            valid_bound <= 1'b0;
            bound_x[0] <= 9'b0;
            bound_x[1] <= 9'b0;
            bound_y[0] <= 9'b0;
            bound_y[1] <= 9'b0;
        end

        else begin

            case (state)

            RESET: begin
                if (start_bound) begin
                    state <= BOUNDS_X;
                end
            end

            BOUNDS_X: begin
                old_pixel <= horz_patterns[x];

                if (x == WIDTH -1) begin
                    x <= 9'b0;
                    state  <= BOUNDS_Y;
                    old_pixel <= 1'b0;
                end else begin
                    x <= x + 1;
                end

                if ((horz_patterns[x] != old_pixel) && old_pixel) begin
                    if (bounds_x_index < 2) begin
                        bound_x[bounds_x_index] <= x + OFFSET;
                        bounds_x_index <= bounds_x_index + 1;
                    end
                end
            end

            BOUNDS_Y: begin
                old_pixel <= vert_patterns[y];

                if (y == HEIGHT -1) begin
                    y <= 9'b0;
                    state  <= FINISHED;
                    valid_bound <= 1'b1;
                end else begin
                    y <= y + 1;
                end

                if ((vert_patterns[y] != old_pixel) && old_pixel) begin
                    if (bounds_y_index < 2) begin
                        bound_y[bounds_y_index] <= y + OFFSET;
                        bounds_y_index <= bounds_y_index + 1;
                    end
                end
            end

            FINISHED: begin
                valid_bound <= 1'b0;
            end

            endcase
        end
    end 


endmodule

`default_nettype wire
