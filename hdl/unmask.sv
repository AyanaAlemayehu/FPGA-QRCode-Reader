`timescale 1ns / 1ps
`default_nettype none

module unmask
    #(parameter MOD_SIZE = 21)
    (
        input wire clk_in,
        input wire rst_in,
        input wire start_unmask,
        input wire [440:0] downsampled_qr,

        output logic [440:0] qr_unmasked,
        output logic unmask_ready
    );

    typedef enum {RESET, WAIT_ONE, WAIT_TWO, DETERMINE, FINISHED} fsm_state;
    fsm_state state = RESET;

    logic [2:0] mask_type;  // have to neg the mask cause we assumed black is 0 and white is 1 so far, but actually black is 1 and white is 0.
    assign mask_type = {(~downsampled_qr[12+2*MOD_SIZE] ^ 1'b1), (~downsampled_qr[12+3*MOD_SIZE] ^ 1'b0), (~downsampled_qr[12+4*MOD_SIZE] ^ 1'b1)};   //have to XOR mask pattern with 101.

    logic [9:0] address;
    assign address = x + y * MOD_SIZE;
    logic [8:0] x,y;
    logic [8:0] row, col;
    assign row = (MOD_SIZE-1) - x;
    assign col = y;

    logic unmask;


    always_comb begin
        case (mask_type)
        3'b000: unmask = ((row+col)%2) == 0;
        3'b001: unmask = (row%2) == 0;
        3'b010: unmask = (col%3) == 0;
        3'b011: unmask = ((row+col)%3 ) == 0;
        3'b100: unmask = (((row/2)+(col/3))%2)==0;
        3'b101: unmask = (((row%2)*(col%2))%2 + ((row%3)*(col%3))%3) == 0;
        3'b110: unmask = ((((row%2)*(col%2))%2 + ((row%3)*(col%3))%3)  %2) == 0;
        3'b111: unmask = ((((row%2)+(col%2))%2 + ((row%3)*(col%3))%3)  %2) == 0;
        default: unmask = 1'b0;
        endcase
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= RESET;
            x <= 9'b0;
            y <= 9'b0;
            unmask_ready <= 1'b0;
            qr_unmasked <= 441'b0;
        end

        else begin
            case (state)
            RESET: state <= (start_unmask)? WAIT_ONE: RESET;

            WAIT_ONE: state <= WAIT_TWO;

            WAIT_TWO: state <= DETERMINE;

            DETERMINE: begin
                if (x<MOD_SIZE-1) begin
                    x <=x+1;
                end else begin
                    if (y<MOD_SIZE-1) begin
                        x <= 1'b0;
                        y <= y+1;
                    end else begin
                        state <= FINISHED;
                        unmask_ready <= 1'b1;
                    end
                end

            qr_unmasked[address] = unmask ^ downsampled_qr[address];

            end

            FINISHED: unmask_ready <= 1'b0;
            default: state <= RESET;
            endcase
        end
    end

endmodule