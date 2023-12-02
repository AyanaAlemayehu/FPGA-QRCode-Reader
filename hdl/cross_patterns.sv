// ERROR: NEVER FORGET DEFAULT NETTYPE
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
        output logic centers_not_found_error,
        output logic centers_not_found_error2
    );



    typedef enum {RESET, PENDING, WAIT_ONE, WAIT_TWO, DETERMINE,CALCULATE, FINISHED} fsm_state;
    fsm_state state = RESET;

    logic [8:0] x_read, y_read;  // current coordinates checking pixel at, reset to zero at rst_in and whenever we switch box
    // ERROR: FORGOT TO OFFSET READING ADDRESS ANDDDDDDD THIS WAS CALLED READING_ADDRESS (WRONG NAME)
    // triggers used for debugging
    logic lookup_trigger, match_trigger;
    assign lookup_trigger = horz_patterns[box_min_x + x_read] && vert_patterns[box_min_y + y_read];
    assign match_trigger =  counter_black > ((counter_white + counter_black) - ((counter_white + counter_black)>>1) - ((counter_white + counter_black)>>3));
    
    assign address_reading = box_min_x + x_read + (y_read + box_min_y) * WIDTH;
    logic [8:0] box_min_x, box_min_y, box_max_x, box_max_y; // current box boundries, changes whenever we switch zone.
    logic [1:0] zone_x, zone_y;

    
    // perhaps switching to an always_ff will fix this
    // SIKE ONE CYCLE LATE BREAKS STUFF?
    always_comb begin
        case (zone_x)
            2'b00: begin
                box_min_x = 8'b0;
                box_max_x = bound_x[0];
            end 
            2'b01: begin
                box_min_x = bound_x[0];
                box_max_x = bound_x[1];
            end 
            2'b10: begin
                box_min_x = bound_x[1];
                box_max_x = WIDTH-1;
            end 
            default: begin 
                box_min_x = 120;
                box_max_x = 360;
            end
        endcase
        case (zone_y)
            2'b00: begin
                box_min_y = 8'b0;
                box_max_y = bound_y[0];
            end 
            2'b01: begin
                box_min_y = bound_y[0];
                box_max_y = bound_y[1];
            end 
            2'b10: begin
                box_min_y = bound_y[1];
                box_max_y = HEIGHT-1;
            end 
            default: begin 
                box_min_y = 120;
                box_max_y = 360;
            end
        endcase
    end

    logic [19:0] counter_black;
    logic [19:0] counter_white;
    logic [3:0] center_index;
    logic [8:0] x_start, y_start, x_end, y_end;
    logic first_white;

    always_ff @(posedge clk_in) begin

        if(rst_in) begin
            state <= RESET;
            x_read <= 9'b0;
            y_read <= 9'b0;
            x_start <= 9'b0;
            y_start <= 9'b0;
            x_end <= 9'b0;
            y_end <= 9'b0;
            counter_black <= 20'b0; // POTENTIAL ERROR: OVERFLOW IN INTERMEDIATE ADDITON?
            counter_white <= 20'b0;
            zone_x <= 2'b00;
            zone_y <= 2'b00;
            center_index <= 4'b0;
            first_white <= 1'b1;
            centers_x[0] <= 9'b0;
            centers_x[1] <= 9'b0;
            centers_x[2] <= 9'b0;
            centers_y[0] <= 9'b0;
            centers_y[1] <= 9'b0;
            centers_y[2] <= 9'b0;
            centers_valid <= 1'b0;
            centers_not_found_error <= 1'b0;
            centers_not_found_error2 <= 1'b0;
        end 

        else begin
            case (state)

            RESET: begin
                if (start_cross) begin
                    state <= PENDING;
                end 
            end

            PENDING: begin
                // check if pixel is white to see if need to read it's value.
                // if pixel is white go to wait one then wait two until it's value read, then go to determine to decide if count or not.
                if (lookup_trigger) begin
                    state <= WAIT_ONE;
                    x_end <= x_read;
                    y_end <= y_read;
                    if (first_white) begin
                        x_start <= x_read;
                        y_start <= y_read;
                        first_white <= 1'b0;
                    end 
                end
                // if black, stay and continue reading until you see a white again
                // go to CALCULATE ONCE FINISHED BOX
                else begin
                    if ( (x_read + box_min_x)  < box_max_x ) begin
                        x_read <= x_read + 9'b1;
                    end else begin
                        x_read <= 9'b0;
                        if ( (y_read + box_min_y)  < box_max_y ) begin
                            y_read <= y_read + 9'b1;
                        end else begin
                            // end of box
                            y_read <= 9'b0;
                            state <= CALCULATE;
                        end
                    end
                end
            end 

            WAIT_ONE: begin
                state <= WAIT_TWO;
            end 

            WAIT_TWO: begin
                state <= DETERMINE;
            end 

            DETERMINE: begin
                // increament counters for majority checking
                if (pixel_reading) begin
                    counter_white <= counter_white + 1;
                end else begin
                    counter_black <= counter_black + 1;
                end
                // increament coords and move to a different state.
                if ( (x_read + box_min_x)  < box_max_x ) begin
                        x_read <= x_read + 9'b1;
                        state <= PENDING;
                    end else begin
                        x_read <= 9'b0;
                        if ( (y_read + box_min_y)  < box_max_y ) begin
                            y_read <= y_read + 9'b1;
                            state <= PENDING;
                        end else begin
                            // end of box
                            y_read <= 9'b0;
                            state <= CALCULATE;
                        end
                    end
            end 

            CALCULATE: begin
                /////// new zone: change box, reset counters, reset coords
                // 1- our first white again is going to be the first white
                first_white <= 1'b1;
                // 2- reset counters:
                counter_black <= 20'b0;
                counter_white <= 20'b0; 
                // 3- reset coords, already done when moved to this state, but keep anyways
                x_read <= 9'b0;
                y_read <= 9'b0;
                x_start <= 9'b0;
                y_start <= 9'b0;
                x_end <= 9'b0;
                y_end <= 9'b0;
                // 4- change zone:
                if (zone_x < 2'b10) begin
                    zone_x <= zone_x + 1;
                    state <= PENDING;
                end else begin
                    zone_x <= 2'b00;
                    if (zone_y < 2'b10) begin
                        state <= PENDING;
                        zone_y <= zone_y + 1;
                    end else begin
                        // already looked all boxes and not break, return error
                        zone_y <= 2'b00;
                        state <= FINISHED;// POTENTIAL ERROR: MANIPULATING STATE TWICE??? (heavily modified it to stop that now)
                        centers_valid <= 1'b1;
                        // but still running through the last one yet, may find something

                        if (center_index > 2'b11) begin     ///EDIT
                            centers_not_found_error <= 1'b1;    //red you have more than 3 centers detected
                        end else if (center_index < 2'b11) begin   
                            centers_not_found_error2 <= 1'b1;   //green you have less than 3 centers detected
                        end
                    end
                end

                // add center of current box if majority is black
                if ( counter_black > ((counter_white + counter_black) - ((counter_white + counter_black)>>3)) ) begin
                        //EDIT removed the if
                        //EDIT up to 87.5% threshold
                        center_index <= center_index + 1;
                        // POTENTIAL ERROR: SYSTEM VERILOG CAN OVERFLOW IN THE MIDDLE OF ADDITOIN, SO OFFSET WITH 1'b0
                        
                        centers_x[center_index] <= (({1'b0, x_start} + {1'b0, x_end})>>1) + box_min_x; 
                        centers_y[center_index] <= (({1'b0, y_start} + {1'b0, y_end})>>1) + box_min_y;

                end 
            end 

            FINISHED: begin
                centers_valid <= 1'b0;
            end

            endcase

        end
    end

endmodule

`default_nettype wire


// DEBUGGING IDEA: READ counter_black and counter_white 