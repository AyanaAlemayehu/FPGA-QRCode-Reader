`timescale 1ns / 1ps
`default_nettype none

module rotate #(
  parameter WIDTH = 640 // again image is stored rotated, so width is our final height
)(
  input wire clk_in,
  input wire rst_in,
  input wire[10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire valid_addr_in,
  output logic [19:0] pixel_addr_out,
  output logic valid_addr_out);

  logic [10:0] rot_hcount;
  logic [9:0] rot_vcount;

  always_comb begin
    rot_hcount = (WIDTH - 1) - vcount_in;
    rot_vcount = hcount_in;
  end
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      valid_addr_out <= 0;
      pixel_addr_out <= 0;
    end else begin
      valid_addr_out <= valid_addr_in;
      if (valid_addr_in)begin
        pixel_addr_out <= WIDTH*rot_vcount + rot_hcount;
      end
    end
  end
endmodule

`default_nettype wire
