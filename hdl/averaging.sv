`timescale 1ns / 1ps
`default_nettype none
module average
    #(parameter WIDTH = 480,
      parameter HEIGHT = 480)
    (
        input wire clk_in,
        input wire rst_in,
        input wire buffer_pixel_data,
        input wire start_average,

        output logic[18:0] buffer_address,
        output logic[18:0] BRAM_one_address,
        output logic BRAM_one_data,
        output logic BRAM_one_data_valid,
        output logic average_finished
    );

    logic [8:0] center_x, center_y;
    logic [3:0] neighbor_counter;
    logic [8:0] neighbors;
    logic [3:0] num_ones;
    assign num_ones =   (neighbors[0]&1'b1) + 
                        (neighbors[1]&1'b1) + 
                        (neighbors[2]&1'b1) + 
                        (neighbors[3]&1'b1) + 
                        (neighbors[4]&1'b1) + 
                        (neighbors[5]&1'b1) + 
                        (neighbors[6]&1'b1) + 
                        (neighbors[7]&1'b1) + 
                        (neighbors[8]&1'b1);

    logic valid_center_x_y;
    assign valid_center_x_y = (center_x > 0) && 
                              (center_y > 0) && 
                              (center_x < WIDTH) && 
                              (center_y < HEIGHT);
    
    typedef enum {RESET, GRAB, WAIT_ONE, WAIT_TWO, AVERAGE, FINISHED} fsm_state;
    fsm_state state = RESET; // check here for errors

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= RESET;
            center_x <= 0;
            center_y <= 0;
            neighbors <= 9'b0;
            average_finished <= 1'b0;
        end
        else begin
            if (state == RESET) begin
                if (start_average)
                    state <= GRAB;
                neighbor_counter <= 4'b0;
            end
            else if (state == GRAB) begin
                // need to start grabbing pixels at 2 cycle intervals

                // first check to see if out of bounds
                // determining accurate address
                neighbor_counter <= neighbor_counter + 1; // MODULO TAKEN CARE OF BY LATER STATES
                if (valid_center_x_y) begin
                    case(neighbor_counter)
                        4'd0: buffer_address <= (center_x - 1) + (center_y - 1)*WIDTH;
                        4'd1: buffer_address <= (center_x) + (center_y - 1)*WIDTH;
                        4'd2: buffer_address <= (center_x + 1) + (center_y - 1)*WIDTH;                       
                        4'd3: buffer_address <= (center_x - 1) + (center_y)*WIDTH; 
                        4'd4: buffer_address <= (center_x) + (center_y)*WIDTH;
                        4'd5: buffer_address <= (center_x + 1) + (center_y)*WIDTH; 
                        4'd6: buffer_address <= (center_x - 1) + (center_y + 1)*WIDTH;  
                        4'd7: buffer_address <= (center_x) + (center_y + 1)*WIDTH;  
                        4'd8: buffer_address <= (center_x + 1) + (center_y + 1)*WIDTH; 
                        default: buffer_address <= 19'b0;// should never happen
                    endcase
                end
                else begin
                    // you are just average off of yourself
                    buffer_address <= center_x + (center_y)*WIDTH;
                end
                state <= WAIT_ONE; 
            end
            else if (state == WAIT_ONE) begin
                state <= WAIT_TWO;
            end
            else if (state == WAIT_TWO) begin
                // at this point the data is valid from the buffer
                neighbors[neighbor_counter] <= buffer_pixel_data;
                // two cases, we either have all of the neighbors (and need to average) or dont
                if (neighbor_counter == 4'd8) begin
                    neighbor_counter <= 0;
                    state <= AVERAGE;
                end
                else begin
                    state <= GRAB;
                end
            end
            else if (state == AVERAGE) begin
                // averages the pixel values & increments the center
                if (center_x == WIDTH - 1) begin
                    if (center_y == HEIGHT - 1) begin
                        state <= FINISHED;
                        average_finished <= 1'b1;
                    end
                    else begin
                        center_x <= 0;
                        center_y <= center_y + 1;
                        state <= GRAB;
                    end
                end
                else begin
                    center_x <= center_x + 1;
                    state <= GRAB;
                end

                BRAM_one_address <= center_x + center_y*WIDTH;
                BRAM_one_data <= num_ones > 4;
                BRAM_one_data_valid <= 1'b1;
            end
            else if (state == FINISHED) begin
                average_finished <= 1'b0;
            end
        end
    end

endmodule
`default_nettype wire
