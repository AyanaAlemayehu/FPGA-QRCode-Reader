`timescale 1ns / 1ps
`default_nettype none

module finder_tb;
    // NEVER TESTED
    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic pixel_data;
    logic start_finder;

    logic[19:0] pixel_address;
    logic[2:0] finder_encodings;
    logic data_valid;

    horizontal_pattern_ratio_finder #(.WIDTH(150), .HEIGHT(3)) uut
            (.clk_in(clk_in), .rst_in(rst_in), .start_finder(start_finder),
             .pixel_data(pixel_data),
             .pixel_address(pixel_address),
             .finder_encodings(finder_encodings),
             .data_valid(data_valid));
    
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("finder.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,finder_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        pixel_data = 0;
        #10
        rst_in = 1;
        #20
        rst_in = 0;
        start_finder = 1;
        pixel_data = 1;
        #600;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #270;
        pixel_data = 0;
        #330;
        pixel_data = 1;
        #210;
        pixel_data = 0;
        #960;
        pixel_data = 1;
        #240;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #330;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #660;

        pixel_data = 1;
        #4500

        pixel_data = 1;
        #600;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #270;
        pixel_data = 0;
        #330;
        pixel_data = 1;
        #210;
        pixel_data = 0;
        #960;
        pixel_data = 1;
        #240;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #330;
        pixel_data = 0;
        #300;
        pixel_data = 1;
        #660;


        $display("Finishing Sim"); //print nice message
        $finish;



    end
endmodule //counter_tb
