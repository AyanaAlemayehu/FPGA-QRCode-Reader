`timescale 1ns / 1ps
`default_nettype none
// ONE IS BLACK ONLY IN DECODING
module vertical_pattern_ratio_finder
    #(parameter WIDTH = 480,
      parameter HEIGHT = 480,
      parameter ERROR = 1)
    (
        input wire clk_in,
        input wire rst_in,
        input wire pixel_data,
        input wire start_finder,

        output logic[19:0] pixel_address,
        output logic[479:0] finder_encodings,
        output logic data_valid
    );

    typedef enum {RESET, WAIT_ONE, WAIT_TWO, DETERMINE, FINISHED} fsm_state;
    typedef enum {RESET2, BACKGROUND, BLACK_ONE_START, WHITE_ONE_START, BLACK_THREE, WHITE_ONE_END, BLACK_ONE_END, VALID_RATIO} ratio_state;

    logic old_pixel;
    logic new_line;
    logic [8:0] index;
    logic [8:0] black, white;
    logic [8:0] y;
    logic [8:0] length;
    fsm_state state = RESET; // check here for errors
    ratio_state state_ratio = RESET2;
    assign pixel_address = index + y*WIDTH;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= RESET;
            index <= 9'b0;
            y <= 9'b0;
            old_pixel <= 1'b0;
            new_line <= 1'b0;
            black <= 9'b1;
            white <= 9'b1;
        end
        else begin
            case(state)
            
                RESET: begin
                    if (start_finder) begin
                        state <= WAIT_ONE;
                    end
                end
                WAIT_ONE: begin
                    state <= WAIT_TWO;
                    new_line <= 1'b0;
                end
                WAIT_TWO: begin
                    state <= DETERMINE;
                end
                DETERMINE: begin
                    old_pixel <= pixel_data;
                    // always increase x and or y
                    if (y < HEIGHT - 1) begin
                        y <= y + 1;
                        state <= WAIT_ONE;
                    end
                    else begin
                        black <= 9'b1;
                        white <= 9'b1;
                        y <= 0;
                        new_line <= 1'b1;
                        index <= index + 1;
                        if (index == HEIGHT - 1) begin
                            state <= FINISHED;
                            data_valid <= 1'b1;
                        end
                        else begin
                            state <= WAIT_ONE;
                        end
                    end
                    if (pixel_data == old_pixel) begin
                        if (pixel_data)begin
                            white <= white + 1;
                            black <= 0;
                        end else begin
                            black <= black + 1;
                            white <= 0;
                        end
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
            state_ratio <= RESET2;
            length <= 9'b0;
        end
        else begin
            if (new_line) begin
                state_ratio <= BACKGROUND;
            end
            else begin
                case(state_ratio)
                    RESET2: begin
                        if (start_finder)
                            state_ratio <= BACKGROUND;
                    end
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
                                state_ratio <= ((white - length) < (length >> ERROR)) ? BLACK_THREE : BLACK_ONE_START;
                            end
                            else begin
                                state_ratio <= ((length - white) < (length >> ERROR)) ? BLACK_THREE : BLACK_ONE_START;
                            end
                        end
                    end
                    BLACK_THREE: begin
                        if (pixel_data) begin
                            // determine if within spec of ratio
                            // absolute value
                            if (black > 3*length)begin
                                if ((black - 3*length) < (length >> ERROR)) begin
                                    state_ratio <= WHITE_ONE_END;
                                end else begin
                                    state_ratio <= WHITE_ONE_START;
                                    length <= black;
                                end
                            end
                            else begin
                                if ((3*length - black) < (length >> ERROR)) begin
                                    state_ratio <= WHITE_ONE_END;
                                end else begin
                                    state_ratio <= WHITE_ONE_START;
                                    length <= black; // new refernce length
                                end
                            end
                        end
                    end
                    WHITE_ONE_END: begin
                        if (~pixel_data) begin
                            // determine if within spec of ratio
                            // absolute value
                            if (white > length)begin
                                state_ratio <= ((white - length) < (length >> ERROR)) ? BLACK_ONE_END : BLACK_ONE_START;
                            end
                            else begin
                                state_ratio <= ((length - white) < (length >> ERROR)) ? BLACK_ONE_END : BLACK_ONE_START;
                            end
                        end
                    end
                    BLACK_ONE_END: begin
                        if (pixel_data) begin
                            // determine if within spec of ratio
                            // absolute value
                            if (black > length)begin
                                if ((black - length) < (length >> ERROR)) begin
                                    state_ratio <= VALID_RATIO;
                                end else begin
                                    state_ratio <= WHITE_ONE_START;
                                    length <= black;
                                end
                            end
                            else begin
                                if ((length - black) < (length >> ERROR)) begin
                                    state_ratio <= VALID_RATIO;
                                end else begin
                                    state_ratio <= WHITE_ONE_START;
                                    length <= black;
                                end
                            end
                        end
                    end
                    VALID_RATIO: begin
                        finder_encodings[index] <= 1'b1;
                        // state_ratio <= new_line ? BACKGROUND : VALID_RATIO;
                    end
                endcase
            end
        end
    end

endmodule
`default_nettype wire
