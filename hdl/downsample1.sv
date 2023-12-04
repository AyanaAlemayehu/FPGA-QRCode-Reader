`timescale 1ns / 1ps
`default_nettype none
// WE ARE READING THE NON-ROTATED QR CODE, SO WE WILL INDEX INTO THE 90 degree counter-clockwise qr code
// FOR A 21 x 21 VERSION 1 QR CODE
module downsample_1 #(parameter CODE_SIZE = 21,
                    parameter WIDTH = 480)
    (
        input wire clk_in,
        input wire rst_in,
        input wire start_downsample,
        input wire reading_pixel,
        input wire [8:0] module_size,
        input wire [8:0] centers_x [2:0],
        input wire [8:0] centers_y [2:0],

        output logic [19:0] reading_address,
        output logic [440:0] qr_code,
        output logic valid_qr
    );


    typedef enum {RESET, WAIT_ONE, WAIT_TWO, DETERMINE, FINISHED} fsm_state;
    fsm_state state = RESET;
    // x and y are indexes within [0, 21)
    // min_x and min_y are the pixel offset of the begining center index of the top left most square module
    logic [10:0] x, y, max_x, min_y;
    
    // determines bounds of qr code
    // AGAIN, THE INDEXING AND ASSUMPTIONS IN THIS MODULE IS BASED UPON THE PRE-ROTATION QR CODE
    // thus the third finder pattern (determined by the 2nd index) is the location where we downsample
    always_comb begin
        max_x = centers_x[1] + module_size*3;
        min_y = centers_y[1] - module_size*3;
        reading_address = max_x - x*module_size + (min_y + y*module_size)*WIDTH;
    end
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            x <= 11'b0;
            y <= 11'b0;
            valid_qr <= 1'b0;
            qr_code <= 441'b0;
            state <= RESET;
        end
        else begin
            case (state)
                RESET: state <= (start_downsample) ? WAIT_ONE : RESET;

                WAIT_ONE: state <= WAIT_TWO;

                WAIT_TWO: state <= DETERMINE;

                DETERMINE: begin
                    if (reading_pixel)
                        qr_code[(CODE_SIZE-1-x) + y*CODE_SIZE] <= 1'b1;
                    if (x < CODE_SIZE-1) begin
                        x <= x + 1;
                        state <= WAIT_ONE;
                    end
                    else begin
                        x <= 11'b0;
                        if (y < CODE_SIZE-1) begin
                            y <= y + 1;
                            state <= WAIT_ONE;
                        end
                        else begin
                            state <= FINISHED;
                            valid_qr <= 1'b1;
                        end
                    end
                end

                FINISHED: valid_qr <= 1'b0;
            endcase
        
        end
    end
endmodule

`default_nettype wire
