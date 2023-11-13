`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
//   output logic [8:0] q_m_out,
//   output logic [4:0] tally_out,
//   output logic [4:0] num_ones_out,
//   output logic [4:0] num_zeros_out
);
 
  logic [8:0] q_m;
  logic [4:0] tally; // <--- cnt ??
  logic [4:0] num_ones;
  logic [4:0] num_zeros;

//   assign tally_out = tally;
//   assign q_m_out = q_m;
//   assign num_ones_out = num_ones;
//   assign num_zeros_out = num_zeros;

  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  count_ones oneCounter (.data_in(q_m[7:0]), .sum_out(num_ones));
  count_ones zeroCounter(.data_in(~q_m[7:0]), .sum_out(num_zeros)); // negate so that it counts the zeros
 
 
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        tmds_out <= 0;  
        tally <= 0;  
    end 
    else if (ve_in) begin
        if ((tally == 0) || (num_ones == num_zeros)) begin
            tmds_out[9] <= ~q_m[8];
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= (q_m[8]) ? q_m[7:0] : ~q_m[7:0];
            if (q_m[8] == 1'b0) begin
                tally <= tally + num_zeros - num_ones;
            end
            else begin
                tally <= tally + num_ones - num_zeros;
            end
        end
        else begin
            if ((tally[4] == 0 && num_ones > num_zeros) || (tally[4] == 1 && num_ones < num_zeros)) begin // tally[7] is msb used to determine negativness
                tmds_out[9] <= 1;
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= ~q_m[7:0];
                tally <= tally + {q_m[8], 1'b0} + num_zeros - num_ones;
            end
            else begin
                tmds_out[9] <= 0;
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= q_m[7:0];
                tally <= tally - {~q_m[8], 1'b0} + num_ones - num_zeros;
            end
        end
    end 
    else begin
        tally <= 0;
        case (control_in) 
            2'b00: tmds_out <= 10'b1101010100;
            2'b01: tmds_out <= 10'b0010101011;
            2'b10: tmds_out <= 10'b0101010100;
            2'b11: tmds_out <= 10'b1010101011;
            default: tmds_out <= 'X;// default undefined to break early
        endcase
    end
  end
endmodule
`default_nettype wire