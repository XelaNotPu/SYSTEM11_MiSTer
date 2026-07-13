//==============================================================================
// pause_overlay.v
//
// Pause-overlay module for the ZN-1 MiSTer core.
//
// When `enable` is high, replaces the input video with:
//   - 512x256 XN logo positioned at (LOGO_X_START, LOGO_Y_START) — 8-bit
//     indexed via 256-entry RGB palette
//   - vertically scrolling Patreon credits text rendered with an 8x16 font
//
// All four asset ROMs (logo / palette / text / font) are initialized from
// .mif files in rtl/pause_assets/ at synthesis time.
//
// Output color priority: text pixel > logo palette > black background.
//==============================================================================

module pause_overlay (
    input  wire        clk,
    input  wire        ce_pix,        // pulse high once per output pixel
    input  wire        hblank,
    input  wire        vblank,
    input  wire        enable,        // 1 = show overlay, 0 = passthrough

    input  wire  [7:0] vid_r_in,
    input  wire  [7:0] vid_g_in,
    input  wire  [7:0] vid_b_in,

    output reg   [7:0] vid_r_out,
    output reg   [7:0] vid_g_out,
    output reg   [7:0] vid_b_out
);

   // ----- Asset sizes -----
   // Logo is stored 256×256 but rendered 2× horizontally (=512 on-screen) to
   // compensate for the typically-taller game-pixel aspect.
   localparam [11:0] LOGO_W       = 12'd512;   // on-screen logo width  (512 src × 1 native, no stretch)
   localparam [11:0] LOGO_H       = 12'd256;   // on-screen logo height (256 src × 1)
   localparam [11:0] TEXT_WIDTH   = 12'd256;   // 32 cols × 8 px = 256 px text band (1× scale)
   localparam [11:0] TEXT_HEIGHT  = 12'd2048;  // 128 lines × 16 px (67 used by pause.txt)

   // Auto-centering: track frame-by-frame display width/height. Latch the last
   // visible pixel index on each scanline (= width-1) and the last visible
   // line index in the frame (= height-1). Logo and text positions derive
   // from these so the overlay self-centers for any game resolution.
   reg [11:0] disp_w = 12'd512;
   reg [11:0] disp_h = 12'd480;
   reg [11:0] frame_w_max = 0;
   reg [11:0] frame_h_max = 0;

   // Logo top-left position centers the on-screen logo box (W×H) in the display.
   // LOGO_Y_NUDGE shifts the logo down a few pixels — auto-detected disp_h tends
   // to slightly under-count on interlaced/cropped outputs so plain (disp_h-LOGO_H)/2
   // looks a touch high. Empirically +32 lines puts the logo at visual center for
   // typical 480i ZN-1 video.
   localparam [11:0] LOGO_Y_NUDGE = 12'd16;
   wire [11:0] LOGO_X_START = (disp_w > LOGO_W) ? ((disp_w - LOGO_W) >> 1) : 12'd0;
   wire [11:0] LOGO_Y_START = (disp_h > LOGO_H) ? (((disp_h - LOGO_H) >> 1) + LOGO_Y_NUDGE) : LOGO_Y_NUDGE;

   // Text band is centered horizontally above the logo (or centered vertically
   // through the screen as a marquee).
   wire [11:0] TEXT_X_START = (disp_w > TEXT_WIDTH) ? ((disp_w - TEXT_WIDTH) >> 1) : 12'd0;
   wire [11:0] TEXT_Y_START = 12'd0;
   wire [11:0] TEXT_Y_END   = disp_h;

   // ----- Pixel counters from blank signals + per-frame size detection -----
   reg [11:0] px = 0, py = 0;
   reg        hblank_d = 0, vblank_d = 0;

   always @(posedge clk) begin
      if (ce_pix) begin
         hblank_d <= hblank;
         vblank_d <= vblank;

         if (hblank) begin
            // Entering hblank: latch line width (px now holds count of visible pixels)
            if (~hblank_d) begin
               if (px > frame_w_max) frame_w_max <= px;
            end
            px <= 0;
         end else begin
            px <= px + 1'd1;
         end

         if (hblank_d & ~hblank) begin
            py <= py + 1'd1;
            if (py > frame_h_max) frame_h_max <= py;
         end

         if (~vblank_d & vblank) begin
            // Entering vblank: latch detected dimensions for next frame use
            if (frame_w_max > 12'd64) disp_w <= frame_w_max;
            if (frame_h_max > 12'd64) disp_h <= frame_h_max;
            frame_w_max <= 0;
            frame_h_max <= 0;
            py <= 0;
         end
      end
   end

   // ----- Scroll counter: advances once per VBLANK -----
   // Text grid holds 67 pause.txt lines (of 128 ROM lines) × 16 px. Wrap after
   // the used lines plus an 8-line blank gap so the loop restarts cleanly.
   reg [10:0] scroll = 0;
   reg        vbl_d2 = 0;
   reg        enable_d = 0;
   // pause.txt currently holds 19 content lines. Loop over those + a 3-line gap
   // = 22 lines. The wrap MUST match the real content height: leaving it at the
   // old 69-line value made ~50 blank lines crawl past between cycles (the
   // "delay between cycles"). Combined with the mod-LOOP tiling of text_line
   // below, the credits scroll continuously — content is always on screen, so
   // there is no blank stall waiting for the counter to wrap.
   localparam [6:0]  TEXT_LOOP   = 7'd22;       // 19 content + 3-line gap
   localparam [10:0] SCROLL_WRAP = 11'd352;     // TEXT_LOOP × 16 px

   always @(posedge clk) begin
      if (ce_pix) begin
         vbl_d2   <= vblank_d;
         enable_d <= enable;
         if (~enable_d & enable) begin
            // Pause just pressed: restart the credits from the top immediately,
            // instead of catching the free-running marquee at a random position.
            scroll <= 11'd0;
         end else if (enable & ~vbl_d2 & vblank_d) begin
            // Advance once per frame, only while paused (no free-run drift).
            scroll <= (scroll == SCROLL_WRAP - 1) ? 11'd0 : scroll + 1'd1;
         end
      end
   end

   // ===========================================================================
   // ROM 1: Logo image (256x256 4-bit indices)
   // ===========================================================================
   wire in_logo_x = (px >= LOGO_X_START) && (px < LOGO_X_START + LOGO_W);
   wire in_logo_y = (py >= LOGO_Y_START) && (py < LOGO_Y_START + LOGO_H);
   wire in_logo   = in_logo_x & in_logo_y;

   // Native 512×256 logo: 1:1 horizontal (no stretch), 512 real horizontal samples,
   // 8-bit indices into a 256-colour palette. addr = logo_y*512 + logo_x.
   wire [11:0] logo_x_off = (px - LOGO_X_START);
   wire  [8:0] logo_x = logo_x_off[8:0];   // 0..511, native (was /2 stretch)
   wire  [7:0] logo_y = (py - LOGO_Y_START);
   wire [16:0] logo_addr = {logo_y, logo_x};   // logo_y*512 + logo_x
   wire  [7:0] logo_idx;

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(17),
      .numwords_a(131072),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("xn_logo.mif"),
      .lpm_type("altsyncram")
   ) logo_rom (
      .clock0(clk),
      .address_a(logo_addr),
      .q_a(logo_idx)
   );

   // ===========================================================================
   // ROM 2: Palette (256 × 24-bit RGB)
   // ===========================================================================
   wire [23:0] palette_rgb;

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(24),
      .widthad_a(8),
      .numwords_a(256),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("xn_palette.mif"),
      .lpm_type("altsyncram")
   ) palette_rom (
      .clock0(clk),
      .address_a(logo_idx),
      .q_a(palette_rgb)
   );

   // ===========================================================================
   // Text scroller — 2D grid: 128 lines × 32 cols, address = {line[6:0], col[4:0]}
   // ===========================================================================
   wire in_text_x = (px >= TEXT_X_START) && (px < TEXT_X_START + TEXT_WIDTH);
   wire in_text_y = (py >= TEXT_Y_START) && (py < TEXT_Y_END);
   wire in_text   = in_text_x & in_text_y;

   wire [11:0] text_x_off = (px - TEXT_X_START);
   wire [11:0] text_y_raw = (py - TEXT_Y_START) + {1'b0, scroll};

   // Each text line is 16 px tall. Tile the visible line index modulo TEXT_LOOP
   // so the credits wrap around seamlessly: as the top of the text scrolls off,
   // the first line reappears at the bottom of the same window (no blank stall).
   // text_line_raw = (scroll + py)>>4 can reach ~(351+disp_h)/16; for disp_h up
   // to ~1000 that is < 4*TEXT_LOOP, so three conditional subtracts reduce it
   // into [0, TEXT_LOOP) without an (expensive) hardware divider.
   wire  [6:0] text_line_raw = text_y_raw[10:4];
   wire  [6:0] tl_r1      = (text_line_raw >= TEXT_LOOP) ? (text_line_raw - TEXT_LOOP) : text_line_raw;
   wire  [6:0] tl_r2      = (tl_r1        >= TEXT_LOOP) ? (tl_r1        - TEXT_LOOP) : tl_r1;
   wire  [6:0] text_line  = (tl_r2        >= TEXT_LOOP) ? (tl_r2        - TEXT_LOOP) : tl_r2;
   wire  [3:0] text_yoff  = text_y_raw[3:0];   // row within the line (0..15)

   // 1× horizontal: each font pixel = one output pixel (8 px wide chars)
   wire  [4:0] text_col   = text_x_off[7:3];   // col within the line (0..31)
   wire  [2:0] text_xoff  = text_x_off[2:0];   // pixel within the char (0..7)

   // ===========================================================================
   // ROM 3: Text grid (128 × 32 = 4096 bytes)
   // ===========================================================================
   wire [7:0] text_char;
   wire [11:0] text_addr = {text_line, text_col};

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(12),
      .numwords_a(4096),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("patreon_text.mif"),
      .lpm_type("altsyncram")
   ) text_rom (
      .clock0(clk),
      .address_a(text_addr),
      .q_a(text_char)
   );

   // ===========================================================================
   // ROM 4: Font 8x16 (96 printable chars × 16 bytes)
   // ===========================================================================
   wire  [7:0] disp_char = (text_char >= 8'h20 && text_char <= 8'h7E) ? text_char : 8'h20;
   wire [10:0] font_addr = {disp_char[6:0] - 7'd32, text_yoff};
   wire  [7:0] font_row_bits;

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(11),
      .numwords_a(1536),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("font_8x16.mif"),
      .lpm_type("altsyncram")
   ) font_rom (
      .clock0(clk),
      .address_a(font_addr),
      .q_a(font_row_bits)
   );

   // Pick out the bit corresponding to text_xoff (MSB = leftmost pixel).
   wire text_pixel = in_text & font_row_bits[7 - text_xoff];

   // ===========================================================================
   // Final output mux — gated by ce_pix to match the video pipeline
   // ===========================================================================
   always @(posedge clk) begin
      if (ce_pix) begin
         if (enable) begin
            if (text_pixel) begin
               vid_r_out <= 8'hFF;
               vid_g_out <= 8'hFF;
               vid_b_out <= 8'hFF;
            end else if (in_logo) begin
               vid_r_out <= palette_rgb[23:16];
               vid_g_out <= palette_rgb[15:8];
               vid_b_out <= palette_rgb[7:0];
            end else begin
               vid_r_out <= 8'h00;
               vid_g_out <= 8'h00;
               vid_b_out <= 8'h00;
            end
         end else begin
            vid_r_out <= vid_r_in;
            vid_g_out <= vid_g_in;
            vid_b_out <= vid_b_in;
         end
      end
   end

endmodule
