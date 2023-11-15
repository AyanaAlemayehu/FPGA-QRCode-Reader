`timescale 1ns / 1ps
`default_nettype none
// binarizes the input pixels for storage in the framebuffer, grabs data from recover.sv
module binary
    (
        input wire clk_in,
        input wire [15:0] pixel_in, // assumed to be in the camera's 16 bit format
        input wire [8:0] thresh_in,
        output logic bin_out // the 1/0 version of the pixel_in (8 BIT FOR TESTING RN),
                                  // defined by the threshold and y chromincance of input
    );

    //output of rgb to ycrcb conversion (10 bits due to module)
    logic [9:0] y_full; //y component of y cr cb conversion of full pixel
    // pipelines for latency, bottom eight of the full values
    logic [7:0] y_pipe [2:0];
    
    always_ff @(posedge clk_in) begin
        y_pipe[0] <= y_full[7:0];
        for (int i=1; i<3; i = i+1)begin
            y_pipe[i] <= y_pipe[i-1];
        end
    end

    // THREE CYCLE LATENCY 
    rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_in),
    .r_in(pixel_in[15:11]),
    .g_in(pixel_in[10:5]),
    .b_in(pixel_in[4:0]),
    .y_out(y_full)
    );

    assign bin_out = y_pipe[2] < thresh_in ? 1'b0 : 1'b1;

endmodule
`default_nettype wire
