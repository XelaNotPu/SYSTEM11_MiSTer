library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pGPU.all;

entity gpu is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      clkvid               : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      allowunpause         : out std_logic;
      savestate_busy       : in  std_logic;
      system_paused        : in  std_logic;
      
      ditherOff            : in  std_logic;
      -- System 11 GPU is the CXD8538Q = MAME "gputype 1": all coordinate-register Y fields
      -- sit 2 bits higher than the retail PSX GPU (gputype 2) this core models. When '1',
      -- parse E3/E4/E5 draw area+offset and GP1(05) display-start Y from the +2 positions.
      gpuType1             : in  std_logic := '0';
      interlaced480pHack   : in  std_logic;
      REPRODUCIBLEGPUTIMING: in  std_logic;
      videoout_on          : in  std_logic;
      isPal                : in  std_logic;
      pal60                : in  std_logic;
      fpscountOn           : in  std_logic;
      noTexture            : in  std_logic;
      textureFilter        : in  std_logic_vector(1 downto 0);
      textureFilterStrength: in  std_logic_vector(1 downto 0);
      textureFilter2DOff   : in  std_logic;
      dither24             : in  std_logic;
      render24             : in  std_logic;
      drawSlow             : in  std_logic;
      debugmodeOn          : in  std_logic;
      syncVideoOut         : in  std_logic;
      syncInterlace        : in  std_logic;
      rotate180            : in  std_logic;
      fixedVBlank          : in  std_logic;
      vCrop                : in  std_logic_vector(1 downto 0);
      hCrop                : in  std_logic;

	  oldGPU               : in  std_logic;

      Gun1CrosshairOn      : in  std_logic;
      Gun1X                : in  unsigned(7 downto 0);
      Gun1Y_scanlines      : in  unsigned(8 downto 0);
      Gun1offscreen        : in  std_logic;
      Gun1IRQ10            : out std_logic;

      Gun2CrosshairOn      : in  std_logic;
      Gun2X                : in  unsigned(7 downto 0);
      Gun2Y_scanlines      : in  unsigned(8 downto 0);
      Gun2offscreen        : in  std_logic;
      Gun2IRQ10            : out std_logic;
	  
      cdSlow               : in  std_logic;
      
      errorOn              : in  std_logic;
      errorEna             : in  std_logic;
      errorCode            : in  unsigned(3 downto 0);
      
      LBAOn                : in  std_logic;
      LBAdisplay           : in  unsigned(19 downto 0);
      
      errorLINE            : out std_logic;
      errorRECT            : out std_logic;
      errorPOLY            : out std_logic;
      errorGPU             : out std_logic;
      errorMASK            : out std_logic;
      errorFIFO            : out std_logic;
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0);
      bus_stall            : out std_logic := '0';
      
      dmaOn                : in  std_logic;
      gpu_dmaRequest       : out std_logic;
      DMA_GPU_waiting      : in  std_logic;
      DMA_GPU_writeEna     : in  std_logic;
      DMA_GPU_readEna      : in  std_logic;
      DMA_GPU_write        : in  std_logic_vector(31 downto 0);
      DMA_GPU_read         : out std_logic_vector(31 downto 0);
      
      irq_VBLANK           : out std_logic := '0';
      irq_GPU              : out std_logic := '0';

      -- build #169: expose GPUSTAT bit 31 (DrawingOddline) for psx_top instrumentation
      gpustat31_out        : out std_logic := '0';

      -- System 11 GPU-hang diagnostic: full GPUSTAT value + input-FIFO empty flag.
      -- Tekken hangs polling GPUSTAT bit 28 (=ReadyRecDMA=fifoIn_Empty) which never sets.
      gpustat_out          : out std_logic_vector(31 downto 0) := (others => '0');
      fifoIn_empty_out     : out std_logic := '0';

      -- expose drawingArea bottom Y + drawing offset Y (diagnostic hook)
      -- buffer-swap probe. drawingAreaBottom is 10 bits (0..1023). drawingOffsetY is
      -- 11-bit signed (-1024..1023) — psx_top can compare against 240.
      drawingAreaBottom_out : out std_logic_vector(9 downto 0) := (others => '0');
      drawingOffsetY_out    : out std_logic_vector(10 downto 0) := (others => '0');
           
      vram_pause           : in  std_logic;
      vram_paused          : out std_logic := '0';
      vram_BUSY            : in  std_logic;                    
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      vram_BURSTCNT        : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_ADDR            : out std_logic_vector(27 downto 0) := (others => '0');                       
      vram_DIN             : out std_logic_vector(63 downto 0) := (others => '0');
      vram_BE              : out std_logic_vector(7 downto 0) := (others => '0'); 
      vram_WE              : out std_logic := '0';
      vram_RD              : out std_logic := '0';     

      hblank_tmr           : out std_logic := '0';
      vblank_tmr           : out std_logic := '0';
      dotclock             : out std_logic;
      
      video_hsync          : out std_logic := '0';
      video_vsync          : out std_logic := '0';
      video_hblank         : out std_logic := '0';
      video_vblank         : out std_logic := '0';
      video_DisplayWidth   : out unsigned(10 downto 0);
      video_DisplayHeight  : out unsigned( 9 downto 0);
      video_DisplayOffsetX : out unsigned( 9 downto 0) := (others => '0'); 
      video_DisplayOffsetY : out unsigned( 8 downto 0) := (others => '0');
      video_ce             : out std_logic;
      video_interlace      : out std_logic;
      video_r              : out std_logic_vector(7 downto 0);
      video_g              : out std_logic_vector(7 downto 0);
      video_b              : out std_logic_vector(7 downto 0);
      video_isPal          : out std_logic;
      video_fbmode         : out std_logic;
      video_fb24           : out std_logic;
      video_hResMode       : out std_logic_vector(2 downto 0);
      video_frameindex     : out std_logic_vector(3 downto 0);
      
-- synthesis translate_off
      export_gtm           : out unsigned(11 downto 0);
      export_line          : out unsigned(11 downto 0);
      export_gpus          : out unsigned(31 downto 0);
      export_gobj          : out unsigned(15 downto 0) := (others => '0');
-- synthesis translate_on
      
      loading_savestate    : in  std_logic;
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(2 downto 0);
      SS_wren_GPU          : in  std_logic;
      SS_wren_Timing       : in  std_logic;
      SS_rden_GPU          : in  std_logic;
      SS_rden_Timing       : in  std_logic;
      SS_DataRead_GPU      : out std_logic_vector(31 downto 0);
      SS_DataRead_Timing   : out std_logic_vector(31 downto 0);
      SS_Idle              : out std_logic;

      -- debug taps
      dbg_pipeline_pixelWrite : out std_logic;
      dbg_pipeline_write_in_top : out std_logic;
      dbg_vram_WE            : out std_logic;
      dbg_pipeline_color_varied : out std_logic;  -- pipeline_pixelWrite=1 AND color != 0x4000 (navy)
      dbg_vram_din_non_navy : out std_logic;       -- vram_WE=1 AND vram_DIN != 0x4000_4000_4000_4000 (any non-navy word in the burst)
      dbg_vram_dout_nonnavy : out std_logic;       -- vram_DOUT_READY=1 AND any 16-bit lane != 0x4000 (DDR3 returned non-navy on a GPU read)
      dbg_videoout_linebuf_nonnavy   : out std_logic;  -- line buffer fill captured non-navy (build #5: write-side gated by store/store2)
      dbg_videoout_pixeldata_nonnavy : out std_logic;  -- videoout pixelData_R/G/B differs from pure navy
      -- build #5: address-range narrowing
      dbg_rast_display_nonnavy   : out std_logic;  -- pipeline_pixelWrite=1, color!=0x4000, AND addr in display region (Y<480 AND X<512)
      dbg_rast_offdisp_nonnavy   : out std_logic;  -- pipeline_pixelWrite=1, color!=0x4000, AND addr OUTSIDE display region
      dbg_vramdin_display_nonnavy: out std_logic;  -- vram_WE=1, any lane != 0x4000, AND vram_ADDR in display region
      -- build #7: pipeline color-path narrowing
      dbg_clut_write_nonnavy : out std_logic;      -- CLUT was just written with non-navy data
      dbg_clut_read_nonnavy  : out std_logic;      -- texdata_palette currently non-navy/non-zero
      dbg_stage4_texture     : out std_logic;      -- stage4 textured-pixel
      -- build #8: CLUT-load chain pinpoint
      dbg_textPalNew         : out std_logic;      -- pipeline_textPalNew (rect or poly asserted CLUT-load request)
      dbg_textPalReq_set     : out std_logic;      -- pixelpipeline accepted the request (gating passed)
      dbg_state_REQ_PAL      : out std_logic;      -- pixelpipeline state in REQUESTPALETTE
      dbg_CLUTwrenA_any      : out std_logic;      -- CLUTwrenA asserted (regardless of data)
      dbg_drawMode_8         : out std_logic;      -- current drawMode(8) value (15-bit direct mode)
      dbg_noTexture_pin      : out std_logic;      -- noTexture input value
      -- build #11: CPU2VRAM upload path taps
      dbg_cpu2vram_pixelWrite : out std_logic;     -- CPU2VRAM module fired a pixel write this cycle
      dbg_cpu2vram_color_nonnavy : out std_logic;  -- CPU2VRAM pixel write with non-navy color
      -- build #13: CLUT addressing inspection
      dbg_textPalReqX_nonzero    : out std_logic;
      dbg_textPalReqY_nonzero    : out std_logic;
      dbg_cpu2vram_dstY_bit8_LATCHED_src : out std_logic; -- cpu2vram dest Y has bit 8 set (Y>=256) live
      dbg_cpu2vram_dstY_nonzero  : out std_logic;
      -- build #14: CPU2VRAM destination X (does game ever write at X=0?)
      dbg_cpu2vram_dstX_zero     : out std_logic;
      dbg_cpu2vram_dstX_nonzero  : out std_logic;
      -- build #15: any vram write to X=0 (any source)
      dbg_vram_we_x_zero         : out std_logic;
      dbg_vram_we_x_zero_nonnavy : out std_logic;
      dbg_vram2vram_active       : out std_logic;
      dbg_vramFill_active        : out std_logic;
      -- 2026-06-27: packed GPU command-FSM state to pinpoint the wedged command (render-loop hang)
      dbg_procstate              : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_polyv0                 : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_polyv2                 : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_vram_coord             : in  std_logic_vector(31 downto 0) := (others => '0');  -- JTAG VRAM readback coord
      -- build #17: verify Y-wrap fix - Y bit 9 (>= 512) anywhere
      dbg_pixelAddr_Y_hi          : out std_logic;  -- pixelAddr(20)=1 ever (any source produces Y>=512)
      dbg_cpu2vram_Y_hi           : out std_logic;  -- cpu2vram_pixelAddr(20)=1 ever (post-fix should be DARK)
      dbg_vram_addr_Y_hi_we       : out std_logic;  -- vram_ADDR(20)=1 during vram_WE (post-fix should be DARK)
      dbg_vram_addr_Y_hi_rd       : out std_logic;  -- vram_ADDR(20)=1 during vram_RD (CLUT reads should be DARK)
      -- build #19: lpadv-tuned diagnostics
      dbg_textPalReqX_ge_256     : out std_logic;  -- textPalReqX(8) live (X>=256)
      dbg_textPalReqX_hi          : out std_logic;  -- textPalReqX(9) live (X>=512, e.g. CLUT X=768)
      dbg_cpu2vram_dstX_hi        : out std_logic;  -- cpu2vram dst X bit 9 live (X>=512)
      -- build #21: parser-side capture of cpu2vram dst word with X>=512
      dbg_cpu2vram_parsed_dstX_hi : out std_logic;
      -- 2026-07-03 TEXTURE-WRITE probe: does the GPU ever WRITE VRAM X>=512 (texture region)?
      -- [31]c2v_any(cpu2vram wrote any px) [30]c2v_xhi(cpu2vram INTENDED X>=512) [29]we_xhi(DDR3 vram_WE at X>=512)
      -- [28]parsed_xhi(parser saw dstX>=512) [19:10]=max cpu2vram write X [9:0]=max DDR3-write X (X[9:2]&"00")
      dbg_texwrite_xhi            : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #23: G/B channel-bit detection
      dbg_pipeline_g_set         : out std_logic;  -- pipeline_pixelWrite=1 AND pipeline_pixelColor bits 9:5 non-zero
      dbg_pipeline_b_set         : out std_logic;  -- pipeline_pixelWrite=1 AND pipeline_pixelColor bits 14:10 non-zero
      dbg_vram_din_gb            : out std_logic;  -- vram_WE=1 AND any 16-bit lane has G or B bits set
      dbg_cpu2vram_color_gb      : out std_logic;  -- cpu2vram_pixelWrite=1 AND cpu2vram_pixelColor has G or B bits
      -- build #24: textured-rect rendering mode tracking (live signals; psx_top frame-windows them)
      dbg_rect_tex_4bit          : out std_logic;  -- textured-rect pixel rendered with drawMode(8:7)="00" (4-bit CLUT)
      dbg_rect_tex_8bit          : out std_logic;  -- textured-rect pixel rendered with drawMode(8:7)="01" (8-bit CLUT)
      dbg_rect_tex_15bit         : out std_logic;  -- textured-rect pixel rendered with drawMode(8)='1' (15-bit direct)
      dbg_desync                 : out std_logic_vector(31 downto 0) := (others => '0');  -- 2026-07-06 {unkcmd_cnt16, unkcmd_last8, disp_cnt8}
      dbg_rect_tex_pixel_gb      : out std_logic;  -- textured-rect pixel was drawn AND output color has G or B bits
      -- build #26: cube-CLUT (X>=512) readback color forensics
      dbg_cubeclut_gb            : out std_logic;  -- loaded CLUT X>=512 and looked-up entry colorful (cube CLUT read good)
      dbg_cubeclut_ronly         : out std_logic;  -- loaded CLUT X>=512 and looked-up entry red-only (cube CLUT read corrupt)
      dbg_loclut_gb              : out std_logic;  -- loaded CLUT X<512 and looked-up entry colorful (positive control)
      -- build #57: stage4 textured pixel with non-zero RAW texel index (texture DATA present, pre-CLUT)
      dbg_stage4_texraw_nz       : out std_logic;
      -- build #63: textPalReqY in CLUT range [460,500) — gates CLUT loads targeting lpadv's CLUT-Y region
      dbg_textPalReqY_clut       : out std_logic;
      -- build #67: (textPalReqX, textPalReqY) of last high-Y CLUT load that returned real color
      dbg_last_succ_palX         : out std_logic_vector(9 downto 0);
      dbg_last_succ_palY         : out std_logic_vector(9 downto 0);
      -- build #68: split Y-range gates
      dbg_textPalReqY_lo         : out std_logic;
      dbg_textPalReqY_hi         : out std_logic;
      -- build #82: direct vram_DOUT capture at first hi-Y CLUTwrenA (textPalY=482, CLUTaddrA=0)
      dbg_b82_byte_redslot       : out std_logic_vector(7 downto 0);
      dbg_b82_byte_greenslot     : out std_logic_vector(7 downto 0);
      dbg_b82_captured           : out std_logic;
      -- build #39: Tecmo bank register state, plumbed from memorymux via psx_top
      bank_8mb_in                : in  std_logic_vector(2 downto 0) := (others => '0');
      -- build #114 H1+H2: cube 0x64 rect path test (7 sticky boolean indicators)
      dbg_h12_red_anchor          : out std_logic;
      dbg_h12_green_dm_ok         : out std_logic;
      dbg_h12_blue_dm_stale       : out std_logic;
      dbg_h12_yellow_busy0        : out std_logic;
      dbg_h12_white_dm_chg        : out std_logic;
      dbg_h12_cyan_emit_busy0     : out std_logic;
      dbg_h12_magenta_busy_long   : out std_logic;
      -- build #115: H1 race-frequency quantification (each = upper 9 bits of 16-bit counter)
      dbg_h12_stale_count_hi      : out std_logic_vector(8 downto 0);
      dbg_h12_ok_count_hi         : out std_logic_vector(8 downto 0);
      dbg_h12_stale_gt_ok         : out std_logic;
      -- build #117: G+B stripping locator
      dbg_h17_anchor              : out std_logic;
      dbg_h17_g_set               : out std_logic;
      dbg_h17_b_set               : out std_logic;
      -- build #119: vram_DIN G+B locator at cube area SDRAM writes
      dbg_h19_anchor              : out std_logic;
      dbg_h19_g_in_din            : out std_logic;
      dbg_h19_b_in_din            : out std_logic;
      -- build #120: counter-based G+B prevalence (upper 9 bits of 16-bit counter)
      dbg_h20_anchor_count_hi     : out std_logic_vector(8 downto 0);
      dbg_h20_g_count_hi          : out std_logic_vector(8 downto 0);
      dbg_h20_b_count_hi          : out std_logic_vector(8 downto 0);
      -- build #122: vram_DOUT capture (5-bit R and G channels of CLUT[3])
      dbg_h22_anchor              : out std_logic;
      dbg_h22_clut3_r             : out std_logic_vector(4 downto 0);
      dbg_h22_clut3_g             : out std_logic_vector(4 downto 0);
      -- build #124: SDRAM round-trip self-test outputs
      dbg_h24_write_r             : out std_logic_vector(4 downto 0);
      dbg_h24_read_r              : out std_logic_vector(4 downto 0);
      dbg_h24_both_anchors        : out std_logic;
      -- build #128: cpu2vram vs vram_DIN comparison
      dbg_h28_cpu_r               : out std_logic_vector(4 downto 0);
      dbg_h28_vram_r              : out std_logic_vector(4 downto 0);
      dbg_h28_both_anchors        : out std_logic;
      -- build #129: Tecmo bank verification
      dbg_h29_bank                : out std_logic_vector(2 downto 0);
      dbg_h29_bank_anchor         : out std_logic;
      dbg_h29_bank_ever_changed   : out std_logic;
      -- build #131: DMA channel 2 delivery instrumentation
      dbg_h31_pixel1_r            : out std_logic_vector(4 downto 0);
      dbg_h31_pixel2_r            : out std_logic_vector(4 downto 0);
      dbg_h31_rich_ever           : out std_logic;
      -- build #132: DMA R-value sticky detectors
      dbg_h32_r31_ever            : out std_logic;
      dbg_h32_r_high_ever         : out std_logic;
      dbg_h32_pixel1_nonzero_ever : out std_logic;
      -- build #133: fifo_data_1 vs cpu2vram_pixelColor at cube CLUT lane-3
      dbg_h33_fifo_data_1_r        : out std_logic_vector(4 downto 0);
      dbg_h33_cpu_color_r          : out std_logic_vector(4 downto 0);
      dbg_h33_anchor               : out std_logic;
      dbg_h33_r31_ever             : out std_logic;
      -- build #134: fifoIn_Dout halfword R bits stickys
      dbg_h34_lower_r31_ever       : out std_logic;
      dbg_h34_upper_r31_ever       : out std_logic;
      dbg_h34_upper_msb_ever       : out std_logic;
      -- build #137: cpu2vram FSM latch-chain probes (set-only)
      dbg_h37_input_r31_ever       : out std_logic;
      dbg_h37_writing_r31_ever     : out std_logic;
      dbg_h37_latch_r31_ever       : out std_logic;
      -- build #138: cube-CLUT-specific lane probes (set-only)
      dbg_h38_lane2_input_r31_ever : out std_logic;
      dbg_h38_lane3_latch_r31_ever : out std_logic;
      dbg_h38_lane3_anchor_ever    : out std_logic;
      -- build #139: cube-shape Y observability probes (set-only)
      dbg_h39_cubeshape_any_ever   : out std_logic;
      dbg_h39_cubeshape_y482_ever  : out std_logic;
      dbg_h39_cubeshape_y488_ever  : out std_logic;
      -- build #140: CLUT-RAM cube CLUT presence probes (set-only)
      dbg_h40_cube_clut_loaded_ever : out std_logic;
      dbg_h40_clut_read_7fff_ever   : out std_logic;
      dbg_h40_clut_read_023f_ever   : out std_logic;
      -- build #158: H4 cache-staleness probes (set-only)
      dbg_h58_x_stale_seen          : out std_logic;
      dbg_h58_y_stale_seen          : out std_logic;
      dbg_h58_pixel_seen            : out std_logic;
      -- build #159: H7 CLUT load value capture
      dbg_h59_loaded_entry0_lo      : out std_logic_vector(8 downto 0);
      dbg_h59_loaded_y              : out std_logic_vector(8 downto 0);
      dbg_h59_anchor                : out std_logic;
      -- build #145: Y=482/480 pixelWrite probes (set-only)
      dbg_h45_y482_anchor   : out std_logic;
      dbg_h45_y482_pixwrite : out std_logic;
      dbg_h45_y480_pixwrite : out std_logic;
      -- build #146-149: cpu2vram value-capture probes (semantics evolve per build)
      dbg_h46_y_minus_240   : out std_logic_vector(8 downto 0);
      dbg_h46_y_high_bit    : out std_logic;
      dbg_h46_anchor        : out std_logic;
      dbg_h49_entry1_low    : out std_logic_vector(8 downto 0)
   );
end entity;

architecture arch of gpu is
  
   signal softReset                 : std_logic := '0';
   signal drawer_reset              : std_logic := '0';
   
   signal videoout_settings         : tvideoout_settings;
   signal videoout_reports          : tvideoout_reports;
   signal videoout_out              : tvideoout_out;
   
   signal GPUREAD                   : std_logic_vector(31 downto 0) := (others => '0');
   signal GPUSTAT                   : std_logic_vector(31 downto 0) := (others => '0');
   signal GPUSTAT_TextPageX         : std_logic_vector(3 downto 0);
   signal GPUSTAT_TextPageY         : std_logic;
   signal GPUSTAT_Transparency      : std_logic_vector(1 downto 0);
   signal GPUSTAT_TextPageColors    : std_logic_vector(1 downto 0);
   signal GPUSTAT_Dither            : std_logic;
   signal GPUSTAT_DrawToDisplay     : std_logic;
   signal GPUSTAT_SetMask           : std_logic;
   signal GPUSTAT_DrawPixelsMask    : std_logic;
   signal t1_status11               : std_logic := '0';  -- gputype1: GPUSTAT(11) reflection (E1 tpage bit11 / E6 bit0) — status only
   signal t1_status12               : std_logic := '0';  -- gputype1: GPUSTAT(12) reflection (E1 tpage bit12 / E6 bit1) — status only
   signal GPUSTAT_ReverseFlag       : std_logic;
   signal GPUSTAT_TextureDisable    : std_logic;
   signal GPUSTAT_HorRes2           : std_logic := '0';
   signal GPUSTAT_HorRes1           : std_logic_vector(1 downto 0) := "00";
   signal GPUSTAT_VerRes            : std_logic := '0';
   signal GPUSTAT_PalVideoMode      : std_logic := '0';
   signal GPUSTAT_ColorDepth24      : std_logic := '0';
   signal GPUSTAT_VertInterlace     : std_logic := '0';
   signal GPUSTAT_DisplayDisable    : std_logic := '1';
   signal GPUSTAT_IRQRequest        : std_logic;
   signal GPUSTAT_DMADataRequest    : std_logic;
   signal GPUSTAT_ReadyRecCmd       : std_logic;
   signal GPUSTAT_ReadySendVRAM     : std_logic;
   signal GPUSTAT_ReadyRecDMA       : std_logic;
   signal GPUSTAT_DMADirection      : std_logic_vector(1 downto 0);
      
   signal vramRange                 : unsigned(19 downto 0) := (others => '0');
   signal hDisplayRange             : unsigned(23 downto 0) := x"C60260";
   signal vDisplayRange             : unsigned(19 downto 0) := x"3FC10";
      
   signal drawMode                  : unsigned(13 downto 0) := (others => '0');
      
   signal textureWindow             : unsigned(19 downto 0) := (others => '0');
   signal textureWindow_AND_X       : unsigned(7 downto 0) := (others => '0');
   signal textureWindow_AND_Y       : unsigned(7 downto 0) := (others => '0');   
   signal textureWindow_OR_X        : unsigned(7 downto 0) := (others => '0');
   signal textureWindow_OR_Y        : unsigned(7 downto 0) := (others => '0');
      
   signal drawingAreaLeft           : unsigned(9 downto 0) := (others => '0');
   signal drawingAreaRight          : unsigned(9 downto 0) := (others => '0');
   signal drawingAreaTop            : unsigned(9 downto 0) := (others => '0');
   signal drawingAreaBottom         : unsigned(9 downto 0) := (others => '0');
   signal drawingOffsetX            : signed(10 downto 0) := (others => '0');
   signal drawingOffsetY            : signed(10 downto 0) := (others => '0');
   signal interlacedDrawing         : std_logic;
      
   -- FIFO IN  
   signal fifoIn_reset              : std_logic; 
   signal fifoIn_Din                : std_logic_vector(31 downto 0);
   signal fifoIn_Wr                 : std_logic; 
   signal fifoIn_Dout               : std_logic_vector(31 downto 0);
   signal fifoIn_Rd                 : std_logic;
   signal fifoIn_Empty              : std_logic;
   signal fifoIn_NearFull           : std_logic;
   signal fifoInPio_pend            : std_logic := '0';                     -- 2026-07-06 collision fix
   signal fifoInPio_data            : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_unkcmd_cnt            : unsigned(15 downto 0) := (others => '0');  -- 2026-07-06 desync detector
   signal dbg_unkcmd_last           : std_logic_vector(7 downto 0) := (others => '0');
   signal dbg_disp_cnt              : unsigned(7 downto 0) := (others => '0');
   signal errfifo_sticky            : std_logic := '0';
   signal fifoIn_Valid              : std_logic;
      
   -- Processing  
   signal proc_idle                 : std_logic;
   signal proc_done                 : std_logic;
   --signal proc_CmdDone              : std_logic;
   signal proc_requestFifo          : std_logic;
   signal timeout                   : integer range 0 to 67108863 := 0;
   
   signal pixelStall                : std_logic;
   signal pixelColor                : std_logic_vector(15 downto 0);
   signal pixelColor2               : std_logic_vector(15 downto 0);
   signal pixelAddr                 : unsigned(20 downto 0);
   signal pixelWrite                : std_logic;
      
   signal pixel64data               : std_logic_vector(63 downto 0) := (others => '0');
   signal pixel64data2              : std_logic_vector(63 downto 0) := (others => '0');
   signal pixel64wordEna            : std_logic_vector(3 downto 0) := (others => '0');
   signal pixel64addr               : std_logic_vector(17 downto 0) := (others => '0');
   signal pixel64filled             : std_logic := '0';
   signal pixel64source             : std_logic := '0';
   signal pixel64timeout            : integer range 0 to 15;
      
   -- workers  
   type t_div_array is array(0 to 5) of div_type;
   signal div_array                 : t_div_array;
   
   signal vramFill_requestFifo      : std_logic; 
   signal vramFill_done             : std_logic; 
   --signal vramFill_CmdDone          : std_logic; 
   signal vramFill_pixelColor       : std_logic_vector(15 downto 0);
   signal vramFill_pixelAddr        : unsigned(20 downto 0);
   signal vramFill_pixelWrite       : std_logic;   
      
   signal cpu2vram_requestFifo      : std_logic; 
   signal cpu2vram_done             : std_logic; 
   --signal cpu2vram_CmdDone          : std_logic; 
   signal cpu2vram_pixelColor       : std_logic_vector(15 downto 0);
   signal cpu2vram_pixelAddr        : unsigned(20 downto 0);
   signal cpu2vram_pixelWrite       : std_logic;
   -- texture-write (X>=512) sticky probe
   signal txw_c2v_any               : std_logic := '0';
   signal txw_c2v_xhi               : std_logic := '0';
   signal txw_we_xhi                : std_logic := '0';
   signal txw_parsed_xhi            : std_logic := '0';
   signal txw_c2v_maxX              : unsigned(9 downto 0) := (others => '0');
   signal txw_we_maxX               : unsigned(9 downto 0) := (others => '0');
   signal txw_we_fb_seen            : std_logic := '0';                            -- vram_WE ever hit framebuffer X<512,Y<480
   signal txw_we_fb_back            : std_logic := '0';                            -- vram_WE ever hit BACK buffer X<512, 240<=Y<480
   signal txw_we_minX               : unsigned(9 downto 0) := (others => '1');      -- min X of any vram_WE write (init 1023)
   signal txw_we_maxY               : unsigned(9 downto 0) := (others => '0');      -- max Y of any framebuffer (X<512) vram_WE write
   -- VRAM write-vs-readback comparator: watch one framebuffer word address, compare what was WRITTEN vs a later READ
   signal wr_watch_addr             : std_logic_vector(17 downto 0) := (others => '0');  -- vram_ADDR(20:3)
   signal wr_watch_valid            : std_logic := '0';
   signal wr_watch_data             : std_logic_vector(15 downto 0) := (others => '0');
   signal rd_pending_addr           : std_logic_vector(17 downto 0) := (others => '0');
   signal cmp_wdata                 : std_logic_vector(15 downto 0) := (others => '0');
   signal cmp_rdata                 : std_logic_vector(15 downto 0) := (others => '0');
   signal cmp_seen                  : std_logic := '0';
   signal cmp_mismatch              : std_logic := '0';
   signal rd_burst_base             : unsigned(17 downto 0) := (others => '0');  -- burst-start word addr vram_ADDR(20:3)
   signal rd_word_cnt               : unsigned(7 downto 0)  := (others => '0');  -- word index within the read burst
   signal cpu2vram_parsed_dstX_hi   : std_logic;  -- build #21
   signal cpu2vram_cube_in_green    : std_logic;  -- build #45
   signal cpu2vram_cube_in_red      : std_logic;  -- build #45
   signal cpu2vram_cube_in_any      : std_logic;  -- build #45
   signal cpu2vram_fifo_data_1      : std_logic_vector(15 downto 0);  -- build #133
   -- build #137: cpu2vram FSM latch-chain probes (signals out of gpu_cpu2vram, up to entity port)
   signal h37_input_r31_ever_sig    : std_logic;
   signal h37_writing_r31_ever_sig  : std_logic;
   signal h37_latch_r31_ever_sig    : std_logic;
   -- build #138: cube-CLUT-specific lane probes
   signal h38_lane2_input_r31_ever_sig : std_logic;
   signal h38_lane3_latch_r31_ever_sig : std_logic;
   signal h38_lane3_anchor_ever_sig    : std_logic;
   -- build #139: cube-shape Y observability probes
   signal h39_cubeshape_any_ever_sig   : std_logic;
   signal h39_cubeshape_y482_ever_sig  : std_logic;
   signal h39_cubeshape_y488_ever_sig  : std_logic;
   -- build #145: Y=482/480 pixelWrite probes
   signal h45_y482_anchor_sig    : std_logic;
   signal h45_y482_pixwrite_sig  : std_logic;
   signal h45_y480_pixwrite_sig  : std_logic;
   -- build #146-149: cpu2vram value-capture probes (semantics per build)
   signal h46_y_minus_240_sig    : std_logic_vector(8 downto 0);
   signal h46_y_high_bit_sig     : std_logic;
   signal h46_anchor_sig         : std_logic;
   signal h49_entry1_low_sig     : std_logic_vector(8 downto 0);

   signal vram2vram_requestFifo     : std_logic;
   signal vram2vram_done            : std_logic; 
   --signal vram2vram_CmdDone         : std_logic; 
   signal vram2vram_pixelColor      : std_logic_vector(15 downto 0);
   signal vram2vram_pixelAddr       : unsigned(20 downto 0);
   signal vram2vram_pixelWrite      : std_logic;
   signal vram2vram_reqVRAMEnable   : std_logic;
   signal vram2vram_reqVRAMXPos     : unsigned(9 downto 0);
   signal vram2vram_reqVRAMYPos     : unsigned(9 downto 0);
   signal vram2vram_reqVRAMSize     : unsigned(10 downto 0);
   signal vram2vram_vramLineEna     : std_logic;
   signal vram2vram_vramLineAddr    : unsigned(9 downto 0);
   
   signal vram2cpu_requestFifo      : std_logic; 
   signal vram2cpu_done             : std_logic; 
   --signal vram2cpu_CmdDone          : std_logic; 
   signal vram2cpu_reqVRAMEnable    : std_logic;
   signal vram2cpu_reqVRAMXPos      : unsigned(9 downto 0);
   signal vram2cpu_reqVRAMYPos      : unsigned(9 downto 0);
   signal vram2cpu_reqVRAMSize      : unsigned(10 downto 0);
   signal vram2cpu_vramLineEna      : std_logic;
   signal vram2cpu_vramLineAddr     : unsigned(9 downto 0);
   signal vram2cpu_Fifo_Dout        : std_logic_vector(31 downto 0);
   signal vram2cpu_Fifo_Rd          : std_logic;
   signal vram2cpu_Fifo_Empty       : std_logic;
   signal vram2cpu_Fifo_ready       : std_logic;
   
   signal line_requestFifo          : std_logic; 
   signal line_done                 : std_logic;
   --signal line_CmdDone              : std_logic;
   signal line_div                  : t_div_array;
   signal line_pipeline_new         : std_logic;
   signal line_pipeline_transparent : std_logic;
   signal line_pipeline_x           : unsigned(9 downto 0);
   signal line_pipeline_y           : unsigned(9 downto 0);
   signal line_pipeline_cr          : unsigned(7 downto 0);
   signal line_pipeline_cg          : unsigned(7 downto 0);
   signal line_pipeline_cb          : unsigned(7 downto 0);
   signal line_reqVRAMEnable        : std_logic;
   signal line_reqVRAMXPos          : unsigned(9 downto 0);
   signal line_reqVRAMYPos          : unsigned(9 downto 0);
   signal line_reqVRAMSize          : unsigned(10 downto 0);
   signal line_vramLineEna          : std_logic;
   signal line_vramLineAddr         : unsigned(9 downto 0);
   
   signal rect_requestFifo          : std_logic; 
   signal rect_done                 : std_logic;
   --signal rect_CmdDone              : std_logic;
   signal rect_pipeline_new         : std_logic;
   signal rect_pipeline_texture     : std_logic;
   signal rect_pipeline_transparent : std_logic;
   signal rect_pipeline_rawTexture  : std_logic;
   signal rect_pipeline_x           : unsigned(9 downto 0);
   signal rect_pipeline_y           : unsigned(9 downto 0);
   signal rect_pipeline_cr          : unsigned(7 downto 0);
   signal rect_pipeline_cg          : unsigned(7 downto 0);
   signal rect_pipeline_cb          : unsigned(7 downto 0);
   signal rect_pipeline_u           : unsigned(7 downto 0);
   signal rect_pipeline_v           : unsigned(7 downto 0);
   signal rect_reqVRAMEnable        : std_logic;
   signal rect_reqVRAMXPos          : unsigned(9 downto 0);
   signal rect_reqVRAMYPos          : unsigned(9 downto 0);
   signal rect_reqVRAMSize          : unsigned(10 downto 0);
   signal rect_vramLineEna          : std_logic;
   signal rect_vramLineAddr         : unsigned(9 downto 0);
   signal rect_textPalNew           : std_logic;
   signal rect_textPalX             : unsigned(9 downto 0);   
   signal rect_textPalY             : unsigned(9 downto 0);
   
   signal poly_requestFifo          : std_logic; 
   signal poly_done                 : std_logic;
   --signal poly_CmdDone              : std_logic;
   signal poly_div                  : t_div_array;
   signal poly_pipeline_new         : std_logic;
   signal poly_pipeline_texture     : std_logic;
   signal poly_pipeline_transparent : std_logic;
   signal poly_pipeline_rawTexture  : std_logic;
   signal poly_pipeline_dithering   : std_logic;
   signal poly_pipeline_x           : unsigned(9 downto 0);
   signal poly_pipeline_y           : unsigned(9 downto 0);
   signal poly_pipeline_cr          : unsigned(7 downto 0);
   signal poly_pipeline_cg          : unsigned(7 downto 0);
   signal poly_pipeline_cb          : unsigned(7 downto 0);
   signal poly_pipeline_u           : unsigned(7 downto 0);
   signal poly_pipeline_v           : unsigned(7 downto 0);
   signal poly_pipeline_u11         : unsigned(7 downto 0);
   signal poly_pipeline_v11         : unsigned(7 downto 0);
   signal poly_reqVRAMEnable        : std_logic;
   signal poly_reqVRAMXPos          : unsigned(9 downto 0);
   signal poly_reqVRAMYPos          : unsigned(9 downto 0);
   signal poly_reqVRAMSize          : unsigned(10 downto 0);
   signal poly_vramLineEna          : std_logic;
   signal poly_vramLineAddr         : unsigned(9 downto 0);
   signal poly_drawModeRec          : unsigned(13 downto 0);
   signal poly_drawModeNew          : std_logic;
   signal poly_textPalNew           : std_logic;
   signal poly_textPalX             : unsigned(9 downto 0);   
   signal poly_textPalY             : unsigned(9 downto 0);
   
   signal pipeline_pixelColor       : std_logic_vector(15 downto 0);
   signal pipeline_pixelColor2      : std_logic_vector(15 downto 0);
   signal pipeline_pixelAddr        : unsigned(20 downto 0);
   signal dbg_clut_write_nonnavy_int : std_logic;
   signal dbg_clut_read_nonnavy_int  : std_logic;
   signal dbg_stage4_texture_int     : std_logic;
   signal dbg_textPalReq_set_int     : std_logic;
   signal dbg_state_REQ_PAL_int      : std_logic;
   signal dbg_CLUTwrenA_any_int      : std_logic;
   signal dbg_drawMode_8_int         : std_logic;
   signal dbg_noTexture_pin_int      : std_logic;
   signal dbg_textPalReqX_nz_int     : std_logic;
   signal dbg_textPalReqY_nz_int     : std_logic;
   -- build #19: lpadv-tuned
   signal dbg_textPalReqX_hi_int     : std_logic;  -- textPalReqX(9)
   signal dbg_textPalReqX_b8_int     : std_logic;  -- textPalReqX(8)
   -- build #26: cube-CLUT readback forensics
   signal dbg_cubeclut_gb_int        : std_logic;
   signal dbg_cubeclut_ronly_int     : std_logic;
   signal dbg_loclut_gb_int          : std_logic;
   signal dbg_stage4_texraw_nz_int   : std_logic;  -- build #57
   signal dbg_textPalReqY_clut_int   : std_logic;  -- build #63
   signal dbg_last_succ_palX_int     : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_last_succ_palY_int     : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_textPalReqY_lo_int     : std_logic;  -- build #68
   signal dbg_textPalReqY_hi_int     : std_logic;  -- build #68
   signal dbg_b82_byte_redslot_int   : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_byte_greenslot_int : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_captured_int       : std_logic;                      -- build #82
   -- build #102: trace the fifo_data that produces textPalY=507 in gpu_poly
   signal poly_dbg_b102_fifodata     : std_logic_vector(31 downto 0);
   signal poly_dbg_b102_y507_pulse   : std_logic;
   -- build #103: same trace from gpu_rect
   signal rect_dbg_b103_fifodata     : std_logic_vector(31 downto 0);
   signal rect_dbg_b103_y507_pulse   : std_logic;
   -- combined feed to pixelpipeline: OR pulses; mux fifo_data on whichever pulses
   signal combined_b102_fifodata     : std_logic_vector(31 downto 0);
   signal combined_b102_pulse        : std_logic;
   signal pipeline_pixelWrite       : std_logic;
   signal pipeline_reqVRAMEnable    : std_logic;
   signal pipeline_reqVRAMXPos      : unsigned(9 downto 0);
   signal pipeline_reqVRAMYPos      : unsigned(9 downto 0);
   signal pipeline_reqVRAMSize      : unsigned(10 downto 0);
   -- high-Y VRAM-fetch diagnostic (JTAG mode E): max/last pixel-pipeline texture+CLUT fetch Y, max X
   signal dbg_pipeReqY_max          : unsigned(9 downto 0) := (others => '0');
   signal dbg_pipeReqY_last         : unsigned(9 downto 0) := (others => '0');
   signal dbg_pipeReqX_max          : unsigned(9 downto 0) := (others => '0');
   signal dbg_texel_sig             : std_logic_vector(31 downto 0); -- texel-read diag from pixelpipeline (mode D)
   signal dbg_uv_sig                : std_logic_vector(31 downto 0); -- U/V-range diag from pixelpipeline (mode E)
   signal dbg_dispread_sig          : std_logic_vector(31 downto 0); -- videoout line-buffer INPUT signature (mode D)
   signal dbg_linebufrd_sig         : std_logic_vector(31 downto 0); -- videoout line-buffer OUTPUT signature (mode E)
   -- DMA-delivered GPU data checksum (texture upload data): mode D=xor, mode E=count&last16
   signal dbg_dma_xor               : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_dma_last              : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_dma_cnt               : unsigned(15 downto 0) := (others => '0');
   signal dbg_dma_wrEna_prev        : std_logic := '0';
   -- IMGLOAD size-word diagnostic: max width/height + runaway counts (H=0=>512, W=0=>1024)
   signal dbg_maxH                  : unsigned(8 downto 0) := (others => '0');
   signal dbg_maxW                  : unsigned(9 downto 0) := (others => '0');
   signal dbg_h0_cnt                : unsigned(5 downto 0) := (others => '0');
   signal dbg_w0_cnt                : unsigned(5 downto 0) := (others => '0');
   signal dbg_copysize_prev         : std_logic_vector(31 downto 0) := (others => '0');
   -- cpu2vram (IMGLOAD 0xA0) write-coverage diagnostic (JTAG mode D=count&xor, E=maxcol&maxrow)
   signal dbg_c2v_count             : unsigned(15 downto 0) := (others => '0');
   signal dbg_c2v_maxcol            : unsigned(9 downto 0) := (others => '0');
   signal dbg_c2v_maxrow            : unsigned(9 downto 0) := (others => '0');
   signal dbg_c2v_minrow            : unsigned(9 downto 0) := (others => '1');
   signal dbg_pixcolor_last         : std_logic_vector(15 downto 0) := (others => '0');
   signal dbg_c2v_xor               : std_logic_vector(15 downto 0) := (others => '0');
   -- 2026-07-03 rasterizer non-navy WRITE Y-range (where the title is actually rendered in VRAM)
   signal dbg_minWriteY             : unsigned(9 downto 0) := (others => '1');  -- init 1023
   signal dbg_maxWriteY             : unsigned(9 downto 0) := (others => '0');
   signal dbg_writeYcnt             : unsigned(11 downto 0) := (others => '0');  -- count of non-navy writes (saturating)
   -- 2026-07-03 written-pixel COLOR: is the rasterizer writing colored (title) or just black? BGR555: R=[4:0] G=[9:5] B=[14:10]
   signal dbg_r_seen                : std_logic := '0';  -- any written pixel with R!=0
   signal dbg_g_seen                : std_logic := '0';  -- any written pixel with G!=0
   signal dbg_b_seen                : std_logic := '0';  -- any written pixel with B!=0
   signal dbg_nonblack_seen         : std_logic := '0';  -- any written pixel != 0x0000 and != 0x4000
   -- X/Y range of NONBLACK (colored) writes = where the title colors actually land
   signal dbg_nb_minX               : unsigned(9 downto 0) := (others => '1');
   signal dbg_nb_maxX               : unsigned(9 downto 0) := (others => '0');
   signal dbg_nb_maxY               : unsigned(9 downto 0) := (others => '0');

   signal pipeline_busy             : std_logic;
   signal pipeline_stall            : std_logic;
   signal pipeline_new              : std_logic;
   signal pipeline_texture          : std_logic;
   signal pipeline_transparent      : std_logic;
   signal pipeline_rawTexture       : std_logic;
   signal pipeline_dithering        : std_logic;
   signal pipeline_x                : unsigned(9 downto 0);
   signal pipeline_y                : unsigned(9 downto 0);
   signal pipeline_cr               : unsigned(7 downto 0);
   signal pipeline_cg               : unsigned(7 downto 0);
   signal pipeline_cb               : unsigned(7 downto 0);
   signal pipeline_u                : unsigned(7 downto 0);
   signal pipeline_v                : unsigned(7 downto 0);
   signal pipeline_filter           : std_logic;   
   signal pipeline_u11              : unsigned(7 downto 0);
   signal pipeline_v11              : unsigned(7 downto 0);
   signal pipeline_uAcc             : unsigned(7 downto 0);
   signal pipeline_vAcc             : unsigned(7 downto 0);
   
   signal pipeline_clearCacheTexture: std_logic := '0';
   signal pipeline_clearCachePalette: std_logic := '0';
   
   signal pipeline_textPalNew       : std_logic;
   signal pipeline_textPalX         : unsigned(9 downto 0);
   signal pipeline_textPalY         : unsigned(9 downto 0);

   -- build #114 H1+H2: cube rect path investigation
   signal h12_cube_emit             : std_logic;
   signal h12_red_anchor            : std_logic := '0';
   signal h12_green_dm_ok           : std_logic := '0';
   signal h12_blue_dm_stale         : std_logic := '0';
   signal h12_yellow_busy0          : std_logic := '0';
   signal h12_white_dm_chg          : std_logic := '0';
   signal h12_cyan_emit_busy0       : std_logic := '0';
   signal h12_magenta_busy_long     : std_logic := '0';
   signal h12_drawMode_prev         : unsigned(13 downto 0) := (others => '0');
   signal h12_drawMode_changed      : std_logic;
   signal h12_busy_run_count        : unsigned(15 downto 0) := (others => '0');
   -- build #115: quantify H1 race frequency
   signal h12_stale_count           : unsigned(15 downto 0) := (others => '0');
   signal h12_ok_count              : unsigned(15 downto 0) := (others => '0');
   signal h12_stale_gt_ok_sticky    : std_logic := '0';

   -- build #117: locate G+B stripping point in pixel pipeline
   -- Trigger: pipeline_pixelWrite='1' (i.e. stage6_valid='1') to cube display area
   signal h17_cube_pxwr             : std_logic;
   signal h17_anchor_sticky         : std_logic := '0';  -- cube pixelWrite ever happened
   signal h17_g_sticky              : std_logic := '0';  -- pipeline_pixelColor[9:5] != 0 at trigger
   signal h17_b_sticky              : std_logic := '0';  -- pipeline_pixelColor[14:10] != 0 at trigger

   -- build #119: instrument vram_DIN at cube area writes (downstream of pipelinepixel)
   -- Pivots from pipelinepixel-level (B117) to actual SDRAM write payload.
   -- vram_ADDR encoding: bits 20:11 = Y (10-bit), bits 10:3 = X[9:2] (4-pixel-aligned). X<300 → X[9:2]<75.
   -- vram_DIN is 64-bit = 4 × 16-bit BGR-555 pixels. G bits at [9:5] per lane, B bits at [14:10] per lane.
   signal h19_cube_we               : std_logic;
   signal h19_anchor_sticky         : std_logic := '0';
   signal h19_g_in_din              : std_logic := '0';  -- any of 4 lanes has G bits at trigger
   signal h19_b_in_din              : std_logic := '0';  -- any of 4 lanes has B bits at trigger

   -- build #120: COUNTER-based vram_DIN G+B analysis to distinguish "ratio of G+B writes" vs sticky.
   -- If C_anchor >> C_g/C_b → most cube area writes lack G+B → bug at pixelpipe (cubes are R-only)
   -- If C_anchor ≈ C_g/C_b → most writes have G+B → bug downstream (SDRAM, videoout)
   signal h20_anchor_count          : unsigned(15 downto 0) := (others => '0');
   signal h20_g_count               : unsigned(15 downto 0) := (others => '0');
   signal h20_b_count               : unsigned(15 downto 0) := (others => '0');

   -- build #122: pass-through signals from pixelpipeline's vram_DOUT capture
   signal h22_anchor_sig            : std_logic;
   signal h22_clut3_r_sig           : std_logic_vector(4 downto 0);
   signal h22_clut3_g_sig           : std_logic_vector(4 downto 0);
   -- build #140: CLUT-RAM cube CLUT presence probes
   signal h40_cube_clut_loaded_ever_sig : std_logic;
   signal h40_clut_read_7fff_ever_sig   : std_logic;
   signal h40_clut_read_023f_ever_sig   : std_logic;
   -- build #158
   signal h58_x_stale_seen_sig          : std_logic;
   signal h58_y_stale_seen_sig          : std_logic;
   signal h58_pixel_seen_sig            : std_logic;
   -- build #159
   signal h59_loaded_entry0_lo_sig      : std_logic_vector(8 downto 0);
   signal h59_loaded_y_sig              : std_logic_vector(8 downto 0);
   signal h59_anchor_sig                : std_logic;

   -- build #124: SDRAM round-trip self-test at cube CLUT[3] address (Y=480, X=0..3 lane 3)
   -- Captures the WRITE data at this address (vram_DIN lane 3 R bits)
   -- and the READ data (vram_DOUT lane 3 R bits) when DDR3 returns data after a matching read request.
   -- If write_R != read_R → DDR3 round-trip corrupts data → SDRAM-level bug confirmed.
   signal h24_addr_match            : std_logic;
   signal h24_read_pending          : std_logic := '0';
   signal h24_write_anchor          : std_logic := '0';
   signal h24_write_r               : std_logic_vector(4 downto 0) := (others => '0');
   signal h24_read_anchor           : std_logic := '0';
   signal h24_read_r                : std_logic_vector(4 downto 0) := (others => '0');

   -- build #128: compare cpu2vram_pixelColor (what cpu2vram intends) vs vram_DIN (what reaches SDRAM)
   -- Captures the most recent cpu2vram write to CLUT band with lane-3 address (pixelAddr[2:1]="11")
   -- and the most recent vram_DIN lane 3 R bits at CLUT band write.
   -- If cpu2vram_r differs from vram_din_r → corruption between cpu2vram and vram_DIN pipeline
   -- (pixel64data lane assembly, fifoOut packing, or B109 priority mux interference).
   -- If they match → corruption is upstream of cpu2vram (DMA delivery or CPU RAM).
   signal h28_cpu_addr_match        : std_logic;
   signal h28_vram_addr_match       : std_logic;
   signal h28_cpu_r                 : std_logic_vector(4 downto 0) := (others => '0');
   signal h28_cpu_anchor            : std_logic := '0';
   signal h28_vram_r                : std_logic_vector(4 downto 0) := (others => '0');
   signal h28_vram_anchor           : std_logic := '0';

   -- build #129: capture zn_bank_8mb at cpu2vram CLUT band writes.
   -- Tecmo banking: bank register at 0x1FB00006, 3-bit bank value, ROM mapped at (bank+1)*8MB.
   -- Per MAME: 109 bank switches during cube attract (game code at 0x800504F0 loads assets from banks).
   -- If FPGA's banking is wrong, CPU reads CLUT data from wrong bank → uploads wrong data.
   signal h29_bank_at_cpu_write     : std_logic_vector(2 downto 0) := (others => '0');
   signal h29_bank_anchor           : std_logic := '0';
   signal h29_bank_ever_changed     : std_logic := '0';
   signal h29_bank_prev             : std_logic_vector(2 downto 0) := (others => '0');

   -- build #131: instrument DMA channel 2 delivery (DMA → GPU FIFO).
   -- Each 32-bit DMA word carries 2 PSX pixels (BGR-555): pixel 1 in bits[15:0], pixel 2 in bits[31:16].
   -- R bits per pixel: pixel 1 R = DMA_GPU_write[4:0], pixel 2 R = DMA_GPU_write[20:16].
   -- Non-sticky update for R values; sticky for "rich data ever delivered".
   signal h31_anchor                : std_logic := '0';
   signal h31_pixel1_r              : std_logic_vector(4 downto 0) := (others => '0');
   signal h31_pixel2_r              : std_logic_vector(4 downto 0) := (others => '0');
   signal h31_rich_ever             : std_logic := '0';

   -- build #132: stickys for specific R values ever delivered by DMA.
   -- Tests whether DMA can carry MAME's expected R=31 for cube CLUT entries.
   signal h32_r31_ever              : std_logic := '0';  -- pixel1 or pixel2 ever delivered R=31
   signal h32_r_high_ever           : std_logic := '0';  -- pixel1 or pixel2 ever delivered R>=24 (close to 31)
   signal h32_pixel1_nonzero_ever   : std_logic := '0';  -- pixel1 ever had non-zero R bits (it was always 0 in B131)

   -- build #133: capture fifo_data_1 (cpu2vram's latched upper halfword) vs cpu2vram_pixelColor at cube CLUT writes.
   -- Trigger: cpu2vram_pixelWrite='1' AND pixelAddr Y∈[460,500] AND pixelAddr[2:1]="11" (lane 3 = CLUT[3]).
   -- This is the moment cpu2vram outputs CLUT[3] data. It should be using fifo_data_1 as source.
   -- If fifo_data_1 R=31 but cpu2vram_pixelColor R=0 → pixel-select mux broken.
   -- If fifo_data_1 R=0 → upper halfword latch broken (data lost between fifoIn and the latch).
   signal h33_trigger               : std_logic;
   signal h33_anchor                : std_logic := '0';
   signal h33_fifo_data_1_r         : std_logic_vector(4 downto 0) := (others => '0');
   signal h33_cpu_color_r           : std_logic_vector(4 downto 0) := (others => '0');
   signal h33_fifo_data_1_r31_ever  : std_logic := '0';

   -- build #134: probe fifoIn_Dout directly to compare halfword R bits.
   -- Tests: does R=31 ever reach fifoIn output? Both lower and upper halfword?
   -- If lower=LIT, upper=DARK → upper halfword loses R=31 somewhere
   -- If both=LIT → cpu2vram's latch step has the bug
   -- If both=DARK → fifoIn FIFO IP corrupts ALL R=31 (rare)
   signal h34_lower_r31_ever        : std_logic := '0';
   signal h34_upper_r31_ever        : std_logic := '0';
   signal h34_upper_msb_ever        : std_logic := '0';

   -- FIFO OUT
   signal fifoOut_reset             : std_logic; 
   signal fifoOut_Din               : std_logic_vector(86 downto 0);
   signal fifoOut_Wr                : std_logic;
   signal fifoOut_Wr_1              : std_logic;
   signal fifoOut_NearFull          : std_logic;
   signal fifoOut_Dout              : std_logic_vector(86 downto 0);
   signal fifoOut_Rd                : std_logic;
   signal fifoOut_Empty             : std_logic;
   signal fifoOut_idle              : std_logic;
   
   signal fifoOut2_Din              : std_logic_vector(63 downto 0);
   signal fifoOut2_Dout             : std_logic_vector(63 downto 0);
   signal fifoOut2_Dout_1           : std_logic_vector(63 downto 0);
   
   -- vram access
   type tvramState is
   (
      IDLE,
      WRITESECOND,
      READSECOND,
      READVRAM,
      CLEARLINESTART,
      CLEARLINE
   );
   signal vramState : tvramState := IDLE;
   signal dbg_vram_st3 : std_logic_vector(2 downto 0);
   signal dbg_cmd : std_logic_vector(7 downto 0) := (others => '0');
   signal poly_dbg_state : std_logic_vector(4 downto 0);
   signal poly_dbg_v0 : std_logic_vector(31 downto 0);
   signal poly_dbg_v2 : std_logic_vector(31 downto 0);
   signal dbg_gp105_raw : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_e5_raw    : std_logic_vector(31 downto 0) := (others => '0');
   signal cpu2vram_copysize : std_logic_vector(31 downto 0) := (others => '0');
   signal cpu2vram_copydst  : std_logic_vector(31 downto 0) := (others => '0');
   
   signal VRAMIdle                  : std_logic;
   signal reqVRAMIdle               : std_logic;
   signal reqVRAMDone               : std_logic;
   signal vram_pauseCnt             : integer range 0 to 3;
   
   signal reqVRAMEnable             : std_logic;
   signal reqVRAMXPos               : unsigned(9 downto 0);
   signal reqVRAMYPos               : unsigned(9 downto 0);
   signal reqVRAMSize               : unsigned(10 downto 0);
   signal reqVRAMremain             : unsigned(7 downto 0);
   signal reqVRAMremain2            : unsigned(7 downto 0);
   signal reqVRAMwait               : unsigned(7 downto 0);
   signal reqVRAMwrap               : unsigned(7 downto 0);
   signal reqVRAMnext               : unsigned(7 downto 0);
   signal reqVRAMaddr               : unsigned(7 downto 0) := (others => '0');
   signal reqVRAMaddr2              : unsigned(7 downto 0) := (others => '0');
   signal reqVRAMStore              : std_logic := '0';        
   signal reqVRAMStore2             : std_logic := '0';        
   signal reqVRAMtwice              : std_logic := '0';        
   
   signal vramLineAddr              : unsigned(9 downto 0);
   
   signal vramLineData              : std_logic_vector(15 downto 0);
   signal vramLineData2             : std_logic_vector(15 downto 0);
   
   -- build #39: latch zn_bank_8mb value at the moment cpu2vram writes to the FAILED palette region (X<256, Y=488).
   --  Tests whether the Tecmo bank register is in the correct state (bank=0 for lpadv's rp00 green palette)
   --  during the upload that build #38 showed delivers RED instead of GREEN.
   -- build #44 proved cpu2vram OUTPUT (pixelColor) is RED at the cube gate (X<256, Y=488).
   -- build #45: re-latch these from the cpu2vram INPUT classification (dbg_cube_in_* from
   -- gpu_cpu2vram) to split read-path vs cpu2vram: INPUT red => pass-through (bug upstream
   -- of FIFO: DMA/RAM/read); INPUT green => cpu2vram corrupts green->red.
   signal cube488_green_seen : std_logic := '0';  -- cpu2vram INPUT pure-green at cube gate -> GREEN bar
   signal cube488_red_seen   : std_logic := '0';  -- cpu2vram INPUT pure-red   at cube gate -> YELLOW bar
   signal cube488_any_seen   : std_logic := '0';  -- any pixel written at (X<256,Y=488) (sanity) -> WHITE bar

   -- videoout
   signal videoout_reqVRAMEnable    : std_logic;
   signal videoout_reqRAMMirror     : std_logic;
   signal videoout_reqVRAMXPos      : unsigned(9 downto 0);
   signal videoout_reqVRAMYPos      : unsigned(9 downto 0);  -- 10-bit: full 2MB VRAM Y readback
   signal videoout_reqVRAMSize      : unsigned(10 downto 0);
   
   -- direct framebuffer mode
   signal frameindex_current        : unsigned(1 downto 0) := (others => '0');
   signal frameindex_last           : unsigned(1 downto 0) := (others => '0');
   signal irq_VBLANK_1              : std_logic := '0';
   signal poly_requestFifo_1        : std_logic := '0';
   signal frameWriteCount           : integer := 0;
   signal framePolyCount            : integer range 0 to 16777215 := 0;
   signal frameFastCount            : integer range 0 to 3 := 0;
   signal frameFastmode             : std_logic := '0';
   signal frameVramType             : std_logic := '0';
   signal frameFirstChangedLine     : unsigned(8 downto 0) := (others => '0');
   signal frameLastChangedLine      : unsigned(8 downto 0) := (others => '0');
   
   signal frameClearRequest         : std_logic := '0';
   signal frameClearYPos            : unsigned(8 downto 0) := (others => '0');
   signal frameClearCnt             : unsigned(8 downto 0) := (others => '0');
   signal frameClearPosLow          : unsigned(8 downto 0) := (others => '0');
   signal frameClearPosHigh         : unsigned(8 downto 0) := (others => '0');
   signal frameClearXPos            : unsigned(9 downto 0) := (others => '0');
   
   -- fps counter
   signal fpscountBCD               : unsigned(7 downto 0) := (others => '0');
   signal fpscountBCD_next          : unsigned(7 downto 0) := (others => '0');
   signal fps_SecondCounter         : integer range 0 to 33868799 := 0;
   signal fps_vramRange_last        : unsigned(19 downto 0) := (others => '0');
   
   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0);
   signal ss_gpu_in     : t_ssarray := (others => (others => '0'));
   signal ss_timing_in  : t_ssarray := (others => (others => '0'));   
   signal ss_gpu_out    : t_ssarray := (others => (others => '0'));
   signal ss_timing_out : t_ssarray := (others => (others => '0'));
   
   signal videoout_ss_in  : tvideoout_ss;
   signal videoout_ss_out : tvideoout_ss;
   
begin 

-- synthesis translate_off
   export_gtm  <= unsigned(videoout_ss_out.nextHCount);
   export_line <= "000" & unsigned(videoout_ss_out.vpos);
   export_gpus <= unsigned(GPUSTAT);
-- synthesis translate_on
   
   gpu_dmaRequest <= GPUSTAT_DMADataRequest;

   GPUSTAT(3 downto 0)     <= GPUSTAT_TextPageX;
   GPUSTAT(4)              <= GPUSTAT_TextPageY;
   GPUSTAT(6 downto 5)     <= GPUSTAT_Transparency;
   GPUSTAT(8 downto 7)     <= GPUSTAT_TextPageColors;
   GPUSTAT(9)              <= GPUSTAT_Dither;
   GPUSTAT(10)             <= GPUSTAT_DrawToDisplay;
   -- gputype1: bits 11/12 are the REFLECTED tpage/E6 bits (status only, no enforcement — see E1 fix)
   GPUSTAT(11)             <= t1_status11 when (gpuType1 = '1') else GPUSTAT_SetMask;
   GPUSTAT(12)             <= t1_status12 when (gpuType1 = '1') else GPUSTAT_DrawPixelsMask;
   GPUSTAT(13)             <= not videoout_reports.GPUSTAT_InterlaceField;
   GPUSTAT(14)             <= GPUSTAT_ReverseFlag;
   GPUSTAT(15)             <= GPUSTAT_TextureDisable;
   GPUSTAT(16)             <= GPUSTAT_HorRes2;
   GPUSTAT(18 downto 17)   <= GPUSTAT_HorRes1;
   GPUSTAT(19)             <= GPUSTAT_VerRes;
   GPUSTAT(20)             <= GPUSTAT_PalVideoMode;
   GPUSTAT(21)             <= GPUSTAT_ColorDepth24;
   GPUSTAT(22)             <= GPUSTAT_VertInterlace;
   GPUSTAT(23)             <= GPUSTAT_DisplayDisable;
   GPUSTAT(24)             <= GPUSTAT_IRQRequest;
   GPUSTAT(25)             <= GPUSTAT_DMADataRequest;
   -- ★ 2026-07-05 READY FIX part 2 (gputype1): MAME NEVER clears GPUSTAT bit26 (init 0x14802000,
   -- no writer touches it). Tekken's PIO upload/command loop polls bit26 per strip; the retail
   -- semantics (0 while a command renders) throttled it to ~60 words/s — the intro-movie textures
   -- never arrived. gputype1 reports "ready" whenever the command fifo has room (not NearFull),
   -- exactly matching the always-ready behavior the game was written against.
   GPUSTAT(26)             <= (not fifoIn_NearFull) when (gpuType1 = '1') else
                              (GPUSTAT_ReadyRecCmd and ((not gpu_dmaRequest) or (not DMA_GPU_waiting)));
   GPUSTAT(27)             <= GPUSTAT_ReadySendVRAM;
   GPUSTAT(28)             <= GPUSTAT_ReadyRecDMA;
   GPUSTAT(30 downto 29)   <= GPUSTAT_DMADirection;
   GPUSTAT(31)             <= videoout_reports.GPUSTAT_DrawingOddline;
   gpustat31_out           <= videoout_reports.GPUSTAT_DrawingOddline;  -- build #169
   gpustat_out             <= GPUSTAT;             -- S11 GPU-hang diagnostic: full status
   fifoIn_empty_out        <= fifoIn_Empty;        -- S11 GPU-hang diagnostic: input-FIFO empty
   drawingAreaBottom_out   <= std_logic_vector(drawingAreaBottom);     -- build #172
   drawingOffsetY_out      <= std_logic_vector(drawingOffsetY);        -- build #172

   GPUSTAT_DMADataRequest <= '0' when (GPUSTAT_DMADirection = "00") else
                             GPUSTAT_ReadyRecDMA when (GPUSTAT_DMADirection = "01") else
                             GPUSTAT_ReadyRecDMA when (GPUSTAT_DMADirection = "10") else
                             not vram2cpu_Fifo_Empty; -- GPUSTAT_ReadySendVRAM cannot be used, because data is read earlier                

   -- video out
   irq_VBLANK             <= videoout_reports.irq_VBLANK;
   hblank_tmr             <= videoout_reports.hblank_tmr;

   -- savestates

   ss_gpu_out(0)  <= GPUREAD;                
   ss_gpu_out(1)  <= GPUSTAT;                

   ss_timing_out(4)(19)            <= videoout_ss_out.interlacedDisplayField;
   ss_timing_out(2)(19 downto 0)   <= std_logic_vector(vramRange);
   ss_timing_out(1)(23 downto 0)   <= std_logic_vector(hDisplayRange);
   ss_timing_out(0)(19 downto 0)   <= std_logic_vector(vDisplayRange);
   ss_timing_out(4)(11 downto 0)   <= videoout_ss_out.nextHCount;
   ss_timing_out(3)(24 downto 16)  <= videoout_ss_out.vpos;      
   ss_timing_out(4)(17)            <= videoout_ss_out.inVsync;      
   ss_timing_out(4)(20)            <= videoout_ss_out.activeLineLSB;
   ss_timing_out(4)(29 downto 21)  <= videoout_ss_out.vdisp;

   process (clk1x)
      variable cmdNew           : unsigned(7 downto 0);
      variable frameWriteLineY  : unsigned(8 downto 0);    
   begin
      if rising_edge(clk1x) then
      
         fifoIn_reset  <= '0';
         fifoOut_reset <= '0';
         
         drawer_reset  <= '0';
         
         vblank_tmr <= videoout_reports.inVsync;

         if (reset = '1') then
               
            softReset               <= not loading_savestate;
            bus_stall               <= '0';
            
            fifoIn_reset            <= '1';
            fifoOut_reset           <= '1';
            
            vramRange               <= unsigned(ss_timing_in(2)(19 downto 0));
            hDisplayRange           <= unsigned(ss_timing_in(1)(23 downto 0)); -- x"C60260";
            vDisplayRange           <= unsigned(ss_timing_in(0)(19 downto 0)); -- x"3FC10";
      
            GPUSTAT_ReverseFlag     <= ss_gpu_in(1)(14);
            GPUSTAT_HorRes2         <= ss_gpu_in(1)(16);
            GPUSTAT_HorRes1         <= ss_gpu_in(1)(18 downto 17);
            GPUSTAT_VerRes          <= ss_gpu_in(1)(19);
            GPUSTAT_PalVideoMode    <= ss_gpu_in(1)(20); --isPal;
            GPUSTAT_ColorDepth24    <= ss_gpu_in(1)(21);
            GPUSTAT_VertInterlace   <= ss_gpu_in(1)(22);
            GPUSTAT_DisplayDisable  <= ss_gpu_in(1)(23);
            GPUSTAT_IRQRequest      <= ss_gpu_in(1)(24);
            GPUSTAT_DMADirection    <= ss_gpu_in(1)(30 downto 29);
            GPUREAD                 <= ss_gpu_in(0);       
            
            fpscountBCD_next        <= (others => '0');
            
            frameFastCount          <= 0;
            frameFastmode           <= '0';

         elsif (ce = '1') then
         
            bus_dataRead <= (others => '0');
            softReset    <= '0';
            
            -- bus read
            if (bus_read = '1') then
               if (bus_addr(3 downto 2) = "00") then
               
                  if (vram2cpu_Fifo_Empty = '0') then
                     bus_dataRead <= vram2cpu_Fifo_Dout;
                     GPUREAD      <= vram2cpu_Fifo_Dout;
                  else
                     bus_dataRead <= GPUREAD;
                  end if;
                  
                  if (vram2cpu_Fifo_ready = '0') then
                     bus_stall <= '1';
                  end if;
                  
               elsif (bus_addr(3 downto 2) = "01") then
                  bus_dataRead <= GPUSTAT;
               else
                  bus_dataRead <= x"FFFFFFFF";
               end if;
            end if;
            
            if (bus_stall = '1' and vram2cpu_Fifo_ready = '1') then
               bus_dataRead <= vram2cpu_Fifo_Dout;
               GPUREAD      <= vram2cpu_Fifo_Dout;
               bus_stall    <= '0';
            end if;

            -- bus write
            if (bus_write = '1') then
            
               if (bus_addr = 4) then
                  
                  case (to_integer(unsigned(bus_dataWrite(29 downto 24)))) is
                     when 16#00# => -- reset
                        softReset    <= '1';
                        fifoIn_reset <= '1'; 
                        
                     when 16#01# => -- clear fifo
                        -- gputype1 (System 11 CXD8538Q): MAME treats GP1(01) as a packet-framing
                        -- reset ONLY (n_gpu_buffer_offset=0) — queued/in-progress work is NOT
                        -- destroyed, and Tekken sends GP1(01) every frame while the (slower) FPGA
                        -- renderer is still busy. Flushing the fifo + killing the drawer here
                        -- discards nearly every queued draw -> almost no VRAM writes -> noise.
                        -- Keep the destructive semantics for retail PSX (ridge racer needs the
                        -- mid-rectangle cancel), skip them for gputype1.
                        if (gpuType1 = '0') then
                           fifoIn_reset <= '1';
                           drawer_reset <= '1';
                        end if;
                        -- todo: must reset drawing units to idle? -> ridge racer triggers that in the middle of a rectangle command clearing the screen
                        -- reset CLUT cache?
                        
                     when 16#02# => -- ack irq
                        GPUSTAT_IRQRequest <= '0';
                        
                     when 16#03# => -- display on/off
                        GPUSTAT_DisplayDisable <= bus_dataWrite(0);
                        
                     when 16#04# => -- DMA direction
                        GPUSTAT_DMADirection <= bus_dataWrite(1 downto 0);
                        
                     when 16#05# => -- Start of Display area (in VRAM)
                        -- DisplayOffsetX = vramRange(9:0), DisplayOffsetY = vramRange(18:10).
                        -- gputype1 (System 11 CXD8538Q): display-start Y is at bits 21:12 (vs 19:10).
                        -- Repack so Y(bits 20:12) lands in vramRange(18:10); X (bits 9:1) unchanged.
                        if (gpuType1 = '1') then
                           vramRange <= '0' & unsigned(bus_dataWrite(20 downto 12)) & unsigned(bus_dataWrite(9 downto 1)) & '0';
                        else
                           vramRange <= unsigned(bus_dataWrite(19 downto 1)) & '0';
                        end if;
                        dbg_gp105_raw <= gpuType1 & "0000000" & std_logic_vector(bus_dataWrite(23 downto 0));

                     when 16#06# => -- horizontal diplay range
                        hDisplayRange <= unsigned(bus_dataWrite(23 downto 0));
                        
                     when 16#07# => -- vertical diplay range
                        vDisplayRange <= unsigned(bus_dataWrite(19 downto 0));
                        
                     when 16#08# => -- Set display mode
                        GPUSTAT_HorRes1       <= bus_dataWrite(1 downto 0);
                        GPUSTAT_VerRes        <= bus_dataWrite(2);
                        GPUSTAT_PalVideoMode  <= bus_dataWrite(3);
                        GPUSTAT_ColorDepth24  <= bus_dataWrite(4);
                        GPUSTAT_VertInterlace <= bus_dataWrite(5);
                        GPUSTAT_HorRes2       <= bus_dataWrite(6);
                        GPUSTAT_ReverseFlag   <= bus_dataWrite(7);
                        
                     when 16#09# => -- Allow texture disable
                        -- todo
                          
                     when 16#10# | 16#11# | 16#12# | 16#13# | 16#14# | 16#15# | 16#16# | 16#17# | 16#18# | 16#19# | 16#1A# | 16#1B# | 16#1C# | 16#1D# | 16#1E# | 16#1F# => -- GPUInfo
                        case (to_integer(unsigned(bus_dataWrite(2 downto 0)))) is
                           when 2 => --Get Texture Window
                              GPUREAD <= x"000" & std_logic_vector(textureWindow);
                           
                           when 3 => --Get Draw Area Top Left. gputype1: Y at bits 21:12 (vs retail 19:10).
                              if (gpuType1 = '1') then GPUREAD <= "0000000000" & std_logic_vector(drawingAreaTop) & "00" & std_logic_vector(drawingAreaLeft);
                              else                     GPUREAD <= x"000" & std_logic_vector(drawingAreaTop) & std_logic_vector(drawingAreaLeft); end if;

                           when 4 => --Get Draw Area Bottom Right. gputype1: Y at bits 21:12.
                              if (gpuType1 = '1') then GPUREAD <= "0000000000" & std_logic_vector(drawingAreaBottom) & "00" & std_logic_vector(drawingAreaRight);
                              else                     GPUREAD <= x"000" & std_logic_vector(drawingAreaBottom) & std_logic_vector(drawingAreaRight); end if;

                           when 5 => --Get Drawing Offset. gputype1: Y at bits 22:12 (vs retail 21:11).
                              if (gpuType1 = '1') then GPUREAD <= "000000000" & std_logic_vector(drawingOffsetY) & "0" & std_logic_vector(drawingOffsetX);
                              else                     GPUREAD <= x"00" & "00" & std_logic_vector(drawingOffsetY) & std_logic_vector(drawingOffsetX); end if;

                           when 7 => --Get GPU Type/Version. 2026-06-28: was MISSING (fell to null -> stale
                              -- GPUREAD), so the game mis-detected the GPU and used RETAIL coord shifts (10)
                              -- instead of gputype1 (12) -> display-start Y=60 vs 240 -> broken doublebuffer.
                              -- CXD8538Q (System 11) = MAME gputype 1; retail = 2.
                              if (gpuType1 = '1') then GPUREAD <= x"00000001"; else GPUREAD <= x"00000002"; end if;

                           when others => null;
                        end case;
                     
                     when others => report "GP1 Command not implemented" severity failure; 
                  end case;
               
               end if;
            
            end if;
            
            if (irq_GPU = '1') then
               GPUSTAT_IRQRequest <= '1';
            end if;
            
            -- 480i framebuffer logic
            frameWriteLineY := unsigned(vram_ADDR(19 downto 11)) - videoout_out.DisplayOffsetY;

            if (vram_we = '1' and frameVramType = '1') then
               if (unsigned(vram_ADDR(19 downto 11)) >= videoout_out.DisplayOffsetY) then
                  if (unsigned(vram_ADDR(19 downto 11)) < (videoout_out.DisplayOffsetY + videoout_out.DisplayHeightReal)) then
                     
                     if (frameWriteLineY < frameFirstChangedLine) then
                        frameFirstChangedLine <= frameWriteLineY;
                     end if;
                     
                     if (frameWriteLineY > frameLastChangedLine) then
                        frameLastChangedLine <= frameWriteLineY;
                     end if;
                  
                     if (unsigned(vram_ADDR(10 downto 1)) >= videoout_out.DisplayOffsetX) then
                        if (unsigned(vram_ADDR(10 downto 1)) < (videoout_out.DisplayOffsetX + videoout_out.DisplayWidthReal)) then
                           frameWriteCount <= frameWriteCount + 1;
                        end if;
                     end if;
                  
                  end if;
               end if;

            end if;
            
            poly_requestFifo_1 <= poly_requestFifo;
            if (poly_requestFifo_1 = '0' and poly_requestFifo = '1') then
               framePolyCount <= framePolyCount + 1;
            end if;

            irq_VBLANK_1 <= videoout_reports.irq_VBLANK;
            if (videoout_reports.irq_VBLANK = '1' and irq_VBLANK_1 = '0') then
               frameFastmode    <= '0';
               frameWriteCount  <= 0;
               framePolyCount   <= 0;
               frameFirstChangedLine <= (others => '1');
               frameLastChangedLine  <= (others => '0');
               if (GPUSTAT_VertInterlace = '1' and GPUSTAT_VerRes = '1') then
                  -- condition to allow 480p hack: game is in 480i mode and draws most of the screen every frame
                  if (frameWriteCount > 40000 and framePolyCount > 31 and frameFirstChangedLine < 40 and (videoout_out.DisplayHeightReal - frameLastChangedLine) < 30) then 
                     if (frameFastCount < 3) then
                        frameFastCount <= frameFastCount + 1;
                     else
                        frameFastmode <= interlaced480pHack;
                     end if;
                     frameindex_last <= frameindex_current;
                     if (frameindex_current = 2) then
                        frameindex_current <= (others => '0');
                     else
                        frameindex_current <= frameindex_current + 1;
                     end if;
                  end if;
               else
                  frameFastCount <= 0;
                  frameFastmode  <= '0';
               end if;
            end if;
            
            -- fps counter
            if (videoout_reports.irq_VBLANK = '1') then
               fps_vramRange_last <= vramRange;
               if (vramRange /= fps_vramRange_last) then
                  if (fpscountBCD_next(3 downto 0) = x"9") then
                     fpscountBCD_next(7 downto 4) <= fpscountBCD_next(7 downto 4) + 1;
                     fpscountBCD_next(3 downto 0) <= x"0";
                  else
                     fpscountBCD_next(3 downto 0) <= fpscountBCD_next(3 downto 0) + 1;
                  end if;
               end if;
            end if;
            
            if (fps_SecondCounter = 33868799) then
               fps_SecondCounter <= 0;
               fpscountBCD       <= fpscountBCD_next;
               fpscountBCD_next  <= (others => '0');       
            else
               fps_SecondCounter <= fps_SecondCounter + 1;            
            end if;

            -- softreset
            if (softReset = '1') then
               vramRange              <= (others => '0');
               hDisplayRange          <= x"C60260";
               vDisplayRange          <= x"3FC10";
                     
               GPUSTAT_ReverseFlag    <= '0';
               GPUSTAT_HorRes2        <= '0';
               GPUSTAT_HorRes1        <= "00";
               GPUSTAT_VerRes         <= '0';
               GPUSTAT_PalVideoMode   <= isPal;
               GPUSTAT_ColorDepth24   <= '0';
               GPUSTAT_VertInterlace  <= '0';
               GPUSTAT_DisplayDisable <= '1';
               GPUSTAT_IRQRequest     <= '0';
               GPUSTAT_DMADirection   <= "00";

            end if;

         end if;
      end if;
   end process;
   
   video_fbmode <= frameFastmode;
   video_fb24   <= frameFastmode and GPUSTAT_ColorDepth24;
   
   iSyncFifo_IN: entity mem.SyncFifo
   generic map
   (
      --SIZE             => 32, -- 16 is correct, but only allows 15 entries -> use nearfull or allow this big for broken homebrew -> some games seem to exceed it also with DMA, how is that possible?
      -- 2026-07-11 note: 4096 was tried for the T2 texture-corruption overflow theory but BOTH seeds
      -- nofit, and MAME BCR ground truth (16-word DMA blocks vs 240-word request margin) makes
      -- overflow implausible anyway. Kept at 256; errfifo_sticky (JTAG mode 7 bit3) monitors overflow.
      SIZE             => 256,
      DATAWIDTH        => 32,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoIn_reset,  
      Din      => fifoIn_Din,     
      Wr       => fifoIn_Wr,      
      Full     => ERRORFIFO,
      NearFull => fifoIn_NearFull,
      Dout     => fifoIn_Dout,
      Rd       => fifoIn_Rd,
      Empty    => fifoIn_Empty
   );
   
   fifoIn_Rd <= '1' when (ce = '1' and (proc_idle = '1' or proc_requestFifo = '1') and pipeline_busy = '0' and fifoIn_Empty = '0' and fifoIn_Valid = '0' and (clk2xIndex = '0' or REPRODUCIBLEGPUTIMING = '0')) else '0';
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         if (reset = '1') then
            
         elsif (ce = '1') then
         
            fifoIn_Wr  <= '0';

            -- ★ 2026-07-06 COLLISION FIX: a PIO GP0 write and a DMA word can arrive in the
            -- SAME clk1x cycle (the CPU runs on while DMA2 streams autonomously — Tekken's
            -- hybrid uploads send each A0 header via PIO and the pixel body via DMA, back to
            -- back). The old code let the DMA assignment OVERWRITE the PIO word -> one word
            -- silently lost -> GP0 parser desync -> whole upload batches scrambled/vanished
            -- (attract texture noise). The colliding DMA word belongs to the PREVIOUS
            -- transfer's tail, so it is logically older: enqueue DMA now, defer the PIO word
            -- to the free clk2xIndex='0' slot of the same clk1x cycle (fifo is clk2x).
            if (clk2xIndex = '1' and bus_write = '1' and bus_addr = 0) then
               if (DMA_GPU_writeEna = '1') then
                  fifoInPio_pend <= '1';
                  fifoInPio_data <= bus_dataWrite;
               else
                  fifoIn_Wr  <= '1';
                  fifoIn_Din <= bus_dataWrite;
               end if;
            end if;

            if (clk2xIndex = '1' and DMA_GPU_writeEna = '1') then
               fifoIn_Wr  <= '1';
               fifoIn_Din <= DMA_GPU_write;
            end if;

            if (clk2xIndex = '0' and fifoInPio_pend = '1') then
               fifoIn_Wr      <= '1';
               fifoIn_Din     <= fifoInPio_data;
               fifoInPio_pend <= '0';
            end if;
            
         end if;

      end if;
   end process;

   ss_gpu_out(2)(19 downto 0)   <= std_logic_vector(textureWindow);
   ss_gpu_out(4)(9 downto 0)    <= std_logic_vector(drawingAreaLeft);  
   ss_gpu_out(5)(9 downto 0)    <= std_logic_vector(drawingAreaRight); 
   ss_gpu_out(4)(25 downto 16)  <= std_logic_vector(drawingAreaTop);
   ss_gpu_out(5)(25 downto 16)  <= std_logic_vector(drawingAreaBottom);
   ss_gpu_out(6)(10 downto 0)   <= std_logic_vector(drawingOffsetX);   
   ss_gpu_out(6)(26 downto 16)  <= std_logic_vector(drawingOffsetY);   
   ss_gpu_out(3)(13 downto 0)   <= std_logic_vector(drawMode);         
   ss_gpu_out(3)(16)            <= GPUSTAT_DrawPixelsMask;         
   ss_gpu_out(3)(17)            <= GPUSTAT_TextureDisable;         
   
   process (clk2x)
      variable cmdNew : unsigned(7 downto 0);
   begin
      if rising_edge(clk2x) then
      
         textureWindow_AND_X     <= not (textureWindow(4 downto 0) & "000");
         textureWindow_AND_Y     <= not (textureWindow(9 downto 5) & "000");            
         textureWindow_OR_X      <= (textureWindow(4 downto 0) and textureWindow(14 downto 10)) & "000";
         textureWindow_OR_Y      <= (textureWindow(9 downto 5) and textureWindow(19 downto 15)) & "000";
      
         errorGPU <= '0';
         if (proc_idle = '1') then
            timeout <= 0;
         elsif (timeout < 67108863) then
            timeout  <= timeout + 1;
         else
            errorGPU <= '1';
         end if;
      
         if (reset = '1') then
         
            proc_idle <= '1';
            
            textureWindow           <= unsigned(ss_gpu_in(2)(19 downto 0));   
            
            drawingAreaLeft         <= unsigned(ss_gpu_in(4)(9 downto 0)); 
            drawingAreaRight        <= unsigned(ss_gpu_in(5)(9 downto 0)); 
            drawingAreaTop          <= unsigned(ss_gpu_in(4)(25 downto 16));
            drawingAreaBottom       <= unsigned(ss_gpu_in(5)(25 downto 16));
            drawingOffsetX          <= signed(ss_gpu_in(6)(10 downto 0)); 
            drawingOffsetY          <= signed(ss_gpu_in(6)(26 downto 16)); 
            
            drawMode                <= unsigned(ss_gpu_in(3)(13 downto 0));  
            
            --GPUSTAT_DrawPixelsMask  <= ss_gpu_in(3)(16);
            --GPUSTAT_TextureDisable  <= ss_gpu_in(3)(17);
            
            GPUSTAT_TextPageX       <= ss_gpu_in(1)(3 downto 0);
            GPUSTAT_TextPageY       <= ss_gpu_in(1)(4);
            GPUSTAT_Transparency    <= ss_gpu_in(1)(6 downto 5);
            GPUSTAT_TextPageColors  <= ss_gpu_in(1)(8 downto 7);
            GPUSTAT_Dither          <= ss_gpu_in(1)(9);
            GPUSTAT_DrawToDisplay   <= ss_gpu_in(1)(10);
            GPUSTAT_SetMask         <= ss_gpu_in(1)(11);
            GPUSTAT_DrawPixelsMask  <= ss_gpu_in(1)(12);
            GPUSTAT_TextureDisable  <= ss_gpu_in(1)(15);
            GPUSTAT_ReadyRecCmd     <= '1'; --ss_gpu_in(1)(26); -- in savestate should never be busy
            GPUSTAT_ReadyRecDMA     <= '1'; --ss_gpu_in(1)(28);
            
            fifoIn_Valid            <= '0';
            
         elsif (ce = '1') then
         
            fifoIn_Valid <= fifoIn_Rd and not fifoIn_reset;
            
            pipeline_clearCacheTexture <= '0';
            pipeline_clearCachePalette <= '0';
         
            if (poly_drawModeNew = '1') then
               if (gpuType1 = '1') then -- remap gputype1 polygon tpage into canonical drawMode (see E1 above)
                  drawMode(3 downto 0) <= poly_drawModeRec(3 downto 0);
                  drawMode(4)          <= poly_drawModeRec(5);
                  drawMode(6 downto 5) <= poly_drawModeRec(8 downto 7);
                  drawMode(8 downto 7) <= poly_drawModeRec(10 downto 9);
                  drawMode(11)         <= poly_drawModeRec(6);
                  -- 2026-07-06 INTERLEAVED-TEXTURE FIX: tpage bit13 = ti (CXD8538Q swizzled
                  -- texture mode; MAME n_ti). Tekken sets it on ALL fighter texpages - linear
                  -- sampling of the swizzled data was the in-fight texture striping.
                  drawMode(13)         <= poly_drawModeRec(13);
               else
                  drawMode(8 downto 0) <= poly_drawModeRec(8 downto 0);
                  drawMode(11)         <= poly_drawModeRec(11);
               end if;
            end if;
            
            if (clk2xIndex = '1') then
               irq_GPU <= '0';
            end if;
         
            if (fifoIn_Valid = '1' and proc_idle = '1') then

               cmdNew := unsigned(fifoIn_Dout(31 downto 24));
-- synthesis translate_off
               report "GP0DISPATCH " & to_hstring(fifoIn_Dout);
-- synthesis translate_on

               if ((cmdNew >= 16#20# and cmdNew <=16#DF#) or cmdNew = 16#02#) then

                  proc_idle           <= '0';
                  GPUSTAT_ReadyRecCmd <= '0';
                  dbg_cmd             <= std_logic_vector(cmdNew);  -- 2026-06-27: latch the command the GPU dispatches
                  
               elsif (cmdNew = 16#01#) then -- clear cache
                  pipeline_clearCacheTexture <= '1';
                  pipeline_clearCachePalette <= '1';
                  
               elsif (cmdNew = 16#1F#) then -- irq request
                  if (GPUSTAT_IRQRequest = '0') then
                     irq_GPU <= '1';
                  end if;
                  
               elsif (cmdNew = 16#E1#) then -- Draw Mode setting
                  -- GPU-type-dependent tpage field layout (MAME decode_tpage, psx.cpp:824).
                  -- gputype2/CXD8561Q (retail): tx=b0-3, ty=b4, abr=b5-6, tp=b7-8, dith=b9,
                  --   draw2disp=b10, texdis=b11; bits 11,12 left to the E6 mask command.
                  -- gputype1/CXD8538Q (System 11): GPUSTAT[12:0]=tpage[12:0]; tx=b0-3, ty=b5-6
                  --   (2-bit Y base), abr=b7-8, tp=b9-10. Boot GPU-type probe (@0x8004DA04) writes
                  --   E1 with bit12 and tests GPUSTAT bit12 -> selects gputype1 (shift-12 coords)
                  --   vs retail (shift-10). Sampler reads canonical drawMode: X=b3:0*64,
                  --   Y=drawMode(11)&drawMode(4)*256, abr=b6:5, depth=b8:7 -> remap gputype1 fields.
                  if (gpuType1 = '1') then
                     GPUSTAT_TextPageX      <= fifoIn_Dout(3 downto 0);
                     GPUSTAT_TextPageY      <= fifoIn_Dout(5);
                     GPUSTAT_Transparency   <= fifoIn_Dout(8 downto 7);
                     GPUSTAT_TextPageColors <= fifoIn_Dout(10 downto 9);
                     GPUSTAT_Dither         <= '0';
                     GPUSTAT_DrawToDisplay  <= '0';
                     GPUSTAT_TextureDisable <= '0';
                     -- ★ 2026-07-05 MASK FIX (MAME ground truth, decode_tpage gputype1): E1 bits
                     -- 11/12 are REFLECTED in GPUSTAT (gpustatus = tpage & 0x1fff — the game's
                     -- gputype probe reads bit12 back) but have NO mask semantics (bit12 is even
                     -- flagged "not handled" by MAME's ~0x27ef check). The old mapping wired
                     -- bit12 -> DrawPixelsMask; Tekken draws with E1=0x001000 (bit12 SET) always,
                     -- which force-enabled check-mask + dest-line pre-reads: rendering crawled,
                     -- fifoIn backed up, the game's PIO texture uploads overran the fifo and were
                     -- silently dropped -> texture pages stayed uninitialized -> screen = noise.
                     -- Masking on gputype1 is owned by GP0(E6) alone (Tekken sends E6=0 always).
                     t1_status11            <= fifoIn_Dout(11);
                     t1_status12            <= fifoIn_Dout(12);
                     drawMode(3 downto 0)   <= unsigned(fifoIn_Dout(3 downto 0));
                     drawMode(4)            <= fifoIn_Dout(5);
                     drawMode(6 downto 5)   <= unsigned(fifoIn_Dout(8 downto 7));
                     drawMode(8 downto 7)   <= unsigned(fifoIn_Dout(10 downto 9));
                     drawMode(9)            <= '0';
                     drawMode(10)           <= '0';
                     drawMode(11)           <= fifoIn_Dout(6);
                     drawMode(12)           <= '0';
                     drawMode(13)           <= fifoIn_Dout(13);  -- ti: interleaved texture (see poly remap)
                  else
                     GPUSTAT_TextPageX      <= fifoIn_Dout(3 downto 0);
                     GPUSTAT_TextPageY      <= fifoIn_Dout(4);
                     GPUSTAT_Transparency   <= fifoIn_Dout(6 downto 5);
                     GPUSTAT_TextPageColors <= fifoIn_Dout(8 downto 7);
                     GPUSTAT_Dither         <= fifoIn_Dout(9);
                     GPUSTAT_DrawToDisplay  <= fifoIn_Dout(10);
                     GPUSTAT_TextureDisable <= fifoIn_Dout(11);
                     drawMode               <= unsigned(fifoIn_Dout(13 downto 0));
                  end if;
                  
               elsif (cmdNew = 16#E2#) then -- Set Texture window
                  textureWindow <= unsigned(fifoIn_Dout(19 downto 0));
                  
               elsif (cmdNew = 16#E3#) then -- Set Drawing Area top left (X1,Y1)
                  drawingAreaLeft <= unsigned(fifoIn_Dout(9 downto 0));
                  if (gpuType1 = '1') then drawingAreaTop <= unsigned(fifoIn_Dout(21 downto 12)); -- gputype1: Y at bits 21:12
                  else                     drawingAreaTop <= unsigned(fifoIn_Dout(19 downto 10)); end if;

               elsif (cmdNew = 16#E4#) then -- Set Drawing Area bottom right (X2,Y2)
                  drawingAreaRight  <= unsigned(fifoIn_Dout(9 downto 0));
                  if (gpuType1 = '1') then drawingAreaBottom <= unsigned(fifoIn_Dout(21 downto 12)); -- gputype1: Y at bits 21:12
                  else                     drawingAreaBottom <= unsigned(fifoIn_Dout(19 downto 10)); end if;
                  
               elsif (cmdNew = 16#E5#) then -- Set Drawing Offset (X,Y)
                  drawingOffsetX <= signed(fifoIn_Dout(10 downto 0));
                  if (gpuType1 = '1') then drawingOffsetY <= signed(fifoIn_Dout(22 downto 12)); -- gputype1: offset Y at bits 22:12
                  else                     drawingOffsetY <= signed(fifoIn_Dout(21 downto 11)); end if;
                  dbg_e5_raw <= gpuType1 & "0000000" & std_logic_vector(fifoIn_Dout(23 downto 0));
                  
               elsif (cmdNew = 16#E6#) then -- Mask Bit Setting
                  GPUSTAT_SetMask        <= fifoIn_Dout(0);
                  GPUSTAT_DrawPixelsMask <= fifoIn_Dout(1);
                  -- gputype1: E6 also updates the reflected status bits (MAME keeps gpustatus
                  -- bits 11/12 in sync from both E1-tpage and E6)
                  t1_status11            <= fifoIn_Dout(0);
                  t1_status12            <= fifoIn_Dout(1);

               elsif ((cmdNew >= 16#03# and cmdNew <= 16#1E#) or cmdNew >= 16#E7#) then
                  -- ★ 2026-07-06 PARSER-DESYNC DETECTOR: bytes 0x03-0x1E / 0xE7+ reaching the
                  -- dispatcher are not commands Tekken ever sends deliberately. A desynced
                  -- parser (lost/duplicated word) chews pixel data as commands -> this counts
                  -- them. Healthy stream => counter static.
                  dbg_unkcmd_cnt <= dbg_unkcmd_cnt + 1;
                  dbg_unkcmd_last <= std_logic_vector(cmdNew);
               end if;

               dbg_disp_cnt <= dbg_disp_cnt + 1;
            
            end if;
            
            if (proc_idle = '1') then
               interlacedDrawing <= GPUSTAT_VertInterlace and GPUSTAT_VerRes and not GPUSTAT_DrawToDisplay;
            end if;

            -- ★ 2026-07-05 READY FIX (gputype1): MAME keeps GPUSTAT bit28 permanently 1 (init
            -- 0x14802000, never cleared) — Tekken's PIO texture-upload loop polls bit28 between
            -- strips and was written against that optimistic semantic. fifoIn_Empty here made
            -- bit28≈0 whenever rendering keeps the fifo non-empty → the intro-movie upload crawled
            -- at ~0.5 strips/s (needs ~140/s). Use not-NearFull for gputype1: still honest
            -- backpressure (16-slot margin paces the DMA request too), but reads as READY whenever
            -- there is real room. Retail PSX keeps the conservative fifoIn_Empty.
            if (gpuType1 = '1') then
               GPUSTAT_ReadyRecDMA <= not fifoIn_NearFull;
            else
               GPUSTAT_ReadyRecDMA <= fifoIn_Empty;
            end if;
            
            if (proc_done = '1') then
-- synthesis translate_off
               export_gobj          <= export_gobj + 1;
-- synthesis translate_on
               proc_idle            <= '1';
               GPUSTAT_ReadyRecCmd  <= '1';
            end if;
            
            if (vramFill_done = '1' or cpu2vram_done = '1' or vram2vram_done = '1') then
               pipeline_clearCacheTexture <= '1';
               pipeline_clearCachePalette <= '1';
            end if;
            
            if (softReset = '1') then
               proc_idle              <= '1';
               drawMode               <= (others => '0');
               GPUSTAT_TextPageX      <= "0000";
               GPUSTAT_TextPageY      <= '0';
               GPUSTAT_Transparency   <= "00";
               GPUSTAT_TextPageColors <= "00";
               GPUSTAT_Dither         <= '0';
               GPUSTAT_DrawToDisplay  <= '0';
               GPUSTAT_SetMask        <= '0';
               GPUSTAT_DrawPixelsMask <= '0';
               t1_status11            <= '0';
               t1_status12            <= '0';
               GPUSTAT_TextureDisable <= '0';
               GPUSTAT_ReadyRecCmd    <= '1';
               GPUSTAT_ReadyRecDMA    <= '1';
               drawingAreaLeft        <= (others => '0');
               drawingAreaTop         <= (others => '0');
               drawingAreaRight       <= (others => '1');  -- reset to 1023, matching real hardware (MAME: n_drawarea_x2=1023)
               drawingAreaBottom      <= (others => '1');  -- reset to 1023, matching real hardware (MAME: n_drawarea_y2=1023)
               drawingOffsetX         <= (others => '0');
               drawingOffsetY         <= (others => '0');
            end if;
            
         end if;
         
      end if;
   end process; 
   
   proc_done        <= vramFill_done        or cpu2vram_done        or vram2vram_done        or vram2cpu_done        or line_done        or rect_done        or poly_done       ;
   --proc_CmdDone     <= vramFill_CmdDone     or cpu2vram_CmdDone     or vram2vram_CmdDone     or vram2cpu_CmdDone     or line_CmdDone     or rect_CmdDone     or poly_CmdDone    ;
   proc_requestFifo <= vramFill_requestFifo or cpu2vram_requestFifo or vram2vram_requestFifo or vram2cpu_requestFifo or line_requestFifo or rect_requestFifo or poly_requestFifo;

   -- packed GPU command-FSM state (which command is the GPU wedged on?)
   dbg_vram_st3 <= "000" when vramState = IDLE           else
                   "001" when vramState = WRITESECOND    else
                   "010" when vramState = READSECOND     else
                   "011" when vramState = READVRAM       else
                   "100" when vramState = CLEARLINESTART else "101";
   dbg_procstate <= proc_idle & proc_requestFifo & pipeline_busy & fifoIn_Empty & fifoIn_Valid &
                    dbg_vram_st3 &
                    vramFill_requestFifo & cpu2vram_requestFifo & vram2vram_requestFifo &
                    vram2cpu_requestFifo & line_requestFifo & rect_requestFifo & poly_requestFifo &
                    dbg_cmd &
                    poly_dbg_state & errfifo_sticky & "000";
   -- sticky fifoIn-overflow latch: fifoIn was written while FULL => GP0 word(s) silently LOST
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (reset = '1') then
            errfifo_sticky <= '0';
         elsif (ERRORFIFO = '1' and fifoIn_Wr = '1') then
            errfifo_sticky <= '1';
         end if;
      end if;
   end process;
   -- mode D (JTAG): texel-read diag from pixel pipeline. [31:16]=XOR of read texels [15:0]=last texel.
   -- For the title's 15-bit x>=512 textures: non-zero XOR + real BGR555 colors => texture READ works
   -- (bug is downstream); XOR=0 or all 0x4000(navy)/0x0000 => texture READ returns empty/garbage.
   -- mode D (JTAG): actual WRITTEN framebuffer color (pipeline_pixelColor at stage6, after all color
   -- stages). [31:16]=XOR of written colors [15:0]=last written color. Identity modulation => should
   -- equal the texels (white/real BGR555). If green/red (e.g. 001F/03E0) => color stage 2-6 bug.
   -- mode D (JTAG): videoout line-buffer INPUT (vram_DOUT fill). [31:16]=XOR of all 4 lanes
   -- accumulated [15:0]=last lane0. Varied => display reads the correct framebuffer from VRAM.
   -- mode D = JTAG VRAM-readback pixel (VRAM[ov_x,ov_y], from videoout override). mode E = DMA checksum.
-- dbg_polyv0 <= dbg_dispread_sig;                                  -- mode D = VRAM[ov_x,ov_y] (2 px)
   -- 2026-06-30 TEMP DIAG: mode D = cpu2vram latched size. [10:0]=copySizeX(width) [20:11]=copySizeY(height)
   -- [22:21]=state. Huge => corrupt IMGLOAD size word (DMA-read data); reasonable => pixels not delivered.
   -- dbg_polyv0 now = rasterizer write-Y-range (assigned after the pipeline-write process below)
   -- mode E = [31:16]=count of IMGLOADs with height-field=0 (runaway), [15:0]=last bad size word low16
   -- mode E = [31:26]=W0-count(6b) [25:16]=max copySizeY(H field) [15:10]=H0-count(6b) [9:0]=max copySizeX(W field)
-- dbg_polyv2 <= std_logic_vector(dbg_w0_cnt) & "0" & std_logic_vector(dbg_maxH) & std_logic_vector(dbg_h0_cnt) & std_logic_vector(dbg_maxW);
   -- 2026-06-30 TEMP DIAG: mode E = cpu2vram latched raw DEST word (word1). upper16=Y lower16=X.
   -- Compare to mode D (latched SIZE). If DEST==a real dest and SIZE==(that dest, 3 bits off) => the GPU
   -- duplicated/shifted (off-by-one parse). If DEST correct and SIZE is corrupt-vs-real-size => data error.
   -- mode-E: live drawing CLIP area + offset. [29:20]=drawAreaTop [19:10]=drawAreaBottom [9:0]=drawAreaRight.
   -- gputype1 back-buffer render needs drawAreaBottom>=479; if it clips ~239 the Y=240 buffer is never drawn.
   -- (superseded by VRAM write-vs-readback comparator below)
   -- dbg_polyv2 <= "00" & std_logic_vector(drawingAreaTop) & std_logic_vector(drawingAreaBottom) & std_logic_vector(drawingAreaRight);

   process (clk2x)
   begin
      if rising_edge(clk2x) then
         dbg_copysize_prev <= cpu2vram_copysize;
         if (cpu2vram_copysize /= dbg_copysize_prev) then          -- a new IMGLOAD size word arrived
            if (unsigned(cpu2vram_copysize(24 downto 16)) > dbg_maxH) then dbg_maxH <= unsigned(cpu2vram_copysize(24 downto 16)); end if;
            if (unsigned(cpu2vram_copysize( 9 downto  0)) > dbg_maxW) then dbg_maxW <= unsigned(cpu2vram_copysize( 9 downto  0)); end if;
            if (cpu2vram_copysize(24 downto 16) = "000000000") then dbg_h0_cnt <= dbg_h0_cnt + 1; end if;  -- H=0 => copySizeY 512
            if (cpu2vram_copysize( 9 downto  0) = "0000000000") then dbg_w0_cnt <= dbg_w0_cnt + 1; end if;  -- W=0 => copySizeX 1024
         end if;
      end if;
   end process;

   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (softReset = '1' or SS_reset = '1') then
            dbg_dma_xor <= (others => '0');
            dbg_dma_cnt <= (others => '0');
         else
            dbg_dma_wrEna_prev <= DMA_GPU_writeEna;
            if (DMA_GPU_writeEna = '1' and dbg_dma_wrEna_prev = '0') then  -- rising edge: one accumulate per word
               dbg_dma_xor  <= dbg_dma_xor xor DMA_GPU_write;
               dbg_dma_last <= DMA_GPU_write;
               dbg_dma_cnt  <= dbg_dma_cnt + 1;
            end if;
         end if;
      end if;
   end process;

   -- (retired) videoout line-buffer signatures:
   -- dbg_polyv0 <= dbg_dispread_sig;
   -- mode E (JTAG): videoout line-buffer OUTPUT (videoout_pixelRead/2 read back from dpram_dif).
   -- [31:16]=XOR accumulated [15:0]=last. (retired; mode E now = DMA word count above.)
   -- dbg_polyv2 <= dbg_linebufrd_sig;

   -- latch pixel-pipeline rendered-pixel WRITE position range (max X, max/min Y)
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (softReset = '1' or SS_reset = '1') then
            dbg_c2v_xor       <= (others => '0');
            dbg_pixcolor_last <= (others => '0');
         elsif (pipeline_pixelWrite = '1') then
            dbg_c2v_xor       <= dbg_c2v_xor xor pipeline_pixelColor;
            dbg_pixcolor_last <= pipeline_pixelColor;
            -- FIX: use the actual pixel WRITE address (pipeline_pixelAddr = stage6_y & stage6_x & '0'),
            -- NOT pipeline_reqVRAMYPos (that is the TEXTURE-READ address). writeY=addr(20:11) writeX=addr(10:1).
            if (pipeline_pixelColor /= x"4000") then  -- non-navy RENDERED content
               if (pipeline_pixelAddr(20 downto 11) < dbg_minWriteY) then dbg_minWriteY <= pipeline_pixelAddr(20 downto 11); end if;
               if (pipeline_pixelAddr(20 downto 11) > dbg_maxWriteY) then dbg_maxWriteY <= pipeline_pixelAddr(20 downto 11); end if;
               if (dbg_writeYcnt /= x"FFF") then dbg_writeYcnt <= dbg_writeYcnt + 1; end if;
            end if;
            if (pipeline_pixelColor( 4 downto  0) /= "00000") then dbg_r_seen <= '1'; end if;
            if (pipeline_pixelColor( 9 downto  5) /= "00000") then dbg_g_seen <= '1'; end if;
            if (pipeline_pixelColor(14 downto 10) /= "00000") then dbg_b_seen <= '1'; end if;
            if (pipeline_pixelColor /= x"0000" and pipeline_pixelColor /= x"4000") then
               dbg_nonblack_seen <= '1';
               if (pipeline_pixelAddr(10 downto 1) < dbg_nb_minX) then dbg_nb_minX <= pipeline_pixelAddr(10 downto 1); end if;
               if (pipeline_pixelAddr(10 downto 1) > dbg_nb_maxX) then dbg_nb_maxX <= pipeline_pixelAddr(10 downto 1); end if;
               if (pipeline_pixelAddr(20 downto 11) > dbg_nb_maxY) then dbg_nb_maxY <= pipeline_pixelAddr(20 downto 11); end if;
            end if;
         end if;
      end if;
   end process;
   -- mode-F: TEXEL-READ diag = the texture data the GPU READS from VRAM (X>=512 textures). [31:16]=XOR of all read
   -- texels [15:0]=last texel (texdata_raw). Varied real BGR555/index => texture READS work (bug downstream); all
   -- 0x0000/0x4000(navy)/constant or XOR=0 => texture READS return empty/GARBAGE = DDR3 read-corruption ROOT.
   -- (superseded by VRAM write-vs-readback comparator below)
   -- dbg_polyv0 <= dbg_texel_sig;

   pixelStall <= fifoOut_NearFull;
   
   -- workers
   igpu_fillVram : entity work.gpu_fillVram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset, 

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,      
      
      interlacedDrawing    => interlacedDrawing and not interlaced480pHack,  -- build #162: re-enable for 480i games (skip when 480p hack on)
      activeLineLSB        => videoout_reports.activeLineLSB,    
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vramFill_requestFifo,
      done                 => vramFill_done,
      --CmdDone              => vramFill_CmdDone,
      
      pixelStall           => pixelStall,
      pixelColor           => vramFill_pixelColor,
      pixelAddr            => vramFill_pixelAddr, 
      pixelWrite           => vramFill_pixelWrite
   );
   
   igpu_cpu2vram : entity work.gpu_cpu2vram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,    
      drawer_reset         => drawer_reset,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      SetMask              => GPUSTAT_SetMask,
      gpuType1             => gpuType1,
      errorMASK            => errorMASK,
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => cpu2vram_requestFifo,
      done                 => cpu2vram_done,
      --CmdDone              => cpu2vram_CmdDone,
      
      pixelStall           => pixelStall,
      pixelColor           => cpu2vram_pixelColor,
      pixelAddr            => cpu2vram_pixelAddr,
      pixelWrite           => cpu2vram_pixelWrite,
      dbg_parsed_dstX_hi   => cpu2vram_parsed_dstX_hi,
      dbg_cube_in_green    => cpu2vram_cube_in_green,
      dbg_cube_in_red      => cpu2vram_cube_in_red,
      dbg_cube_in_any      => cpu2vram_cube_in_any,
      -- build #133: expose latched upper halfword (= pixel 2 source)
      dbg_fifo_data_1      => cpu2vram_fifo_data_1,
      -- build #137: cpu2vram FSM latch-chain probes
      dbg_h37_input_r31_ever   => h37_input_r31_ever_sig,
      dbg_h37_writing_r31_ever => h37_writing_r31_ever_sig,
      dbg_h37_latch_r31_ever   => h37_latch_r31_ever_sig,
      -- build #138: cube-CLUT-specific lane probes
      dbg_h38_lane2_input_r31_ever => h38_lane2_input_r31_ever_sig,
      dbg_h38_lane3_latch_r31_ever => h38_lane3_latch_r31_ever_sig,
      dbg_h38_lane3_anchor_ever    => h38_lane3_anchor_ever_sig,
      -- build #139: cube-shape Y observability probes
      dbg_h39_cubeshape_any_ever   => h39_cubeshape_any_ever_sig,
      dbg_h39_cubeshape_y482_ever  => h39_cubeshape_y482_ever_sig,
      dbg_h39_cubeshape_y488_ever  => h39_cubeshape_y488_ever_sig,
      -- build #145: Y=482/480 pixelWrite probes
      dbg_h45_y482_anchor   => h45_y482_anchor_sig,
      dbg_h45_y482_pixwrite => h45_y482_pixwrite_sig,
      dbg_h45_y480_pixwrite => h45_y480_pixwrite_sig,
      -- build #146-149: cpu2vram value-capture probes
      dbg_h46_y_minus_240   => h46_y_minus_240_sig,
      dbg_h46_y_high_bit    => h46_y_high_bit_sig,
      dbg_h46_anchor        => h46_anchor_sig,
      dbg_h49_entry1_low    => h49_entry1_low_sig,
      dbg_copysize          => cpu2vram_copysize,
      dbg_copydst           => cpu2vram_copydst
   );

   igpu_vram2vram : entity work.gpu_vram2vram
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,     
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      SetMask              => GPUSTAT_SetMask,
      
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,  
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vram2vram_requestFifo,
      done                 => vram2vram_done,
      --CmdDone              => vram2vram_CmdDone,
      
      pipeline_busy        => pipeline_busy,
      fifoOut_idle         => fifoOut_idle,
      requestVRAMEnable    => vram2vram_reqVRAMEnable,
      requestVRAMXPos      => vram2vram_reqVRAMXPos,  
      requestVRAMYPos      => vram2vram_reqVRAMYPos,  
      requestVRAMSize      => vram2vram_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => vram2vram_vramLineEna, 
      vramLineAddr         => vram2vram_vramLineAddr,
      vramLineData         => vramLineData,
      
      pixelEmpty           => fifoOut_Empty,
      pixelStall           => pixelStall,
      pixelColor           => vram2vram_pixelColor,
      pixelAddr            => vram2vram_pixelAddr, 
      pixelWrite           => vram2vram_pixelWrite
   );
   
   vram2cpu_Fifo_Rd <= '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and DMA_GPU_readEna = '1') else
                       '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and bus_read = '1' and bus_addr(3 downto 2) = "00") else
                       '1' when (vram2cpu_Fifo_Empty = '0' and clk2xIndex = '0' and bus_stall = '1') else
                       '0';
   
   DMA_GPU_read <= vram2cpu_Fifo_Dout when (vram2cpu_Fifo_Empty = '0') else (others => '1');
   
   GPUSTAT_ReadySendVRAM <= not vram2cpu_Fifo_Empty;
   
   igpu_vram2cpu : entity work.gpu_vram2cpu
   port map
   (
      clk2x                => clk2x,     
      ce                   => ce,        
      reset                => softreset or SS_reset,   
      drawer_reset         => drawer_reset,

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING, 

      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => vram2cpu_requestFifo,
      done                 => vram2cpu_done,
      --CmdDone              => vram2cpu_CmdDone,
      
      pipeline_busy        => pipeline_busy,
      fifoOut_idle         => fifoOut_idle,
      requestVRAMEnable    => vram2cpu_reqVRAMEnable,
      requestVRAMXPos      => vram2cpu_reqVRAMXPos,  
      requestVRAMYPos      => vram2cpu_reqVRAMYPos,  
      requestVRAMSize      => vram2cpu_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => vram2cpu_vramLineEna, 
      vramLineAddr         => vram2cpu_vramLineAddr,
      vramLineData         => vramLineData,
      
      Fifo_Dout            => vram2cpu_Fifo_Dout, 
      Fifo_Rd              => vram2cpu_Fifo_Rd,   
      Fifo_Empty           => vram2cpu_Fifo_Empty,
      Fifo_ready           => vram2cpu_Fifo_ready
   );
   
   igpu_line : entity work.gpu_line
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,

      error                => errorLINE,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing and not interlaced480pHack,  -- build #162: re-enable for 480i games (skip when 480p hack on)
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      div1                 => line_div(0), 
      div2                 => line_div(1), 
      div3                 => line_div(2), 
      div4                 => line_div(3), 
      div5                 => line_div(4), 
      div6                 => line_div(5), 
      
      fifoOut_idle         => fifoOut_idle,
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => line_pipeline_new,        
      pipeline_transparent => line_pipeline_transparent,
      pipeline_x           => line_pipeline_x,          
      pipeline_y           => line_pipeline_y,          
      pipeline_cr          => line_pipeline_cr,         
      pipeline_cg          => line_pipeline_cg,         
      pipeline_cb          => line_pipeline_cb,         
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => line_requestFifo,
      done                 => line_done,
      --CmdDone              => line_CmdDone,
      
      requestVRAMEnable    => line_reqVRAMEnable,
      requestVRAMXPos      => line_reqVRAMXPos,  
      requestVRAMYPos      => line_reqVRAMYPos,  
      requestVRAMSize      => line_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      vramLineEna          => line_vramLineEna, 
      vramLineAddr         => line_vramLineAddr
   );
   
   igpu_rect : entity work.gpu_rect
   port map
   (
      clk2x                => clk2x,  
      clk2xIndex           => clk2xIndex,      
      ce                   => ce,        
      reset                => softreset or SS_reset,     
      
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,
      
      error                => errorRECT,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing and not interlaced480pHack,  -- build #162: re-enable for 480i games (skip when 480p hack on)
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      fifoOut_idle         => fifoOut_idle,
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => rect_pipeline_new,        
      pipeline_texture     => rect_pipeline_texture,
      pipeline_transparent => rect_pipeline_transparent,
      pipeline_rawTexture  => rect_pipeline_rawTexture,
      pipeline_x           => rect_pipeline_x,          
      pipeline_y           => rect_pipeline_y,          
      pipeline_cr          => rect_pipeline_cr,         
      pipeline_cg          => rect_pipeline_cg,         
      pipeline_cb          => rect_pipeline_cb,         
      pipeline_u           => rect_pipeline_u,         
      pipeline_v           => rect_pipeline_v,         
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => rect_requestFifo,
      done                 => rect_done,
      --CmdDone              => rect_CmdDone,
      
      requestVRAMEnable    => rect_reqVRAMEnable,
      requestVRAMXPos      => rect_reqVRAMXPos,  
      requestVRAMYPos      => rect_reqVRAMYPos,  
      requestVRAMSize      => rect_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      textPalNew           => rect_textPalNew,
      textPalX             => rect_textPalX,
      textPalY             => rect_textPalY,

      vramLineEna          => rect_vramLineEna,
      vramLineAddr         => rect_vramLineAddr,

      -- build #103
      dbg_b103_fifodata    => rect_dbg_b103_fifodata,
      dbg_b103_y507_pulse  => rect_dbg_b103_y507_pulse
   );
   
   igpu_poly : entity work.gpu_poly
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,   

      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,    
      textureFilter        => textureFilter,
      textureFilterStrength=> textureFilterStrength,
      textureFilter2DOff   => textureFilter2DOff,

      error                => errorPOLY,
      
      DrawPixelsMask       => GPUSTAT_DrawPixelsMask,
      interlacedDrawing    => interlacedDrawing and not interlaced480pHack,  -- build #162: re-enable for 480i games (skip when 480p hack on)
      activeLineLSB        => videoout_reports.activeLineLSB,    
      drawingOffsetX       => drawingOffsetX,   
      drawingOffsetY       => drawingOffsetY,   
      drawingAreaLeft      => drawingAreaLeft,  
      drawingAreaRight     => drawingAreaRight, 
      drawingAreaTop       => drawingAreaTop,   
      drawingAreaBottom    => drawingAreaBottom,
      
      drawModeRec          => poly_drawModeRec,
      drawModeNew          => poly_drawModeNew,
      drawmode_dithering   => drawMode(9),
      
      div1                 => poly_div(0), 
      div2                 => poly_div(1), 
      div3                 => poly_div(2), 
      div4                 => poly_div(3), 
      div5                 => poly_div(4), 
      div6                 => poly_div(5), 
      
      fifoOut_idle         => fifoOut_idle,
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => poly_pipeline_new,        
      pipeline_texture     => poly_pipeline_texture,
      pipeline_transparent => poly_pipeline_transparent,
      pipeline_rawTexture  => poly_pipeline_rawTexture,
      pipeline_dithering   => poly_pipeline_dithering,
      pipeline_x           => poly_pipeline_x,          
      pipeline_y           => poly_pipeline_y,          
      pipeline_cr          => poly_pipeline_cr,         
      pipeline_cg          => poly_pipeline_cg,         
      pipeline_cb          => poly_pipeline_cb,         
      pipeline_u           => poly_pipeline_u,         
      pipeline_v           => poly_pipeline_v, 
      pipeline_filter      => pipeline_filter,
      pipeline_u11         => poly_pipeline_u11,   
      pipeline_v11         => poly_pipeline_v11,         
      pipeline_uAcc        => pipeline_uAcc,
      pipeline_vAcc        => pipeline_vAcc,
      
      proc_idle            => proc_idle,
      fifo_Valid           => fifoIn_Valid, 
      fifo_data            => fifoIn_Dout,
      requestFifo          => poly_requestFifo,
      done                 => poly_done,
      --CmdDone              => poly_CmdDone,
      
      requestVRAMEnable    => poly_reqVRAMEnable,
      requestVRAMXPos      => poly_reqVRAMXPos,  
      requestVRAMYPos      => poly_reqVRAMYPos,  
      requestVRAMSize      => poly_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      
      textPalNew           => poly_textPalNew,
      textPalX             => poly_textPalX,
      textPalY             => poly_textPalY,

      vramLineEna          => poly_vramLineEna,
      vramLineAddr         => poly_vramLineAddr,

      -- build #102
      dbg_b102_fifodata    => poly_dbg_b102_fifodata,
      dbg_b102_y507_pulse  => poly_dbg_b102_y507_pulse,
      dbg_state            => poly_dbg_state,
      dbg_v0               => poly_dbg_v0,
      dbg_v2               => poly_dbg_v2
   );
   
   pipeline_new         <= line_pipeline_new         or rect_pipeline_new         or poly_pipeline_new        ;       
   pipeline_texture     <= '0'                       or rect_pipeline_texture     or poly_pipeline_texture    ;
   pipeline_transparent <= line_pipeline_transparent or rect_pipeline_transparent or poly_pipeline_transparent;          
   pipeline_rawTexture  <= '0'                       or rect_pipeline_rawTexture  or poly_pipeline_rawTexture ; 
   pipeline_dithering   <= (line_pipeline_new        or '0'                       or poly_pipeline_dithering  ) and drawMode(9) and (not ditherOff);
   pipeline_x           <= line_pipeline_x           or rect_pipeline_x           or poly_pipeline_x          ;       
   pipeline_y           <= line_pipeline_y           or rect_pipeline_y           or poly_pipeline_y          ;     
   pipeline_cr          <= line_pipeline_cr          or rect_pipeline_cr          or poly_pipeline_cr         ;
   pipeline_cg          <= line_pipeline_cg          or rect_pipeline_cg          or poly_pipeline_cg         ;
   pipeline_cb          <= line_pipeline_cb          or rect_pipeline_cb          or poly_pipeline_cb         ;
   
   pipeline_u           <= ((rect_pipeline_u or poly_pipeline_u) and textureWindow_AND_X) or textureWindow_OR_X;
   pipeline_v           <= ((rect_pipeline_v or poly_pipeline_v) and textureWindow_AND_Y) or textureWindow_OR_Y;
   
   pipeline_u11         <= (poly_pipeline_u11 and textureWindow_AND_X) or textureWindow_OR_X;
   pipeline_v11         <= (poly_pipeline_v11 and textureWindow_AND_Y) or textureWindow_OR_Y;
   
   
   -- build #94: revert B93 MUX. Bug is at gpu_rect/poly.vhd 9-bit Y instead.
   pipeline_textPalNew  <= rect_textPalNew or poly_textPalNew;
   pipeline_textPalX    <= rect_textPalX   or poly_textPalX  ;
   pipeline_textPalY    <= rect_textPalY   or poly_textPalY  ;
   
   igpu_pixelpipeline : entity work.gpu_pixelpipeline
   port map
   (
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => softreset or SS_reset,

      noTexture            => noTexture,     
      render24             => render24,
      drawSlow             => drawSlow,
      gpuType1             => gpuType1,
	  
	  oldGPU           	   => oldGPU,

      drawMode_in          => drawMode,
      DrawPixelsMask_in    => GPUSTAT_DrawPixelsMask,
      SetMask_in           => GPUSTAT_SetMask,
      
      clearCacheTexture    => pipeline_clearCacheTexture,
      clearCachePalette    => pipeline_clearCachePalette,
      
      fifoOut_idle         => fifoOut_idle,
      pipeline_busy        => pipeline_busy,
      pipeline_stall       => pipeline_stall,      
      pipeline_new         => pipeline_new,        
      pipeline_texture     => pipeline_texture,    
      pipeline_transparent => pipeline_transparent,
      pipeline_rawTexture  => pipeline_rawTexture, 
      pipeline_dithering   => pipeline_dithering,
      pipeline_x           => pipeline_x,          
      pipeline_y           => pipeline_y,          
      pipeline_cr          => pipeline_cr,         
      pipeline_cg          => pipeline_cg,         
      pipeline_cb          => pipeline_cb,         
      pipeline_u           => pipeline_u,          
      pipeline_v           => pipeline_v, 
      pipeline_filter      => pipeline_filter,
      pipeline_u11         => pipeline_u11,   
      pipeline_v11         => pipeline_v11, 
      pipeline_uAcc        => pipeline_uAcc,
      pipeline_vAcc        => pipeline_vAcc,      
      
      requestVRAMEnable    => pipeline_reqVRAMEnable,
      requestVRAMXPos      => pipeline_reqVRAMXPos,  
      requestVRAMYPos      => pipeline_reqVRAMYPos,  
      requestVRAMSize      => pipeline_reqVRAMSize,  
      requestVRAMIdle      => reqVRAMIdle,
      requestVRAMDone      => reqVRAMDone,
      vram_DOUT            => vram_DOUT,      
      vram_DOUT_READY      => vram_DOUT_READY,
      
      vramLineData         => vramLineData,
      vramLineData2        => vramLineData2,
      
      textPalInNew         => pipeline_textPalNew,
      textPalInX           => pipeline_textPalX,  
      textPalInY           => pipeline_textPalY,  
      
      pixelStall           => pixelStall,
      pixelColor           => pipeline_pixelColor,
      pixelColor2          => pipeline_pixelColor2,
      pixelAddr            => pipeline_pixelAddr,
      pixelWrite           => pipeline_pixelWrite,
      dbg_clut_write_nonnavy => dbg_clut_write_nonnavy_int,
      dbg_clut_read_nonnavy  => dbg_clut_read_nonnavy_int,
      dbg_stage4_texture     => dbg_stage4_texture_int,
      dbg_texel              => dbg_texel_sig,
      dbg_uv                 => dbg_uv_sig,
      -- build #8
      dbg_textPalReq_set     => dbg_textPalReq_set_int,
      dbg_state_REQ_PAL      => dbg_state_REQ_PAL_int,
      dbg_CLUTwrenA_any      => dbg_CLUTwrenA_any_int,
      dbg_drawMode_8         => dbg_drawMode_8_int,
      dbg_noTexture_pin      => dbg_noTexture_pin_int,
      -- build #13
      dbg_textPalReqX_nonzero  => dbg_textPalReqX_nz_int,
      dbg_textPalReqY_nonzero  => dbg_textPalReqY_nz_int,
      dbg_textPalReqX_high_bit => dbg_textPalReqX_hi_int,
      dbg_textPalReqY_high_bit => open,
      dbg_textPalReqX_bit8     => dbg_textPalReqX_b8_int,
      -- build #26
      dbg_cubeclut_gb          => dbg_cubeclut_gb_int,
      dbg_cubeclut_ronly       => dbg_cubeclut_ronly_int,
      dbg_loclut_gb            => dbg_loclut_gb_int,
      -- build #57
      dbg_stage4_texraw_nz     => dbg_stage4_texraw_nz_int,
      -- build #63
      dbg_textPalReqY_clut     => dbg_textPalReqY_clut_int,
      -- build #67
      dbg_last_succ_palX       => dbg_last_succ_palX_int,
      dbg_last_succ_palY       => dbg_last_succ_palY_int,
      -- build #68
      dbg_textPalReqY_lo       => dbg_textPalReqY_lo_int,
      dbg_textPalReqY_hi       => dbg_textPalReqY_hi_int,
      -- build #82
      dbg_b82_byte_redslot     => dbg_b82_byte_redslot_int,
      dbg_b82_byte_greenslot   => dbg_b82_byte_greenslot_int,
      dbg_b82_captured         => dbg_b82_captured_int,
      -- build #102/103: route the combined fifo_data trace (rect or poly) into pixelpipeline's latch
      dbg_b102_poly_fifodata_in => combined_b102_fifodata,
      dbg_b102_poly_y507_pulse_in => combined_b102_pulse,
      -- build #122: vram_DOUT capture at hi-Y CLUT[3] load
      dbg_h22_anchor             => h22_anchor_sig,
      dbg_h22_clut3_r            => h22_clut3_r_sig,
      dbg_h22_clut3_g            => h22_clut3_g_sig,
      -- build #140: CLUT-RAM cube CLUT presence probes
      dbg_h40_cube_clut_loaded_ever => h40_cube_clut_loaded_ever_sig,
      dbg_h40_clut_read_7fff_ever   => h40_clut_read_7fff_ever_sig,
      dbg_h40_clut_read_023f_ever   => h40_clut_read_023f_ever_sig,
      -- build #158: H4 cache-staleness probes
      dbg_h58_x_stale_seen          => h58_x_stale_seen_sig,
      dbg_h58_y_stale_seen          => h58_y_stale_seen_sig,
      dbg_h58_pixel_seen            => h58_pixel_seen_sig,
      -- build #159: H7 CLUT load capture
      dbg_h59_loaded_entry0_lo      => h59_loaded_entry0_lo_sig,
      dbg_h59_loaded_y              => h59_loaded_y_sig,
      dbg_h59_anchor                => h59_anchor_sig
   );

   -- build #112: route cpu2vram_pixelColor + write to instrument.
   -- Pulse = cpu2vram_pixelWrite (write event)
   -- Data = cpu2vram_pixelColor (16-bit) and cpu2vram_pixelAddr X/Y for filtering
   -- Pack into 32-bit: [31:16] = pixelColor, [15:8] = pixelAddr[18:11] (Y low byte), [7:0] = pixelAddr[10:3] (X high byte)
   combined_b102_pulse <= cpu2vram_pixelWrite;
   combined_b102_fifodata <= cpu2vram_pixelColor
                             & std_logic_vector(cpu2vram_pixelAddr(18 downto 11))
                             & std_logic_vector(cpu2vram_pixelAddr(10 downto 3));
   
   gdividers: for i in 0 to 5 generate
   begin
   
      div_array(i).start    <= line_div(i).start    or poly_div(i).start;
      div_array(i).dividend <= line_div(i).dividend or poly_div(i).dividend;
      div_array(i).divisor  <= line_div(i).divisor  or poly_div(i).divisor;
      
      line_div(i).done      <= div_array(i).done;     
      line_div(i).quotient  <= div_array(i).quotient; 
      line_div(i).remainder <= div_array(i).remainder;
      
      poly_div(i).done      <= div_array(i).done;     
      poly_div(i).quotient  <= div_array(i).quotient; 
      poly_div(i).remainder <= div_array(i).remainder;
      
      idivider : entity work.divider
      port map
      (
         clk       => clk2x,      
         start     => div_array(i).start,
         done      => div_array(i).done,          
         dividend  => div_array(i).dividend, 
         divisor   => div_array(i).divisor,  
         quotient  => div_array(i).quotient, 
         remainder => div_array(i).remainder
      );
   end generate;
   
   -- build #109 FIX: replace OR-mash with priority mux for pixelAddr/pixelColor.
   -- pipeline_pixelAddr is driven by `pixelAddr <= stage6_y & stage6_x & '0'` (gpu_pixelpipeline.vhd:1044)
   -- as a CONTINUOUS assignment — it holds stage6 values even when pipeline_pixelWrite='0'.
   -- The OR-mash combined stale pipeline bits into cpu2vram uploads, sending uploads to wrong addresses.
   -- pixelWrite stays OR (any writer triggers a write); pixelColor/pixelAddr use priority mux.
   pixelColor  <= cpu2vram_pixelColor  when cpu2vram_pixelWrite  = '1' else
                  vram2vram_pixelColor when vram2vram_pixelWrite = '1' else
                  pipeline_pixelColor;
   pixelColor2 <=                                                pipeline_pixelColor2;
   pixelAddr   <= cpu2vram_pixelAddr  when cpu2vram_pixelWrite  = '1' else
                  vram2vram_pixelAddr when vram2vram_pixelWrite = '1' else
                  pipeline_pixelAddr;
   pixelWrite  <= cpu2vram_pixelWrite or vram2vram_pixelWrite or pipeline_pixelWrite;

   dbg_pipeline_pixelWrite <= pipeline_pixelWrite;
   -- DIAGNOSTIC: rasterizer wrote to Y<256 (pipeline_pixelAddr bits 20:19 both 0 → Y[9:8]="00")
   dbg_pipeline_write_in_top <= '1' when (pipeline_pixelWrite = '1' and pipeline_pixelAddr(20 downto 19) = "00") else '0';
   -- DIAGNOSTIC: actual vram_WE assertion to DDR3 (tracks if pixels truly reach memory)
   dbg_vram_WE <= vram_WE;
   -- DIAGNOSTIC: rasterizer produced a non-navy color (any pixel where pipeline_pixelColor != 0x4000)
   dbg_pipeline_color_varied <= '1' when (pipeline_pixelWrite = '1' and pipeline_pixelColor /= x"4000") else '0';
   -- DIAGNOSTIC: vram_DIN contains non-navy data anywhere in the 64-bit burst (any 16-bit lane != 0x4000)
   dbg_vram_din_non_navy <= '1' when (vram_WE = '1' and
                                       (vram_DIN(15 downto 0)  /= x"4000" or
                                        vram_DIN(31 downto 16) /= x"4000" or
                                        vram_DIN(47 downto 32) /= x"4000" or
                                        vram_DIN(63 downto 48) /= x"4000")) else '0';
   -- DIAGNOSTIC: GPU received a DDR3 read whose data has any non-navy 16-bit lane.
   -- If WHITE (vram_DIN non-navy) is bright but this stays dark, DDR3 isn't returning what we wrote.
   dbg_vram_dout_nonnavy <= '1' when (vram_DOUT_READY = '1' and
                                       (vram_DOUT(15 downto 0)  /= x"4000" or
                                        vram_DOUT(31 downto 16) /= x"4000" or
                                        vram_DOUT(47 downto 32) /= x"4000" or
                                        vram_DOUT(63 downto 48) /= x"4000")) else '0';
   -- DIAGNOSTIC build #5: rasterizer wrote non-navy AND target address is in the displayed region.
   -- pipeline_pixelAddr encoding: Y[9:0] = bits(20:11), X[9:0] = bits(10:1). Display region = Y<480 AND X<512.
   dbg_rast_display_nonnavy <= '1' when (pipeline_pixelWrite = '1' and
                                          pipeline_pixelColor /= x"4000" and
                                          pipeline_pixelAddr(10) = '0' and                    -- X < 512
                                          pipeline_pixelAddr(20 downto 11) < to_unsigned(480, 10)) else '0';
   -- DIAGNOSTIC build #5: rasterizer wrote non-navy AND target address is OUTSIDE the displayed region.
   dbg_rast_offdisp_nonnavy <= '1' when (pipeline_pixelWrite = '1' and
                                          pipeline_pixelColor /= x"4000" and
                                          (pipeline_pixelAddr(10) = '1' or                    -- X >= 512
                                           pipeline_pixelAddr(20 downto 11) >= to_unsigned(480, 10))) else '0';
   -- DIAGNOSTIC build #5: vram_DIN had non-navy lane AND the destination DDR3 address is in the displayed region.
   -- vram_ADDR encoding: vram_ADDR(20:11) = Y, vram_ADDR(10:1) = X. Display region = Y<480 AND X<512.
   dbg_vramdin_display_nonnavy <= '1' when (vram_WE = '1' and
                                             (vram_DIN(15 downto 0)  /= x"4000" or
                                              vram_DIN(31 downto 16) /= x"4000" or
                                              vram_DIN(47 downto 32) /= x"4000" or
                                              vram_DIN(63 downto 48) /= x"4000") and
                                             vram_ADDR(10) = '0' and                          -- X < 512
                                             unsigned(vram_ADDR(20 downto 11)) < to_unsigned(480, 10)) else '0';
   dbg_clut_write_nonnavy <= dbg_clut_write_nonnavy_int;
   dbg_clut_read_nonnavy  <= dbg_clut_read_nonnavy_int;
   dbg_stage4_texture     <= dbg_stage4_texture_int;
   dbg_stage4_texraw_nz   <= dbg_stage4_texraw_nz_int;  -- build #57
   dbg_textPalReqY_clut   <= dbg_textPalReqY_clut_int;  -- build #63
   dbg_last_succ_palX     <= dbg_last_succ_palX_int;    -- build #67
   dbg_last_succ_palY     <= dbg_last_succ_palY_int;    -- build #67
   dbg_textPalReqY_lo     <= dbg_textPalReqY_lo_int;    -- build #68
   dbg_textPalReqY_hi     <= dbg_textPalReqY_hi_int;    -- build #68
   dbg_b82_byte_redslot   <= dbg_b82_byte_redslot_int;  -- build #82
   dbg_b82_byte_greenslot <= dbg_b82_byte_greenslot_int; -- build #82
   dbg_b82_captured       <= dbg_b82_captured_int;       -- build #82
   -- build #8 wire-through: textPalNew is the gpu.vhd-level OR of rect and poly drivers
   dbg_textPalNew         <= pipeline_textPalNew;
   dbg_textPalReq_set     <= dbg_textPalReq_set_int;
   dbg_state_REQ_PAL      <= dbg_state_REQ_PAL_int;
   dbg_CLUTwrenA_any      <= dbg_CLUTwrenA_any_int;
   dbg_drawMode_8         <= dbg_drawMode_8_int;
   dbg_noTexture_pin      <= dbg_noTexture_pin_int;
   -- build #11: CPU2VRAM tap
   dbg_cpu2vram_pixelWrite <= cpu2vram_pixelWrite;
   dbg_cpu2vram_color_nonnavy <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelColor /= x"4000" and cpu2vram_pixelColor /= x"0000") else '0';
   -- build #13: CLUT addressing inspection
   dbg_textPalReqX_nonzero    <= dbg_textPalReqX_nz_int;
   dbg_textPalReqY_nonzero    <= dbg_textPalReqY_nz_int;
   -- cpu2vram_pixelAddr Y = bits 20:11. Y>=256 means Y(8)='1' i.e. bit 19.
   dbg_cpu2vram_dstY_bit8_LATCHED_src <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(19) = '1') else '0';
   dbg_cpu2vram_dstY_nonzero <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(20 downto 11) /= "0000000000") else '0';
   -- build #14: CPU2VRAM destination X — does game ever write at X=0 (where CLUT reads from)?
   -- cpu2vram_pixelAddr X = bits 10:1. X=0 means bits 10:1 all zero.
   dbg_cpu2vram_dstX_zero    <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(10 downto 1) = "0000000000") else '0';
   dbg_cpu2vram_dstX_nonzero <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(10 downto 1) /= "0000000000") else '0';
   -- build #15: ANY write to VRAM at X=0 column (vram_ADDR X-portion is bits 10:3 = X[9:2])
   -- X[9:2] = 0 means X in [0,3]
   dbg_vram_we_x_zero <= '1' when (vram_WE = '1' and vram_ADDR(10 downto 3) = "00000000") else '0';
   dbg_vram_we_x_zero_nonnavy <= '1' when (vram_WE = '1' and vram_ADDR(10 downto 3) = "00000000" and
                                            (vram_DIN(15 downto 0)  /= x"4000" or
                                             vram_DIN(31 downto 16) /= x"4000" or
                                             vram_DIN(47 downto 32) /= x"4000" or
                                             vram_DIN(63 downto 48) /= x"4000")) else '0';
   dbg_vram2vram_active <= vram2vram_pixelWrite;
   dbg_vramFill_active <= vramFill_pixelWrite;
   -- build #17: verify Y-wrap fix took effect
   dbg_pixelAddr_Y_hi     <= '1' when (pipeline_pixelWrite = '1' or cpu2vram_pixelWrite = '1' or vram2vram_pixelWrite = '1' or vramFill_pixelWrite = '1') and pixelAddr(20) = '1' else '0';
   dbg_cpu2vram_Y_hi      <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(20) = '1') else '0';
   dbg_vram_addr_Y_hi_we  <= '1' when (vram_WE = '1' and vram_ADDR(20) = '1') else '0';

   -- TEXTURE-WRITE (X>=512) sticky probe: does the GPU ever WRITE the texture region? cpu2vram X = pixelAddr(10:1),
   -- X>=512 <=> pixelAddr(10)=1. DDR3 write X[9:2] = vram_ADDR(10:3), X>=512 <=> vram_ADDR(10)=1.
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (softReset = '1' or SS_reset = '1') then
            txw_c2v_any <= '0'; txw_c2v_xhi <= '0'; txw_we_xhi <= '0'; txw_parsed_xhi <= '0';
            txw_c2v_maxX <= (others => '0'); txw_we_maxX <= (others => '0');
            txw_we_fb_seen <= '0'; txw_we_minX <= (others => '1');
            txw_we_fb_back <= '0'; txw_we_maxY <= (others => '0');
         else
            if (cpu2vram_pixelWrite = '1') then
               txw_c2v_any <= '1';
               if (cpu2vram_pixelAddr(10) = '1') then txw_c2v_xhi <= '1'; end if;
               if (cpu2vram_pixelAddr(10 downto 1) > txw_c2v_maxX) then txw_c2v_maxX <= cpu2vram_pixelAddr(10 downto 1); end if;
            end if;
            if (vram_WE = '1' and vram_ADDR(10) = '1') then txw_we_xhi <= '1'; end if;
            -- KEY: did vram_WE ever commit a FRAMEBUFFER pixel (X<512, Y<480) to DDR3? If not, framebuffer stays
            -- uninitialized => display shows noise even though the GPU "renders".
            if (vram_WE = '1' and vram_ADDR(10) = '0' and unsigned(vram_ADDR(20 downto 11)) < 480) then
               txw_we_fb_seen <= '1';
               if (unsigned(vram_ADDR(20 downto 11)) > txw_we_maxY) then txw_we_maxY <= unsigned(vram_ADDR(20 downto 11)); end if;
               if (unsigned(vram_ADDR(20 downto 11)) >= 240) then txw_we_fb_back <= '1'; end if;   -- BACK buffer (Y>=240) write
            end if;
            if (vram_WE = '1' and (unsigned(vram_ADDR(10 downto 3)) & unsigned'("00")) > txw_we_maxX) then
               txw_we_maxX <= unsigned(vram_ADDR(10 downto 3)) & unsigned'("00");
            end if;
            if (vram_WE = '1' and (unsigned(vram_ADDR(10 downto 3)) & unsigned'("00")) < txw_we_minX) then
               txw_we_minX <= unsigned(vram_ADDR(10 downto 3)) & unsigned'("00");
            end if;
            if (cpu2vram_parsed_dstX_hi = '1') then txw_parsed_xhi <= '1'; end if;
         end if;
      end if;
   end process;
   -- [31]c2v_any [30]we_xhi(X>=512) [29]we_FB_front(X<512,Y<480 wrote) [28]we_FB_BACK(X<512,Y>=240 wrote)
   -- [19:10]=we_maxY (max Y of any framebuffer write) [9:0]=we_maxX. we_FB_BACK=0 => back buffer never written => noise.
   dbg_texwrite_xhi <= txw_c2v_any & txw_we_xhi & txw_we_fb_seen & txw_we_fb_back & "00000000" &
                       std_logic_vector(txw_we_maxY) & std_logic_vector(txw_we_maxX);

   -- VRAM WRITE-vs-READBACK comparator. Watch the FIRST framebuffer word written (Y<480,X<512); track the last
   -- value written there; on a later READ of that same word, compare vram_DOUT lane0 vs the written value.
   -- cmp_mismatch=1 => VRAM read returned a DIFFERENT value than was written = DDR3 VRAM READ CORRUPTION.
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (softReset = '1' or SS_reset = '1') then
            wr_watch_valid <= '0'; cmp_seen <= '0'; cmp_mismatch <= '0';
         else
            -- Watch a FRAMEBUFFER word (X<512, Y<240 front buffer). INITIAL latch picks a real non-zero pixel; then
            -- track EVERY write to that word (incl. clears to 0) so wr_watch_data is the TRUE latest VRAM value.
            -- The videoout reads every framebuffer pixel each frame => a read MUST return wr_watch_data unless the
            -- DDR3 read is corrupt (this avoids the false-mismatch from an overwrite the non-zero-only update had).
            if (vram_WE = '1' and vram_ADDR(10) = '0' and unsigned(vram_ADDR(20 downto 11)) < 240) then
               if (wr_watch_valid = '0') then
                  if (vram_DIN(15 downto 0) /= x"0000" and vram_DIN(15 downto 0) /= x"4000") then
                     wr_watch_addr  <= vram_ADDR(20 downto 3);
                     wr_watch_valid <= '1';
                     wr_watch_data  <= vram_DIN(15 downto 0);
                  end if;
               elsif (vram_ADDR(20 downto 3) = wr_watch_addr) then
                  wr_watch_data  <= vram_DIN(15 downto 0);   -- track ANY write (incl. 0) = true latest VRAM value
               end if;
            end if;
            -- BURST-AWARE read side: latch burst base on vram_RD, count each returned word; the current word's
            -- address = rd_burst_base + rd_word_cnt. Compare when it equals the watched write address.
            if (vram_RD = '1') then
               rd_burst_base <= unsigned(vram_ADDR(20 downto 3));
               rd_word_cnt   <= (others => '0');
            end if;
            if (vram_DOUT_READY = '1') then
               if (wr_watch_valid = '1' and (rd_burst_base + rd_word_cnt) = unsigned(wr_watch_addr)) then
                  cmp_wdata <= wr_watch_data;
                  cmp_rdata <= vram_DOUT(15 downto 0);
                  cmp_seen  <= '1';
                  if (vram_DOUT(15 downto 0) /= wr_watch_data) then cmp_mismatch <= '1'; end if;
               end if;
               rd_word_cnt <= rd_word_cnt + 1;
            end if;
         end if;
      end if;
   end process;
   -- mode-F = written[31:16] & readback[15:0]; mode-E = [31]seen [30]mismatch [29:12]=watch_addr [11:0]=0
   dbg_polyv0 <= dbg_dispread_sig;   -- 2026-07-08 FMV triage: JTAG VRAM readback (coord via dbg_vram_coord 0xF|Y<<10|X)
   dbg_polyv2 <= cmp_seen & cmp_mismatch & wr_watch_addr & "000000000000";
   dbg_vram_addr_Y_hi_rd  <= '1' when (vram_RD = '1' and vram_ADDR(20) = '1') else '0';
   -- build #19: lpadv-tuned diagnostics
   dbg_textPalReqX_ge_256 <= dbg_textPalReqX_b8_int;
   dbg_textPalReqX_hi     <= dbg_textPalReqX_hi_int;
   -- cpu2vram_pixelAddr X = bits 10:1. X>=512 means pixel-X bit 9 = pixelAddr bit 10 = '1'.
   dbg_cpu2vram_dstX_hi   <= '1' when (cpu2vram_pixelWrite = '1' and cpu2vram_pixelAddr(10) = '1') else '0';
   -- build #21: parser-side dst-X high detector forwarded from gpu_cpu2vram
   dbg_cpu2vram_parsed_dstX_hi <= cpu2vram_parsed_dstX_hi;
   -- build #23: G/B channel-bit detection in pipeline output and write side
   dbg_pipeline_g_set <= '1' when (pipeline_pixelWrite = '1' and pipeline_pixelColor(9 downto 5)  /= "00000") else '0';
   dbg_pipeline_b_set <= '1' when (pipeline_pixelWrite = '1' and pipeline_pixelColor(14 downto 10) /= "00000") else '0';
   -- vram_DIN spans 4 16-bit BGR15 lanes. Fire if ANY lane has non-zero G (bits 9:5) OR B (bits 14:10).
   dbg_vram_din_gb <= '1' when (vram_WE = '1' and (
                                vram_DIN(14 downto 5)   /= "0000000000" or
                                vram_DIN(30 downto 21)  /= "0000000000" or
                                vram_DIN(46 downto 37)  /= "0000000000" or
                                vram_DIN(62 downto 53)  /= "0000000000")) else '0';
   dbg_cpu2vram_color_gb <= '1' when (cpu2vram_pixelWrite = '1' and (
                                cpu2vram_pixelColor(9 downto 5)   /= "00000" or
                                cpu2vram_pixelColor(14 downto 10) /= "00000")) else '0';
   -- build #24: when a rect rasterization is producing a textured pixel, sample drawMode bits 7:8
   -- (drawMode(8) is the 15-bit-direct flag; drawMode(7) distinguishes 4-bit from 8-bit CLUT)
   dbg_rect_tex_4bit  <= '1' when (rect_pipeline_new = '1' and rect_pipeline_texture = '1'
                                   and drawMode(8) = '0' and drawMode(7) = '0') else '0';
   dbg_rect_tex_8bit  <= '1' when (rect_pipeline_new = '1' and rect_pipeline_texture = '1'
                                   and drawMode(8) = '0' and drawMode(7) = '1') else '0';
   dbg_desync <= std_logic_vector(dbg_unkcmd_cnt) & dbg_unkcmd_last & std_logic_vector(dbg_disp_cnt);
   dbg_rect_tex_15bit <= '1' when (rect_pipeline_new = '1' and rect_pipeline_texture = '1'
                                   and drawMode(8) = '1') else '0';
   -- textured-rect pixel produced with G or B bits set in output color
   -- (using the rect's contribution to pipeline_pixelColor: when rect_pipeline_new is high,
   --  the rasterizer is feeding the pipeline, but final output may be from pipeline stages.
   --  Approximating: any pipeline_pixelWrite during rect rendering with G/B bits.)
   dbg_rect_tex_pixel_gb <= '1' when (pipeline_pixelWrite = '1' and rect_pipeline_texture = '1' and
                                       (pipeline_pixelColor(9 downto 5)   /= "00000" or
                                        pipeline_pixelColor(14 downto 10) /= "00000")) else '0';
   -- build #45: classify the cpu2vram INPUT (FIFO source word) at the cube-CLUT dest
   -- (row=488, col<256). cpu2vram is a pure copy, so input==output; build #44 already
   -- proved the OUTPUT (pixelColor) is RED there. This re-measures the INPUT to split:
   --   INPUT red  -> cpu2vram is a faithful pass-through -> bug is UPSTREAM of the GPU
   --                 FIFO (DMA / RAM staging / banked-ROM read).  [most likely]
   --   INPUT green -> cpu2vram turns green->red -> cpu2vram IS the bug.
   -- Sources are the combinational dbg_cube_in_* pulses from gpu_cpu2vram (build #45).
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (reset = '1') then
            cube488_green_seen <= '0';
            cube488_red_seen   <= '0';
            cube488_any_seen   <= '0';
         else
            if (cpu2vram_cube_in_any   = '1') then cube488_any_seen   <= '1'; end if;
            if (cpu2vram_cube_in_green = '1') then cube488_green_seen <= '1'; end if;
            if (cpu2vram_cube_in_red   = '1') then cube488_red_seen   <= '1'; end if;
         end if;
      end if;
   end process;
   dbg_loclut_gb      <= cube488_green_seen;  -- GREEN:  cpu2vram INPUT green at cube gate -> cpu2vram IS the bug (input green, output red)
   dbg_cubeclut_gb    <= cube488_red_seen;    -- YELLOW: cpu2vram INPUT red   at cube gate -> cpu2vram pass-through -> bug UPSTREAM of FIFO
   dbg_cubeclut_ronly <= cube488_any_seen;    -- WHITE:  any INPUT pixel at cube gate (sanity - anchor fired)

   -- build #114 H1+H2: rect 0x64 cube-path test
   -- Trigger: rect engine emits pixel in actual cube area (per B114a screenshot scan: cubes at Y=50-188).
   -- B114a's Y=[200,230] filter caught only CREDIT 0 text — fixed in B114b.
   -- Also exclude the bottom-right CREDIT/UI text area via X<300.
   h12_cube_emit <= '1' when (rect_pipeline_new = '1'
                              and rect_pipeline_y >= 40
                              and rect_pipeline_y <= 200
                              and rect_pipeline_x < 300) else '0';

   h12_drawMode_changed <= '1' when (drawMode /= h12_drawMode_prev) else '0';

   process (clk2x)
   begin
      if rising_edge(clk2x) then
         h12_drawMode_prev <= drawMode;

         if (pipeline_busy = '0') then
            h12_busy_run_count <= (others => '0');
         elsif (h12_busy_run_count /= x"FFFF") then
            h12_busy_run_count <= h12_busy_run_count + 1;
         end if;

         if (reset = '1' or softReset = '1') then
            h12_red_anchor        <= '0';
            h12_green_dm_ok       <= '0';
            h12_blue_dm_stale     <= '0';
            h12_yellow_busy0      <= '0';
            h12_white_dm_chg      <= '0';
            h12_cyan_emit_busy0   <= '0';
            h12_magenta_busy_long <= '0';
         else
            if (h12_cube_emit = '1') then
               h12_red_anchor <= '1';
            end if;

            if (h12_cube_emit = '1' and
                (drawMode(3 downto 0) = x"A" or drawMode(3 downto 0) = x"B")) then
               h12_green_dm_ok <= '1';
            end if;

            if (h12_cube_emit = '1' and
                drawMode(3 downto 0) /= x"A" and drawMode(3 downto 0) /= x"B") then
               h12_blue_dm_stale <= '1';
            end if;

            if (h12_red_anchor = '1' and pipeline_busy = '0') then
               h12_yellow_busy0 <= '1';
            end if;

            if (h12_red_anchor = '1' and h12_drawMode_changed = '1') then
               h12_white_dm_chg <= '1';
            end if;

            if (h12_cube_emit = '1' and pipeline_busy = '0') then
               h12_cyan_emit_busy0 <= '1';
            end if;

            if (h12_red_anchor = '1' and h12_busy_run_count >= 4096) then
               h12_magenta_busy_long <= '1';
            end if;

            -- build #115: quantify race — count cube_emit events by drawMode correctness
            if (h12_cube_emit = '1') then
               if (drawMode(3 downto 0) = x"A" or drawMode(3 downto 0) = x"B") then
                  if (h12_ok_count /= x"FFFF") then
                     h12_ok_count <= h12_ok_count + 1;
                  end if;
               else
                  if (h12_stale_count /= x"FFFF") then
                     h12_stale_count <= h12_stale_count + 1;
                  end if;
               end if;
            end if;
            -- sticky: meaningful imbalance favoring stale (>= 8 stale events more than ok)
            if (h12_stale_count > h12_ok_count + 8) then
               h12_stale_gt_ok_sticky <= '1';
            end if;

            -- build #117: G+B stripping locator
            if (h17_cube_pxwr = '1') then
               h17_anchor_sticky <= '1';
               if (pipeline_pixelColor(9 downto 5) /= "00000") then
                  h17_g_sticky <= '1';
               end if;
               if (pipeline_pixelColor(14 downto 10) /= "00000") then
                  h17_b_sticky <= '1';
               end if;
            end if;

            -- build #119: vram_DIN G+B locator at cube area SDRAM writes
            if (h19_cube_we = '1') then
               h19_anchor_sticky <= '1';
               if (vram_DIN(9 downto 5) /= "00000" or
                   vram_DIN(25 downto 21) /= "00000" or
                   vram_DIN(41 downto 37) /= "00000" or
                   vram_DIN(57 downto 53) /= "00000") then
                  h19_g_in_din <= '1';
               end if;
               if (vram_DIN(14 downto 10) /= "00000" or
                   vram_DIN(30 downto 26) /= "00000" or
                   vram_DIN(46 downto 42) /= "00000" or
                   vram_DIN(62 downto 58) /= "00000") then
                  h19_b_in_din <= '1';
               end if;
            end if;

            -- build #120: counter-based G+B prevalence at cube area writes
            if (h19_cube_we = '1') then
               if (h20_anchor_count /= x"FFFF") then
                  h20_anchor_count <= h20_anchor_count + 1;
               end if;
               if (vram_DIN(9 downto 5) /= "00000" or
                   vram_DIN(25 downto 21) /= "00000" or
                   vram_DIN(41 downto 37) /= "00000" or
                   vram_DIN(57 downto 53) /= "00000") then
                  if (h20_g_count /= x"FFFF") then
                     h20_g_count <= h20_g_count + 1;
                  end if;
               end if;
               if (vram_DIN(14 downto 10) /= "00000" or
                   vram_DIN(30 downto 26) /= "00000" or
                   vram_DIN(46 downto 42) /= "00000" or
                   vram_DIN(62 downto 58) /= "00000") then
                  if (h20_b_count /= x"FFFF") then
                     h20_b_count <= h20_b_count + 1;
                  end if;
               end if;
            end if;

            -- build #126: SDRAM round-trip self-test, NON-STICKY (overwrite each event)
            -- Captures LATEST write/read R values at (Y=482, X=256..259). Anchors still stick LIT.
            -- The FIRST write was likely a clear pass; LATEST reflects the current loaded cube CLUT.
            if (vram_WE = '1' and h24_addr_match = '1') then
               h24_write_anchor <= '1';
               h24_write_r <= vram_DIN(52 downto 48);  -- R bits of lane 3 (CLUT[3])
            end if;
            if (vram_RD = '1' and h24_addr_match = '1') then
               h24_read_pending <= '1';
            end if;
            if (h24_read_pending = '1' and vram_DOUT_READY = '1') then
               h24_read_anchor <= '1';
               h24_read_r <= vram_DOUT(52 downto 48);
               h24_read_pending <= '0';
            end if;

            -- build #128: cpu2vram vs vram_DIN comparison for cube CLUT band writes (lane 3 / CLUT[3] equivalents)
            if (h28_cpu_addr_match = '1') then
               h28_cpu_anchor <= '1';
               h28_cpu_r <= cpu2vram_pixelColor(4 downto 0);  -- R bits of 16-bit BGR-555
            end if;
            if (h28_vram_addr_match = '1') then
               h28_vram_anchor <= '1';
               h28_vram_r <= vram_DIN(52 downto 48);  -- R bits of lane 3
            end if;

            -- build #129: capture zn_bank_8mb at cube CLUT cpu2vram writes
            h29_bank_prev <= bank_8mb_in;
            if (bank_8mb_in /= h29_bank_prev) then
               h29_bank_ever_changed <= '1';
            end if;
            if (h28_cpu_addr_match = '1') then
               -- Same trigger as B128: cpu2vram writing to CLUT band lane 3
               h29_bank_anchor <= '1';
               h29_bank_at_cpu_write <= bank_8mb_in;
            end if;

            -- build #133: capture fifo_data_1 + cpu2vram_pixelColor at cube CLUT lane-3 writes
            if (h33_trigger = '1') then
               h33_anchor <= '1';
               h33_fifo_data_1_r <= cpu2vram_fifo_data_1(4 downto 0);
               h33_cpu_color_r   <= cpu2vram_pixelColor(4 downto 0);
            end if;
            -- sticky: fifo_data_1 ever has R=31
            if (cpu2vram_fifo_data_1(4 downto 0) = "11111") then
               h33_fifo_data_1_r31_ever <= '1';
            end if;

            -- build #134: probe fifoIn_Dout halfword R bits
            if (fifoIn_Valid = '1') then
               if (fifoIn_Dout(4 downto 0) = "11111") then
                  h34_lower_r31_ever <= '1';
               end if;
               if (fifoIn_Dout(20 downto 16) = "11111") then
                  h34_upper_r31_ever <= '1';
               end if;
               if (fifoIn_Dout(20) = '1') then
                  h34_upper_msb_ever <= '1';
               end if;
            end if;

            -- build #131: capture DMA_GPU_write at every DMA delivery
            if (DMA_GPU_writeEna = '1') then
               h31_anchor <= '1';
               h31_pixel1_r <= DMA_GPU_write(4 downto 0);
               h31_pixel2_r <= DMA_GPU_write(20 downto 16);
               -- Sticky: ever delivered non-zero R bits (either pixel)?
               if (DMA_GPU_write(4 downto 0) /= "00000" or DMA_GPU_write(20 downto 16) /= "00000") then
                  h31_rich_ever <= '1';
               end if;

               -- build #132: stickys for R=31 / R>=24 / pixel1 nonzero
               if (DMA_GPU_write(4 downto 0) = "11111" or DMA_GPU_write(20 downto 16) = "11111") then
                  h32_r31_ever <= '1';
               end if;
               if (unsigned(DMA_GPU_write(4 downto 0)) >= 24 or unsigned(DMA_GPU_write(20 downto 16)) >= 24) then
                  h32_r_high_ever <= '1';
               end if;
               if (DMA_GPU_write(4 downto 0) /= "00000") then
                  h32_pixel1_nonzero_ever <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;

   -- build #118 trigger (combinational): pipeline pixel write to cube display area DURING cube attract.
   -- Cube attract drives global drawMode[3:0] to 0xA (TexPage X=640) or 0xB (X=704) per MAME ground truth.
   -- Splash/INSERT-COIN text use different drawMode values, so this filter excludes them.
   h17_cube_pxwr <= '1' when (pipeline_pixelWrite = '1'
                              and pipeline_pixelAddr(20 downto 11) >= 40
                              and pipeline_pixelAddr(20 downto 11) <= 200
                              and pipeline_pixelAddr(10 downto 1) < 300
                              and (drawMode(3 downto 0) = x"A" or drawMode(3 downto 0) = x"B")) else '0';

   -- build #119 trigger: SDRAM write to cube display area
   -- vram_ADDR(20:11)=Y, vram_ADDR(10:3)=X[9:2]. Y in [40,200], X[9:2]<75 (= X<300).
   h19_cube_we <= '1' when (vram_WE = '1'
                            and unsigned(vram_ADDR(20 downto 11)) >= 40
                            and unsigned(vram_ADDR(20 downto 11)) <= 200
                            and unsigned(vram_ADDR(10 downto 3)) < 75) else '0';

   -- build #127: WIDER Y filter to catch any cube CLUT band activity.
   -- B125/B126 (Y=482 exact) showed write_R=read_R=0, suggesting cube CLUT might use different Y.
   -- Y∈[460,500] covers Y=462 (text font) + Y=480-487 (cube CLUT band per MAME).
   -- ANY X in range (no X restriction) — capture whatever the FPGA writes/reads in this Y band.
   h24_addr_match <= '1' when (unsigned(vram_ADDR(20 downto 11)) >= 460
                               and unsigned(vram_ADDR(20 downto 11)) <= 500) else '0';

   -- build #128: filters for cpu2vram and vram_DIN comparison
   -- cpu2vram_pixelAddr encoding: bits 20:11 = Y, bits 10:1 = X[9:0], bit 0 = '0'
   -- For lane 3 of a 64-bit word, pixelAddr[2:1] = "11"
   h28_cpu_addr_match  <= '1' when (cpu2vram_pixelWrite = '1'
                                    and cpu2vram_pixelAddr(20 downto 11) >= 460
                                    and cpu2vram_pixelAddr(20 downto 11) <= 500
                                    and cpu2vram_pixelAddr(2 downto 1) = "11") else '0';
   h28_vram_addr_match <= '1' when (vram_WE = '1'
                                    and unsigned(vram_ADDR(20 downto 11)) >= 460
                                    and unsigned(vram_ADDR(20 downto 11)) <= 500) else '0';

   -- build #133: same trigger as h28_cpu_addr_match (cube CLUT lane-3 cpu2vram write)
   h33_trigger <= h28_cpu_addr_match;

   dbg_h12_red_anchor        <= h12_red_anchor;
   dbg_h12_green_dm_ok       <= h12_green_dm_ok;
   dbg_h12_blue_dm_stale     <= h12_blue_dm_stale;
   dbg_h12_yellow_busy0      <= h12_yellow_busy0;
   dbg_h12_white_dm_chg      <= h12_white_dm_chg;
   dbg_h12_cyan_emit_busy0   <= h12_cyan_emit_busy0;
   dbg_h12_magenta_busy_long <= h12_magenta_busy_long;
   -- build #115: counter outputs (upper 9 bits of 16-bit counters = events/128, saturate at 65408)
   dbg_h12_stale_count_hi    <= std_logic_vector(h12_stale_count(15 downto 7));
   dbg_h12_ok_count_hi       <= std_logic_vector(h12_ok_count(15 downto 7));
   dbg_h12_stale_gt_ok       <= h12_stale_gt_ok_sticky;

   -- build #117: G+B stripping diagnostics
   dbg_h17_anchor            <= h17_anchor_sticky;
   dbg_h17_g_set             <= h17_g_sticky;
   dbg_h17_b_set             <= h17_b_sticky;

   -- build #119: vram_DIN G+B diagnostics
   dbg_h19_anchor            <= h19_anchor_sticky;
   dbg_h19_g_in_din          <= h19_g_in_din;
   dbg_h19_b_in_din          <= h19_b_in_din;

   -- build #120: counter outputs (upper 9 bits of 16-bit counter, saturate)
   dbg_h20_anchor_count_hi   <= std_logic_vector(h20_anchor_count(15 downto 7));
   dbg_h20_g_count_hi        <= std_logic_vector(h20_g_count(15 downto 7));
   dbg_h20_b_count_hi        <= std_logic_vector(h20_b_count(15 downto 7));

   -- build #122: vram_DOUT capture passthrough
   dbg_h22_anchor   <= h22_anchor_sig;
   dbg_h22_clut3_r  <= h22_clut3_r_sig;
   dbg_h22_clut3_g  <= h22_clut3_g_sig;

   -- build #124: SDRAM round-trip outputs
   dbg_h24_write_r       <= h24_write_r;
   dbg_h24_read_r        <= h24_read_r;
   dbg_h24_both_anchors  <= h24_write_anchor and h24_read_anchor;

   -- build #128: cpu2vram vs vram_DIN comparison outputs
   dbg_h28_cpu_r         <= h28_cpu_r;
   dbg_h28_vram_r        <= h28_vram_r;
   dbg_h28_both_anchors  <= h28_cpu_anchor and h28_vram_anchor;

   -- build #129: Tecmo bank diagnostic outputs
   dbg_h29_bank              <= h29_bank_at_cpu_write;
   dbg_h29_bank_anchor       <= h29_bank_anchor;
   dbg_h29_bank_ever_changed <= h29_bank_ever_changed;

   -- build #131: DMA delivery outputs
   dbg_h31_pixel1_r  <= h31_pixel1_r;
   dbg_h31_pixel2_r  <= h31_pixel2_r;
   dbg_h31_rich_ever <= h31_rich_ever;

   -- build #132: DMA R-value sticky outputs
   dbg_h32_r31_ever             <= h32_r31_ever;
   dbg_h32_r_high_ever          <= h32_r_high_ever;
   dbg_h32_pixel1_nonzero_ever  <= h32_pixel1_nonzero_ever;

   -- build #133: fifo_data_1 capture outputs
   dbg_h33_fifo_data_1_r  <= h33_fifo_data_1_r;
   dbg_h33_cpu_color_r    <= h33_cpu_color_r;
   dbg_h33_anchor         <= h33_anchor;
   dbg_h33_r31_ever       <= h33_fifo_data_1_r31_ever;

   -- build #134: fifoIn_Dout halfword stickys
   dbg_h34_lower_r31_ever  <= h34_lower_r31_ever;
   dbg_h34_upper_r31_ever  <= h34_upper_r31_ever;
   dbg_h34_upper_msb_ever  <= h34_upper_msb_ever;

   -- build #137: cpu2vram FSM latch-chain probes
   dbg_h37_input_r31_ever    <= h37_input_r31_ever_sig;
   dbg_h37_writing_r31_ever  <= h37_writing_r31_ever_sig;
   dbg_h37_latch_r31_ever    <= h37_latch_r31_ever_sig;

   -- build #138: cube-CLUT-specific lane probes
   dbg_h38_lane2_input_r31_ever <= h38_lane2_input_r31_ever_sig;
   dbg_h38_lane3_latch_r31_ever <= h38_lane3_latch_r31_ever_sig;
   dbg_h38_lane3_anchor_ever    <= h38_lane3_anchor_ever_sig;

   -- build #139: cube-shape Y observability probes
   dbg_h39_cubeshape_any_ever  <= h39_cubeshape_any_ever_sig;
   dbg_h39_cubeshape_y482_ever <= h39_cubeshape_y482_ever_sig;
   dbg_h39_cubeshape_y488_ever <= h39_cubeshape_y488_ever_sig;

   -- build #145: Y=482/480 pixelWrite probes
   dbg_h45_y482_anchor   <= h45_y482_anchor_sig;
   dbg_h45_y482_pixwrite <= h45_y482_pixwrite_sig;
   dbg_h45_y480_pixwrite <= h45_y480_pixwrite_sig;

   -- build #146-149: cpu2vram value-capture probes
   dbg_h46_y_minus_240 <= h46_y_minus_240_sig;
   dbg_h46_y_high_bit  <= h46_y_high_bit_sig;
   dbg_h46_anchor      <= h46_anchor_sig;
   dbg_h49_entry1_low  <= h49_entry1_low_sig;

   -- build #158: H4 cache-staleness probes
   dbg_h58_x_stale_seen <= h58_x_stale_seen_sig;
   dbg_h58_y_stale_seen <= h58_y_stale_seen_sig;
   dbg_h58_pixel_seen   <= h58_pixel_seen_sig;
   -- build #159: H7 CLUT load capture
   dbg_h59_loaded_entry0_lo <= h59_loaded_entry0_lo_sig;
   dbg_h59_loaded_y         <= h59_loaded_y_sig;
   dbg_h59_anchor           <= h59_anchor_sig;

   -- build #140: CLUT-RAM cube CLUT presence probes
   dbg_h40_cube_clut_loaded_ever <= h40_cube_clut_loaded_ever_sig;
   dbg_h40_clut_read_7fff_ever   <= h40_clut_read_7fff_ever_sig;
   dbg_h40_clut_read_023f_ever   <= h40_clut_read_023f_ever_sig;

   -- pixel writing fifo
   iSyncFifo_OUT: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 64 + 18 + 4 + 1,  -- 64bit data + 18 bit address + 4bit word enable + 1bit source=pipeline
      NEARFULLDISTANCE => 250
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoOut_reset,  
      Din      => fifoOut_Din,     
      Wr       => fifoOut_Wr,      
      Full     => open,    
      NearFull => fifoOut_NearFull,
      Dout     => fifoOut_Dout,    
      Rd       => fifoOut_Rd,      
      Empty    => fifoOut_Empty   
   );
   
   iSyncFifo_OUT2: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 256,
      DATAWIDTH        => 64,
      NEARFULLDISTANCE => 250
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoOut_reset,  
      Din      => fifoOut2_Din,     
      Wr       => fifoOut_Wr,      
      Full     => open,    
      NearFull => open,
      Dout     => fifoOut2_Dout,    
      Rd       => fifoOut_Rd,      
      Empty    => open
   );
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         fifoOut_Wr_1 <= fifoOut_Wr;
      
         fifoOut_Wr   <= '0';
         fifoOut_Din  <= pixel64source & pixel64wordEna & pixel64Addr & pixel64data;
         
         fifoOut2_Din <= pixel64data2;
      
         if (reset = '1') then
            
            pixel64filled <= '0';
            
         elsif (ce = '1') then
         
            if (vramFill_pixelWrite = '1') then
            
               fifoOut_Wr    <= '1';
               fifoOut_Din   <=  '1' & "1111" & std_logic_vector(vramFill_pixelAddr(20 downto 3)) & vramFill_pixelColor & vramFill_pixelColor & vramFill_pixelColor & vramFill_pixelColor;
               pixel64filled <= '0';
         
               fifoOut2_Din  <= x"0000000000000000";
         
            elsif (pixelWrite = '1') then
            
               pixel64timeout <= 15;
            
               if (pixel64filled = '0' or pixelAddr(20 downto 3) /= unsigned(pixel64Addr)) then
               
                  fifoOut_Wr <= pixel64filled;
               
                  pixel64Addr <= std_logic_vector(pixelAddr(20 downto 3));
                  case (pixelAddr(2 downto 1)) is
                     when "00" => pixel64data(15 downto  0) <= pixelColor; pixel64data2(15 downto  0) <= pixelColor2; pixel64wordEna <= "0001";
                     when "01" => pixel64data(31 downto 16) <= pixelColor; pixel64data2(31 downto 16) <= pixelColor2; pixel64wordEna <= "0010";
                     when "10" => pixel64data(47 downto 32) <= pixelColor; pixel64data2(47 downto 32) <= pixelColor2; pixel64wordEna <= "0100";
                     when "11" => pixel64data(63 downto 48) <= pixelColor; pixel64data2(63 downto 48) <= pixelColor2; pixel64wordEna <= "1000";
                     when others => null;
                  end case;
                  
                  pixel64filled <= '1';
               
               else
                  
                  case (pixelAddr(2 downto 1)) is
                     when "00" => pixel64data(15 downto  0) <= pixelColor; pixel64data2(15 downto  0) <= pixelColor2; pixel64wordEna(0) <= '1';
                     when "01" => pixel64data(31 downto 16) <= pixelColor; pixel64data2(31 downto 16) <= pixelColor2; pixel64wordEna(1) <= '1';
                     when "10" => pixel64data(47 downto 32) <= pixelColor; pixel64data2(47 downto 32) <= pixelColor2; pixel64wordEna(2) <= '1';
                     when "11" => pixel64data(63 downto 48) <= pixelColor; pixel64data2(63 downto 48) <= pixelColor2; pixel64wordEna(3) <= '1';
                     when others => null;
                  end case;

               end if;
               
               pixel64source <= pipeline_pixelWrite;
            
            elsif (pixel64timeout > 0) then
            
               pixel64timeout <= pixel64timeout - 1;
               if (pixel64timeout = 1 or pipeline_busy = '0') then
                  pixel64filled  <= '0';
                  fifoOut_Wr     <= '1';
                  pixel64timeout <= 0;
               end if;
               
            end if;
            
         end if;

      end if;
   end process;
   
   fifoOut_Rd <= '1' when (ce = '1' and vramState = IDLE and (vram_WE = '0' or vram_BUSY = '0') and fifoOut_Empty = '0' and reqVRAMEnable = '0' and vram_pause = '0') else '0';
   
   fifoOut_idle <= '1' when (fifoOut_Empty = '1' and fifoOut_Wr = '0' and fifoOut_Wr_1 = '0' and pixel64filled = '0') else '0';
   
   VRAMIdle    <= '1' when (vramState = IDLE and (vram_WE = '0' or vram_BUSY = '0')) else '0';
   reqVRAMIdle <= VRAMIdle and (not videoout_reqVRAMEnable) and (not vram_pause);
   
   reqVRAMEnable <= vram2vram_reqVRAMEnable or vram2cpu_reqVRAMEnable or line_reqVRAMEnable or rect_reqVRAMEnable or poly_reqVRAMEnable or pipeline_reqVRAMEnable or videoout_reqVRAMEnable;
   reqVRAMXPos   <= vram2vram_reqVRAMXPos   or vram2cpu_reqVRAMXPos   or line_reqVRAMXPos   or rect_reqVRAMXPos   or poly_reqVRAMXPos   or pipeline_reqVRAMXPos   or videoout_reqVRAMXPos  ;  
   reqVRAMYPos   <= vram2vram_reqVRAMYPos   or vram2cpu_reqVRAMYPos   or line_reqVRAMYPos   or rect_reqVRAMYPos   or poly_reqVRAMYPos   or pipeline_reqVRAMYPos   or videoout_reqVRAMYPos;
   reqVRAMSize   <= vram2vram_reqVRAMSize   or vram2cpu_reqVRAMSize   or line_reqVRAMSize   or rect_reqVRAMSize   or poly_reqVRAMSize   or pipeline_reqVRAMSize   or videoout_reqVRAMSize  ;  
   
   vramLineAddr  <= vram2vram_vramLineAddr when vram2vram_vramLineEna else 
                    vram2cpu_vramLineAddr when vram2cpu_vramLineEna else 
                    line_vramLineAddr  when line_vramLineEna else
                    rect_vramLineAddr  when rect_vramLineEna else
                    poly_vramLineAddr  when poly_vramLineEna else
                    (others => '0');
   
   video_frameindex <= "01" & std_logic_vector(frameindex_last) when (interlaced480pHack = '1') else x"0";
   
   -- vram access
   process (clk2x)
      variable reqVRAMSizeRounded : unsigned(10 downto 0);
   begin
      if rising_edge(clk2x) then
      
         if (vram_BUSY = '0') then
            vram_WE <= '0';
            vram_RD <= '0';
         end if;
         
         vram_paused <= '0';
         if (VRAMIdle = '1' and vram_pause = '1' and vram_WE = '0') then
            if (vram_pauseCnt = 3) then
               vram_paused <= '1';
            else
               vram_pauseCnt <= vram_pauseCnt + 1;
            end if;
         else
            vram_pauseCnt <= 0;
         end if;
         
         if (videoout_reports.irq_VBLANK = '1' and irq_VBLANK_1 = '0') then
            if (frameFastCount > 0 and interlaced480pHack = '1') then
               frameClearRequest <= '1';
               frameClearYPos    <= videoout_out.DisplayOffsetY;
               frameClearCnt     <= (others => '0');
               frameClearPosLow  <= frameFirstChangedLine;
               frameClearPosHigh <= frameLastChangedLine;
            end if;
         end if;
         
         if (reset = '1') then
            
            vramState   <= IDLE;
            reqVRAMDone <= '0';
            
         else
         
            reqVRAMDone <= '0';
         
            case (vramState) is
               when IDLE =>
                  if ((ce = '1' or (videoout_reqVRAMEnable = '1' and savestate_busy = '0')) and (vram_WE = '0' or vram_BUSY = '0') and vram_pause = '0') then
                     if (reqVRAMEnable = '1') then
                        reqVRAMStore  <= (not pipeline_reqVRAMEnable) and (not videoout_reqVRAMEnable);
                        reqVRAMSizeRounded := reqVRAMSize;
                        if (reqVRAMSize(1 downto 0) /= "00") then -- round up read size to full 4*16bit
                           reqVRAMSizeRounded(10 downto 2) := reqVRAMSizeRounded(10 downto 2) + 1;
                        end if;
                        if (reqVRAMXPos(1 downto 0) /= "00" and ((to_integer(reqVRAMXPos(1 downto 0)) + to_integer(reqVRAMSize) > 4))) then 
                           reqVRAMSizeRounded(10 downto 2) := reqVRAMSizeRounded(10 downto 2) + 1;
                        end if;
                        if (reqVRAMSizeRounded > 1024) then reqVRAMSizeRounded := to_unsigned(1024, 11); end if;
                        vramState     <= READVRAM;
                        vram_ADDR     <= "0000000" & std_logic_vector(reqVRAMYPos) & std_logic_vector(reqVRAMXPos(9 downto 2)) & "000";
                        if (videoout_reqVRAMEnable = '1' and videoout_reqRAMMirror = '1') then
                           vram_ADDR(27 downto 20) <= x"04";
                        end if;
                        reqVRAMtwice   <= '0';
                        reqVRAMStore2  <= '0';
                        if (render24 = '1' and (line_reqVRAMEnable = '1' or rect_reqVRAMEnable = '1' or poly_reqVRAMEnable = '1')) then
                           vramState               <= READSECOND;
                           reqVRAMStore2           <= '1';
                           reqVRAMtwice            <= '1';  
                           vram_ADDR(27 downto 20) <= x"04";
                        end if;
                        vram_RD       <= '1';
                        reqVRAMaddr   <= reqVRAMXPos(9 downto 2);
                        reqVRAMaddr2  <= reqVRAMXPos(9 downto 2);
                        if (reqVRAMSizeRounded > 512) then
                           vram_BURSTCNT  <= x"80";
                           reqVRAMremain  <= x"80" - 1;
                           reqVRAMremain2 <= x"80" - 1;
                           reqVRAMnext    <= resize((reqVRAMSizeRounded - 512) / 4, 8);
                        else
                           vram_BURSTCNT  <= std_logic_vector(reqVRAMSizeRounded(9 downto 2));
                           reqVRAMremain  <= reqVRAMSizeRounded(9 downto 2) - 1;
                           reqVRAMremain2 <= reqVRAMSizeRounded(9 downto 2) - 1;
                           reqVRAMnext    <= (others => '0');
                        end if;
                        reqVRAMwrap <= (others => '0');
                        if (vram2vram_reqVRAMEnable = '1' or vram2cpu_reqVRAMEnable = '1') then
                           if (reqVRAMXPos + reqVRAMSizeRounded > 1024) then
                              reqVRAMwrap <= resize(((reqVRAMXPos + reqVRAMSizeRounded) - 1024) / 4, 8);
                           end if;
                        end if;
                     elsif (fifoOut_Empty = '0') then
                        if (render24 = '1' or interlaced480pHack = '1') then
                           vramState   <= WRITESECOND;
                        end if;
                        vram_WE         <= '1';
                        vram_ADDR       <= "0000000" & fifoOut_Dout(81 downto 64) & "000";
                        vram_BE         <= fifoOut_Dout(85) & fifoOut_Dout(85) & fifoOut_Dout(84) & fifoOut_Dout(84) & fifoOut_Dout(83) & fifoOut_Dout(83) & fifoOut_Dout(82) & fifoOut_Dout(82);
                        vram_DIN        <= fifoOut_Dout(63 downto 0);
                        vram_BURSTCNT   <= x"01";
                        frameVramType   <= fifoOut_Dout(86);
                        fifoOut2_Dout_1 <= fifoOut2_Dout;
                        if (interlacedDrawing = '1' and interlaced480pHack = '1' and videoout_reports.activeLineLSB = fifoOut_Dout(72) and fifoOut_Dout(86) = '1') then
                           vram_WE    <= '0';
                        end if;
                     elsif (frameClearRequest = '1' and SS_Idle = '1') then
                        vramState      <= CLEARLINESTART;
                     end if;
                  end if;
                  
               when WRITESECOND =>
                  if (vram_BUSY = '0') then
                     vramState     <= IDLE;
                     vram_WE       <= '1';
                     if (render24 = '1') then
                        vram_ADDR(27 downto 20) <= x"04";
                        vram_DIN      <= fifoOut2_Dout_1;
                     elsif (interlaced480pHack = '1') then
                        vram_ADDR(27 downto 20) <= "000001" & std_logic_vector(frameindex_current);
                     end if;
                  end if;
                  
               when READSECOND =>
                  if (vram_DOUT_READY = '1') then
                     reqVRAMaddr2 <= reqVRAMaddr2 + 1;
                     if (reqVRAMremain2 > 0) then
                        reqVRAMremain2 <= reqVRAMremain2 - 1;
                     else
                        vramState               <= READVRAM;
                        reqVRAMStore2           <= '0';
                        vram_RD                 <= '1';
                        vram_ADDR(27 downto 21) <= "0000000";
                     end if;
                  end if;
                  
               when READVRAM =>
                  if (vram_DOUT_READY = '1') then
                     reqVRAMaddr <= reqVRAMaddr + 1;
                     if (reqVRAMremain > 0) then
                        reqVRAMremain <= reqVRAMremain - 1;
                     else
                        if (reqVRAMtwice = '1') then
                           vramState               <= READSECOND;
                           reqVRAMStore2           <= '1';
                           vram_ADDR(27 downto 20) <= x"04";
                        end if;
                        if (reqVRAMnext > 0) then
                           vram_ADDR(10)  <= '1';
                           vram_RD        <= '1';
                           vram_BURSTCNT  <= std_logic_vector(reqVRAMnext);
                           reqVRAMnext    <= (others => '0');
                           reqVRAMremain  <= (reqVRAMnext - 1);
                           reqVRAMremain2 <= (reqVRAMnext - 1);
                        elsif (reqVRAMwrap > 0) then
                           vram_ADDR(10 downto 0) <= (others => '0');
                           vram_RD        <= '1';
                           vram_BURSTCNT  <= std_logic_vector(reqVRAMwrap);
                           reqVRAMwrap    <= (others => '0');
                           reqVRAMaddr    <= (others => '0');
                           reqVRAMremain  <= (reqVRAMwrap - 1);
                           reqVRAMremain2 <= (reqVRAMwrap - 1);
                           if (reqVRAMwrap > 128) then
                              vram_BURSTCNT  <= x"80";
                              reqVRAMremain  <= x"80" - 1;
                              reqVRAMremain2 <= x"80" - 1;
                              reqVRAMnext    <= reqVRAMwrap - 128;
                           end if;
                        else
                           vramState   <= IDLE;
                           reqVRAMDone <= '1';
                        end if;
                     end if;
                  end if;
                  
               when CLEARLINESTART =>
                  vramState      <= IDLE;
                  frameClearCnt  <= frameClearCnt + 1;
                  frameClearXPos <= videoout_out.DisplayOffsetX(9 downto 2) & "00";
                  if (frameClearCnt = videoout_out.DisplayHeightReal) then
                     frameClearRequest <= '0';
                  elsif (frameClearCnt < frameClearPosLow or frameClearCnt > frameClearPosHigh) then
                     vramState      <= CLEARLINE;
                  else
                     frameClearYPos <= frameClearYPos + 1;
                  end if;
              
               when CLEARLINE =>
                  if (frameClearXPos > videoout_out.DisplayWidthReal + 3) then
                     vramState      <= IDLE;
                     frameClearYPos <= frameClearYPos + 1;
                  elsif (vram_BUSY = '0') then
                     vram_WE        <= '1';
                     vram_ADDR      <= "000001" & std_logic_vector(frameindex_current) & std_logic_vector(frameClearYPos) & std_logic_vector(frameClearXPos(9 downto 2)) & "000";
                     vram_BE        <= x"FF";
                     vram_DIN       <= (others => '0');
                     vram_BURSTCNT  <= x"01";
                     frameClearXPos <= frameClearXPos + 4;
                  end if;

            end case;
            
         end if;

      end if;
   end process;
   
   ilineram: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a  => 8,
      data_width_a  => 64,
      addr_width_b  => 10,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(reqVRAMaddr),
      data_a      => vram_DOUT,
      wren_a      => (vram_DOUT_READY and reqVRAMStore and (not reqVRAMStore2)),
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(vramLineAddr),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => vramLineData
   );
   
   ilineram2: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a  => 8,
      data_width_a  => 64,
      addr_width_b  => 10,
      data_width_b  => 16
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(reqVRAMaddr2),
      data_a      => vram_DOUT,
      wren_a      => (vram_DOUT_READY and reqVRAMStore2),
      
      clock_b     => clk2x,
      address_b   => std_logic_vector(vramLineAddr),
      data_b      => x"0000",
      wren_b      => '0',
      q_b         => vramLineData2
   );
   
--##############################################################
--############################### video out
--##############################################################
   
   videoout_settings.GPUSTAT_VerRes          <= GPUSTAT_VerRes;
   videoout_settings.GPUSTAT_PalVideoMode    <= GPUSTAT_PalVideoMode;
   videoout_settings.GPUSTAT_VertInterlace   <= GPUSTAT_VertInterlace;
   videoout_settings.GPUSTAT_HorRes2         <= GPUSTAT_HorRes2;
   videoout_settings.GPUSTAT_HorRes1         <= GPUSTAT_HorRes1;
   videoout_settings.GPUSTAT_ColorDepth24    <= GPUSTAT_ColorDepth24;
   videoout_settings.GPUSTAT_DisplayDisable  <= GPUSTAT_DisplayDisable;
   videoout_settings.vramRange               <= vramRange(18 downto 0);
   videoout_settings.hDisplayRange           <= hDisplayRange;
   videoout_settings.vDisplayRange           <= vDisplayRange;
   videoout_settings.pal60                   <= pal60;
   videoout_settings.syncInterlace           <= syncInterlace;
   videoout_settings.rotate180               <= rotate180;
   videoout_settings.fixedVBlank             <= fixedVBlank;
   videoout_settings.vCrop                   <= vCrop;
   videoout_settings.hCrop                   <= hCrop;
   videoout_settings.dither24                <= dither24;
   videoout_settings.render24                <= render24;
   
   videoout_ss_in.interlacedDisplayField  <= ss_timing_in(4)(19);
   videoout_ss_in.nextHCount              <= ss_timing_in(4)(11 downto 0);
   videoout_ss_in.vpos                    <= ss_timing_in(3)(24 downto 16);
   videoout_ss_in.vdisp                   <= ss_timing_in(4)(29 downto 21);
   videoout_ss_in.inVsync                 <= ss_timing_in(4)(17);
   videoout_ss_in.activeLineLSB           <= ss_timing_in(4)(20);
   videoout_ss_in.GPUSTAT_InterlaceField  <= ss_gpu_in(1)(13);
   videoout_ss_in.GPUSTAT_DrawingOddline  <= ss_gpu_in(1)(31);
   
   igpu_videoout : entity work.gpu_videoout
   port map
   (
      clk1x                      => clk1x,
      clk2x                      => clk2x,
      clkvid                     => clkvid,
      ce                         => ce,   
      reset                      => reset,
      softReset                  => softReset,
               
      allowunpause               => allowunpause,
      savestate_pause            => savestate_busy,
      system_paused              => system_paused,
               
      videoout_settings          => videoout_settings,
      videoout_reports           => videoout_reports,
         
      videoout_on                => videoout_on,
      syncVideoOut               => syncVideoOut,
            
      debugmodeOn                => debugmodeOn,
            
      fpscountOn                 => fpscountOn,
      fpscountBCD                => fpscountBCD,
   
      Gun1CrosshairOn            => Gun1CrosshairOn,
      Gun1X                      => Gun1X,
      Gun1Y_scanlines            => Gun1Y_scanlines,
      Gun1offscreen              => Gun1offscreen,
      Gun1IRQ10                  => Gun1IRQ10,
   
      Gun2CrosshairOn            => Gun2CrosshairOn,
      Gun2X                      => Gun2X,
      Gun2Y_scanlines            => Gun2Y_scanlines,
      Gun2offscreen              => Gun2offscreen,
      Gun2IRQ10                  => Gun2IRQ10,
            
      cdSlow                     => cdSlow,      
                                 
      errorOn                    => errorOn,  
      errorEna                   => errorEna, 
      errorCode                  => errorCode, 
      
      LBAOn                      => LBAOn,
      LBAdisplay                 => LBAdisplay,
                                 
      requestVRAMEnable          => videoout_reqVRAMEnable,
      requestVRAMMirror          => videoout_reqRAMMirror,
      requestVRAMXPos            => videoout_reqVRAMXPos,  
      requestVRAMYPos            => videoout_reqVRAMYPos,  
      requestVRAMSize            => videoout_reqVRAMSize,  
      requestVRAMIdle            => VRAMIdle and (not vram_pause),
      requestVRAMDone            => reqVRAMDone,
                                 
      vram_DOUT                  => vram_DOUT,      
      vram_DOUT_READY            => vram_DOUT_READY,
          
      videoout_out               => videoout_out,

      videoout_ss_in             => videoout_ss_in,
      videoout_ss_out            => videoout_ss_out,
      dbg_videoout_linebuf_nonnavy   => dbg_videoout_linebuf_nonnavy,
      dbg_videoout_pixeldata_nonnavy => dbg_videoout_pixeldata_nonnavy,
      dbg_dispread                   => dbg_dispread_sig,
      dbg_linebufrd                  => dbg_linebufrd_sig,
      dbg_vram_coord                 => dbg_vram_coord
   );
   
   video_hsync          <= videoout_out.hsync;         
   video_vsync          <= videoout_out.vsync;         
   video_hblank         <= videoout_out.hblank;        
   video_vblank         <= videoout_out.vblank;        
   video_DisplayOffsetX <= videoout_out.DisplayOffsetX;
   video_DisplayOffsetY <= videoout_out.DisplayOffsetY;
   video_DisplayWidth   <= videoout_out.DisplayWidthReal; 
   video_DisplayHeight  <= videoout_out.DisplayHeightReal;
   video_ce             <= videoout_out.ce;            
   video_interlace      <= videoout_out.interlace;     
   video_r              <= videoout_out.r;             
   video_g              <= videoout_out.g;             
   video_b              <= videoout_out.b;             
   video_isPal          <= videoout_out.isPal;
   video_hResMode       <= videoout_out.hResMode;
   
   dotclock             <= videoout_reports.dotclock;
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 7 loop
               ss_gpu_in(i)    <= (others => '0');
               ss_timing_in(i) <= (others => '0');
            end loop;
            
            ss_timing_in(0) <= x"0003FC10"; -- vDisplayRange
            ss_timing_in(1) <= x"00C60260"; -- hDisplayRange
            
         else
            if (SS_wren_GPU = '1') then
               ss_gpu_in(to_integer(SS_Adr)) <= SS_DataWrite;
            end if;
            if (SS_wren_Timing = '1') then
               ss_timing_in(to_integer(SS_Adr)) <= SS_DataWrite;
            end if;
         end if;
         
         SS_Idle <= '0';
         if (proc_idle = '1' and fifoIn_Empty = '1' and fifoOut_Empty = '1' and vramState = IDLE and pipeline_busy = '0' and fifoOut_Wr = '0' and pixelWrite = '0') then
            SS_Idle <= '1';
         end if;     

         if (SS_rden_GPU = '1') then
            SS_DataRead_GPU <= ss_gpu_out(to_integer(SS_Adr));
         end if;
         
         if (SS_rden_Timing = '1') then
            SS_DataRead_Timing <= ss_timing_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

   -- synthesis translate_off
   
   goutput : if 1 = 1 generate
      signal gpuFifoCount     : integer := 0;
      signal gpuDMAFifoCount  : integer := 0;
      signal gpuCPUFifoCount  : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_gpufifo_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_gpufifo_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (DMA_GPU_writeEna = '1' and gpuFifoCount >= 0 and gpuDMAFifoCount >= 0) then
               write(line_out, string'("Fifo: ")); 
               write(line_out, to_hstring(DMA_GPU_write));
               writeline(outfile, line_out);
               gpuFifoCount    <= gpuFifoCount + 1;
               gpuDMAFifoCount <= gpuDMAFifoCount + 1;
            end if;
            
            if (bus_write = '1' and bus_addr = 0 and gpuCPUFifoCount >= 0) then
               write(line_out, string'("Fifo: ")); 
               write(line_out, to_hstring(bus_dataWrite));
               writeline(outfile, line_out);
               gpuFifoCount    <= gpuFifoCount + 1;
               gpuCPUFifoCount <= gpuCPUFifoCount + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   goutput2 : if 1 = 1 generate
      signal pixelCount          : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
      begin
   
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\debug_pixel_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk2x);
            
            if (pixelWrite = '1' and pixelCount >= 0) then
            
               write(line_out, to_integer(pixelAddr(10 downto 1)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(pixelAddr(20 downto 11)));
               write(line_out, string'(" ")); 
               write(line_out, to_integer(unsigned(pixelColor)));
               writeline(outfile, line_out);
               pixelCount <= pixelCount + 1;
               
               if (render24 = '1') then
                  write(line_out, to_integer(pixelAddr(10 downto 1)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(pixelAddr(20 downto 11)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(unsigned(pixelColor(4 downto 0)) & unsigned(pixelColor2(2 downto 0))));
                  writeline(outfile, line_out);
                  
                  write(line_out, to_integer(pixelAddr(10 downto 1)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(pixelAddr(20 downto 11)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(unsigned(pixelColor(9 downto 5)) & unsigned(pixelColor2(5 downto 3))));
                  writeline(outfile, line_out);
                  
                  write(line_out, to_integer(pixelAddr(10 downto 1)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(pixelAddr(20 downto 11)));
                  write(line_out, string'(" ")); 
                  write(line_out, to_integer(unsigned(pixelColor(14 downto 10)) & unsigned(pixelColor2(8 downto 6))));
                  writeline(outfile, line_out);
                  
                  pixelCount <= pixelCount + 4;
               end if;
   
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput2;
   
   
   -- synthesis translate_on

end architecture;





