`timescale 1ns / 1ps
`default_nettype none

module bounds_tb;
    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [479:0] horz_patterns, vert_patterns;
    logic start_bound;
    logic [8:0] bound_x [1:0];
    logic [8:0] bound_y [1:0];
    logic valid_bound;

    bounds uut
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .horz_patterns(horz_patterns),
        .vert_patterns(vert_patterns),
        .start_bound(start_bound),

        .bound_x(bound_x),
        .bound_y(bound_y),
        .valid_bound(valid_bound)
    );
    
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("bounds.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,bounds_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10
        rst_in = 1;
        #10
        rst_in = 0;
        start_bound = 1;
        // 3x3 example 
        for (int i = 0; i < 480; i++)begin
            if (i > 50 && i < 90 )begin
                horz_patterns[i] = 1'b1;
                vert_patterns[i] = 1'b1;
            end
            else if (i > 230 && i < 270 )begin
                horz_patterns[i] = 1'b1;
                vert_patterns[i] = 1'b1;
            end
            else if (i > 400 && i < 440 )begin
                horz_patterns[i] = 1'b1;
                vert_patterns[i] = 1'b1;
            end else begin
                horz_patterns[i] = 1'b0;
                vert_patterns[i] = 1'b0;             
            end
        end

        #10000
        


        $display("Finishing Sim"); //print nice message
        $finish;



    end
endmodule //counter_tb
