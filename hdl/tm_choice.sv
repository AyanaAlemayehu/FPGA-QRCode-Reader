`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );
  //your code here, friend
  logic [4:0] kount;
  count_ones kounter (.data_in(data_in), .sum_out(kount));
  always_comb begin
    if ((kount > 4) || (kount == 4 && data_in[0] == 0)) begin
        qm_out[0] = data_in[0];
        qm_out[1] = ~(data_in[1] ^ qm_out[0]);
        qm_out[2] = ~(data_in[2] ^ qm_out[1]);
        qm_out[3] = ~(data_in[3] ^ qm_out[2]);
        qm_out[4] = ~(data_in[4] ^ qm_out[3]);
        qm_out[5] = ~(data_in[5] ^ qm_out[4]);
        qm_out[6] = ~(data_in[6] ^ qm_out[5]);
        qm_out[7] = ~(data_in[7] ^ qm_out[6]);
        qm_out[8] = 0;
    end else begin
        qm_out[0] = data_in[0];
        qm_out[1] = data_in[1] ^ qm_out[0];
        qm_out[2] = data_in[2] ^ qm_out[1];
        qm_out[3] = data_in[3] ^ qm_out[2];
        qm_out[4] = data_in[4] ^ qm_out[3];
        qm_out[5] = data_in[5] ^ qm_out[4];
        qm_out[6] = data_in[6] ^ qm_out[5];
        qm_out[7] = data_in[7] ^ qm_out[6];
        qm_out[8] = 1;
    end

  end
endmodule //end tm_choice

module count_ones (
  input wire [7:0] data_in,
  output logic [4:0] sum_out
);
    // logic c0, c1, c2, c3, c4;// all of the carry bits
    // logic f0, f1, f2, f3, f4;// all of the full adder bits
    logic c1, c2;
    logic f0, f1;
    
    // FA the first two bits
    assign f0 = data_in[0] ^ data_in[1];
    assign c1 = data_in[0] & data_in[1];
    // FA the next two bits
    assign f1 = data_in[2] ^ data_in[3];
    assign c2 = (data_in[2] & data_in[3]);
    //rca2 them
    logic [3:0] sumOne;
    rca2 adderOne(.a0({c1, f0}), .b0({c2, f1}), .c0(1'b0), .sum_out(sumOne));// no carry

    // repeat for the last half
    logic c3, c4;
    logic f2, f3;
    // FA the first two bits
    assign f2 = data_in[4] ^ data_in[5];
    assign c3 = data_in[4] & data_in[5];
    // FA the next two bits
    assign f3 = data_in[6] ^ data_in[7];
    assign c4 = (data_in[6] & data_in[7]);
    //rca2 them
    logic [3:0] sumTwo;
    rca2 adderTwo(.a0({c3, f2}), .b0({c4, f3}), .c0(1'b0), .sum_out(sumTwo));// no carry
    // finally compute the output
    rca4 adderThree(.a0({sumOne}), .b0({sumTwo}), .c0(1'b0), .sum_out(sum_out));
endmodule

module rca2 (
  input wire[1:0] a0,
  input wire[1:0] b0,
  input wire c0,
  output logic[3:0] sum_out
);

  logic b00, b11, b22;
  logic x0;// helper carry?

  assign b00 = a0[0] ^ b0[0] ^ c0;
  assign x0 = (a0[0] & b0[0]) | (a0[0] ^ b0[0]) & c0;

  assign b11 = a0[1] ^ b0[1] ^ x0;
  assign b22 = (a0[1] & b0[1]) | (a0[1] ^ b0[1]) & x0;
  assign sum_out = {b22, b11, b00};
endmodule

module rca4 (// modified rca4 to drop final carry
  input wire[3:0] a0,
  input wire[3:0] b0,
  input wire c0,
  output logic[4:0] sum_out
);
  logic[3:0] lower, upper;

  rca2 addLowerHalf(.a0({a0[1:0]}), .b0({b0[1:0]}), .c0(c0), .sum_out(lower));
  rca2 addUpperHalf(.a0({a0[3:2]}), .b0({b0[3:2]}), .c0(lower[2]), .sum_out(upper));

  assign sum_out = {upper[2:0], lower[1:0]};
endmodule

`default_nettype wire