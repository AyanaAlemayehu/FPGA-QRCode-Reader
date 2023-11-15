/*
  - centralizes camera output
*/
`timescale 1ns / 1ps
`default_nettype none

module scale #(
  parameter HEIGHT = 640,
  parameter WIDTH = 480
)
(
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  output logic [10:0] scaled_hcount_out,
  output logic [9:0] scaled_vcount_out,
  output logic valid_addr_out
);

  // the input address is centralized, thats when there is a valid addr.
  // BASED UPON 1280 x 720 HDMI OUTPUT
  assign valid_addr_out = (hcount_in > (1280 - WIDTH)/2) &&
                          (hcount_in < (1280 - WIDTH)/2 + WIDTH) &&
                          (vcount_in > (720 - HEIGHT)/2) && 
                          (vcount_in < (720 - HEIGHT)/2 + HEIGHT);
  assign scaled_hcount_out = hcount_in - (1280 - WIDTH)/2;
  assign scaled_vcount_out = vcount_in - (720 - HEIGHT)/2;

endmodule


`default_nettype wire

