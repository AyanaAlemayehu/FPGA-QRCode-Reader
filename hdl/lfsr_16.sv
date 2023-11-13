module lfsr_16 ( input wire clk_in, input wire rst_in,
                    input wire [15:0] seed_in,
                    output logic [15:0] q_out);
  
  logic q1, q2, q3, q4, q5, q6, q7, q8, q9, q10, q11, q12,q13, q14, q15, q16;
  assign q_out = {q16, q15, q14, q13,q12, q11, q10, q9,q8, q7, q6, q5,q4, q3, q2, q1};
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        q1 <= seed_in[0];
        q2 <= seed_in[1];
        q3 <= seed_in[2];
        q4 <= seed_in[3];
      q5 <= seed_in[4];
      q6 <= seed_in[5];
      q7 <= seed_in[6];
      q8 <= seed_in[7];
      q9 <= seed_in[8];
      q10 <= seed_in[9];
      q11 <= seed_in[10];
      q12 <= seed_in[11];
      q13 <= seed_in[12];
      q14 <= seed_in[13];
      q15 <= seed_in[14];
      q16 <= seed_in[15];
    end else begin
        q1 <= q16;
        q2 <= q1;
        q3 <= q2^q16;
        q4 <= q3;
        q5 <= q4;
        q6 <= q5;
        q7 <= q6;
        q8 <= q7;
        q9 <= q8;
        q10 <= q9;
        q11 <= q10;
        q12 <= q11;
        q13 <= q12;
        q14 <= q13;
        q15 <= q14;
        q16 <= q15^q16;
    end
  
  end


endmodule

