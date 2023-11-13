`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire [15:0] sw, //all 16 input slide switches
  input wire [3:0] btn, //all four momentary button switches
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic [2:0] hdmi_tx_p, //hdmi output signals (blue, green, red)
  output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives)
  output logic hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
  input wire [7:0] pmoda,
  input wire [2:0] pmodb,
  output logic pmodbclk,
  output logic pmodblock
  );

  /*
    VARIABLE INITIALIZATION
    --------------------------------------------------------------------
  */

    assign led = sw; //for debugging
    assign rgb1= 0;  //shut up those rgb LEDs (active high):
    assign rgb0 = 0;
    //have btnd control system reset
    logic sys_rst;
    assign sys_rst = btn[0];
    
    //Clocking Variables:
    logic clk_pixel, clk_5x; //clock lines (pixel clock and 1/2 tmds clock)
    logic locked; //locked signal (we'll leave unused but still hook it up)

    //Signals related to driving the video pipeline
    logic [10:0] hcount; //horizontal count
    logic [9:0] vcount; //vertical count
    logic vert_sync; //vertical sync signal
    logic hor_sync; //horizontal sync signal
    logic active_draw; //active draw signal
    logic new_frame; //new frame (use this to trigger center of mass calculations)
    logic [5:0] frame_count; //current frame

    //camera module: (see datasheet)
    logic cam_clk_buff, cam_clk_in; //returning camera clock
    logic vsync_buff, vsync_in; //vsync signals from camera
    logic href_buff, href_in; //href signals from camera
    logic [7:0] pixel_buff, pixel_in; //pixel lines from camera
    logic [15:0] cam_pixel; //16 bit 565 RGB image from camera
    logic valid_pixel; //indicates valid pixel from camera
    logic frame_done; //indicates completion of frame from camera

    //outputs of the recover module:
    logic [15:0] pixel_data_rec; // pixel data from recovery module
    logic [10:0] hcount_rec; //hcount from recovery module
    logic [9:0] vcount_rec; //vcount from recovery module
    logic  data_valid_rec; //single-cycle (74.25 MHz) valid data from recovery module

    //output of the scaled modules:
    logic [10:0] hcount_scaled; //scaled hcount for looking up camera frame pixel
    logic [9:0] vcount_scaled; //scaled vcount for looking up camera frame pixel
    logic valid_addr_scaled; //whether or not two values above are valid (or out of frame)

    //outputs of the rotation module:
    logic [16:0] img_addr_rot; //result of image transformation rotation
    logic valid_addr_rot; //forward propagated valid_addr_scaled
    logic [1:0] valid_addr_rot_pipe; //pipelining variables in || with frame_buffer

    //values from the frame buffer:
    logic [15:0] frame_buff_raw; //output of frame buffer (direct)
    logic [15:0] frame_buff; //output of frame buffer OR black (based on pipeline valid)

    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;

    //binarized output
    logic [7:0] bin_out;

    //final processed red, gren, blue for consumption in tmds module
    logic [7:0] red, green, blue;

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic tmds_signal [2:0]; //output of each TMDS serializer!

  /*
   PARAMETER INITIALIZATION
   ---------------------------------------------------------------------
  */
    localparam WIDTH = 320;
    localparam HEIGHT = 240;

  //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS,respectively
  hdmi_clk_wiz_720p mhdmicw (
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0),
      .locked(locked),
      .clk_ref(clk_100mhz)
  );
  
  //Clock domain crossing to synchronize the camera's clock
  //to be back on the 65MHz system clock, delayed by a clock cycle.
  always_ff @(posedge clk_pixel) begin
    cam_clk_buff <= pmodb[0]; //sync camera
    cam_clk_in <= cam_clk_buff;
    vsync_buff <= pmodb[1]; //sync vsync signal
    vsync_in <= vsync_buff;
    href_buff <= pmodb[2]; //sync href signal
    href_in <= href_buff;
    pixel_buff <= pmoda; //sync pixels
    pixel_in <= pixel_buff;
  end

  //from week 04! (make sure you include in your hdl) (same as before)
  video_sig_gen mvg(
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount),
      .vcount_out(vcount),
      .vs_out(vert_sync),
      .hs_out(hor_sync),
      .ad_out(active_draw),
      .nf_out(new_frame),
      .fc_out(frame_count)
  );

  //Controls and Processes Camera information
  camera camera_m(
    .clk_pixel_in(clk_pixel),
    .pmodbclk(pmodbclk), //data lines in from camera
    .pmodblock(pmodblock), //
    //returned information from camera (raw):
    .cam_clk_in(cam_clk_in),
    .vsync_in(vsync_in),
    .href_in(href_in),
    .pixel_in(pixel_in),
    //output framed info from camera for processing:
    .pixel_out(cam_pixel), //16 bit 565 RGB pixel
    .pixel_valid_out(valid_pixel), //pixel valid signal
    .frame_done_out(frame_done) //single-cycle indicator of finished frame
  );

  //The recover module takes in information from the camera
  // and sends out:
  // * 5-6-5 pixels of camera information
  // * corresponding hcount and vcount for that pixel
  // * single-cycle valid indicator
  recover recover_m (
    .valid_pixel_in(valid_pixel),
    .pixel_in(cam_pixel),
    .frame_done_in(frame_done),
    .system_clk_in(clk_pixel),
    .rst_in(sys_rst),
    .pixel_out(pixel_data_rec), //processed pixel data out
    .data_valid_out(data_valid_rec), //single-cycle valid indicator
    .hcount_out(hcount_rec), //corresponding hcount of camera pixel
    .vcount_out(vcount_rec) //corresponding vcount of camera pixel
  );

  // scale
  scale(
    .scale_in({sw[0],btn[1]}),
    .hcount_in(hcount),
    .vcount_in(vcount),
    .scaled_hcount_out(hcount_scaled),
    .scaled_vcount_out(vcount_scaled),
    .valid_addr_out(valid_addr_scaled)
  );

  //Rotates and mirror-images Image to render correctly (pi/2 CCW rotate):
  // The output address should be fed right into the frame buffer for lookup
  rotate rotate_m (
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .hcount_in(hcount_scaled),
    .vcount_in(vcount_scaled),
    .valid_addr_in(valid_addr_scaled),
    .pixel_addr_out(img_addr_rot),
    .valid_addr_out(valid_addr_rot)
    );

  //Framebuffer
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(16), //each entry in this memory is 16 bits
    .RAM_DEPTH(WIDTH*HEIGHT)) //there are 240*320 or 76800 entries for full frame
    frame_buffer (
    .addra(hcount_rec + WIDTH*vcount_rec), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(data_valid_rec),
    .dina(pixel_data_rec),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(img_addr_rot),//transformed lookup pixel
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(valid_addr_rot),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(frame_buff_raw)
  );
  
  // pipelined valid_addr_rot to take care of BRAM 2 clock latency
  always_ff @(posedge clk_pixel)begin
    valid_addr_rot_pipe[0] <= valid_addr_rot;
    valid_addr_rot_pipe[1] <= valid_addr_rot_pipe[0];
  end
  assign frame_buff = valid_addr_rot_pipe[1]?frame_buff_raw:16'b0;

  // //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
  // assign fb_red = {frame_buff[15:11],3'b0};
  // assign fb_green = {frame_buff[10:5], 2'b0};
  // assign fb_blue = {frame_buff[4:0],3'b0};

  // calculate binarized version
  binary bin(
    .clk_in(clk_pixel),
    .pixel_in(frame_buff),
    .thresh_in(sw[15:8]),
    .bin_out(bin_out)
  );

  // binarized output routed directly to tmds encoders
  assign red = frame_buff == 16'b0 ? 8'b0 : bin_out;
  assign green = frame_buff == 16'b0 ? 8'b0 : bin_out;
  assign blue = frame_buff == 16'b0 ? 8'b0 : bin_out;


  // // Camera output routed directly to tmds encoders
  // assign red = fb_red;
  // assign green = fb_green;
  // assign blue = fb_blue;

  //three tmds_encoders (blue, green, red)
  tmds_encoder tmds_red(
	.clk_in(clk_pixel),
  .rst_in(sys_rst),
	.data_in(red),
  .control_in(2'b0),
	.ve_in(active_draw),
	.tmds_out(tmds_10b[2]));

  tmds_encoder tmds_green(
	.clk_in(clk_pixel),
  .rst_in(sys_rst),
	.data_in(green),
  .control_in(2'b0),
	.ve_in(active_draw),
	.tmds_out(tmds_10b[1]));

  tmds_encoder tmds_blue(
	.clk_in(clk_pixel),
  .rst_in(sys_rst),
	.data_in(blue),
  .control_in({vert_sync,hor_sync}),
	.ve_in(active_draw),
	.tmds_out(tmds_10b[0]));

  //four tmds_serializers (blue, green, red, and clock)
  tmds_serializer red_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[2]),
    .tmds_out(tmds_signal[2]));

  tmds_serializer green_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[1]),
    .tmds_out(tmds_signal[1]));

  tmds_serializer blue_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[0]),
    .tmds_out(tmds_signal[0]));

  //output buffers generating differential signal:
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

endmodule // top_level
`default_nettype wire
