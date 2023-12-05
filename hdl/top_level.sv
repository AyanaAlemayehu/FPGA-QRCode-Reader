`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire [15:0] sw, //all 16 input slide switches
  input wire uart_rxd, // uart for manta instance
  input wire [3:0] btn, //all four momentary button switches
  output logic uart_txd,
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
    CONTROLS:
    - sw[0] captures a photo, frame_buffer on screen
    - sw[1] starts the decoding process
    - sw[2] BRAM1 on screen
    - sw[15] -> sw[8] control the threshold (on 0 - 255 scale)
  */

  /*
    VARIABLE INITIALIZATION
    --------------------------------------------------------------------
  */

    // assign led = sw; //for debugging
    // assign rgb1= 0;  //shut up those rgb LEDs (active high):
    // assign rgb0 = 0;
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
    logic [19:0] img_addr_rot; //result of image transformation rotation
    logic valid_addr_rot; //forward propagated valid_addr_scaled
    logic [1:0] valid_addr_rot_pipe; //pipelining variables in || with frame_buffer

    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;

    //binarized output
    logic bin_out;

    //final processed red, gren, blue for consumption in tmds module
    logic [7:0] red, green, blue;

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic tmds_signal [2:0]; //output of each TMDS serializer!

    // values to go on hdmi, read from Memory or zero depending on the state.
    logic hdmi_out_raw_pixel;   // pixel value read from a certain BRAM (direct)
    logic hdmi_out_pixel;   // what to go on screen, from hdmi_out_raw_pixel, (based on pipeline valid)

  /*
   PARAMETER INITIALIZATION
   ---------------------------------------------------------------------
  */
    // why two different height/widths? Because camera is outputting 640x480, but we are only using 480x480 of its output
    // to store in the BRAM. Thus, depending on where the module is in the pipeline, we will use different paramters
    localparam WIDTH = 640;// note its flipped because image is stored rotated (thus this should be the higher number)
    localparam HEIGHT = 480;
    localparam STORED_WIDTH = 480;
    localparam STORED_HEIGHT = 480;
    localparam QR_SIZE = 21;


  /*
    Top Level State Maching
  */
    typedef enum {RESET, STREAMING1, AVERAGING, HORIZ_PATTERNS, VERT_PATTERNS, CLEAN, BOUNDS, CROSS, FIND_MOD, DOWNSAMPLE_0, DOWNSAMPLE_1, DOWNSAMPLE_2, UNMASK, FINISHED} fsm_state;
    fsm_state state = RESET; // check here for errors

    always_ff @(posedge clk_pixel) begin

      if (sys_rst) begin
          state <= RESET;

      end else begin

          case (state)
          RESET: begin
                    state <= STREAMING1;
                    led <= 16'b1;
                end

          STREAMING1: begin
            // streaming1 is when taking picture, it ends when both capturing and starting_decoding switches are on.
            // during this stage, the pixels from frame buffer on hdmi
                    led <= 16'b10;
                          if (sw[0] && sw[1]) begin
                            state <= AVERAGING;
                          end
          end

          AVERAGING: begin    
            // averaging is when applying the sharpening kernel, it end when reciving a finishing signel from average module.
            // during this stage, the hdmi should show nothing, until the image is sharpened.
                        // if recived an end signal from average module, move to streaming2 state
                        led <= 16'b100;
                        state <= average_finished == 1'b1 ? HORIZ_PATTERNS : AVERAGING;
                    end 
          HORIZ_PATTERNS: begin
                led <= 16'b1000;
            // detecting the horizontal patterns
                state <= BRAM_one_horizontal_data_valid == 1'b1 ? VERT_PATTERNS : HORIZ_PATTERNS;
          end
          VERT_PATTERNS: begin
                led <= 16'b10000;
            // detecting the vertical patterns
                state <= BRAM_one_vertical_data_valid == 1'b1 ? CLEAN : VERT_PATTERNS;
          end

          CLEAN: begin
                led <= 16'b100000;
                state <= (clean_horz_valid_saved && clean_vert_valid_saved)? BOUNDS: CLEAN;
          end

          BOUNDS: begin
              led <= 16'b1000000;
              state <= (valid_bound) ? CROSS : BOUNDS;
          end

          CROSS: begin
                led <= 16'b10000000;
                state <= (cross_valid)? FIND_MOD: CROSS;
          end

          FIND_MOD: begin
                led <= 16'b100000000;
                state <= (mod_size_valid)? DOWNSAMPLE_0: FIND_MOD;
          end

          DOWNSAMPLE_0: begin
                led <= 16'b1000000000;
                state <= (valid_qr_0)? DOWNSAMPLE_1: DOWNSAMPLE_0;
          end

          DOWNSAMPLE_1: begin
                led <= 16'b10000000000;
                state <= (valid_qr_1)? DOWNSAMPLE_2: DOWNSAMPLE_1;
          end

          DOWNSAMPLE_2: begin
                led <= 16'b100000000000;
                state <= (valid_qr_2)? UNMASK: DOWNSAMPLE_2;
          end

          UNMASK: begin
            led <= 16'b1000000000000;
            state <= (unmask_ready)? FINISHED: UNMASK;
          end 

          FINISHED: begin
                case ({btn[1], btn[2], btn[3]})
                  3'b000 : led <= centers_x_cross[0];
                  3'b001 : led <= centers_x_cross[1];
                  3'b010 : led <= centers_x_cross[2];
                  3'b011 : led <= centers_y_cross[0];
                  3'b100 : led <= centers_y_cross[1];
                  3'b101 : led <= centers_y_cross[2];
                  3'b110 : led <= module_size;
                endcase
          end


          endcase
      end
    end 





  /*
    PIPELINES
    --------------------------------------------------------------------
  */
    // 3 stage pipelines for hdmi: should always exists regardless of the stage of decoding
    logic data_valid_rec_pipe[2:0];
    logic [10:0] hcount_rec_pipe [2:0];
    logic [9:0] vcount_rec_pipe [2:0];
    always_ff @(posedge clk_pixel) begin
      data_valid_rec_pipe[0] <= data_valid_rec;
      hcount_rec_pipe[0] <= hcount_rec;
      vcount_rec_pipe[0] <= vcount_rec;
      for (int i = 1; i < 3; i=i+1)begin
        data_valid_rec_pipe[i] <= data_valid_rec_pipe[i-1];
        hcount_rec_pipe[i] <= hcount_rec_pipe[i-1];
        vcount_rec_pipe[i] <= vcount_rec_pipe[i-1];
      end
    end

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
  recover #(.WIDTH(WIDTH))
  recover_m
  (
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

  // calculate binarized version
  binary bin(
    .clk_in(clk_pixel),
    .pixel_in(pixel_data_rec),
    .thresh_in(sw[15:8]),
    .bin_out(bin_out)
  );

  // scale
  scale #(.WIDTH(STORED_WIDTH),
        .HEIGHT(STORED_HEIGHT))
  scalemodule 
  (
    .hcount_in(hcount),
    .vcount_in(vcount),
    .scaled_hcount_out(hcount_scaled),
    .scaled_vcount_out(vcount_scaled),
    .valid_addr_out(valid_addr_scaled)
  );

  //Rotates and mirror-images Image to render correctly (pi/2 CCW rotate):
  // The output address should be fed right into the frame buffer for lookup
  rotate #(.WIDTH(STORED_WIDTH))
  rotate_m 
  (
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .hcount_in(hcount_scaled),
    .vcount_in(vcount_scaled),
    .valid_addr_in(valid_addr_scaled),
    .pixel_addr_out(img_addr_rot),
    .valid_addr_out(valid_addr_rot)
    );



  // frame buffer variables
  logic [19:0] frame_buffer_reading_address;
  logic frame_buffer_reading_pixel;
  logic frame_buffer_reading_enb;

  logic buffer_averaging_pixel;
  logic [19:0] buffer_averaging_address;
  logic average_finished;

  //BRAM1 related variables
  // only writing through average
  logic BRAM_one_average_pixel;
  logic [19:0] BRAM_one_average_address;
  logic BRAM_one_average_data_valid;

  logic [19:0] BRAM_one_reading_address;
  logic BRAM_one_reading_pixel;
  logic BRAM_one_reading_enb;
  

  //Framebuffer
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(1), //each entry in this memory is 1 bit
    .RAM_DEPTH(STORED_WIDTH*STORED_HEIGHT))
    frame_buffer (
    .addra(hcount_rec_pipe[2] + STORED_WIDTH*vcount_rec_pipe[2]), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(~sw[0] && data_valid_rec_pipe[2] && hcount_rec_pipe[2] < STORED_HEIGHT && vcount_rec_pipe[2] < STORED_WIDTH),
    .dina(bin_out),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(frame_buffer_reading_address),
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(frame_buffer_reading_enb),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(frame_buffer_reading_pixel)
  );

  average #(.WIDTH(STORED_WIDTH), .HEIGHT(STORED_HEIGHT))
  average_m
    (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .start_average(sw[1]),
      .buffer_pixel_data(buffer_averaging_pixel),
      .buffer_address(buffer_averaging_address),
      .BRAM_one_address(BRAM_one_average_address),
      .BRAM_one_data(BRAM_one_average_pixel),
      .BRAM_one_data_valid(BRAM_one_average_data_valid),
      .average_finished(average_finished)
    );

  //BRAM1
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(1),
    .RAM_DEPTH(STORED_WIDTH*STORED_HEIGHT))
    bram_one (
    .addra(BRAM_one_average_address),
    .clka(clk_pixel),
    .wea(BRAM_one_average_data_valid),
    .dina(BRAM_one_average_pixel),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(),

    .addrb(BRAM_one_reading_address),
    .dinb(1'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(BRAM_one_reading_enb),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(BRAM_one_reading_pixel)
  );

  // pattern relatede variables
  logic BRAM_one_horizontal_pixel_data;
  logic [19:0] BRAM_one_horizontal_pixel_address;
  logic [479:0] BRAM_one_horizontal_finder_encodings;
  logic BRAM_one_horizontal_data_valid;

  horizontal_pattern_ratio_finder horizontal
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .pixel_data(BRAM_one_horizontal_pixel_data),// MAKE NEW VARIABLE
        .start_finder(average_finished),
        .pixel_address(BRAM_one_horizontal_pixel_address),
        .finder_encodings(BRAM_one_horizontal_finder_encodings),
        .data_valid(BRAM_one_horizontal_data_valid)
    );

  logic BRAM_one_vertical_pixel_data;
  logic [19:0] BRAM_one_vertical_pixel_address;
  logic [479:0] BRAM_one_vertical_finder_encodings;
  logic BRAM_one_vertical_data_valid;

  vertical_pattern_ratio_finder vertical
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .pixel_data(BRAM_one_vertical_pixel_data),// MAKE NEW VARIABLE
        .start_finder(BRAM_one_horizontal_data_valid),
        .pixel_address(BRAM_one_vertical_pixel_address),
        .finder_encodings(BRAM_one_vertical_finder_encodings),
        .data_valid(BRAM_one_vertical_data_valid)
    );

    logic clean_horz_valid;
    logic clean_vert_valid;
    logic clean_horz_valid_saved;
    logic clean_vert_valid_saved;

    always_ff @(posedge clk_pixel) begin
      if (sys_rst) begin
          clean_horz_valid_saved <= 1'b0;
          clean_vert_valid_saved <= 1'b0;
      end
      else begin
        if (clean_horz_valid)
          clean_horz_valid_saved <=1'b1;

        if (clean_vert_valid)
          clean_vert_valid_saved <=1'b1;
      end
    end

    logic [479:0] BRAM_one_vertical_finder_encodings_clean;
    logic [479:0] BRAM_one_horizontal_finder_encodings_clean;


    clean_patterns #(.WIDTH(STORED_WIDTH))
    clean_horz
    (   
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .pattern(BRAM_one_horizontal_finder_encodings),
        .start_cleaning(BRAM_one_horizontal_data_valid),
        .data_valid(clean_horz_valid),
        .clean_pattern(BRAM_one_horizontal_finder_encodings_clean)
    );

    clean_patterns #(.WIDTH(STORED_WIDTH))
    clean_vert
    (   
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .pattern(BRAM_one_vertical_finder_encodings),
        .start_cleaning(BRAM_one_vertical_data_valid),
        .data_valid(clean_vert_valid),
        .clean_pattern(BRAM_one_vertical_finder_encodings_clean)
    );

    logic [8:0] bounds_x [1:0];
    logic [8:0] bounds_y [1:0];
    logic valid_bound;

    bounds #(.WIDTH(STORED_WIDTH), .HEIGHT(STORED_HEIGHT),
             .OFFSET(10))
    bounds_mod
    (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .horz_patterns(BRAM_one_horizontal_finder_encodings_clean),
      .vert_patterns(BRAM_one_vertical_finder_encodings_clean),
      .start_bound(clean_horz_valid_saved && clean_vert_valid_saved),

      .bound_x(bounds_y), // ERROR: SWITCHED THEM HERE (cause they were actually inverted) (can also just switch the finder encodings)
      .bound_y(bounds_x),
      .valid_bound(valid_bound)
    );


  logic BRAM_one_cross_reading_pixel;
  logic [19:0] BRAM_one_cross_reading_address;
  logic [8:0] centers_x_cross [2:0];
  logic [8:0] centers_y_cross [2:0];
  logic cross_valid;

  cross_patterns cross_mod
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .horz_patterns(BRAM_one_vertical_finder_encodings_clean), // ERROR: SWITCHED AGAIN HERE 
        .vert_patterns(BRAM_one_horizontal_finder_encodings_clean),
        .start_cross(valid_bound),
        .pixel_reading(BRAM_one_cross_reading_pixel),
        .bound_x(bounds_x),
        .bound_y(bounds_y),

        .address_reading(BRAM_one_cross_reading_address),
        .centers_x(centers_x_cross),
        .centers_y(centers_y_cross),
        .centers_valid(cross_valid),
        .centers_not_found_error(rgb0[0]),// using rgb to err out
        .centers_not_found_error2(rgb0[1])
    );

  logic [8:0] module_size;
  logic mod_size_valid;
  find_mod_size #(.MODULES(14))// 15 modules between version 1 qr codes
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .centers_x(centers_x_cross),
        .centers_y(centers_y_cross),
        .start_downsample(cross_valid),

        .mod_size(module_size), // oversized by a lot lol
        .mod_size_valid(mod_size_valid)
    );

    logic BRAM_one_downsample_reading_pixel_0;
    logic [19:0] BRAM_one_downsample_address_0;
    logic [440:0] qr_code_0;
    logic valid_qr_0;

    downsample_0 #(.WIDTH(STORED_WIDTH))
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .start_downsample(mod_size_valid),
        .reading_pixel(BRAM_one_downsample_reading_pixel_0),
        .module_size(module_size),
        .centers_x(centers_x_cross),
        .centers_y(centers_y_cross),

        .reading_address(BRAM_one_downsample_address_0),
        .qr_code(qr_code_0),
        .valid_qr(valid_qr_0)
    );

    logic BRAM_one_downsample_reading_pixel_1;
    logic [19:0] BRAM_one_downsample_address_1;
    logic [440:0] qr_code_1;
    logic valid_qr_1;

    downsample_1 #(.WIDTH(STORED_WIDTH))
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .start_downsample(valid_qr_0),
        .reading_pixel(BRAM_one_downsample_reading_pixel_1),
        .module_size(module_size),
        .centers_x(centers_x_cross),
        .centers_y(centers_y_cross),

        .reading_address(BRAM_one_downsample_address_1),
        .qr_code(qr_code_1),
        .valid_qr(valid_qr_1)
    );

    logic BRAM_one_downsample_reading_pixel_2;
    logic [19:0] BRAM_one_downsample_address_2;
    logic [440:0] qr_code_2;
    logic valid_qr_2;

    downsample_2 #(.WIDTH(STORED_WIDTH))
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .start_downsample(valid_qr_1),
        .reading_pixel(BRAM_one_downsample_reading_pixel_2),
        .module_size(module_size),
        .centers_x(centers_x_cross),
        .centers_y(centers_y_cross),

        .reading_address(BRAM_one_downsample_address_2),
        .qr_code(qr_code_2),
        .valid_qr(valid_qr_2)
    );

  logic [440:0] qr_code;


  downsample_combine #(.CODE_SIZE(QR_SIZE))
      (
          .qr_0(qr_code_0),
          .qr_1(qr_code_1),
          .qr_2(qr_code_2),
          .qr_code(qr_code)
      );


  logic [440:0] qr_code_unmask;
  logic unmask_ready;


  unmask #(.MOD_SIZE(QR_SIZE))
    (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .start_unmask(valid_qr_2),
        .downsampled_qr(qr_code),
        .qr_unmasked(qr_code_unmask),
        .unmask_ready(unmask_ready)
    );

  logic [3:0] data_type;
  logic [7:0] data_length;
  logic [7:0] bytes [18:0];

  decode #(.MOD_SIZE(QR_SIZE))
    (
        .qr_unmasked(qr_code_unmask),
        .data_type(data_type),
        .data_length(data_length),
        .bytes(bytes)
    );


  manta (
    .clk(clk_pixel),
    .rx(uart_rxd),
    .tx(uart_txd),

    .block1_in({bytes[0], bytes[1], bytes[2], bytes[3]}),
    .block2_in({bytes[4], bytes[5], bytes[6], bytes[7]}),
    .block3_in({bytes[8], bytes[9], bytes[10], bytes[11]}),
    .block4_in({bytes[12], bytes[13], bytes[14], bytes[15]}),
    .block5_in({bytes[16], bytes[17], bytes[18], 8'b0}),
  
    .datatype_in(data_type),
    .length_in(data_length));

  /*
    Controling Memory Ports
  */
    always_comb begin
      if (state == STREAMING1) begin
        // reading frame buffer goes to hdmi if state is streaming1
        frame_buffer_reading_address = img_addr_rot;
        frame_buffer_reading_enb = valid_addr_rot;
        // hdmi_out_raw_pixel = frame_buffer_reading_pixel;  //already written in hdmi control
      end

      else if (state == AVERAGING) begin
        // reading frame buffer goes to average if state is AVERAGING
        frame_buffer_reading_address = buffer_averaging_address;
        buffer_averaging_pixel = frame_buffer_reading_pixel;
        frame_buffer_reading_enb = 1'b1;
      end
      else if (state == HORIZ_PATTERNS)begin
        // reading frame buffer goes to horizontal pattern finder if state is HORIZ_PATTERNS
        BRAM_one_reading_address = BRAM_one_horizontal_pixel_address;
        BRAM_one_horizontal_pixel_data = BRAM_one_reading_pixel;
        BRAM_one_reading_enb = 1'b1;
      end
      else if (state == VERT_PATTERNS) begin
        BRAM_one_reading_address = BRAM_one_vertical_pixel_address;
        BRAM_one_vertical_pixel_data = BRAM_one_reading_pixel;
        BRAM_one_reading_enb = 1'b1;
      end
      else if (state == CROSS) begin
        BRAM_one_reading_address = BRAM_one_cross_reading_address;
        BRAM_one_cross_reading_pixel = BRAM_one_reading_pixel;
        BRAM_one_reading_enb = 1'b1;
      end
      else if (state == DOWNSAMPLE_0) begin
        BRAM_one_reading_address <= BRAM_one_downsample_address_0;
        BRAM_one_downsample_reading_pixel_0 <= BRAM_one_reading_pixel;
        BRAM_one_reading_enb <= 1'b1;
      end
      else if (state == DOWNSAMPLE_1) begin
        BRAM_one_reading_address <= BRAM_one_downsample_address_1;
        BRAM_one_downsample_reading_pixel_1 <= BRAM_one_reading_pixel;
        BRAM_one_reading_enb <= 1'b1;
      end
      else if (state == DOWNSAMPLE_2) begin
        BRAM_one_reading_address <= BRAM_one_downsample_address_2;
        BRAM_one_downsample_reading_pixel_2 <= BRAM_one_reading_pixel;
        BRAM_one_reading_enb <= 1'b1;
      end
      else if (state == FINISHED) begin
        // add switches to control what's on hdmi after this stage.
        // reading frame buffer goes to hdmi if state is streaming
        // i undid the rotation that img_addr_rot did to BRAM_one for sake of debugging
        BRAM_one_reading_address = img_addr_rot;
        BRAM_one_reading_enb = valid_addr_rot;
        frame_buffer_reading_address = img_addr_rot;
        frame_buffer_reading_enb = valid_addr_rot;
      end
    end

  // NOTE: LETS JUST GET RID OF ROTATIONS POST FRAME BUFFER BECAUSE ITS THE IMAGE ADDRESS THATS ROTATED, NOT WHAT WE SHOW
  // MAYBE THE BOUNDS WERE INCORRECT AND THATS WHY? (they were rotated)

  /*
    WHAT TO SHOW ON SCREEN:
  */

// Controling what goes on screen
  always_comb begin  //add switches
    case ({sw[6], sw[5], sw[4], sw[3]})
      4'b0000: hdmi_out_raw_pixel = frame_buffer_reading_pixel;
      4'b0001: hdmi_out_raw_pixel = state == AVERAGING ? 1'b0 : BRAM_one_reading_pixel;
      4'b0010: hdmi_out_raw_pixel = (state == FINISHED) ? 
                                  (BRAM_one_horizontal_finder_encodings[hcount_scaled]) &&
                                  (BRAM_one_vertical_finder_encodings[STORED_WIDTH - vcount_scaled]) :  1'b0;
      4'b0011: hdmi_out_raw_pixel = (state == FINISHED) ?
                                  (BRAM_one_horizontal_finder_encodings_clean[hcount_scaled]) &&
                                  (BRAM_one_vertical_finder_encodings_clean[STORED_WIDTH - vcount_scaled]) :  1'b0;

      4'b0100: hdmi_out_raw_pixel = (state == FINISHED) ? ((STORED_WIDTH - vcount_scaled == bounds_x[0]) ||
                                                         (STORED_WIDTH - vcount_scaled == bounds_x[1])) ||
                                                         ((hcount_scaled == bounds_y[0]) ||
                                                         ( hcount_scaled == bounds_y[1])) ||
                                                         ((BRAM_one_horizontal_finder_encodings_clean[hcount_scaled]) &&
                                  (BRAM_one_vertical_finder_encodings_clean[STORED_WIDTH - vcount_scaled])): 1'b0;

      4'b0101: hdmi_out_raw_pixel = (state == FINISHED) ? ((STORED_WIDTH - vcount_scaled == centers_x_cross[0]) && (hcount_scaled == centers_y_cross[0])) ||
                                                         ((STORED_WIDTH - vcount_scaled == centers_x_cross[1]) && (hcount_scaled == centers_y_cross[1])) ||
                                                         ((STORED_WIDTH - vcount_scaled == centers_x_cross[2]) && (hcount_scaled == centers_y_cross[2])) : 1'b0;  
      4'b0110: hdmi_out_raw_pixel = (state == FINISHED) ? ((((STORED_WIDTH - vcount_scaled) >> 4) < QR_SIZE) &&
                                                         ((hcount_scaled) >> 4 < QR_SIZE)) ? qr_code_0[((STORED_WIDTH - vcount_scaled) >> 4) + ((hcount_scaled) >> 4)*QR_SIZE]: 1'b0
                                                         : 1'b0;
      4'b0111: hdmi_out_raw_pixel = (state == FINISHED) ? ((((STORED_WIDTH - vcount_scaled) >> 4) < QR_SIZE) &&
                                                         ((hcount_scaled) >> 4 < QR_SIZE)) ? qr_code_1[((STORED_WIDTH - vcount_scaled) >> 4) + ((hcount_scaled) >> 4)*QR_SIZE]: 1'b0
                                                         : 1'b0;
      4'b1000: hdmi_out_raw_pixel = (state == FINISHED) ? ((((STORED_WIDTH - vcount_scaled) >> 4) < QR_SIZE) &&
                                                         ((hcount_scaled) >> 4 < QR_SIZE)) ? qr_code_2[((STORED_WIDTH - vcount_scaled) >> 4) + ((hcount_scaled) >> 4)*QR_SIZE]: 1'b0
                                                         : 1'b0;
      4'b1001: hdmi_out_raw_pixel = (state == FINISHED) ? ((((STORED_WIDTH - vcount_scaled) >> 4) < QR_SIZE) &&
                                                         ((hcount_scaled) >> 4 < QR_SIZE)) ? qr_code[((STORED_WIDTH - vcount_scaled) >> 4) + ((hcount_scaled) >> 4)*QR_SIZE]: 1'b0
                                                         : 1'b0;
      4'b1010: hdmi_out_raw_pixel = (state == FINISHED) ? ((((STORED_WIDTH - vcount_scaled) >> 4) < QR_SIZE) &&
                                                         ((hcount_scaled) >> 4 < QR_SIZE)) ? qr_code_unmask[((STORED_WIDTH - vcount_scaled) >> 4) + ((hcount_scaled) >> 4)*QR_SIZE]: 1'b0
                                                         : 1'b0;

      default: hdmi_out_raw_pixel = 1'b0;
    endcase
  end


 // pipelined valid_addr_rot to take care of BRAM 2 clock latency
  always_ff @(posedge clk_pixel)begin
    valid_addr_rot_pipe[0] <= valid_addr_rot;
    valid_addr_rot_pipe[1] <= valid_addr_rot_pipe[0];
  end

  assign hdmi_out_pixel = valid_addr_rot_pipe[1]?hdmi_out_raw_pixel:1'b0;

  // binarized output routed directly to tmds encoders after 8 bit conversion
  always_comb begin
    if ({sw[6], sw[5], sw[4], sw[3]} == 3'b0101) begin
      // custom colors for each detected center
      if ((STORED_WIDTH - vcount_scaled == centers_x_cross[0]) && (hcount_scaled == centers_y_cross[0])) begin
        red = 8'd255;
        green = 8'd0;
        blue = 8'd0; 
      end
      else if ((STORED_WIDTH - vcount_scaled == centers_x_cross[1]) && (hcount_scaled == centers_y_cross[1])) begin
        red = 8'd0;
        green = 8'd255;
        blue = 8'd0; 
      end
      else if ((STORED_WIDTH - vcount_scaled == centers_x_cross[2]) && (hcount_scaled == centers_y_cross[2])) begin
        red = 8'd50;
        green = 8'd50;
        blue = 8'd255; 
      end
      else begin
        red = 8'd0;
        green = 8'd0;
        blue = 8'd0; 
      end
    end
    else begin
      red = hdmi_out_pixel == 1'b0 ? 8'b0 : 8'd255;
      green = hdmi_out_pixel == 1'b0 ? 8'b0 : 8'd255;
      blue = hdmi_out_pixel == 1'b0 ? 8'b0 : 8'd255;
    end

  end



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
