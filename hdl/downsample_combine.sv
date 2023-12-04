`timescale 1ns / 1ps
`default_nettype none

module downsample_combine #(parameter CODE_SIZE = 21)
    (
        input wire [440:0] qr_0,
        input wire [440:0] qr_1,
        input wire [440:0] qr_2,
        output logic [440:0] qr_code
    );

    always_comb begin
        for (integer x = 0; x<CODE_SIZE; x=x+1) begin
            for (integer y=0; y<CODE_SIZE; y=y+1) begin

                if (x < 10) begin
                    if (y < 10) begin
                        qr_code[x + y*CODE_SIZE] = qr_0[x + y*CODE_SIZE];
                    end 
                    else begin
                        qr_code[x + y*CODE_SIZE] = qr_2[x + y*CODE_SIZE];
                    end 
                end
                else begin
                    if (y < 10) begin
                        qr_code[x + y*CODE_SIZE] = qr_1[x + y*CODE_SIZE];
                    end 
                    else begin
                        qr_code[x + y*CODE_SIZE] = qr_2[x + y*CODE_SIZE];
                    end 
                end

            end 
        end 
    end

endmodule