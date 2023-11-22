`timescale 1ns / 1ps
`default_nettype none

module cross_patterns #(parameter HEIGHT = 480,
                        parameter WIDTH = 480)
    (
        input wire clk_in,
        input wire rst_in,
        input wire [479:0] horz_patterns,
        input wire [479:0] vert_patterns,
        input wire start_cross,
        input wire pixel_reading,
        input wire [8:0] bound_x [1:0],
        input wire [8:0] bound_y [1:0],

        output logic [19:0] address_reading,
        output logic [8:0] centers_x [2:0],
        output logic [8:0] centers_y [2:0],
        output logic centers_valid,
        output logic centers_not_found_error
    );


    typedef enum {RESET, PENDING, WAIT_ONE, WAIT_TWO, DETERMINE,CALCULATE, FINISHED} fsm_state;

    fsm_state state = RESET;

    logic [1:0] zone_x;
    logic [1:0] zone_y;

    logic old_pixel;

    logic [8:0] box_min_x, box_min_y, box_max_x, box_max_y;
    assign address_reading = (box_min_x + x_read) + (y_read + box_min_y) * WIDTH;

    always_comb begin
        // assign box boundries for zone_y, zone_x
        case (zone_x)
            2'b00: begin
                box_min_x = 0;
                box_max_x = bound_x[0];
            end
            2'b01:begin
                box_min_x = bound_x[0];
                box_max_x = bound_x[1];
            end
            2'b10:begin
                box_min_x = bound_x[1];
                box_max_x = WIDTH - 1;
            end
            default: begin
                box_min_x = WIDTH - 1;
                box_max_x = WIDTH - 1;
            end
        endcase

        case (zone_y)
            2'b00: begin
                box_min_y = 0;
                box_max_y = bound_y[0];
            end
            2'b01:begin
                box_min_y = bound_y[0];
                box_max_y = bound_y[1];
            end
            2'b10:begin
                box_min_y = bound_y[1];
                box_max_y = HEIGHT - 1;
            end
            default: begin
                box_min_y = HEIGHT - 1;
                box_max_y = HEIGHT - 1;
            end
        endcase

    end 

    logic [8:0] x_read;
    logic [8:0] y_read;
    logic [13:0] counter_black;
    logic [13:0] counter_white;
    logic loaded;
    logic [8:0] start_x, start_y, end_x, end_y;
    logic [1:0] center_index;


    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            start_x <= 9'b0;
            start_y <= 9'b0;
            end_x <= 9'b0;
            end_y <= 9'b0;
            zone_y <= 2'b0;
            zone_x <= 2'b0;
            x_read <= 9'b0;
            y_read <= 9'b0;
            counter_black <= 14'b0;
            counter_white <= 14'b0;
            state <= RESET;
            loaded <= 1'b0;
            center_index <= 2'b0;
            centers_valid <= 1'b0;
            centers_not_found_error <= 1'b0;
        end

        else begin
            case (state) 
                RESET: begin
                    if(start_cross) begin
                        state <= PENDING;
                    end
                end

                PENDING: begin // check if need to lookup

                    if (horz_patterns[box_min_x + x_read] && vert_patterns[box_min_y + y_read]) begin
                        state <= WAIT_ONE;
                        end_x <= x_read;
                        end_y <= y_read;
                        if (!loaded)begin
                            loaded <= 1'b1;
                            start_x <= x_read;
                            start_y <= y_read;
                        end
                    end 

                    else begin   // in case you got black
                        if (box_min_x + x_read < box_max_x) begin
                            x_read <= x_read + 1;
                        end 
                        else begin
                            x_read <= 9'b0;
                            if (box_min_y + y_read < box_max_y) begin
                                y_read <= y_read + 1;
                            end 
                            else begin
                                state <= CALCULATE;
                            end
                        end 
                    end
                end 

                WAIT_ONE: state <= WAIT_TWO;
                WAIT_TWO: state <= DETERMINE;

                DETERMINE: begin   // increament counters, increament coordinates, increament zones
                    if (pixel_reading) begin
                        counter_white <= counter_white + 1;
                    end else begin
                        counter_black <= counter_black + 1;
                    end
                    if (box_min_x + x_read < box_max_x) begin
                            x_read <= x_read + 1;
                            state <= PENDING;
                        end 
                        else begin
                            x_read <= 9'b0;
                            if (box_min_y + y_read < box_max_y) begin
                                y_read <= y_read + 1;
                                state <= PENDING;
                            end
                            else begin
                                state <= CALCULATE;
                            end
                        end 
                end

                CALCULATE: begin   
                    // RUNS ONCE A ZONE COMPLETES THIS RUNS
                    // return a center if a valid answer if non-zero majority black.
                    if (zone_x < 2'b10) begin
                        zone_x <= zone_x + 1;
                    end
                    else begin
                        zone_x <= 2'b0;
                        if (zone_y < 2'b10) begin
                            zone_y <= zone_y + 1;                            
                        end
                        else begin
                            state <= FINISHED;
                            centers_not_found_error <= 1'b1;
                        end
                    end
                    loaded <= 1'b0;
                        if (center_index == 2) begin
                            state <= FINISHED;
                            centers_valid <= 1'b1;
                        end else begin
                            counter_black <= 14'b0;
                            counter_white <= 14'b0;
                            y_read <= 9'b0;
                            x_read <= 9'b0;// might be unecessary
                            state <= PENDING;
                        end
                        if (counter_black > (counter_white + counter_black) - (counter_white + counter_black)>>2) begin 
                            // SOMETHING IS WRONG HERE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            //-------------------------------------------------------------------------------------
                            // currently requires more than 75% of all pixels to be black when doing lookup
                            //// a valid answer, return center
                            center_index <= center_index + 2'b01;

                            centers_x[center_index] <= box_min_x;
                            centers_y[center_index] <= box_min_y;
                            // centers_x[center_index] <= (start_x + box_min_x);
                            // centers_y[center_index] <= (start_y + box_min_y + center_index*10);
                            //-------------------------------------------------------------------------------------
                        end
                end

                FINISHED: centers_valid <= 1'b0;
            endcase
        end
    end
endmodule

`default_nettype wire