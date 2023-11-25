`timescale 1ns / 1ps
`default_nettype none

// TESTBENCH DEPENDENT ON PERFECTLY CENTERED VERSION 1 QR CODE THATS ROTATED AND OFFCENTER
// IMAGE NEEDS TO BE INVERTED BECAUSE OF PECULARITIES WITH img-to-mem.py
// currently has inverted qr code loaded

// MODULE PASSES ROTATED TESTBENCH
module cross_patterns_tb_2;
    // NEVER TESTED
    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [479:0] horz_patterns;
    logic [479:0] vert_patterns;
    logic start_cross;
    logic [8:0] bound_x [1:0];
    logic [8:0] bound_y [1:0];

    logic [8:0] centers_x [2:0];
    logic [8:0] centers_y [2:0];
    logic centers_valid;
    logic centers_not_found_error;
    logic centers_not_found_error2;
    logic [19:0] counter_black_s [2:0];
    logic [19:0] counter_white_s [2:0];

   cross_patterns_testing_variant   uut
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .horz_patterns(horz_patterns),
        .vert_patterns(vert_patterns),
        .start_cross(start_cross),
        .bound_x(bound_x),
        .bound_y(bound_y),

        .centers_x(centers_x),
        .centers_y(centers_y),
        .centers_valid(centers_valid),
        .centers_not_found_error(centers_not_found_error),
        .centers_not_found_error2(centers_not_found_error2),
        .counter_black_s(counter_black_s),
        .counter_white_s(counter_white_s)
    );
    
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("cross.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,cross_patterns_tb_2); //store everything at the current level and below
        // visualizes the arrays
        $dumpvars(0, centers_x[0]);
        $dumpvars(0, centers_x[1]);
        $dumpvars(0, centers_x[2]);
        $dumpvars(0, centers_y[0]);
        $dumpvars(0, centers_y[1]);
        $dumpvars(0, centers_y[2]);
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        // initialize the horz and vert patterns data
        for (int i = 0; i < 480; i++) begin
            // determined from the qr code png
            // each if statement is its own finder pattern
            if (i > 195 && i < 215)
                horz_patterns[i] <= 1'b1;
            else if (i > 255 && i < 275)
                horz_patterns[i] <= 1'b1;
            else if (i > 400 && i < 425)
                horz_patterns[i] <= 1'b1;
            else
                horz_patterns[i] <= 1'b0;
            
            
            if (i > 190 && i < 210)
                vert_patterns[i] <= 1'b1;
            else if (i > 250 && i < 275)
                vert_patterns[i] <= 1'b1;
            else if (i > 340 && i < 360)
                vert_patterns[i] <= 1'b1;
            else
                vert_patterns[i] <= 1'b0;
        end
        // initialize bound_x and bound_y data
        bound_x[0] <= 224;
        bound_y[0] <= 224;// woowww syymmetric ;D
        bound_x[1] <= 284;
        bound_y[1] <= 284;
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;
        start_cross = 1;
        #10;
        start_cross = 0;
        #3000000 // wait for it to finish


        $display("Finishing Sim"); //print nice message
        $finish;



    end
endmodule //counter_tb
