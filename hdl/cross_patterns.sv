
module cross_patterns #(parameter HEIGHT = 480,
                        parameter WIDTH = 480)
    (
        input wire clk_in,
        input wire rst_in,
        input wire [479:0] horz_patterns,
        input wire [479:0] vert_patterns,
        input wire start_cross,
        input wire pixel_reading,

        output logic [19:0] address_reading,
        output logic [8:0] centers_x [2:0],
        output logic [8:0] centers_y [2:0],
        output logic centers_valid
    );

    parameter OFFSET = 10;

    typedef enum {RESET, BOUNDS_X, BOUNDS_Y, ZONE} fsm_state;
    typedef enum {RESET2, PENDING, WAIT_ONE, WAIT_TWO, DETERMINE,CALCULATE, FINISHED_ALL} zone_state;

    fsm_state state = RESET;
    zone_state state_zone = RESET2;

    logic [8:0] x,y;

    logic [8:0] bound_x [1:0];
    logic [1:0] bounds_x_index; 
    logic [8:0] bound_y [1:0];
    logic [1:0] bounds_y_index; 

    logic [1:0] zone_x;
    logic [1:0] zone_y;
    logic zone_trigger;

    logic old_pixel;

    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            state <= RESET;
            x <= 9'b0;
            y <= 9'b0;
            old_pixel <= 1'b0;
            bounds_x_index <= 2'b0;
            bounds_y_index <= 2'b0;
            zone_trigger <= 1'b0;
        end

        else begin

            case (state)

            RESET: begin
                if (start_cross) begin
                    state <= BOUNDS_X;
                end
            end

            BOUNDS_X: begin
                old_pixel <= horz_patterns[x];

                if (x == WIDTH -1) begin
                    x <= 9'b0;
                    state  <= BOUNDS_Y;
                    old_pixel <= 1'b0;
                end else begin
                    x <= x + 1;
                end

                if ((horz_patterns[x] != old_pixel) && old_pixel) begin
                    if (bounds_x_index < 2) begin
                        bound_x[bounds_x_index] <= x + OFFSET;
                        bounds_x_index <= bounds_x_index+1;
                    end
                end
            end

            BOUNDS_Y: begin
                old_pixel <= vert_patterns[y];

                if (y == HEIGHT -1) begin
                    y <= 9'b0;
                    state  <= ZONE;
                    zone_trigger <= 1'b1;
                end else begin
                    y <= y + 1;
                end

                if ((vert_patterns[y] != old_pixel) && old_pixel) begin
                    if (bounds_y_index < 2) begin
                        bound_y[bounds_y_index] <= y + OFFSET;
                        bounds_y_index <= bounds_y_index+1;
                    end
                end
            end

            ZONE: begin
                zone_trigger <= 1'b0;
            end

            endcase
        end
    end 


   logic [8:0] box_min_x, box_min_y, box_max_x, box_max_y;
   assign address_reading = (box_min_x + x_read) + (y_read + box_min_y) * WIDTH;

   always_comb begin
    // assign box boundries for zone_y, zone_x
    case (zone_x)
        2'b00: begin
            box_min_x = 0;
            box_max_x = bound_x[0];
        end
        2'b01:begin
            box_min_x = bound_x[0];
            box_max_x = bound_x[1];
        end
        2'b10:begin
            box_min_x = bound_x[1];
            box_max_x = WIDTH -1;
        end
        default: begin
            box_min_x = WIDTH -1;
            box_max_x = WIDTH -1;
        end
    endcase

    case (zone_y)
        2'b00: begin
            box_min_y = 0;
            box_max_y = bound_y[0];
        end
        2'b01:begin
            box_min_y = bound_y[0];
            box_max_y = bound_y[1];
        end
        2'b10:begin
            box_min_y = bound_y[1];
            box_max_y = HEIGHT -1;
        end
        default: begin
            box_min_y = HEIGHT -1;
            box_max_y = HEIGHT -1;
        end
    endcase

   end 

    logic [8:0] x_read;
    logic [8:0] y_read;
    logic [13:0] counter_black;
    logic [13:0] counter_white;
    logic started, loaded;
    logic [8:0] start_x, start_y, end_x, end_y;
    logic [1:0] center_index;


    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            zone_y <= 2'b0;
            zone_x <= 2'b0;
            x_read <= 9'b0;
            y_read <= 9'b0;
            counter_black <= 14'b0;
            counter_white <= 14'b0;
            state_zone <= RESET2;
            started <= 1'b0;
            loaded <= 1'b0;
            center_index <= 2'b0;
        end

        else begin
            case (state_zone) 
                RESET2: begin
                    if(zone_trigger) begin
                        state_zone <= PENDING;
                    end
                end

                PENDING: begin // check if need to lookup

                    if (horz_patterns[box_min_x + x_read] && vert_patterns[box_min_y+y_read]) begin
                        started <= 1'b1;
                        state_zone <= WAIT_ONE;
                        end_x <= x_read;
                        end_y <= y_read;
                        if (started && !loaded)begin
                            loaded <= 1'b1;
                            start_x <= x_read;
                            start_y <= y_read;
                        end
                    end 

                    else begin   // in case you got black
                        if (box_min_x + x_read < box_max_x) begin
                            x_read <= x_read +1;
                        end 
                        else begin
                            x_read <= 9'b0;
                            if (box_min_y + y_read < box_max_y) begin
                                y_read <= y_read +1;
                            end 
                            else begin
                                state_zone <= CALCULATE;
                            end
                        end 
                    end
                end 

                WAIT_ONE: state_zone <= WAIT_TWO;
                WAIT_TWO: state_zone <= DETERMINE;

                DETERMINE: begin   // increament counters, increament coordinates, increament zones
                    if (pixel_reading) begin
                        counter_white <= counter_white + 1;
                    end else begin
                        counter_black <= counter_black + 1;
                    end

                    if (box_min_x + x_read < box_max_x) begin
                            x_read <= x_read +1;
                        end 
                        else begin
                            x_read <= 9'b0;
                            if (box_min_y + y_read < box_max_y) begin
                                y_read <= y_read +1;
                            end
                            else begin
                                state_zone <= CALCULATE;
                            end
                        end 

                end

                CALCULATE: begin   // return a center if a valid answer if non-zero majority black.
                    started <= 1'b0;
                    loaded <= 1'b0;
                        if (counter_black > (counter_white + counter_black) - (counter_white + counter_black)>>2) begin 
                            //// a valid answer, return center
                            center_index <= center_index + 1;
                            centers_x[center_index] <= (start_x + end_x)>>1 + box_min_x;
                            centers_y[center_index] <= (start_y + end_y)>>1 + box_min_y;
                            if (center_index == 2) begin
                                state_zone <= FINISHED_ALL;
                                centers_valid <= 1'b1;
                            end 
                        end

                        else begin // not a valid center because majority is not black
                        end
                end

                FINISHED_ALL: centers_valid <= 1'b0;
            endcase
        end
    end



endmodule
