`timescale 1ns / 1ps
`default_nettype none

module clean_patterns #(parameter WIDTH = 480)
    (   
        input wire clk_in,
        input wire rst_in,
        input wire [479:0] pattern,
        input wire start_cleaning,

        output logic data_valid,
        output logic [479:0] clean_pattern
    );

    parameter MIN_SIZE = 6;

    typedef enum {RESET, CLEAN_1, CLEAN_2, FINISHED} fsm_state;
    fsm_state state = RESET;
    logic [8:0] counter;
    logic [8:0] index;
    logic old_pixel;


    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            state <= RESET;
            index <= 9'b0;
            counter <= 9'b0;
            data_valid <= 1'b0;
        end


        else begin

            case (state)

            RESET: begin
                        if (start_cleaning) begin
                            state <= CLEAN_1;
                            clean_pattern <= ~480'b0;
                        end
                    end

            CLEAN_1: begin
                        old_pixel <= pattern[index];
                        index <= index + 1;
                        if (!pattern[index]) begin
                            counter <= counter + 1;
                            clean_pattern[index] <= 1'b0;

                        end else if (pattern[index]!= old_pixel)begin
                            counter <= 1'b0;
                            if (counter < MIN_SIZE) begin
                                if (index > 0)
                                    clean_pattern[index-1] <= 1'b1;
                                if (index > 1)
                                    clean_pattern[index-2] <= 1'b1;
                                if (index > 2)
                                    clean_pattern[index-3] <= 1'b1;
                                if (index > 3)
                                    clean_pattern[index-4] <= 1'b1;
                                if (index > 4)
                                    clean_pattern[index-5] <= 1'b1;
                            end
                        end

                        if (index == WIDTH-1) begin
                            state <= CLEAN_2;
                            counter <= 9'b0;
                            index <= 9'b0;
                            old_pixel <= 1'b0;
                        end
                    end

            CLEAN_2: begin
                        old_pixel <= pattern[index];
                        index <= index + 1;
                        if (clean_pattern[index]) begin
                            counter <= counter + 1;
                            clean_pattern[index] <= 1'b1;

                        end else if (pattern[index]!= old_pixel)begin
                            counter <= 1'b0;
                            if (counter < MIN_SIZE) begin
                                if (index > 0)
                                    clean_pattern[index-1] <= 1'b0;
                                if (index > 1)
                                    clean_pattern[index-2] <= 1'b0;
                                if (index > 2)
                                    clean_pattern[index-2] <= 1'b0;

                            end
                        end

                        if (index == WIDTH-1) begin
                            state <= FINISHED;
                            data_valid <= 1'b1;
                        end
                    end

            FINISHED: data_valid <=0;
            endcase
        end
    end

endmodule

`default_nettype wire