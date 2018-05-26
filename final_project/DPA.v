module DPA (clk,reset,IM_A, IM_Q,IM_D,IM_WEN,CR_A,CR_Q);
input         clk;
input         reset;
output [19:0] IM_A;
input  [23:0] IM_Q;
output [23:0] IM_D;
output        IM_WEN;
output [8:0]  CR_A;
input  [12:0] CR_Q;

// Const
parameter [31:0] CYCLE_0_2 = 32'd200000;
parameter [31:0] CYCLE_0_4 = 32'd400000;
parameter [31:0] CYCLE_1_0 = 32'd1000000;
parameter [31:0] CYCLE_1_4 = 32'd1400000;
parameter [31:0] CYCLE_2_0 = 32'd2000000;

// FSM
parameter [5:0] S_INIT  = 6'd0;
parameter [5:0] S_TYPE  = 6'd1;
parameter [5:0] S_128A  = 6'd2; // DO B, then do A (see spec)
parameter [5:0] S_128B  = 6'd3; // DO B, then do A (see spec)
parameter [5:0] S_256A  = 6'd4; // DO B, then do A (see spec)
parameter [5:0] S_256B  = 6'd5; // DO B, then do A (see spec)
parameter [5:0] S_512A  = 6'd6; // DO B, then do A (see spec)
parameter [5:0] S_512B  = 6'd7; // DO B, then do A (see spec)
parameter [5:0] S_DCLK  = 6'd8;
parameter [5:0] S_WAIT1 = 6'd9;  // 0.0 ~ 0.2 (Photo 1 & Photo 2)
parameter [5:0] S_WAIT2 = 6'd10; // 0.2 ~ 0.4 (Photo 2)
parameter [5:0] S_WAIT3 = 6'd11; // 0.4 ~ 1.0 (Photo 2)
parameter [5:0] S_WAIT4 = 6'd12; // 1.0 ~ 1.4 (Photo 2)
parameter [5:0] S_WAIT5 = 6'd13; // 1.4 ~ 2.0 (Photo 2)

// Signals
reg [31:0] cycle_cnt_r, cycle_cnt_w;
reg [7:0]  hr_r, hr_w, min_r, min_w, sec_r, sec_w;
reg [19:0] fb_addr_r, fb_addr_w;
reg [2:0]  ph_num_r, ph_num_w;
reg [5:0]  state_r, state_w;
reg [1:0]  type_r, type_w;        // 0: 128; 1: 256; 2: 512;
reg [19:0] ph_addr_r, ph_addr_w;
reg [31:0] cnt_r, cnt_w;
reg [31:0] ph_cnt_r, ph_cnt_w;    // current photo idx
reg [31:0] px_cnt_r, px_cnt_w;    // current pixel idx
reg [19:0] im_a_r, im_a_w;
reg [19:0] im_d_r, im_d_w;
reg        im_wen_r, im_wen_w;
reg [15:0] iter_r, iter_w;
reg [19:0] fb_a_r, fb_a_w;        // current write addr 
reg [19:0] ph_a_r, ph_a_w;        // current photo addr
reg [3:0]  s_cnt_r, s_cnt_w;

assign #10IM_A   = im_a_r;
assign #10IM_D   = im_d_r;
assign #10IM_WEN = im_wen_r;

always @ (*) begin
  state_w      = state_r;
  fb_addr_w    = fb_addr_r;
  ph_num_w     = ph_num_r;
  type_w       = type_r;
  ph_addr_w    = ph_addr_r;
  cnt_w        = cnt_r;
  ph_cnt_w     = ph_cnt_r;
  px_cnt_w     = px_cnt_r;
  im_a_w       = im_a_r;
  im_d_w       = im_d_r;
  im_wen_w     = im_wen_r;
  iter_w       = iter_r;
  fb_a_w       = fb_a_r;
  ph_a_w       = ph_a_r;
  s_cnt_w      = s_cnt_r;
  {hr_w, min_w, sec_w} = {hr_r, min_r, sec_r};

  case (state_r)
    //////////////////////////////
    // Initial
    //////////////////////////////
    S_INIT: begin
      cnt_w = cnt_r + 1;
      im_wen_w = 1;
      if (cnt_r == 0) begin
        im_a_w = 0;
      end else if (cnt_r == 1) begin
        im_a_w = 1;
      end else if (cnt_r == 2) begin
        im_a_w = 2;
        {hr_w, min_w, sec_w} = IM_Q;
      end else if (cnt_r == 3) begin
        fb_addr_w = IM_Q;
      end else if (cnt_r == 4) begin
        ph_num_w = IM_Q;
        cnt_w = 0;
        state_w = S_TYPE;
        ph_cnt_w = 0;
      end
    end

    //////////////////////////////
    // Type
    //////////////////////////////
    S_TYPE: begin
      cnt_w = cnt_r + 1;
      im_wen_w = 1;
      if (cnt_r == 0) begin
        im_a_w = 3 + (ph_cnt_r << 1);
      end else if (cnt_r == 1) begin
        im_a_w = im_a_r + 1;
      end else if (cnt_r == 2) begin
        ph_addr_w = IM_Q;
      end else if (cnt_r == 3) begin
        cnt_w = 0;
        if (IM_Q == 128) begin
          state_w = S_128B;
        end else if (IM_Q == 256) begin
          state_w = S_256B;
        end else begin // IM_Q == 512
          state_w = S_512B;
        end
        im_a_w = ph_addr_r + 1;
        im_wen_w = 1;
        fb_a_w = fb_addr_r + 1;
        ph_a_w = ph_addr_r + 1;
        iter_w = 0;
        s_cnt_r = 0;
      end
    end

    //////////////////////////////
    // 256
    //////////////////////////////
    S_256B: begin
      if (iter_r >= 128) begin
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
        state_w = S_WAIT1;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r + 1;
          ph_a_w = ph_addr_r + 1;
          fb_a_r = fb_addr_r + 1;
        end else if (s_cnt_r == 1) begin
        end else if (s_cnt_r == 2) begin
          im_d_w = IM_Q;
          im_wen_w = 0;
          im_a_w = fb_a_r;
        end else if (s_cnt_r == 3) begin
          im_wen_w = 1;
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin 
            im_a_w = ph_a_r + 2;
            ph_a_w = ph_a_r + 2;
            fb_a_w = fb_a_r + 2;
          end else if (cnt_r == 127) begin
            im_a_w = ph_a_r + 1;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 1;
          end else if (cnt_r < 255) begin 
            im_a_w = ph_a_r + 2;
            ph_a_w = ph_a_r + 2;
            fb_a_w = fb_a_r + 2;
          end else begin // cnt_r == 255
            ph_a_w = ph_a_r + 3;
            fb_a_w = fb_a_r + 3;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else if (s_cnt_r == 4) begin
          im_a_w = ph_a_r;
          im_wen_w = 1;
          s_cnt_w = 1;
        end
      end
    end

    S_256A: begin      
       if (iter_r >= 128) begin
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
        state_w = S_WAIT2;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r;
          ph_a_w = ph_addr_r;
          fb_a_r = fb_addr_r;
        end else if (s_cnt_r == 1) begin
        end else if (s_cnt_r == 2) begin
          im_d_w = IM_Q;
          im_wen_w = 0;
          im_a_w = fb_a_r;
        end else if (s_cnt_r == 3) begin
          im_wen_w = 1;
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin 
            im_a_w = ph_a_r + 2;
            ph_a_w = ph_a_r + 2;
            fb_a_w = fb_a_r + 2;
          end else if (cnt_r == 127) begin
            im_a_w = ph_a_r + 3;
            ph_a_w = ph_a_r + 3;
            fb_a_w = fb_a_r + 3;
          end else if (cnt_r < 255) begin 
            im_a_w = ph_a_r + 2;
            ph_a_w = ph_a_r + 2;
            fb_a_w = fb_a_r + 2;
          end else begin // cnt_r == 255
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 1;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else if (s_cnt_r == 4) begin
          im_a_w = ph_a_r;
          im_wen_w = 1;
          s_cnt_w = 1;
        end
      end
    end

    //////////////////////////////
    // 128
    //////////////////////////////
    S_128B: begin
    end
    S_128A: begin
    end

    //////////////////////////////
    // 512
    //////////////////////////////
    S_512B: begin
    end
    S_512A: begin
    end

    //////////////////////////////
    // DClk
    //////////////////////////////
    S_DCLK: begin
    end

    //////////////////////////////
    // Wait
    //////////////////////////////
    S_WAIT1: begin
      if (cycle_cnt_r >= CYCLE_0_2) begin
        state_w = S_256A;
        im_wen_w = 1;
        im_a_w = ph_addr_r;
        ph_a_w = ph_addr_r;
        fb_a_w = fb_addr_r;
        s_cnt_w = 0;
        cnt_w = 0;
        iter_w = 0;
      end
    end
    S_WAIT2: begin
      if (cycle_cnt_r >= CYCLE_0_4) begin
        state_w = S_WAIT3;
      end
    end
    S_WAIT3: begin
    end
    S_WAIT4: begin
    end
    S_WAIT5: begin
    end

    default: begin 
    end
  endcase
end


// always @(im_a_r or im_d_r or im_wen_r or reg_256_r) begin
//   if (im_wen_r == 0 && im_a_r == 20'he0001) begin
//     $display("HERE, addr = %h, reg = %h", im_a_r, reg_256_r);
//   end
// end 
    
always @ (posedge clk or posedge reset) begin
  if (reset) begin 
    cnt_r         <= 0;
    fb_addr_r     <= 0;
    ph_num_r      <= 0;
    ph_addr_r     <= 0;
    type_r        <= 0;
    state_r       <= S_INIT;
    ph_cnt_r      <= 0;
    px_cnt_r      <= 0;
    iter_r        <= 0;
    fb_a_r        <= 0;
    ph_a_r        <= 0;
    s_cnt_r       <= 0;
  end else begin
    cnt_r         <= cnt_w;
    fb_addr_r     <= fb_addr_w;
    ph_num_r      <= ph_num_w;
    ph_addr_r     <= ph_addr_w;
    type_r        <= type_w;
    state_r       <= state_w;
    ph_cnt_r      <= ph_cnt_w;
    px_cnt_r      <= px_cnt_w;
    iter_r        <= iter_w;
    fb_a_r        <= fb_a_w;
    ph_a_r        <= ph_a_w;
    s_cnt_r       <= s_cnt_w;
  end
end

always @ (posedge clk or posedge reset) begin
  if (reset) begin
    im_a_r   <= 0;
    im_d_r   <= 0;
    im_wen_r <= 1;
  end else begin
    im_a_r     <= im_a_w;
    im_d_r     <= im_d_w;
    im_wen_r   <= im_wen_w;
  end
end

//////////////////////////////
// Cycle Cnt
//////////////////////////////
always @ (*) begin
  cycle_cnt_w = (cycle_cnt_r == CYCLE_2_0 - 1) ? 0 : cycle_cnt_r + 1;
end

always @ (posedge clk or posedge reset) begin
  if (reset) begin 
    cycle_cnt_r   <= 0;
  end else begin
    cycle_cnt_r   <= cycle_cnt_w;
  end
end

//////////////////////////////
// Digital Clock
//////////////////////////////

// always @ (*) begin
//   hr_w  = hr_r;
//   min_w = min_r;
//   sec_w = (cycle_cnt_r == CYCLE_2_0 - 1) ? sec_r + 1 : sec_r;
//   if (sec_r >= 60) begin
//     sec_w = 0;
//     min_w = min_r + 1;
//   end
//   if (min_r >= 60) begin
//     min_w = 0;
//     hr_w = min_r + 1;
//   end
//   if (min_r >= 24) begin
//     hr_w = 0;
//   end
// end

always @ (posedge clk or posedge reset) begin
  if (reset) begin 
    hr_r   <= 0;
    min_r  <= 0;
    sec_r  <= 0;
  end else begin
    hr_r   <= hr_w;
    min_r  <= min_w;
    sec_r  <= sec_w;
  end
end

endmodule
