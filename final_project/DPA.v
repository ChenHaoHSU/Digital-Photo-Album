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
parameter [5:0] S_DCLK1 = 6'd14;
parameter [5:0] S_DCLK2 = 6'd15;
parameter [5:0] S_DCLK4 = 6'd16;

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
reg [23:0] im_d_r, im_d_w;
reg        im_wen_r, im_wen_w;
reg [15:0] iter_r, iter_w;
reg [19:0] fb_a_r, fb_a_w;        // current write addr 
reg [19:0] ph_a_r, ph_a_w;        // current photo addr
reg [7:0]  s_cnt_r, s_cnt_w;
reg [3:0]  h1, h0;
reg [3:0]  m1, m0;
reg [3:0]  s1, s0;
reg [8:0]  cr_a_r, cr_a_w;
reg [19:0] tm_a_r, tm_a_w;
reg [5:0]  cr_idx_r, cr_idx_w;
reg [5:0]  cr_col_r, cr_col_w;
reg [5:0]  cr_row_r, cr_row_w;
reg [5:0]  cr_num;
reg [23:0] cr_val;
reg [7:0]  cr_state_r, cr_state_w;
reg [9:0]  sum_512r_r, sum_512r_w;
reg [9:0]  sum_512g_r, sum_512g_w;
reg [9:0]  sum_512b_r, sum_512b_w;

assign #10 IM_A   = im_a_r;
assign #10 IM_D   = im_d_r;
assign #10 IM_WEN = im_wen_r;
assign #10 CR_A   = cr_a_r;

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
  cr_a_w       = cr_a_r;
  tm_a_w       = tm_a_r;
  cr_idx_w     = cr_idx_r;
  cr_col_w     = cr_col_r;
  cr_row_w     = cr_row_r;
  cr_state_w   = cr_state_r;
  sum_512r_w   = sum_512r_r;
  sum_512g_w   = sum_512g_r;
  sum_512b_w   = sum_512b_r;

  hr_w  = hr_r;
  min_w = min_r;
  sec_w = (cycle_cnt_r == CYCLE_1_0 - 1) ? sec_r + 1 : sec_r;
  if (sec_r >= 60) begin
    sec_w = 0;
    min_w = min_r + 1;
  end
  if (min_r >= 60) begin
    min_w = 0;
    hr_w = hr_r + 1;
  end
  if (hr_r >= 24) begin
    hr_w = 0;
  end


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
          type_w = 0;
        end else if (IM_Q == 256) begin
          state_w = S_256B;
          type_w = 1;
        end else begin // IM_Q == 512
          state_w = S_512B;
          type_w = 2;
        end
        im_a_w = 0;
        im_wen_w = 1;
        fb_a_w = fb_addr_r + 1;
        ph_a_w = 0;
        iter_w = 0;
        s_cnt_r = 0;
        cnt_w = 0;
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
        state_w = S_DCLK1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
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
        state_w = S_DCLK2;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
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
      if (iter_r >= 128) begin 
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
        state_w = S_DCLK1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r + 2;
          im_wen_w = 1;
          ph_a_w = ph_addr_r + 2;
          fb_a_r = fb_addr_r + 1;
        end else if (s_cnt_r == 1) begin
          sum_512r_w = 0;
          sum_512g_w = 0;
          sum_512b_w = 0;
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          im_a_w = ph_a_r + 512;
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 3) begin
          im_a_w = ph_a_r + 513;
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 4) begin
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 5) begin
          im_a_w = fb_a_r;
          im_wen_w = 0;
          im_d_w[23:16] = (sum_512r_r + IM_Q[23:16]) >> 2;
          im_d_w[15: 8] = (sum_512g_r + IM_Q[15: 8]) >> 2;
          im_d_w[ 7: 0] = (sum_512b_r + IM_Q[ 7: 0]) >> 2;
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin
            ph_a_w = ph_a_r + 4;
            fb_a_w = fb_a_r + 2;
          end else if (cnt_r == 127) begin
            ph_a_w = ph_a_r + 514;
            fb_a_w = fb_a_r + 1;
          end else if (cnt_r < 255) begin 
            ph_a_w = ph_a_r + 4;
            fb_a_w = fb_a_r + 2;
          end else begin // cnt_r == 255
            ph_a_w = ph_a_r + 518;
            fb_a_w = fb_a_r + 3;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else if (s_cnt_r == 6) begin
          s_cnt_w = 1;
          im_a_w = ph_a_r;
          im_wen_w = 1;
        end 
      end
    end

    S_512A: begin
      if (iter_r >= 128) begin 
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
        state_w = S_DCLK2;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r;
          im_wen_w = 1;
          ph_a_w = ph_addr_r;
          fb_a_r = fb_addr_r;
        end else if (s_cnt_r == 1) begin
          sum_512r_w = 0;
          sum_512g_w = 0;
          sum_512b_w = 0;
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          im_a_w = ph_a_r + 512;
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 3) begin
          im_a_w = ph_a_r + 513;
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 4) begin
          im_wen_w = 1;
          sum_512r_w = sum_512r_r + IM_Q[23:16];
          sum_512g_w = sum_512g_r + IM_Q[15: 8];
          sum_512b_w = sum_512b_r + IM_Q[ 7: 0];
        end else if (s_cnt_r == 5) begin
          im_a_w = fb_a_r;
          im_wen_w = 0;
          im_d_w[23:16] = (sum_512r_r + IM_Q[23:16]) >> 2;
          im_d_w[15: 8] = (sum_512g_r + IM_Q[15: 8]) >> 2;
          im_d_w[ 7: 0] = (sum_512b_r + IM_Q[ 7: 0]) >> 2;
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin 
            ph_a_w = ph_a_r + 4;
            fb_a_w = fb_a_r + 2;
          end else if (cnt_r == 127) begin
            ph_a_w = ph_a_r + 518;
            fb_a_w = fb_a_r + 3;
          end else if (cnt_r < 255) begin 
            ph_a_w = ph_a_r + 4;
            fb_a_w = fb_a_r + 2;
          end else begin // cnt_r == 255
            ph_a_w = ph_a_r + 514;
            fb_a_w = fb_a_r + 1;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else if (s_cnt_r == 6) begin
          s_cnt_w = 1;
          im_a_w = ph_a_r;
          im_wen_w = 1;
        end
      end
    end

    //////////////////////////////
    // DClk
    //////////////////////////////
    S_DCLK1: begin
      if (cr_idx_r < 8) begin
        if (cr_row_r < 24) begin
          if (cr_state_r == 0) begin
            im_a_w = (fb_addr_r + 59544) + cr_idx_r * 13 + 256 * cr_row_r;
            cr_a_w = 24 * cr_num + cr_row_r;
            cr_state_w = cr_state_r + 1;
            im_wen_w = 1;
          end else if (cr_state_r == 1) begin
            cr_state_w = cr_state_r + 1;
            im_wen_w = 1;
          end else begin 
            cr_col_w = cr_col_r + 1;
            if (cr_col_r < 11) begin
              im_a_w = im_a_r + 1;
              im_d_w = cr_val;
              im_wen_w = 0;
            end else begin
              im_wen_w = 1;
              cr_state_w = 0;
              cr_col_w = 0;
              cr_row_w = cr_row_r + 1;
            end
          end 
        end else begin
          cr_state_w = 0;
          cr_col_w = 0;
          cr_row_w = 0;
          cr_idx_w = cr_idx_r + 1;
          im_wen_w = 1;
        end
      end else begin
        im_wen_w = 1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
        cr_state_w = 0;
        state_w = S_WAIT1;
      end
    end

    S_DCLK2: begin
      if (cr_idx_r < 8) begin
        if (cr_row_r < 24) begin
          if (cr_state_r == 0) begin
            im_a_w = (fb_addr_r + 59543) + (cr_idx_r * 13) + (256 * cr_row_r);
            cr_a_w = 24 * cr_num + cr_row_r;
            cr_state_w = cr_state_r + 1;
            im_wen_w = 1;
          end else if (cr_state_r == 1) begin
            cr_state_w = cr_state_r + 1;
            im_wen_w = 1;
          end else begin
            cr_col_w = cr_col_r + 1;
            if (cr_col_r < 13) begin
              im_a_w = im_a_r + 1;
              im_d_w = cr_val;
              im_wen_w = 0;
            end else begin
              im_wen_w = 1;
              cr_state_w = 0;
              cr_col_w = 0;
              cr_row_w = cr_row_r + 1;
            end
          end 
        end else begin
          cr_state_w = 0;
          cr_col_w = 0;
          cr_row_w = 0;
          cr_idx_w = cr_idx_r + 1;
          im_wen_w = 1;
        end
      end else begin
        im_wen_w = 1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
        cr_state_w = 0;
        state_w = S_WAIT2;
      end
    end
    
    S_DCLK4: begin
      if (cycle_cnt_r >= CYCLE_1_0 + 100) begin 
        if (cr_idx_r < 8) begin
          if (cr_row_r < 24) begin
            if (cr_state_r == 0) begin
              im_a_w = (fb_addr_r + 59543) + (cr_idx_r * 13) + (256 * cr_row_r);
              cr_a_w = 24 * cr_num + cr_row_r;
              cr_state_w = cr_state_r + 1;
              im_wen_w = 1;
            end else if (cr_state_r == 1) begin
              cr_state_w = cr_state_r + 1;
              im_wen_w = 1;
            end else begin
              cr_col_w = cr_col_r + 1;
              if (cr_col_r < 13) begin
                im_a_w = im_a_r + 1;
                im_d_w = cr_val;
                im_wen_w = 0;
              end else begin
                im_wen_w = 1;
                cr_state_w = 0;
                cr_col_w = 0;
                cr_row_w = cr_row_r + 1;
              end
            end 
          end else begin
            cr_state_w = 0;
            cr_col_w = 0;
            cr_row_w = 0;
            cr_idx_w = cr_idx_r + 1;
            im_wen_w = 1;
          end
        end else begin
          im_wen_w = 1;
          cr_idx_w = 0;
          cr_row_w = 0;
          cr_col_w = 0;
          state_w = S_WAIT4;
        end
      end
    end

    //////////////////////////////
    // Wait
    //////////////////////////////
    S_WAIT1: begin
      if (cycle_cnt_r >= CYCLE_0_2) begin
        if (type_r == 0) begin
          state_w = S_128A;
        end else if (type_r == 1) begin
          state_w = S_256A;
        end else begin 
          state_w = S_512A;
        end 
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
      if (cycle_cnt_r >= CYCLE_1_0) begin
        state_w = S_DCLK4;
      end
    end

    S_WAIT4: begin
      if (cycle_cnt_r >= CYCLE_1_4) begin
        state_w = S_WAIT5;
        im_wen_w = 1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
      end
    end

    S_WAIT5: begin
      if (cycle_cnt_r >= CYCLE_2_0 - 1) begin
        state_w = S_TYPE;
        ph_cnt_w = (ph_cnt_r >= ph_num_r - 1) ? 0 : ph_cnt_r + 1; 
      end
    end

    default: begin 
    end
  endcase

end
    
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
    cr_a_r        <= 0;
    tm_a_r        <= 0;
    cr_idx_r      <= 0;
    cr_col_r      <= 0;
    cr_row_r      <= 0;
    cr_state_r    <= 0;
    sum_512r_r    <= 0;
    sum_512g_r    <= 0;
    sum_512b_r    <= 0;
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
    cr_a_r        <= cr_a_w;
    tm_a_r        <= tm_a_w;
    cr_idx_r      <= cr_idx_w;
    cr_col_r      <= cr_col_w;
    cr_row_r      <= cr_row_w;
    cr_state_r    <= cr_state_w;
    sum_512r_r    <= sum_512r_w;
    sum_512g_r    <= sum_512g_w;
    sum_512b_r    <= sum_512b_w;
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
always @ (*) begin
  case (cr_idx_r) 
    6'd0: cr_num = h1;
    6'd1: cr_num = h0;
    6'd2: cr_num = 10;
    6'd3: cr_num = m1;
    6'd4: cr_num = m0;
    6'd5: cr_num = 10;
    6'd6: cr_num = s1;
    6'd7: cr_num = s0;
    default: cr_num = 0;
  endcase
end 

always @ (*) begin
  if (cr_col_r < 13) begin
    cr_val = CR_Q[12-cr_col_r] ? 24'hffffff : 24'h000000;
  end else begin 
    cr_val = 0;
  end
end

always @ (*) begin
  case (hr_r)
    8'd00:    {h1, h0} = {4'd0, 4'd0};
    8'd01:    {h1, h0} = {4'd0, 4'd1};
    8'd02:    {h1, h0} = {4'd0, 4'd2};
    8'd03:    {h1, h0} = {4'd0, 4'd3};
    8'd04:    {h1, h0} = {4'd0, 4'd4};
    8'd05:    {h1, h0} = {4'd0, 4'd5};
    8'd06:    {h1, h0} = {4'd0, 4'd6};
    8'd07:    {h1, h0} = {4'd0, 4'd7};
    8'd08:    {h1, h0} = {4'd0, 4'd8};
    8'd09:    {h1, h0} = {4'd0, 4'd9};

    8'd10:    {h1, h0} = {4'd1, 4'd0};
    8'd11:    {h1, h0} = {4'd1, 4'd1};
    8'd12:    {h1, h0} = {4'd1, 4'd2};
    8'd13:    {h1, h0} = {4'd1, 4'd3};
    8'd14:    {h1, h0} = {4'd1, 4'd4};
    8'd15:    {h1, h0} = {4'd1, 4'd5};
    8'd16:    {h1, h0} = {4'd1, 4'd6};
    8'd17:    {h1, h0} = {4'd1, 4'd7};
    8'd18:    {h1, h0} = {4'd1, 4'd8};
    8'd19:    {h1, h0} = {4'd1, 4'd9};

    8'd20:    {h1, h0} = {4'd2, 4'd0};
    8'd21:    {h1, h0} = {4'd2, 4'd1};
    8'd22:    {h1, h0} = {4'd2, 4'd2};
    8'd23:    {h1, h0} = {4'd2, 4'd3};
    default:  {h1, h0} = {4'd0, 4'd0};
  endcase
end

always @ (*) begin
  case (min_r)
    8'd00:    {m1, m0} = {4'd0, 4'd0};
    8'd01:    {m1, m0} = {4'd0, 4'd1};
    8'd02:    {m1, m0} = {4'd0, 4'd2};
    8'd03:    {m1, m0} = {4'd0, 4'd3};
    8'd04:    {m1, m0} = {4'd0, 4'd4};
    8'd05:    {m1, m0} = {4'd0, 4'd5};
    8'd06:    {m1, m0} = {4'd0, 4'd6};
    8'd07:    {m1, m0} = {4'd0, 4'd7};
    8'd08:    {m1, m0} = {4'd0, 4'd8};
    8'd09:    {m1, m0} = {4'd0, 4'd9};

    8'd10:    {m1, m0} = {4'd1, 4'd0};
    8'd11:    {m1, m0} = {4'd1, 4'd1};
    8'd12:    {m1, m0} = {4'd1, 4'd2};
    8'd13:    {m1, m0} = {4'd1, 4'd3};
    8'd14:    {m1, m0} = {4'd1, 4'd4};
    8'd15:    {m1, m0} = {4'd1, 4'd5};
    8'd16:    {m1, m0} = {4'd1, 4'd6};
    8'd17:    {m1, m0} = {4'd1, 4'd7};
    8'd18:    {m1, m0} = {4'd1, 4'd8};
    8'd19:    {m1, m0} = {4'd1, 4'd9};

    8'd20:    {m1, m0} = {4'd2, 4'd0};
    8'd21:    {m1, m0} = {4'd2, 4'd1};
    8'd22:    {m1, m0} = {4'd2, 4'd2};
    8'd23:    {m1, m0} = {4'd2, 4'd3};
    8'd24:    {m1, m0} = {4'd2, 4'd4};
    8'd25:    {m1, m0} = {4'd2, 4'd5};
    8'd26:    {m1, m0} = {4'd2, 4'd6};
    8'd27:    {m1, m0} = {4'd2, 4'd7};
    8'd28:    {m1, m0} = {4'd2, 4'd8};
    8'd29:    {m1, m0} = {4'd2, 4'd9};

    8'd30:    {m1, m0} = {4'd3, 4'd0};
    8'd31:    {m1, m0} = {4'd3, 4'd1};
    8'd32:    {m1, m0} = {4'd3, 4'd2};
    8'd33:    {m1, m0} = {4'd3, 4'd3};
    8'd34:    {m1, m0} = {4'd3, 4'd4};
    8'd35:    {m1, m0} = {4'd3, 4'd5};
    8'd36:    {m1, m0} = {4'd3, 4'd6};
    8'd37:    {m1, m0} = {4'd3, 4'd7};
    8'd38:    {m1, m0} = {4'd3, 4'd8};
    8'd39:    {m1, m0} = {4'd3, 4'd9};

    8'd40:    {m1, m0} = {4'd4, 4'd0};
    8'd41:    {m1, m0} = {4'd4, 4'd1};
    8'd42:    {m1, m0} = {4'd4, 4'd2};
    8'd43:    {m1, m0} = {4'd4, 4'd3};
    8'd44:    {m1, m0} = {4'd4, 4'd4};
    8'd45:    {m1, m0} = {4'd4, 4'd5};
    8'd46:    {m1, m0} = {4'd4, 4'd6};
    8'd47:    {m1, m0} = {4'd4, 4'd7};
    8'd48:    {m1, m0} = {4'd4, 4'd8};
    8'd49:    {m1, m0} = {4'd4, 4'd9};

    8'd50:    {m1, m0} = {4'd5, 4'd0};
    8'd51:    {m1, m0} = {4'd5, 4'd1};
    8'd52:    {m1, m0} = {4'd5, 4'd2};
    8'd53:    {m1, m0} = {4'd5, 4'd3};
    8'd54:    {m1, m0} = {4'd5, 4'd4};
    8'd55:    {m1, m0} = {4'd5, 4'd5};
    8'd56:    {m1, m0} = {4'd5, 4'd6};
    8'd57:    {m1, m0} = {4'd5, 4'd7};
    8'd58:    {m1, m0} = {4'd5, 4'd8};
    8'd59:    {m1, m0} = {4'd5, 4'd9};
    default:  {m1, m0} = {4'd0, 4'd0};
  endcase
end

always @ (*) begin
  case (sec_r)
    8'd00:    {s1, s0} = {4'd0, 4'd0};
    8'd01:    {s1, s0} = {4'd0, 4'd1};
    8'd02:    {s1, s0} = {4'd0, 4'd2};
    8'd03:    {s1, s0} = {4'd0, 4'd3};
    8'd04:    {s1, s0} = {4'd0, 4'd4};
    8'd05:    {s1, s0} = {4'd0, 4'd5};
    8'd06:    {s1, s0} = {4'd0, 4'd6};
    8'd07:    {s1, s0} = {4'd0, 4'd7};
    8'd08:    {s1, s0} = {4'd0, 4'd8};
    8'd09:    {s1, s0} = {4'd0, 4'd9};

    8'd10:    {s1, s0} = {4'd1, 4'd0};
    8'd11:    {s1, s0} = {4'd1, 4'd1};
    8'd12:    {s1, s0} = {4'd1, 4'd2};
    8'd13:    {s1, s0} = {4'd1, 4'd3};
    8'd14:    {s1, s0} = {4'd1, 4'd4};
    8'd15:    {s1, s0} = {4'd1, 4'd5};
    8'd16:    {s1, s0} = {4'd1, 4'd6};
    8'd17:    {s1, s0} = {4'd1, 4'd7};
    8'd18:    {s1, s0} = {4'd1, 4'd8};
    8'd19:    {s1, s0} = {4'd1, 4'd9};

    8'd20:    {s1, s0} = {4'd2, 4'd0};
    8'd21:    {s1, s0} = {4'd2, 4'd1};
    8'd22:    {s1, s0} = {4'd2, 4'd2};
    8'd23:    {s1, s0} = {4'd2, 4'd3};
    8'd24:    {s1, s0} = {4'd2, 4'd4};
    8'd25:    {s1, s0} = {4'd2, 4'd5};
    8'd26:    {s1, s0} = {4'd2, 4'd6};
    8'd27:    {s1, s0} = {4'd2, 4'd7};
    8'd28:    {s1, s0} = {4'd2, 4'd8};
    8'd29:    {s1, s0} = {4'd2, 4'd9};

    8'd30:    {s1, s0} = {4'd3, 4'd0};
    8'd31:    {s1, s0} = {4'd3, 4'd1};
    8'd32:    {s1, s0} = {4'd3, 4'd2};
    8'd33:    {s1, s0} = {4'd3, 4'd3};
    8'd34:    {s1, s0} = {4'd3, 4'd4};
    8'd35:    {s1, s0} = {4'd3, 4'd5};
    8'd36:    {s1, s0} = {4'd3, 4'd6};
    8'd37:    {s1, s0} = {4'd3, 4'd7};
    8'd38:    {s1, s0} = {4'd3, 4'd8};
    8'd39:    {s1, s0} = {4'd3, 4'd9};

    8'd40:    {s1, s0} = {4'd4, 4'd0};
    8'd41:    {s1, s0} = {4'd4, 4'd1};
    8'd42:    {s1, s0} = {4'd4, 4'd2};
    8'd43:    {s1, s0} = {4'd4, 4'd3};
    8'd44:    {s1, s0} = {4'd4, 4'd4};
    8'd45:    {s1, s0} = {4'd4, 4'd5};
    8'd46:    {s1, s0} = {4'd4, 4'd6};
    8'd47:    {s1, s0} = {4'd4, 4'd7};
    8'd48:    {s1, s0} = {4'd4, 4'd8};
    8'd49:    {s1, s0} = {4'd4, 4'd9};

    8'd50:    {s1, s0} = {4'd5, 4'd0};
    8'd51:    {s1, s0} = {4'd5, 4'd1};
    8'd52:    {s1, s0} = {4'd5, 4'd2};
    8'd53:    {s1, s0} = {4'd5, 4'd3};
    8'd54:    {s1, s0} = {4'd5, 4'd4};
    8'd55:    {s1, s0} = {4'd5, 4'd5};
    8'd56:    {s1, s0} = {4'd5, 4'd6};
    8'd57:    {s1, s0} = {4'd5, 4'd7};
    8'd58:    {s1, s0} = {4'd5, 4'd8};
    8'd59:    {s1, s0} = {4'd5, 4'd9};

    default:  {s1, s0} = {4'd0, 4'd0};
  endcase
end

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
