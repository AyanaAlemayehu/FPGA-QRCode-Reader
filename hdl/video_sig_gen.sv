module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20)
(
  input wire clk_pixel_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_COLS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out,
  output logic hs_out,
  output logic ad_out,
  output logic nf_out,
  output logic [5:0] fc_out);
 
  localparam TOTAL_COLS = (ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH);
  localparam TOTAL_LINES = (ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH); //figure this out (change me)

  /*
    Basically split into two parts:
        1) a horizontal component of 4 states (drawing, front porch, sync, back porch)
        2) a vertical component of 4 states (drawing, front porch, back porch)
    And metadata regarding the frame
  */

  // GOAL #1: Draw a single line
  logic init;
  always_ff @(posedge clk_pixel_in) begin
    if (rst_in)begin
        hcount_out <= 0;
        vcount_out <= 0;
        vs_out <= 0;
        hs_out <= 0;
        nf_out <= 0;
        fc_out <= 0;
        ad_out <= 0;
        init <= 1;
    end else begin
        // Draw line only if vcount within range (and hcount too ofc)
        if (hcount_out < ACTIVE_H_PIXELS  && vcount_out < ACTIVE_LINES) begin
            // minus one calculation to prepare signal change
            if (hcount_out == ACTIVE_H_PIXELS - 1) begin
                ad_out <= 0;
            end else begin
                ad_out <= 1;
            end
        end
        // Otherwise you're in a sync portion
        else begin
            // HORIZONTAL SYNC
            if (hcount_out >= ACTIVE_H_PIXELS + H_FRONT_PORCH - 1 && hcount_out < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH)begin // VERIFY THE >= IS CORRECT
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1)
                    hs_out <= 0;
                else 
                    hs_out <= 1;
            end
            ad_out <= 0;
        end
        // hcount and vcount ALWAYS increase, does not matter what the rest of the ciruit is doing
        if (hcount_out == TOTAL_COLS - 1)begin
            hcount_out <= 0;
            if (vcount_out == TOTAL_LINES - 1)begin
                vcount_out <= 0;
                // preempt ad_out again
                ad_out <= 1;
            end else begin
                vcount_out <= vcount_out + 1;
                // sloppy but do vsync here
                // VERTICAL SYNC
                if (vcount_out + 1 >= ACTIVE_LINES + V_FRONT_PORCH && vcount_out + 1 <= ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH)begin
                    if (vcount_out + 1 == ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH)
                        vs_out <= 0;
                    else
                        vs_out <= 1;
                end
            end
            // need to preempt ad_out
            if (vcount_out < ACTIVE_LINES - 1)// if we still have a line to go
                ad_out <= 1;
        end else begin
            if (!init)
                hcount_out <= hcount_out + 1;
            else
                init <= 0;
        end
        // frame count updates
        if (hcount_out == ACTIVE_H_PIXELS - 1 && vcount_out == ACTIVE_LINES)begin
            fc_out <= (fc_out == 59) ? 0 : fc_out + 1;
            nf_out <= 1;
        end else begin
            nf_out <= 0;
        end
    end
  end
 
endmodule