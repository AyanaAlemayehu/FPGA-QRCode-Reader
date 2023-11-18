`timescale 1ns / 1ps
`default_nettype none

module average_tb;
    // NEVER TESTED
    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic buffer_pixel_data;
    logic start;

    logic[18:0] buffer_address;
    logic[18:0] BRAM_one_address;
    logic BRAM_one_data;
    logic BRAM_one_data_valid;
    logic average_finished;

    localparam WIDTH = 10;
    localparam HEIGHT = 10;

    average #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) uut
            (.clk_in(clk_in), .rst_in(rst_in), .start_average(start),
             .buffer_pixel_data(buffer_pixel_data),
             .buffer_address(buffer_address),
             .BRAM_one_address(BRAM_one_address),
             .BRAM_one_data(BRAM_one_data),
             .BRAM_one_average_data_valid(BRAM_one_average_data_valid),
             .average_finished(average_finished));
    
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("average.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,average_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        start = 0;
        buffer_pixel_data = 0;
        #100; // wait 10 clock cycles
        rst_in = 1;
        #10;
        rst_in = 0;
        #20;
        // now trigger start
        start = 1;
        #10;
        // send data at 2 cycle intervals
        #20
        // alternating
        for (int i = 0; i<WIDTH*HEIGHT; i= i+1)begin
           buffer_pixel_data = ~buffer_pixel_data;//alternate
          #20;
        end
        
        $display("Finishing Sim"); //print nice message
        $finish;



    end
endmodule //counter_tb

`default_nettype wire