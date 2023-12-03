`timescale 1ns / 1ps
`default_nettype none

module find_mod_size_tb;
    // NEVER TESTED
    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [8:0] centers_x [2:0];
    logic [8:0] centers_y [2:0];
    logic start_downsample;

    logic [8:0] mod_size; // oversized by a lot lol
    logic mod_size_valid;

    find_mod_size #(.MODULES(18)) uut
            (
                .clk_in(clk_in),
                .rst_in(rst_in),
                .centers_x(centers_x),
                .centers_y(centers_y),
                .start_downsample(start_downsample),

                .mod_size(mod_size),
                .mod_size_valid(mod_size_valid)
            );
    
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("mod_size.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,find_mod_size_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;
        centers_y[0] = 111;
        centers_y[1] = 100;
        centers_y[2] = 330;

        centers_x[0] = 110;
        centers_x[1] = 370;
        centers_x[2] = 360;
        start_downsample = 1'b1; 
        #1000;

        $display("Finishing Sim"); //print nice message
        $finish;



    end
endmodule //counter_tb
