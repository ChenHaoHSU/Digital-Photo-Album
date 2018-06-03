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
parameter [21:0] CYCLE_0_2 = 22'd200000;
parameter [21:0] CYCLE_0_4 = 22'd400000;
parameter [21:0] CYCLE_0_9 = 22'd999999;
parameter [21:0] CYCLE_1_0 = 22'd1000000;
parameter [21:0] CYCLE_1_4 = 22'd1400000;
parameter [21:0] CYCLE_1_9 = 22'd1999999;
parameter [21:0] CYCLE_2_0 = 22'd2000000;

parameter AAA  = 1'b0;
parameter BBB  = 1'b1;

//                                              
//   |----|----|----------------|--------|------------|                                           
//   .0   .2   .4              1.0      1.4          2.0
//   __________________________________________________
//   | 1  |         2           |         3           |
 
// FSM
parameter [3:0] S_INIT  = 4'd00;
parameter [3:0] S_TYPE  = 4'd01;
parameter [3:0] S_128A  = 4'd02; // DO B, then do A (see spec)
parameter [3:0] S_128BH = 4'd03; // DO B, then do A (see spec)
parameter [3:0] S_128BV = 4'd04; // DO B, then do A (see spec)
parameter [3:0] S_256   = 4'd05; // DO B, then do A (see spec)
parameter [3:0] S_512   = 4'd06; // DO B, then do A (see spec)
parameter [3:0] S_DCLK  = 4'd07;
parameter [3:0] S_WAIT  = 4'd08;

// Signals
reg [21:0] cycle_cnt_r, cycle_cnt_w;
reg [19:0] fb_addr_r, fb_addr_w;
reg [2:0]  ph_num_r, ph_num_w;
reg [1:0]  type_r, type_w;             // 0: 128; 1: 256; 2: 512;
reg [19:0] ph_addr_r, ph_addr_w;
reg [3:0]  state_r, state_w;
reg [1:0]  ph_idx_r, ph_idx_w;         // current photo idx
reg [15:0] iter_r, iter_w;
reg [7:0]  s_cnt_r, s_cnt_w;
reg [15:0] cnt_r, cnt_w;
reg [19:0] fb_a_r, fb_a_w;             // current write addr 
reg [19:0] ph_a_r, ph_a_w;             // current read addr
reg [9:0]  sum_512r_r, sum_512r_w;
reg [9:0]  sum_512g_r, sum_512g_w;
reg [9:0]  sum_512b_r, sum_512b_w;
reg [23:0] reg_1_r, reg_1_w;           //    1  |  2   
reg [23:0] reg_2_r, reg_2_w;           //  -----------
reg [23:0] reg_3_r, reg_3_w;           //    3  |  4  
reg        ab_r, ab_w;                 // 0 for a; 1 for b;

reg [19:0] im_a_r, im_a_w;
reg [23:0] im_d_r, im_d_w;
reg        im_wen_r, im_wen_w;

reg [7:0]  hr_r, hr_w, min_r, min_w, sec_r, sec_w;
reg [3:0]  h1, h0;
reg [3:0]  m1, m0;
reg [3:0]  s1, s0;
reg [8:0]  cr_a_r, cr_a_w;
reg [4:0]  cr_idx_r, cr_idx_w;
reg [3:0]  cr_col_r, cr_col_w;
reg [4:0]  cr_row_r, cr_row_w;
reg [7:0]  cr_state_r, cr_state_w;
reg [3:0]  cr_num;
reg [23:0] cr_val;
 
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
  ph_idx_w     = ph_idx_r;
  im_a_w       = im_a_r;
  im_d_w       = im_d_r;
  im_wen_w     = im_wen_r;
  iter_w       = iter_r;
  fb_a_w       = fb_a_r;
  ph_a_w       = ph_a_r;
  s_cnt_w      = s_cnt_r;
  cr_a_w       = cr_a_r;
  cr_idx_w     = cr_idx_r;
  cr_col_w     = cr_col_r;
  cr_row_w     = cr_row_r;
  cr_state_w   = cr_state_r;
  sum_512r_w   = sum_512r_r;
  sum_512g_w   = sum_512g_r;
  sum_512b_w   = sum_512b_r;
  reg_1_w      = reg_1_r;
  reg_2_w      = reg_2_r;
  reg_3_w      = reg_3_r;
  ab_w         = ab_r;

  hr_w  = hr_r;
  min_w = min_r;
  if (cycle_cnt_r == CYCLE_0_9 || cycle_cnt_r == CYCLE_1_9) begin
    sec_w = sec_r + 1;
  end else begin
    sec_w = sec_r;
  end 
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
      cnt_w    = cnt_r + 1;
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
      end else begin
        state_w  = S_TYPE;
        cnt_w    = 0;
        ph_num_w = IM_Q;
        ph_idx_w = 0;
      end
    end

    //////////////////////////////
    // Type
    //////////////////////////////
    S_TYPE: begin
      cnt_w = cnt_r + 1;
      im_wen_w = 1;
      if (cnt_r == 0) begin
        im_a_w = 3 + (ph_idx_r << 1);
      end else if (cnt_r == 1) begin
        im_a_w = im_a_r + 1;
      end else if (cnt_r == 2) begin
        ph_addr_w = IM_Q;
      end else begin
        cnt_w    = 0;
        im_a_w   = 0;
        im_wen_w = 1;
        ph_a_w   = 0;
        fb_a_w   = fb_addr_r + 1;
        iter_w   = 0;
        s_cnt_w  = 0;
        ab_w     = BBB;
        if (IM_Q == 128) begin
          state_w = S_128BH;
          type_w  = 0;
        end else if (IM_Q == 256) begin
          state_w = S_256;
          type_w  = 1;
        end else begin // IM_Q == 512
          state_w = S_512;
          type_w  = 2;
        end
      end
    end

    //////////////////////////////
    // 256
    //////////////////////////////    
    S_256: begin
      if (iter_r >= 256) begin
        state_w      = S_DCLK;
        iter_w       = 0;
        s_cnt_w      = 0;
        cnt_w        = 0;
        im_wen_w     = 1;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ab_r ? ph_addr_r + 1 : ph_addr_r;
          ph_a_w = ab_r ? ph_addr_r + 1 : ph_addr_r;
          fb_a_w = ab_r ? fb_addr_r + 1 : fb_addr_r;
          cnt_w  = 0;
        end else if (s_cnt_r == 2) begin
          im_a_w   = fb_a_r;
          im_wen_w = 0;
          im_d_w   = IM_Q;
        end else if (s_cnt_r == 3) begin
          s_cnt_w  = 1;
          im_wen_w = 1;
          cnt_w    = cnt_r + 1;
          if (cnt_r < 127) begin 
            im_a_w = ph_a_r + 2;
            ph_a_w = ph_a_r + 2;
            fb_a_w = fb_a_r + 2;
          end else begin
            im_a_w = ph_a_r + (ab_r ? 1 : 3);
            ph_a_w = ph_a_r + (ab_r ? 1 : 3);
            fb_a_w = fb_a_r + (ab_r ? 1 : 3);
            iter_w = iter_r + 1;
            cnt_w  = 0;
            ab_w   = ~ab_r;
          end
        end
      end
    end

    //////////////////////////////
    // 128
    //////////////////////////////
    S_128BH: begin
      if (iter_r >= 128) begin
        state_w = S_128BV;
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
      end else begin 
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r;
          im_wen_w = 1;
          ph_a_w = ph_addr_r;
          fb_a_w = fb_addr_r + 1;
        end else if (s_cnt_r == 1) begin
          im_a_w = im_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          reg_1_w = IM_Q;
          im_wen_w = 1;
        end else if (s_cnt_r == 3) begin 
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin
            reg_1_w = IM_Q;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 2;
            im_a_w = fb_a_r;
            im_wen_w = 0;
            im_d_w[23:16] = ({1'b0, reg_1_r[23:16]} + {1'b0, IM_Q[23:16]}) >> 1;
            im_d_w[15: 8] = ({1'b0, reg_1_r[15: 8]} + {1'b0, IM_Q[15: 8]}) >> 1;
            im_d_w[ 7: 0] = ({1'b0, reg_1_r[ 7: 0]} + {1'b0, IM_Q[ 7: 0]}) >> 1;
          end else begin // cnt_r == 128
            im_a_w = fb_a_r;
            im_wen_w = 0;
            im_d_w = reg_1_r;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 258;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else begin 
          s_cnt_w = 1;
          im_a_w = ph_a_r;
          im_wen_w = 1;
        end
      end 
    end

    S_128BV: begin
      if (iter_r >= 128) begin
        state_w = S_DCLK;
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
      end else begin 
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r;
          im_wen_w = 1;
          ph_a_w = ph_addr_r;
          fb_a_w = fb_addr_r + 256;
        end else if (s_cnt_r == 1) begin
          im_a_w = im_a_r + 128;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          reg_1_w = IM_Q;
          im_wen_w = 1;
        end else if (s_cnt_r == 3) begin 
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin
            reg_1_w = IM_Q;
            im_a_w = fb_a_r;
            im_wen_w = 0;
            ph_a_w = ph_a_r + 128;
            fb_a_w = fb_a_r + 512;
            im_d_w[23:16] = ({1'b0, reg_1_r[23:16]} + {1'b0, IM_Q[23:16]}) >> 1;
            im_d_w[15: 8] = ({1'b0, reg_1_r[15: 8]} + {1'b0, IM_Q[15: 8]}) >> 1;
            im_d_w[ 7: 0] = ({1'b0, reg_1_r[ 7: 0]} + {1'b0, IM_Q[ 7: 0]}) >> 1;
          end else begin // cnt_r == 127
            im_a_w = fb_a_r;
            im_wen_w = 0;
            im_d_w = reg_1_r;
            ph_a_w = ph_addr_r + iter_r + 1;
            fb_a_w = fb_addr_r + ((iter_r + 1) << 1) + 256;
            iter_w = iter_r + 1;
            cnt_w = 0;
          end
        end else begin 
          s_cnt_w = 1;
          im_a_w = ph_a_r;
          im_wen_w = 1;
        end
      end 
    end

    S_128A: begin
      if (iter_r >= 128) begin
        state_w = S_DCLK;
        iter_w = 0;
        s_cnt_w = 0;
        cnt_w = 0;
        im_wen_w = 1;
      end else if (iter_r == 127) begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_a_r;
          im_wen_w = 1;
          cnt_w = 0;
        end else if (s_cnt_r == 1) begin
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          reg_1_w = IM_Q;
          im_wen_w = 1;
        end else if (s_cnt_r == 3) begin
          im_a_w = fb_a_r;
          im_wen_w = 0;
          im_d_w = reg_1_r;
          reg_2_w = IM_Q;
        end else if (s_cnt_r == 4) begin
          im_a_w = fb_a_r + 2;
          im_wen_w = 0;
          im_d_w = reg_2_r;
        end else if (s_cnt_r == 5) begin 
          cnt_w = cnt_r + 1;
          if (cnt_r < 126) begin
            im_a_w = fb_a_r + 257;
            im_wen_w = 0;
            im_d_w[23:16] = ({1'b0, reg_1_r[23:16]} + {1'b0, reg_2_r[23:16]}) >> 1;
            im_d_w[15: 8] = ({1'b0, reg_1_r[15: 8]} + {1'b0, reg_2_r[15: 8]}) >> 1;
            im_d_w[ 7: 0] = ({1'b0, reg_1_r[ 7: 0]} + {1'b0, reg_2_r[ 7: 0]}) >> 1;
            reg_1_w = reg_2_r;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 2;
          end else begin
            im_a_w = fb_a_r + 257;
            im_wen_w = 0;
            im_d_w = reg_1_r;
            iter_w = iter_r + 1; // must be 128 = 127 + 1
          end 
        end else if (s_cnt_r == 6) begin
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 7) begin
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
          s_cnt_w = 3;
        end 
      end else begin 
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_a_w = ph_addr_r;
          im_wen_w = 1;
          ph_a_w = ph_addr_r;
          fb_a_w = fb_addr_r;
        end else if (s_cnt_r == 1) begin
          im_a_w = ph_a_r + 128;
          im_wen_w = 1;
        end else if (s_cnt_r == 2) begin
          im_a_w = ph_a_r + 1;
          reg_1_w = IM_Q;
          im_wen_w = 1;
        end else if (s_cnt_r == 3) begin
          im_a_w = ph_a_r + 129;
          reg_3_w = IM_Q;
          im_wen_w = 1;
        end else if (s_cnt_r == 4) begin
          reg_2_w = IM_Q;
        end else if (s_cnt_r == 5) begin
          im_a_w = fb_a_r;
          im_wen_w = 0;
          im_d_w = reg_1_r;
        end else if (s_cnt_r == 6) begin 
          cnt_w = cnt_r + 1;
          if (cnt_r < 127) begin
            im_a_w = fb_a_r + 257;
            im_wen_w = 0;
            im_d_w[23:16] = ( ({2'b00, reg_1_r[23:16]} + {2'b00, reg_2_r[23:16]}) 
                            + ({2'b00, reg_3_r[23:16]} + {2'b00, IM_Q[23:16]}) ) >> 2;
            im_d_w[15: 8] = ( ({2'b00, reg_1_r[15: 8]} + {2'b00, reg_2_r[15: 8]}) 
                            + ({2'b00, reg_3_r[15: 8]} + {2'b00, IM_Q[15: 8]}) ) >> 2;
            im_d_w[ 7: 0] = ( ({2'b00, reg_1_r[ 7: 0]} + {2'b00, reg_2_r[ 7: 0]}) 
                            + ({2'b00, reg_3_r[ 7: 0]} + {2'b00, IM_Q[ 7: 0]}) ) >> 2;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_a_r + 2;
            reg_1_w = reg_2_r;
            reg_3_w = IM_Q;
          end else begin
            im_a_w = fb_a_r + 257;
            im_wen_w = 0;
            im_d_w[23:16] = ({1'b0, reg_1_r[23:16]} + {1'b0, reg_3_r[23:16]}) >> 1;
            im_d_w[15: 8] = ({1'b0, reg_1_r[15: 8]} + {1'b0, reg_3_r[15: 8]}) >> 1;
            im_d_w[ 7: 0] = ({1'b0, reg_1_r[ 7: 0]} + {1'b0, reg_3_r[ 7: 0]}) >> 1;
            ph_a_w = ph_a_r + 1;
            fb_a_w = fb_addr_r + ((iter_r + 1) << 9);
            iter_w = iter_r + 1;
            cnt_w = 0;
            s_cnt_w = 9;
            if (iter_r == 127) s_cnt_w = 0;
          end
        end else if (s_cnt_r == 7) begin
          im_a_w = ph_a_r + 1;
          im_wen_w = 1;
        end else if (s_cnt_r == 8) begin
          s_cnt_w = 4;
          im_a_w = ph_a_r + 129;
          im_wen_w = 1;
        end else if (s_cnt_r == 9) begin
          s_cnt_w = 1;
          im_a_w = ph_a_r;
          im_wen_w = 1;
        end
      end 
    end

    //////////////////////////////
    // 512
    //////////////////////////////
    S_512: begin
      if (iter_r >= 256) begin 
        state_w      = S_DCLK;
        iter_w       = 0;
        s_cnt_w      = 0;
        cnt_w        = 0;
        im_wen_w     = 1;
      end else begin
        s_cnt_w = s_cnt_r + 1;
        if (s_cnt_r == 0) begin
          im_wen_w = 1;
          im_a_w   = ab_r ? ph_addr_r + 2 : ph_addr_r;
          ph_a_w   = ab_r ? ph_addr_r + 2 : ph_addr_r;
          fb_a_w   = ab_r ? fb_addr_r + 1 : fb_addr_r;
        end else if (s_cnt_r == 1) begin
          im_a_w     = ph_a_r + 1;
          im_wen_w   = 1;
          sum_512r_w = 0;
          sum_512g_w = 0;
          sum_512b_w = 0;
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
          im_a_w        = fb_a_r;
          im_wen_w      = 0;
          im_d_w[23:16] = (sum_512r_r + IM_Q[23:16]) >> 2;
          im_d_w[15: 8] = (sum_512g_r + IM_Q[15: 8]) >> 2;
          im_d_w[ 7: 0] = (sum_512b_r + IM_Q[ 7: 0]) >> 2;
          cnt_w         = cnt_r + 1;
          if (cnt_r < 127) begin
            ph_a_w = ph_a_r + 4;
            fb_a_w = fb_a_r + 2;
          end else begin
            ph_a_w = ph_a_r + (ab_r ? 514 : 518);
            fb_a_w = fb_a_r + (ab_r ? 1 : 3);
            iter_w = iter_r + 1;
            cnt_w  = 0;
            ab_w   = ~ab_r;
          end
        end else begin
          s_cnt_w  = 1;
          im_a_w   = ph_a_r;
          im_wen_w = 1;
        end 
      end
    end

    //////////////////////////////
    // DClk
    //////////////////////////////
    S_DCLK: begin
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
          cr_col_w   = 0;
          cr_row_w   = 0;
          cr_idx_w   = cr_idx_r + 1;
          im_wen_w   = 1;
        end
      end else begin // finish
        im_wen_w = 1;
        cr_idx_w = 0;
        cr_row_w = 0;
        cr_col_w = 0;
        cr_state_w = 0;
        state_w = S_WAIT;
      end
    end

    //////////////////////////////
    // Wait
    //////////////////////////////
    S_WAIT: begin
      if (cycle_cnt_r == CYCLE_0_2) begin
        im_a_w   = ph_addr_r;
        im_wen_w = 1;
        ph_a_w   = ph_addr_r;
        fb_a_w   = fb_addr_r;
        iter_w   = 0;
        s_cnt_w  = 0;
        cnt_w    = 0;
        ab_w     = AAA;
        case(type_r)
          2'b00:   state_w = S_128A;
          2'b01:   state_w = S_256;
          2'b10:   state_w = S_512;
          default: state_w = S_256;
        endcase
      end else if (cycle_cnt_r == CYCLE_1_0 + 100) begin
        state_w      = S_DCLK;
      end else if (cycle_cnt_r == CYCLE_1_9) begin
        state_w  = S_TYPE;
        ph_idx_w = (ph_idx_r >= ph_num_r - 1) ? 0 : ph_idx_r + 1;
      end
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
    ph_idx_r      <= 0;
    iter_r        <= 0;
    fb_a_r        <= 0;
    ph_a_r        <= 0;
    s_cnt_r       <= 0;
    sum_512r_r    <= 0;
    sum_512g_r    <= 0;
    sum_512b_r    <= 0;
    reg_1_r       <= 0;
    reg_2_r       <= 0;
    reg_3_r       <= 0;
    ab_r          <= BBB;
  end else begin
    cnt_r         <= cnt_w;
    fb_addr_r     <= fb_addr_w;
    ph_num_r      <= ph_num_w;
    ph_addr_r     <= ph_addr_w;
    type_r        <= type_w;
    state_r       <= state_w;
    ph_idx_r      <= ph_idx_w;
    iter_r        <= iter_w;
    fb_a_r        <= fb_a_w;
    ph_a_r        <= ph_a_w;
    s_cnt_r       <= s_cnt_w;
    sum_512r_r    <= sum_512r_w;
    sum_512g_r    <= sum_512g_w;
    sum_512b_r    <= sum_512b_w;
    reg_1_r       <= reg_1_w;
    reg_2_r       <= reg_2_w;
    reg_3_r       <= reg_3_w;
    ab_r          <= ab_w;
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

always @ (posedge clk or posedge reset) begin
  if (reset) begin
    cr_a_r        <= 0;
    cr_idx_r      <= 0;
    cr_col_r      <= 0;
    cr_row_r      <= 0;
    cr_state_r    <= 0;
  end else begin
    cr_a_r        <= cr_a_w;
    cr_idx_r      <= cr_idx_w;
    cr_col_r      <= cr_col_w;
    cr_row_r      <= cr_row_w;
    cr_state_r    <= cr_state_w;
  end
end

//////////////////////////////
// Cycle Cnt
//////////////////////////////
always @ (*) begin
  cycle_cnt_w = (cycle_cnt_r == CYCLE_1_9) ? 0 : cycle_cnt_r + 1;
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
    4'd0: cr_num = h1;
    4'd1: cr_num = h0;
    4'd2: cr_num = 10;
    4'd3: cr_num = m1;
    4'd4: cr_num = m0;
    4'd5: cr_num = 10;
    4'd6: cr_num = s1;
    4'd7: cr_num = s0;
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
