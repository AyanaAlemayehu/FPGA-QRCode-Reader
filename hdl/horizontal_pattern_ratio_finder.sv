`timescale 1ns / 1ps
`default_nettype none
// ONE IS BLACK ONLY IN DECODING
module horizontal_pattern_ratio_finder
    #(parameter WIDTH = 480,
      parameter HEIGHT = 480)
    (
        input wire clk_in,
        input wire rst_in,
        input wire pixel_data,

        output logic[19:0] pixel_address,
        output logic[479:0] finder_encodings,
        output logic data_valid
    );

    typedef enum {RESET, WAIT_ONE, WAIT_TWO, DETERMINE, FINISHED} fsm_state;
    typedef enum {BACKGROUND, BLACK_ONE_START, WHITE_ONE_START, BLACK_THREE, WHITE_ONE_END, BLACK_ONE_END, VALID_RATIO} ratio_state;

    logic old_pixel;
    logic [8:0] index;
    logic [8:0] black, white;
    logic [8:0] x, y;
    logic [8:0] length;
    fsm_state state = RESET; // check here for errors
    ratio_state state_ratio = BACKGROUND;
    assign pixel_address <= x + y*WIDTH;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            index <= 9'b0;
            x <= 9'b0;
            y <= 9'b0;
            old_pixel <= 1'b1;
            length <= 9'b0;
            new_line <= 1'b0;
        end
        else begin
            case(state)
            
                RESET: begin
                    state <= WAIT_ONE;
                end
                WAIT_ONE: begin
                    state <= WAIT_TWO;
                    new_line <= 1'b0;
                end
                WAIT_TWO: begin
                    state <= DETERMINE;
                end
                DETERMINE: begin
                    // always increase x and or y
                    if (x < 480) begin
                        x <= x + 1;
                    end
                    else begin
                        x <= 0;
                        y <= y + 1;
                        new_line <= 1'b1;
                        index <= index + 1;
                        if (index == 479) begin
                            state <= FINISHED;
                            data_valid <= 1'b1;
                        end
                        else begin
                            state <= WAIT_ONE;
                        end
                    end
                    if (pixel_data == old_pixel) begin
                        if (pixel_data)
                            white <= white + 1;
                        else
                            black <= black + 1;
                    end
                    else begin
                        if (pixel_data)begin
                            black <= 0;
                            white <= 1;
                        end
                        else begin
                            white <= 0;
                            black <= 1;
                        end
                    end
                end
                FINISHED: begin
                    data_valid <= 1'b0;
                    // stay here until reset
                end
            endcase
        end
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state_ratio <= BACKGROUND;
        end
        else begin
            case(state_ratio)
                BACKGROUND: begin
                    finder_encodings[index] <= 1'b0;
                    if (!pixel_data) // note zero is black b/c we are not decoding
                        state_ratio <= BLACK_ONE_START;
                end
                BLACK_ONE_START: begin
                    if (pixel_data) begin
                        // this means we have determined the length for the ratio
                        length <= black;
                        state_ratio <= WHITE_ONE_START;
                    end
                end
                WHITE_ONE_START: begin
                    if (~pixel_data) begin
                        // determine if within spec of ratio
                        // absolute value
                        if (white > length)begin
                            state_ratio <= (white - length < length << 2) ? BLACK_THREE : BLACK_ONE_START;
                        end
                        else begin
                            state_ratio <= (length - white < length << 2) ? BLACK_THREE : BLACK_ONE_START;
                        end
                    end
                end
                BLACK_THREE: begin
                    if (pixel_data) begin
                        // determine if within spec of ratio
                        // absolute value
                        if (black > 3*length)begin
                            state_ratio <= (black - 3*length < length << 2) ? WHITE_ONE_END : BACKGROUND;
                        end
                        else begin
                            state_ratio <= (3*length - black < length << 2) ? WHITE_ONE_END : BACKGROUND;
                        end
                    end
                end
                WHITE_ONE_END: begin
                    if (~pixel_data) begin
                        // determine if within spec of ratio
                        // absolute value
                        if (white > length)begin
                            state_ratio <= (white - length < length << 2) ? BLACK_ONE_END : BLACK_ONE_START;
                        end
                        else begin
                            state_ratio <= (length - white < length << 2) ? BLACK_ONE_END : BLACK_ONE_START;
                        end
                    end
                end
                BLACK_ONE_END: begin
                    if (pixel_data) begin
                        // determine if within spec of ratio
                        // absolute value
                        if (black > length)begin
                            state_ratio <= (black - length < length << 2) ? VALID_RATIO : BLACK_ONE_START;
                        end
                        else begin
                            state_ratio <= (length - black < length << 2) ? VALID_RATIO : BLACK_ONE_START;
                        end
                    end
                end
                VALID_RATIO: begin
                    finder_encodings[index] <= 1'b1;
                    state_ratio <= new_line ? BACKGROUND : VALID_RATIO;
                end
            endcase
        end
    end

endmodule
`default_nettype wire