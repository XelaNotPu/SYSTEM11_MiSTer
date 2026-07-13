library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity gpu_pixelpipeline is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
	        
      noTexture            : in  std_logic;
      render24             : in  std_logic;
      drawSlow             : in  std_logic;
      gpuType1             : in  std_logic := '0';   -- 2026-07-06 interleaved-texture fix
      
      drawMode_in          : in  unsigned(13 downto 0) := (others => '0');
      DrawPixelsMask_in    : in  std_logic;
      SetMask_in           : in  std_logic;
	  
	  oldGPU               : in  std_logic;
      
      clearCacheTexture    : in  std_logic;
      clearCachePalette    : in  std_logic;
      
      fifoOut_idle         : in  std_logic;
      pipeline_busy        : out std_logic;
      pipeline_stall       : out std_logic;
      pipeline_new         : in  std_logic;
      pipeline_texture     : in  std_logic;
      pipeline_transparent : in  std_logic;
      pipeline_rawTexture  : in  std_logic;
      pipeline_dithering   : in  std_logic;
      pipeline_x           : in  unsigned(9 downto 0);
      pipeline_y           : in  unsigned(9 downto 0);
      pipeline_cr          : in  unsigned(7 downto 0);
      pipeline_cg          : in  unsigned(7 downto 0);
      pipeline_cb          : in  unsigned(7 downto 0);
      pipeline_u           : in  unsigned(7 downto 0);
      pipeline_v           : in  unsigned(7 downto 0);
      pipeline_filter      : in  std_logic;   
      pipeline_u11         : in  unsigned(7 downto 0);
      pipeline_v11         : in  unsigned(7 downto 0);
      pipeline_uAcc        : in  unsigned(7 downto 0);
      pipeline_vAcc        : in  unsigned(7 downto 0);
      
      requestVRAMEnable    : out std_logic;
      requestVRAMXPos      : out unsigned(9 downto 0);
      requestVRAMYPos      : out unsigned(9 downto 0);
      requestVRAMSize      : out unsigned(10 downto 0);
      requestVRAMIdle      : in  std_logic;
      requestVRAMDone      : in  std_logic;
      vram_DOUT            : in  std_logic_vector(63 downto 0);
      vram_DOUT_READY      : in  std_logic;
      
      vramLineData         : in  std_logic_vector(15 downto 0);
      vramLineData2        : in  std_logic_vector(15 downto 0);
      
      textPalInNew         : in  std_logic;
      textPalInX           : in  unsigned(9 downto 0);   
      textPalInY           : in  unsigned(9 downto 0);
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelColor2          : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(20 downto 0);
      pixelWrite           : out std_logic;
      -- build #7 debug taps
      dbg_clut_write_nonnavy : out std_logic;  -- CLUT was just written with a non-navy 16-bit lane this cycle
      dbg_clut_read_nonnavy  : out std_logic;  -- texdata_palette(0) currently non-navy AND non-zero
      dbg_stage4_texture     : out std_logic;  -- stage4 currently producing a textured-pixel write
      dbg_texel              : out std_logic_vector(31 downto 0); -- [31:16]=XOR of read texels [15:0]=last read texel (texdata_raw)
      dbg_uv                 : out std_logic_vector(31 downto 0); -- [31:24]=max U [23:16]=max V [15:8]=last U [7:0]=last V (textured pixels)
      -- build #8 debug taps (CLUT-load chain pinpoint)
      dbg_textPalReq_set     : out std_logic;  -- textPalReq is being driven '1' this cycle (gating passed)
      dbg_state_REQ_PAL      : out std_logic;  -- state machine currently in REQUESTPALETTE
      dbg_CLUTwrenA_any      : out std_logic;  -- CLUTwrenA asserted (CLUT was written, any data)
      dbg_drawMode_8         : out std_logic;  -- current drawMode bit 8 (15-bit direct texture mode)
      dbg_noTexture_pin      : out std_logic;  -- noTexture input value
      -- build #13: CLUT load address inspection
      dbg_textPalReqX_nonzero : out std_logic; -- textPalReqX != 0
      dbg_textPalReqY_nonzero : out std_logic; -- textPalReqY != 0
      dbg_textPalReqX_high_bit : out std_logic; -- textPalReqX bit 9 set (X >= 512)
      dbg_textPalReqY_high_bit : out std_logic; -- textPalReqY bit 8 set (Y >= 256)
      dbg_textPalReqX_bit8     : out std_logic; -- textPalReqX bit 8 set (X >= 256)
      -- build #26: cube-CLUT (X>=512) readback color forensics
      dbg_cubeclut_gb          : out std_logic; -- loaded CLUT X>=512 AND looked-up entry has G or B bits (cube CLUT read colorful)
      dbg_cubeclut_ronly       : out std_logic; -- loaded CLUT X>=512 AND looked-up entry has R but no G/B (cube CLUT read red-only)
      dbg_loclut_gb            : out std_logic; -- loaded CLUT X<512  AND looked-up entry has G or B bits (low-X CLUT read colorful = positive control)
      -- build #57: raw texel-index non-zero at stage4 (texture DATA present in VRAM, pre-CLUT)
      dbg_stage4_texraw_nz     : out std_logic;
      -- build #63: textPalReqY in [460,500) — gates CLUT loads targeting lpadv's CLUT-Y region
      dbg_textPalReqY_clut     : out std_logic;
      -- build #67: (textPalReqX, textPalReqY) of LAST high-Y CLUT load that returned real color
      dbg_last_succ_palX       : out std_logic_vector(9 downto 0);
      dbg_last_succ_palY       : out std_logic_vector(9 downto 0);
      -- build #68: split Y-range gates — [460,480) (working) vs [480,500) (suspected failing range)
      dbg_textPalReqY_lo       : out std_logic;
      dbg_textPalReqY_hi       : out std_logic;
      -- build #82: direct vram_DOUT capture at first hi-Y CLUTwrenA (textPalY=482, CLUTaddrA=0)
      -- Answers: does DDR3 return correct data, zero, or index-pattern at the failing CLUT addr?
      dbg_b82_byte_redslot     : out std_logic_vector(7 downto 0); -- vram_DOUT(31:24): expected 0x7F for entry 1 high byte
      dbg_b82_byte_greenslot   : out std_logic_vector(7 downto 0); -- vram_DOUT(23:16): expected 0xFF for entry 1 low byte
      dbg_b82_captured         : out std_logic;                    -- latch fired at least once
      -- build #102: fifo_data trace from gpu_poly when textPalY would become 507
      dbg_b102_poly_fifodata_in   : in std_logic_vector(31 downto 0) := (others => '0');
      dbg_b102_poly_y507_pulse_in : in std_logic := '0';
      -- build #122: vram_DOUT capture at first hi-Y CLUT[3] load
      dbg_h22_anchor              : out std_logic;
      dbg_h22_clut3_r             : out std_logic_vector(4 downto 0);
      dbg_h22_clut3_g             : out std_logic_vector(4 downto 0);
      -- build #140: was cube CLUT ever loaded into CLUT-RAM, and ever read back?
      -- Cube CLUT (4-bit, 16 entries) loads at CLUTaddrA=0..3 with vram_DOUT carrying
      -- entries 0-3 (at addr 0), 4-7 (addr 1), 8-11 (addr 2), 12-15 (addr 3).
      -- Expected entries 0..3 (MAME-verified): 0x0000, 0x7FFF, 0x023F, 0x3FFF.
      -- RED  : at CLUTwrenA + CLUTaddrA="000000" ever, vram_DOUT signature matches
      --        cube CLUT word 0 (entry1=0x7FFF AND entry2=0x023F simultaneously).
      --        Decisive: cube CLUT was loaded into CLUT-RAM with the correct values.
      -- GREEN: any CLUTDataB lane ever returned 0x7FFF (cube entry 1, white).
      --        Proves the GPU read-side of CLUT-RAM ever produced white.
      -- BLUE : any CLUTDataB lane ever returned 0x023F (cube entry 2, the unique R=31 G=1 B=0).
      --        Far more cube-specific than white. If LIT, cube CLUT IS used at rendering.
      dbg_h40_cube_clut_loaded_ever : out std_logic;
      dbg_h40_clut_read_7fff_ever   : out std_logic;
      dbg_h40_clut_read_023f_ever   : out std_logic;
      -- build #158: H4 (CLUT-RAM cache staleness) test.
      dbg_h58_x_stale_seen          : out std_logic := '0';
      dbg_h58_y_stale_seen          : out std_logic := '0';
      dbg_h58_pixel_seen            : out std_logic := '0';
      -- build #159: H7 (CLUT-RAM data staleness) — capture first non-trivial CLUT load.
      -- Anchor: FIRST CLUTwrenA='1' event with textPalReqY > 100 (skip BIOS-init noise).
      -- Latch vram_DOUT(15:0) (= CLUT entry 0 being loaded) and textPalReqY (10 bits).
      -- After test, /dev/mem read VRAM at the captured Y to verify the load delivered
      -- the correct data. Match → cache contents = VRAM contents → H7 REFUTED.
      dbg_h59_loaded_entry0_lo      : out std_logic_vector(8 downto 0) := (others => '0');
      dbg_h59_loaded_y              : out std_logic_vector(8 downto 0) := (others => '0');
      dbg_h59_anchor                : out std_logic := '0'
   );
end entity;

architecture arch of gpu_pixelpipeline is
  
   type tDitherMatrix is array(0 to 3, 0 to 3) of integer range -4 to 4;
   constant	DITHERMATRIX : tDitherMatrix := 
   (
		(-4, +0, -3, +1),
		(+2, -2, +3, -1),
		(-3, +1, -4, +0),
		(+3, -1, +2, -2)
	);
   
   type t_filterarray_u2  is array(0 to 3) of unsigned(1 downto 0);
   type t_filterarray_u8  is array(0 to 3) of unsigned(7 downto 0);
   type t_filterarray_u9  is array(0 to 3) of unsigned(8 downto 0);
   type t_filterarray_u10 is array(0 to 3) of unsigned(9 downto 0);
   type t_filterarray_u11 is array(0 to 3) of unsigned(10 downto 0);
   type t_filterarray_u20 is array(0 to 3) of unsigned(20 downto 0);
   type t_filterarray_b8  is array(0 to 3) of std_logic_vector(7 downto 0);
   type t_filterarray_b10 is array(0 to 3) of std_logic_vector(9 downto 0);
   type t_filterarray_b11 is array(0 to 3) of std_logic_vector(10 downto 0);
   type t_filterarray_b16 is array(0 to 3) of std_logic_vector(15 downto 0);
   type t_filterarray_b64 is array(0 to 3) of std_logic_vector(63 downto 0);
   
   signal drawMode            : unsigned(13 downto 0) := (others => '0');
   signal DrawPixelsMask      : std_logic := '0';
   signal SetMask             : std_logic := '0';
   signal palette8bit         : std_logic := '0';
  
   signal tag_addr            : t_filterarray_u8;
   signal tag_data            : t_filterarray_u11;
   signal tag_data_1          : t_filterarray_u11;

   signal tag_address_a       : unsigned(7 downto 0) := (others => '0');
   signal tag_data_a          : std_logic_vector(10 downto 0) := (others => '0');
   signal tag_wren_a          : std_logic := '0';
   signal tag_q_b             : t_filterarray_b11;
      
   signal tagValid            : std_logic_vector(0 to 255) := (others => '0');
      
   signal cache_address_a     : unsigned(7 downto 0) := (others => '0');
   signal cache_wren_a        : std_logic := '0';
   signal cache_address_b     : t_filterarray_u8;
   signal tag_addr_1          : t_filterarray_u8;
   signal cache_q_b           : t_filterarray_b64;
   signal cachehit            : std_logic_vector(0 to 3);
   signal cacherequest        : std_logic_vector(0 to 3) := (others => '0');
      
   signal CLUTaddrA           : unsigned(5 downto 0) := (others => '0');
   signal CLUTwrenA           : std_logic;
   signal CLUTaddrB           : t_filterarray_b8;
   signal CLUTDataB           : t_filterarray_b16;
   -- build #100: 64-bit raw output from same-width CLUT-RAM, lane-extracted to CLUTDataB
   signal clut_full_64        : t_filterarray_b64;
   -- build #121: shadow registers for low-index CLUT entries (bypass dpram for indices 0-31)
   -- Per memory B97/B98/B99: dpram writes CLUT[0]=0x0000 but reads back 0x0016. The dpram (or
   -- mem-mapped fitting) has a read-after-write issue at low indices. Discrete registers avoid it.
   -- 8 × 64-bit covers dpram addresses 0-7 = CLUT indices 0-31 (in 4-bit mode, 4 entries per word).
   type t_clut_shadow is array(0 to 7) of std_logic_vector(63 downto 0);
   signal clut_shadow         : t_clut_shadow := (others => (others => '0'));
   signal clut_shadow_q_b     : t_filterarray_b64;
   signal clut_use_shadow_d1  : std_logic_vector(3 downto 0) := (others => '0');
   signal clut_full_64_muxed  : t_filterarray_b64;

   -- build #140: CLUT-RAM cube CLUT presence probes (sticky, see entity port comment)
   signal h40_cube_clut_loaded_ever : std_logic := '0';
   signal h40_clut_read_7fff_ever   : std_logic := '0';
   signal h40_clut_read_023f_ever   : std_logic := '0';
   -- build #158: H4 cache-staleness sticky bits
   signal h58_x_stale_seen          : std_logic := '0';
   signal h58_y_stale_seen          : std_logic := '0';
   signal h58_pixel_seen            : std_logic := '0';
   -- build #159: H7 data-staleness capture
   signal h59_anchor                : std_logic := '0';
   signal h59_loaded_entry0         : std_logic_vector(15 downto 0) := (others => '0');
   signal h59_loaded_y              : unsigned(9 downto 0) := (others => '0');

   -- build #122: capture vram_DOUT at first hi-Y CLUT load (CLUTaddrA=0, textPalReqY in cube range)
   -- to test whether vram_DOUT itself delivers the index-pattern data, or whether storage corrupts.
   -- vram_DOUT bits 63:48 = CLUT[3] (since CLUTaddrA=0 stores entries 0-3 in 4 lanes).
   -- Cube bug shows CLUT[3] = 0x0003 (index pattern). MAME ground truth says CLUT[3] != 0x0003.
   -- If captured R bits = 3, vram_DOUT delivered the bug → bug is UPSTREAM of CLUT-RAM.
   -- If captured R bits = 0 (or some other value), dpram/shadow corrupts on read.
   signal h22_anchor          : std_logic := '0';
   signal h22_clut3_r         : std_logic_vector(4 downto 0) := (others => '0');
   signal h22_clut3_g         : std_logic_vector(4 downto 0) := (others => '0');
   signal CLUTaddrB_lane_d1   : t_filterarray_u2 := (others => (others => '0'));
  
   signal clearCacheBuffer    : std_logic := '0';
   
   signal textPalReq          : std_logic := '0';
   signal textPalReqX         : unsigned(9 downto 0) := (others => '0');  
   signal textPalReqY         : unsigned(9 downto 0) := (others => '0');
  
   signal textPalFetched      : std_logic := '0';
   signal textPalX            : unsigned(9 downto 0) := (others => '0');   
   signal textPalY            : unsigned(9 downto 0) := (others => '0');
   signal textPalFetchNext    : integer range 0 to 3;
   -- build #67: last_succ_palX/Y retained (output ports); driver removed in cleanup (sticky stays at reset value).
   signal last_succ_palX      : unsigned(9 downto 0) := (others => '0');
   signal last_succ_palY      : unsigned(9 downto 0) := (others => '0');
  
   type tState is
   (
      IDLE,
      REQUESTMORETEXTURE,
      REQUESTTEXTURE,
      WAITTEXTURE,
      REQUESTPALETTE,
      WAITPALETTE
   );
   signal state : tState := IDLE;
   
   signal pipeline_stall_1    : std_logic := '0';
   
   signal slowdown            : std_logic := '0';
   
   signal reqVRAMXPos         : unsigned(9 downto 0)  := (others => '0');
   signal reqVRAMYPos         : unsigned(9 downto 0)  := (others => '0');
   signal reqVRAMSize         : unsigned(10 downto 0) := (others => '0');
  
   signal stageS_valid        : std_logic := '0';
   signal stageS_texture      : std_logic := '0';
   signal stageS_transparent  : std_logic := '0';
   signal stageS_rawTexture   : std_logic := '0';
   signal stageS_dithering    : std_logic := '0';
   signal stageS_x            : unsigned(9 downto 0) := (others => '0');
   signal stageS_y            : unsigned(9 downto 0) := (others => '0');
   signal stageS_cr           : unsigned(7 downto 0) := (others => '0');
   signal stageS_cg           : unsigned(7 downto 0) := (others => '0');
   signal stageS_cb           : unsigned(7 downto 0) := (others => '0');
   signal stageS_u            : unsigned(7 downto 0) := (others => '0');
   signal stageS_v            : unsigned(7 downto 0) := (others => '0');
   signal stageS_filter       : std_logic := '0';   
   signal stageS_u11          : unsigned(7 downto 0) := (others => '0');
   signal stageS_v11          : unsigned(7 downto 0) := (others => '0');   
   signal stageS_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stageS_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stageS_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stageS_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');

   signal stage0_valid        : std_logic := '0';
   signal stage0_texture      : std_logic := '0';
   signal stage0_transparent  : std_logic := '0';
   signal stage0_rawTexture   : std_logic := '0';
   signal stage0_dithering    : std_logic := '0';
   signal stage0_x            : unsigned(9 downto 0) := (others => '0');
   signal stage0_y            : unsigned(9 downto 0) := (others => '0');
   signal stage0_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage0_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage0_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage0_u            : unsigned(7 downto 0) := (others => '0');
   signal stage0_v            : unsigned(7 downto 0) := (others => '0');
   signal stage0_filter       : std_logic := '0';   
   signal stage0_u11          : unsigned(7 downto 0) := (others => '0');
   signal stage0_v11          : unsigned(7 downto 0) := (others => '0');   
   signal stage0_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage0_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage0_oldPixel     : std_logic_vector(15 downto 0);
   signal stage0_oldPixel2    : std_logic_vector(15 downto 0);
   
   signal stage0_u_array      : t_filterarray_u8;
   signal stage0_v_array      : t_filterarray_u8;
   signal stage0_textaddr     : t_filterarray_u20;
   signal stage0_textaddr_1   : t_filterarray_u20;
   
   signal stage1_valid        : std_logic := '0';
   signal stage1_texture      : std_logic := '0';
   signal dbg_texel_xor       : std_logic_vector(15 downto 0) := (others => '0');
   signal dbg_texel_last      : std_logic_vector(15 downto 0) := (others => '0');
   signal dbg_max_u           : unsigned(7 downto 0) := (others => '0');
   signal dbg_max_v           : unsigned(7 downto 0) := (others => '0');
   signal dbg_last_u          : unsigned(7 downto 0) := (others => '0');
   signal dbg_last_v          : unsigned(7 downto 0) := (others => '0');
   signal stage1_transparent  : std_logic := '0';
   signal stage1_rawTexture   : std_logic := '0';
   signal stage1_dithering    : std_logic := '0';
   signal stage1_x            : unsigned(9 downto 0) := (others => '0');
   signal stage1_y            : unsigned(9 downto 0) := (others => '0');
   signal stage1_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage1_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage1_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage1_u            : t_filterarray_u8;
   signal stage1_filter       : std_logic := '0';   
   signal stage1_uAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage1_vAcc         : unsigned(7 downto 0) := (others => '0');
   signal stage1_oldPixel     : std_logic_vector(15 downto 0);
   signal stage1_oldPixel2    : std_logic_vector(15 downto 0);
   
   signal stage1_u_mux        : t_filterarray_u2;
   signal texdata_raw         : t_filterarray_b16;
   
   signal stage2_valid        : std_logic := '0';
   signal stage2_texture      : std_logic := '0';
   signal stage2_transparent  : std_logic := '0';
   signal stage2_rawTexture   : std_logic := '0';
   signal stage2_dithering    : std_logic := '0';
   signal stage2_x            : unsigned(9 downto 0) := (others => '0');
   signal stage2_y            : unsigned(9 downto 0) := (others => '0');
   signal stage2_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage2_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage2_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage2_filter       : std_logic := '0';   
   signal stage2_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage2_texdata      : t_filterarray_b16;
   
   signal texdata_palette     : t_filterarray_b16;
   
   type ttexcolor is array(0 to 3, 0 to 2) of unsigned(4 downto 0); 
   signal texcolor            : ttexcolor;
   
   signal colorIgnore         : std_logic_vector(0 to 3);
   
   signal filtermults         : t_filterarray_u9;
   
   type tcolormults is array(0 to 3, 0 to 2) of unsigned(13 downto 0); 
   signal colormults          : tcolormults;   
   
   type tcolormultadds is array(0 to 2) of unsigned(14 downto 0); 
   signal colormultadds       : tcolormultadds;
   
   type tfiltercolors is array(0 to 2) of unsigned(7 downto 0);
   signal filtercolors        : tfiltercolors;
   
   signal filtercolor_alpha   : std_logic; 
   
   signal useFilter           : std_logic;
   signal texdata_r           : unsigned(7 downto 0);
   signal texdata_g           : unsigned(7 downto 0);
   signal texdata_b           : unsigned(7 downto 0);
   signal texdata_alpha       : std_logic; 
   
   signal stage3_valid        : std_logic := '0';
   signal stage3_texture      : std_logic := '0';
   signal stage3_transparent  : std_logic := '0';
   signal stage3_rawTexture   : std_logic := '0';
   signal stage3_dithering    : std_logic := '0';
   signal stage3_x            : unsigned(9 downto 0) := (others => '0');
   signal stage3_y            : unsigned(9 downto 0) := (others => '0');
   signal stage3_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage3_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage3_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage3_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage3_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage3_tex_r        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_g        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_b        : unsigned(4 downto 0) := (others => '0');
   signal stage3_tex_alpha    : std_logic := '0';
   signal stage3_useFilter    : std_logic := '0';
   
   signal stage4_valid        : std_logic := '0';
   signal stage4_texture      : std_logic := '0';
   -- build #57: raw texel-index non-zero, propagated stage2->stage3->stage4 to align with stage4_texture
   signal stage2_texraw_nz    : std_logic := '0';
   signal stage3_texraw_nz    : std_logic := '0';
   signal stage4_texraw_nz    : std_logic := '0';
   signal stage4_transparent  : std_logic := '0';
   signal stage4_rawTexture   : std_logic := '0';
   signal stage4_dithering    : std_logic := '0';
   signal stage4_x            : unsigned(9 downto 0) := (others => '0');
   signal stage4_y            : unsigned(9 downto 0) := (others => '0');
   signal stage4_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage4_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage4_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage4_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage4_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   signal stage4_ditherAdd    : integer range -4 to 4;
   signal stage4_tex_r        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_g        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_b        : unsigned(7 downto 0) := (others => '0');
   signal stage4_tex_alpha    : std_logic := '0';
   signal stage4_useFilter    : std_logic := '0';
   
   signal stage5_valid        : std_logic := '0';
   signal stage5_transparent  : std_logic := '0';
   signal stage5_alphacheck   : std_logic := '0';
   signal stage5_alphabit     : std_logic := '0';
   signal stage5_x            : unsigned(9 downto 0) := (others => '0');
   signal stage5_y            : unsigned(9 downto 0) := (others => '0');
   signal stage5_cr           : unsigned(7 downto 0) := (others => '0');
   signal stage5_cg           : unsigned(7 downto 0) := (others => '0');
   signal stage5_cb           : unsigned(7 downto 0) := (others => '0');
   signal stage5_texture      : std_logic := '0';  -- build #27: stage5 carries a textured-pixel result
   signal stage3_dm8          : std_logic := '0';  -- build #31: drawMode(8) (15-bit-direct vs CLUT) captured with the texel
   signal stage4_dm8          : std_logic := '0';
   signal stage5_dm8          : std_logic := '0';
   signal stage3_dm3          : std_logic := '0';  -- build #32: drawMode(3) (texpage X base >=512 = cube) carried with the texel
   signal stage4_dm3          : std_logic := '0';
   signal stage5_dm3          : std_logic := '0';
   signal stage3_dm7          : std_logic := '0';  -- build #33: drawMode(7) (4-bit=0 / 8-bit=1 CLUT) carried with the texel
   signal stage4_dm7          : std_logic := '0';
   signal stage5_dm7          : std_logic := '0';
   signal clutload_seen       : std_logic := '0';  -- build #35: an 8-bit CLUT LOAD word arrived from VRAM (control)
   signal clutload_red        : std_logic := '0';  -- build #35: a loaded entry (vram_DOUT lane) was RED-only -> VRAM holds red (upload/storage)
   signal clutload_green      : std_logic := '0';  -- build #35: a loaded entry was GREEN (R clear) -> VRAM holds the correct green ramp
   signal stage5_oldPixel     : std_logic_vector(15 downto 0) := (others => '0');
   signal stage5_oldPixel2    : std_logic_vector(15 downto 0) := (others => '0');
   
   signal stage6_valid        : std_logic := '0';
   signal stage6_alphabit     : std_logic := '0';
   signal stage6_x            : unsigned(9 downto 0) := (others => '0');
   signal stage6_y            : unsigned(9 downto 0) := (others => '0');
   signal stage6_cr           : std_logic_vector(7 downto 0) := (others => '0');
   signal stage6_cg           : std_logic_vector(7 downto 0) := (others => '0');
   signal stage6_cb           : std_logic_vector(7 downto 0) := (others => '0');
  
begin 

   pipeline_stall <= '1' when (pixelStall = '1' or state /= IDLE or slowdown = '1') else '0';

   requestVRAMEnable <= '1'         when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else '0';
   requestVRAMXPos   <= reqVRAMXPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   requestVRAMYPos   <= reqVRAMYPos when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   requestVRAMSize   <= reqVRAMSize when (requestVRAMIdle = '1' and (state = REQUESTTEXTURE or (state = REQUESTPALETTE and fifoOut_idle = '1'))) else (others => '0');
   
   stage0_u_array(0) <= stage0_u; 
   stage0_u_array(1) <= stage0_u;
   stage0_u_array(2) <= stage0_u11;
   stage0_u_array(3) <= stage0_u11;
   
   stage0_v_array(0) <= stage0_v; 
   stage0_v_array(1) <= stage0_v11;
   stage0_v_array(2) <= stage0_v;
   stage0_v_array(3) <= stage0_v11;

   gfiltermemmult : for i in 0 to 3 generate
   begin
   
      itagram : entity mem.RamMLAB
      GENERIC MAP
      (
         width                               => 11,
         widthad                             => 8
      )
      PORT MAP (
         inclock    => clk2x,
         wren       => tag_wren_a,
         data       => tag_data_a,
         wraddress  => std_logic_vector(tag_address_a),
         rdaddress  => std_logic_vector(tag_addr(i)),
         q          => tag_q_b(i)
      );

      -- 64x64 pixel for 4bit mode, 32*64 for 8bit mode, 32*32 for 15 bit mode
      -- tag_addr unchanged from PSX base: captures V[5:0] (4-bit) or V[4:0] (8-bit) + U bits
      tag_addr(i) <= stage0_textaddr(i)(16 downto 11) & stage0_textaddr(i)(4 downto 3) when drawMode(8) = '0' else
                  stage0_textaddr(i)(15 downto 11) & stage0_textaddr(i)(5 downto 3);

      -- tag_data extended to 11 bits: adds drawMode(11) (Y page high bit) at [20] while preserving V[7:6]
      tag_data(i) <= drawMode(8) & stage0_textaddr(i)(20 downto 17) & stage0_textaddr(i)(10 downto 5) when drawMode(8) = '0' else
                     drawMode(8) & stage0_textaddr(i)(20 downto 16) & stage0_textaddr(i)(10 downto 6);
      
      -- 2026-07-06 INTERLEAVED-TEXTURE FIX (CXD8538Q/System 11, tpage bit13 = ti; MAME
      -- TEXTUREINTERLEAVED4BIT/8BIT): texels are stored tile-swizzled; remap (u,v) into the
      -- halfword address. Texel-in-halfword select (u&3 / u&1) is IDENTICAL to linear mode,
      -- so only the address bits change and the downstream nibble/byte extract is untouched.
      --   4bpp: hw_x = tx*64 + {v[3:0],u[3:2]};        v_eff = {v[7:4],u[7:4]}
      --   8bpp: hw_x = tx*64 + {u[4],v[2:0],u[3:1]};   v_eff = {v[7:3],u[7:5]}
      --   15bpp: linear (no swizzle).
      stage0_textaddr(i)(20 downto 11) <=
         drawMode(11) & drawMode(4) & stage0_v_array(i)(7 downto 4) & stage0_u_array(i)(7 downto 4)
            when (gpuType1 = '1' and drawMode(13) = '1' and drawMode(8 downto 7) = "00") else
         drawMode(11) & drawMode(4) & stage0_v_array(i)(7 downto 3) & stage0_u_array(i)(7 downto 5)
            when (gpuType1 = '1' and drawMode(13) = '1' and drawMode(8 downto 7) = "01") else
         drawMode(11) & drawMode(4) & stage0_v_array(i);
      stage0_textaddr(i)(0)            <= '0';
      stage0_textaddr(i)(10 downto 1)  <=
         (drawMode(3 downto 0) & "000000") + (stage0_v_array(i)(3 downto 0) & stage0_u_array(i)(3 downto 2))
            when (gpuType1 = '1' and drawMode(13) = '1' and drawMode(8 downto 7) = "00") else
         (drawMode(3 downto 0) & "000000") + (stage0_u_array(i)(4) & stage0_v_array(i)(2 downto 0) & stage0_u_array(i)(3 downto 1))
            when (gpuType1 = '1' and drawMode(13) = '1' and drawMode(8 downto 7) = "01") else
         (drawMode(3 downto 0) & "000000") + stage0_u_array(i)(7 downto 2) when drawMode(8 downto 7) = "00" else
         (drawMode(3 downto 0) & "000000") + stage0_u_array(i)(7 downto 1) when drawMode(8 downto 7) = "01" else
         (drawMode(3 downto 0) & "000000") + stage0_u_array(i);
      
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 64)
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(cache_address_a),
         data_a      => vram_DOUT,
         wren_a      => cache_wren_a,
         
         clock_b     => clk2x,
         address_b   => std_logic_vector(cache_address_b(i)),
         data_b      => x"0000000000000000",
         wren_b      => '0',
         q_b         => cache_q_b(i)
      );
      
      cache_address_b(i) <= tag_addr_1(i) when (pipeline_stall = '1') else tag_addr(i);
   
      cachehit(i)        <= '1' when (unsigned(tag_q_b(i)) = tag_data(i) and tagValid(to_integer(tag_addr(i))) = '1') else '0';
   
      stage1_u_mux(i)    <= stage1_u(i)(3 downto 2) when drawMode(8 downto 7) = "00" else
                            stage1_u(i)(2 downto 1) when drawMode(8 downto 7) = "01" else
                            stage1_u(i)(1 downto 0);
   
      texdata_raw(i)     <= cache_q_b(i)(15 downto  0) when (stage1_u_mux(i) = "00") else
                            cache_q_b(i)(31 downto 16) when (stage1_u_mux(i) = "01") else
                            cache_q_b(i)(47 downto 32) when (stage1_u_mux(i) = "10") else
                            cache_q_b(i)(63 downto 48);
      
      -- build #100: replace mixed-width dpram_dif (which had write/read alignment bug at port A→B
      -- causing CLUT-RAM[0] to read 0x0016 when written 0x0000) with same-width dpram (64-bit
      -- on both ports). Extract the 16-bit lane in user logic using CLUTaddrB(i)(1:0).
      iCLUTram: entity work.dpram
      generic map
      (
         addr_width => 6,
         data_width => 64
      )
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(CLUTaddrA),
         data_a      => vram_DOUT,
         wren_a      => CLUTwrenA,

         clock_b     => clk2x,
         clken_b     => (not pipeline_stall),
         address_b   => CLUTaddrB(i)(7 downto 2),  -- top 6 bits = 64-entry address
         data_b      => x"0000000000000000",
         wren_b      => '0',
         q_b         => clut_full_64(i)
      );
      
      CLUTaddrB(i) <= x"0" & texdata_raw(i)( 3 downto  0) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "00") else
                      x"0" & texdata_raw(i)( 7 downto  4) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "01") else
                      x"0" & texdata_raw(i)(11 downto  8) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "10") else
                      x"0" & texdata_raw(i)(15 downto 12) when (drawMode(7) = '0' and stage1_u(i)(1 downto 0) = "11") else
                      texdata_raw(i)( 7 downto 0) when (drawMode(7) = '1' and stage1_u(i)(0) = '0') else
                      texdata_raw(i)(15 downto 8);

      -- build #100: register the lane bits to align with dpram's registered-address one-cycle read latency.
      -- Honor pipeline_stall same as the dpram's clken_b so we don't drift out of sync.
      process (clk2x)
      begin
         if rising_edge(clk2x) then
            if (pipeline_stall = '0') then
               CLUTaddrB_lane_d1(i) <= unsigned(CLUTaddrB(i)(1 downto 0));
            end if;
         end if;
      end process;

      -- build #121: shadow CLUT read for low indices (0-31) — bypasses dpram for these entries.
      -- CLUTaddrB(i)(7:5)="000" means CLUTaddrB < 32 → top-6-bit address < 8 → covered by shadow.
      -- Register one cycle to match dpram's read latency.
      process (clk2x)
      begin
         if rising_edge(clk2x) then
            if (pipeline_stall = '0') then
               if (CLUTaddrB(i)(7 downto 5) = "000") then
                  clut_use_shadow_d1(i) <= '1';
               else
                  clut_use_shadow_d1(i) <= '0';
               end if;
               clut_shadow_q_b(i) <= clut_shadow(to_integer(unsigned(CLUTaddrB(i)(4 downto 2))));
            end if;
         end if;
      end process;

      -- build #121: mux dpram output with shadow output (shadow for low indices)
      clut_full_64_muxed(i) <= clut_shadow_q_b(i) when clut_use_shadow_d1(i) = '1' else clut_full_64(i);

      -- build #100: lane-extract the 16-bit CLUT entry from the 64-bit raw word.
      -- build #121: source from muxed signal (dpram OR shadow depending on index).
      CLUTDataB(i) <= clut_full_64_muxed(i)(15 downto  0) when CLUTaddrB_lane_d1(i) = "00" else
                      clut_full_64_muxed(i)(31 downto 16) when CLUTaddrB_lane_d1(i) = "01" else
                      clut_full_64_muxed(i)(47 downto 32) when CLUTaddrB_lane_d1(i) = "10" else
                      clut_full_64_muxed(i)(63 downto 48);

      texdata_palette(i) <= stage2_texdata(i) when (drawMode(8) = '1') else CLUTDataB(i);
          
      colorIgnore(i) <= '1' when (texdata_palette(i) = x"0000") else '0';
          
      texcolor(i,0) <= unsigned(texdata_palette(i)( 4 downto  0));
      texcolor(i,1) <= unsigned(texdata_palette(i)( 9 downto  5));
      texcolor(i,2) <= unsigned(texdata_palette(i)(14 downto 10));
          
   end generate;

   -- build #121: shadow CLUT write process (shared across all i). Fires on CLUTwrenA='1'
   -- when CLUTaddrA < 8 (= dpram addresses 0-7 = CLUT indices 0-31 in 4-bit mode).
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (CLUTwrenA = '1' and CLUTaddrA(5 downto 3) = "000") then
            clut_shadow(to_integer(CLUTaddrA(2 downto 0))) <= vram_DOUT;
         end if;
      end if;
   end process;

   -- build #122 (rev B123): capture vram_DOUT lane 3 (CLUT[3]) at EVERY hi-Y CLUTwrenA event.
   -- Non-sticky update — keeps overwriting so bars reflect the MOST RECENT load to dpram[0].
   -- That's the value shadow(0)[63:48] holds at cube render time.
   -- Anchor still sticks LIT once any event fires.
   -- B122 showed FIRST event delivers rich data (R=10, G=9); B123 reveals if later loads overwrite with index pattern.
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (CLUTwrenA = '1'
             and CLUTaddrA = "000000"
             and textPalReqY >= 460
             and textPalReqY <= 500) then
            h22_anchor   <= '1';
            h22_clut3_r  <= vram_DOUT(52 downto 48);  -- R channel of CLUT[3] (overwritten each event)
            h22_clut3_g  <= vram_DOUT(57 downto 53);  -- G channel of CLUT[3]
         end if;
      end if;
   end process;

   cache_wren_a      <= '1' when (vram_DOUT_READY = '1' and state = WAITTEXTURE) else '0';

   CLUTwrenA         <= '1' when (vram_DOUT_READY = '1' and state = WAITPALETTE) else '0';

   filtercolor_alpha <= texdata_palette(0)(15) or texdata_palette(1)(15) or texdata_palette(2)(15) or texdata_palette(3)(15);
   
   useFilter         <= '1' when (stage2_filter = '1' and colorIgnore = "0000") else '0';

   gfilterColormult : for i in 0 to 2 generate
   begin
   
      colormultadds(i) <= resize(colormults(0,i), 15) + resize(colormults(1,i), 15) + resize(colormults(2,i), 15) + resize(colormults(3,i), 15);
      
      filtercolors(i) <= colormultadds(i)(14 downto 7);
      
   end generate;
   

   
   
   pipeline_busy <= pipeline_stall or stage0_valid or stage1_valid or stage2_valid or stage3_valid or stage4_valid or stage5_valid or stage6_valid;
   
   process (clk2x)
      variable selectIndex : integer range 0 to 3;
      variable colorTr     : unsigned(15 downto 0);
      variable colorTg     : unsigned(15 downto 0);
      variable colorTb     : unsigned(15 downto 0);      
      variable colorDr     : integer range -4 to 4095;
      variable colorDg     : integer range -4 to 4095;
      variable colorDb     : integer range -4 to 4095;
      variable colorBGr    : unsigned(7 downto 0);
      variable colorBGg    : unsigned(7 downto 0);
      variable colorBGb    : unsigned(7 downto 0);
      variable colorMixr   : integer range -255 to 511;
      variable colorMixg   : integer range -255 to 511;
      variable colorMixb   : integer range -255 to 511;
   begin
      if rising_edge(clk2x) then
         
         tag_wren_a    <= '0';
         
         -- must be done here, so it also is effected when ce is off = paused
         if (state = WAITTEXTURE) then
            if (requestVRAMDone = '1') then 
               if (cacherequest = "0000") then
                  state <= IDLE;
               else
                  state <= REQUESTMORETEXTURE;
               end if;
            end if;
            if (vram_DOUT_READY = '1') then
               tag_wren_a    <= '1';
               tagValid(to_integer(tag_address_a)) <= '1';
            end if;
         end if;
               
         if (state = WAITPALETTE) then
            if (requestVRAMDone = '1') then
               textPalFetchNext <= 0;
               if (textPalFetchNext > 0) then
                  -- existing path: 8-bit CLUT line-end wraparound (X=832/896/960)
                  case (textPalFetchNext) is
                     when 3      => reqVRAMSize <= to_unsigned(192, 11);
                     when 2      => reqVRAMSize <= to_unsigned(128, 11);
                     when others => reqVRAMSize <= to_unsigned( 64, 11);
                  end case;
                  state          <= REQUESTPALETTE;
                  reqVRAMXPos    <= (others => '0');
               else
                  state <= IDLE;
               end if;
            end if;
            if (vram_DOUT_READY = '1') then
               CLUTaddrA <= CLUTaddrA + 1;
            end if;
         end if;
         
         
         if (reset = '1') then

            state              <= IDLE;
            stage0_valid       <= '0';
            stage1_valid       <= '0';
            stage3_valid       <= '0';
            stage4_valid       <= '0';
            stage5_valid       <= '0';
            stage6_valid       <= '0';
            textPalFetched     <= '0';

         elsif (ce = '1') then
            
            stage6_valid    <= '0';
            stage6_alphabit <= '0';
            stage6_cb       <= (others => '0');
            stage6_cg       <= (others => '0');
            stage6_cr       <= (others => '0');
            stage6_y        <= (others => '0');
            stage6_x        <= (others => '0');
            
            pipeline_stall_1 <= pipeline_stall;
            
            -- fetch of texture and palette data
            case (state) is
               when IDLE =>
                  if (clearCacheBuffer = '1' and pipeline_busy = '0') then
                     clearCacheBuffer <= '0';
                     tagValid         <= (others => '0');
                  end if;
                  if (textPalReq = '1' and pipeline_busy = '0') then
                     textPalReq     <= '0';
                     state          <= REQUESTPALETTE;
                     CLUTaddrA      <= (others => '0');
                     textPalFetched <= '1';
                     textPalX       <= textPalReqX;
                     textPalY       <= textPalReqY;
                     reqVRAMXPos    <= textPalReqX;
                     reqVRAMYPos    <= textPalReqY;
                     if (drawMode_in(7) = '1') then
                        case to_integer(textPalReqX) is
                           when 960    => reqVRAMSize <= to_unsigned( 64, 11); textPalFetchNext <= 3;
                           when 896    => reqVRAMSize <= to_unsigned(128, 11); textPalFetchNext <= 2;
                           when 832    => reqVRAMSize <= to_unsigned(192, 11); textPalFetchNext <= 1;
                           when others => reqVRAMSize <= to_unsigned(256, 11); textPalFetchNext <= 0;
                        end case;
                     else
                        reqVRAMSize        <= to_unsigned(16, 11);
                        textPalFetchNext   <= 0;
                     end if;
                  elsif (stage0_valid = '1' and stage0_texture = '1' and stage0_filter = '1' and cachehit /= "1111") then
                     state        <= REQUESTMORETEXTURE;
                     cacherequest <= not cachehit;
                  elsif (stage0_valid = '1' and stage0_texture = '1' and cachehit(0) = '0') then
                     state           <= REQUESTTEXTURE;
                     cacherequest    <= (others => '0');
                     tag_data_a      <= std_logic_vector(tag_data(0));
                     tag_address_a   <= tag_addr(0);
                     cache_address_a <= tag_addr(0);
                     
                     reqVRAMXPos <= stage0_textaddr(0)(10 downto 1);
                     reqVRAMYPos <= stage0_textaddr(0)(20 downto 11);
                     reqVRAMSize <= to_unsigned(1, 11);
                  end if;
               
               when REQUESTMORETEXTURE =>
                  state           <= REQUESTTEXTURE;
                  selectIndex := 0;
                  for i in 1 to 3 loop
                     if (cacherequest(i) = '1') then
                        selectIndex := i;
                     end if;
                  end loop;
                     
                  tag_data_a      <= std_logic_vector(tag_data_1(selectIndex));
                  tag_address_a   <= tag_addr_1(selectIndex);
                  cache_address_a <= tag_addr_1(selectIndex);
                  
                  reqVRAMXPos <= stage0_textaddr_1(selectIndex)(10 downto 1);
                  reqVRAMYPos <= stage0_textaddr_1(selectIndex)(20 downto 11);
                  reqVRAMSize <= to_unsigned(1, 11);  
               
               when REQUESTTEXTURE =>
                  -- cannot wait for fifoOut_idle here as this would kill the performance completly 
                  -- also it's totally unclear what real hardware does when primitives draw into their own texture
                  if (requestVRAMIdle = '1') then
                     state       <= WAITTEXTURE;
                  end if;
                  for i in 0 to 3 loop
                     if (tag_address_a = tag_addr_1(i)) then
                        cacherequest(i) <= '0';
                     end if;
                  end loop;
               
               when WAITTEXTURE => null; -- handled outside due to ce
               
               when REQUESTPALETTE =>
                  if (requestVRAMIdle = '1' and fifoOut_idle = '1') then
                     state       <= WAITPALETTE;
                  end if;
 
               when WAITPALETTE => null; -- handled outside due to ce
               
            end case;
            
            -- new palette request
            -- build #116 Fix A: remove pipeline_busy gate. B115 quantified ~100% stale-drawMode
            -- at cube rect emit during early lpadv attract. The gate causes drawMode to lag the
            -- global register, missing fast E1→0x64 sequences. Tracking drawMode_in every cycle
            -- ensures the local drawMode reflects the latest E1 setting before next pixel emits.
            drawMode       <= drawMode_in;
            DrawPixelsMask <= DrawPixelsMask_in;
            SetMask        <= SetMask_in;
            
            if (textPalInNew = '1' and drawMode_in(8) = '0' and (textPalFetched = '0' or textPalInX /= textPalX or textPalInY /= textPalY or palette8bit /= drawMode_in(7) or textPalReq = '1')) then
               textPalReq  <= not noTexture;
               textPalReqX <= textPalInX;
               textPalReqY <= textPalInY;
               palette8bit <= drawMode_in(7);
            end if;
            
            -- clear cache request
            if (clearCacheTexture = '1') then
               clearCacheBuffer <= '1';
            end if;
                        
            if (clearCachePalette = '1') then
               textPalFetched   <= '0';
            end if;
            
            -- slowdown
            if (slowdown = '1') then
               slowdown <= '0';
            elsif (stage1_valid = '1' and drawSlow = '1') then
               slowdown <= '1';
            end if;
            
            -- pixel pipeline
            if (pipeline_stall = '1' and pipeline_stall_1 = '0') then
               stageS_valid         <= pipeline_new and ((not DrawPixelsMask) or (not vramLineData(15)));
               stageS_texture       <= pipeline_texture;
               stageS_transparent   <= pipeline_transparent;
               stageS_rawTexture    <= pipeline_rawTexture; 
               stageS_dithering     <= pipeline_dithering; 
               stageS_x             <= pipeline_x; 
               stageS_y             <= pipeline_y; 
               stageS_cr            <= pipeline_cr;
               stageS_cg            <= pipeline_cg;
               stageS_cb            <= pipeline_cb;
               stageS_u             <= pipeline_u; 
               stageS_v             <= pipeline_v;
               stageS_filter        <= pipeline_filter;
               stageS_u11           <= pipeline_u11;   
               stageS_v11           <= pipeline_v11;                
               stageS_uAcc          <= pipeline_uAcc;   
               stageS_vAcc          <= pipeline_vAcc; 
               stageS_oldPixel      <= vramLineData;
               stageS_oldPixel2     <= vramLineData2;
            end if;
            
            if (pipeline_stall = '0') then
            
               -- stage 0 - receive
               if (pipeline_stall_1 = '1') then
                  stage0_valid         <= stageS_valid;      
                  stage0_texture       <= stageS_texture and (not noTexture);    
                  stage0_transparent   <= stageS_transparent;
                  stage0_rawTexture    <= stageS_rawTexture; 
                  stage0_dithering     <= stageS_dithering; 
                  stage0_x             <= stageS_x;          
                  stage0_y             <= stageS_y;          
                  stage0_cr            <= stageS_cr;         
                  stage0_cg            <= stageS_cg;         
                  stage0_cb            <= stageS_cb;         
                  stage0_u             <= stageS_u;          
                  stage0_v             <= stageS_v;   
                  stage0_filter        <= stageS_filter;
                  stage0_u11           <= stageS_u11;   
                  stage0_v11           <= stageS_v11;                     
                  stage0_uAcc          <= stageS_uAcc;   
                  stage0_vAcc          <= stageS_vAcc;                     
                  stage0_oldPixel      <= stageS_oldPixel;  
                  stage0_oldPixel2     <= stageS_oldPixel2;  
               else
                  stage0_valid         <= pipeline_new and ((not DrawPixelsMask) or (not vramLineData(15)));
                  stage0_texture       <= pipeline_texture and (not noTexture);    
                  stage0_transparent   <= pipeline_transparent;
                  stage0_rawTexture    <= pipeline_rawTexture; 
                  stage0_dithering     <= pipeline_dithering; 
                  stage0_x             <= pipeline_x; 
                  stage0_y             <= pipeline_y; 
                  stage0_cr            <= pipeline_cr;
                  stage0_cg            <= pipeline_cg;
                  stage0_cb            <= pipeline_cb;
                  stage0_u             <= pipeline_u; 
                  stage0_v             <= pipeline_v;
                  stage0_filter        <= pipeline_filter;
                  stage0_u11           <= pipeline_u11;   
                  stage0_v11           <= pipeline_v11;                   
                  stage0_uAcc          <= pipeline_uAcc;   
                  stage0_vAcc          <= pipeline_vAcc;   
                  stage0_oldPixel      <= vramLineData;
                  stage0_oldPixel2     <= vramLineData2;
               end if;

               -- stage1 - fetch texture
               stage1_valid       <= stage0_valid;      
               stage1_texture     <= stage0_texture;    
               stage1_transparent <= stage0_transparent;
               stage1_rawTexture  <= stage0_rawTexture; 
               stage1_dithering   <= stage0_dithering; 
               stage1_x           <= stage0_x;          
               stage1_y           <= stage0_y;          
               stage1_cr          <= stage0_cr;         
               stage1_cg          <= stage0_cg;         
               stage1_cb          <= stage0_cb; 
               stage1_filter      <= stage0_filter;
               stage1_uAcc        <= stage0_uAcc;
               stage1_vAcc        <= stage0_vAcc;
               stage1_oldPixel    <= stage0_oldPixel; 
               stage1_oldPixel2   <= stage0_oldPixel2; 
               for i in 0 to 3 loop
                  stage1_u(i)          <= stage0_u_array(i);
                  tag_addr_1(i)        <= tag_addr(i);
                  tag_data_1(i)        <= tag_data(i);
                  stage0_textaddr_1(i) <= stage0_textaddr(i);
               end loop;
            
               -- stage 2 - texture palette reading
               stage2_valid       <= stage1_valid;      
               stage2_texture     <= stage1_texture;    
               stage2_transparent <= stage1_transparent;
               stage2_rawTexture  <= stage1_rawTexture; 
               stage2_dithering   <= stage1_dithering; 
               stage2_x           <= stage1_x;          
               stage2_y           <= stage1_y;          
               stage2_cr          <= stage1_cr;         
               stage2_cg          <= stage1_cg;         
               stage2_cb          <= stage1_cb; 
               stage2_filter      <= stage1_filter;
               stage2_oldPixel    <= stage1_oldPixel;
               stage2_oldPixel2   <= stage1_oldPixel2;
               for i in 0 to 3 loop
                  stage2_texdata(i) <= texdata_raw(i);
               end loop;
               -- build #57: capture raw texel-index non-zero (same edge/source as stage2_texdata)
               if (texdata_raw(0) /= x"0000") then stage2_texraw_nz <= '1'; else stage2_texraw_nz <= '0'; end if;

               filtermults(0)     <= (to_unsigned(16#FF#, 9) - resize(stage1_uAcc,9)) + (to_unsigned(16#FF#, 9) - resize(stage1_vAcc,9));
               filtermults(1)     <= (to_unsigned(16#FF#, 9) - resize(stage1_uAcc,9)) +                           resize(stage1_vAcc,9) ;
               filtermults(2)     <=                           resize(stage1_uAcc,9)  + (to_unsigned(16#FF#, 9) - resize(stage1_vAcc,9));
               filtermults(3)     <=                           resize(stage1_uAcc,9)  +                           resize(stage1_vAcc,9) ;
               
               -- stage 3 - calculate texture data from normal path or bilinear filtering
               stage3_valid       <= stage2_valid;
               stage3_texture     <= stage2_texture;
               stage3_texraw_nz   <= stage2_texraw_nz;  -- build #57
               stage3_dm8         <= drawMode(8);  -- build #31: color-mode that selected this texel (line 450)
               stage3_dm3         <= drawMode(3);  -- build #32: texpage X base >=512 (cube) for this texel
               stage3_dm7         <= drawMode(7);  -- build #33: 4-bit(0)/8-bit(1) CLUT mode for this texel
               stage3_transparent <= stage2_transparent;
               stage3_rawTexture  <= stage2_rawTexture; 
               stage3_dithering   <= stage2_dithering; 
               stage3_x           <= stage2_x;          
               stage3_y           <= stage2_y;          
               stage3_cr          <= stage2_cr;         
               stage3_cg          <= stage2_cg;         
               stage3_cb          <= stage2_cb; 
               stage3_oldPixel    <= stage2_oldPixel;
               stage3_oldPixel2   <= stage2_oldPixel2;
               stage3_useFilter   <= useFilter;
               stage3_tex_r       <= unsigned(texdata_palette(0)( 4 downto  0));
               stage3_tex_g       <= unsigned(texdata_palette(0)( 9 downto  5));
               stage3_tex_b       <= unsigned(texdata_palette(0)(14 downto 10));
               if (useFilter = '1') then
                  stage3_tex_alpha   <= filtercolor_alpha;
               else
                  stage3_tex_alpha   <= texdata_palette(0)(15);
               end if;
               for i in 0 to 3 loop
                  colormults(i,0) <= filtermults(i) * texcolor(i,0);
                  colormults(i,1) <= filtermults(i) * texcolor(i,1);
                  colormults(i,2) <= filtermults(i) * texcolor(i,2);
               end loop;
               
               -- stage 4 - one additional clock for filtering timing closure
               stage4_valid       <= stage3_valid;
               stage4_texture     <= stage3_texture;
               stage4_texraw_nz   <= stage3_texraw_nz;  -- build #57
               stage4_dm8         <= stage3_dm8;  -- build #31
               stage4_dm3         <= stage3_dm3;  -- build #32
               stage4_dm7         <= stage3_dm7;  -- build #33
               stage4_transparent <= stage3_transparent;
               stage4_rawTexture  <= stage3_rawTexture; 
               stage4_dithering   <= stage3_dithering; 
               stage4_x           <= stage3_x;          
               stage4_y           <= stage3_y;
               -- oldGPU
			   if (oldGPU = '1' and stage3_texture = '1' and stage3_rawTexture = '0') then
			      stage4_cr          <= stage3_cr(7 downto 3) & "000";
                  stage4_cg          <= stage3_cg(7 downto 3) & "000";
                  stage4_cb          <= stage3_cb(7 downto 3) & "000";
               else
                  stage4_cr <= stage3_cr;
                  stage4_cg <= stage3_cg;
                  stage4_cb <= stage3_cb;
               end if;
               stage4_oldPixel    <= stage3_oldPixel;   
               stage4_oldPixel2   <= stage3_oldPixel2;   
               stage4_ditherAdd   <= DITHERMATRIX(to_integer(stage3_y(1 downto 0)), to_integer(stage3_x(1 downto 0)));  
               stage4_useFilter   <= stage3_useFilter;
               stage4_tex_alpha   <= stage3_tex_alpha;
               if (stage3_useFilter = '1') then
                  stage4_tex_r       <= filtercolors(0);
                  stage4_tex_g       <= filtercolors(1);
                  stage4_tex_b       <= filtercolors(2);
               else
                  stage4_tex_r       <= stage3_tex_r & "000";      
                  stage4_tex_g       <= stage3_tex_g & "000";      
                  stage4_tex_b       <= stage3_tex_b & "000";      
               end if;           
               
               -- stage 5 - apply blending or raw color
               stage5_valid       <= stage4_valid;
               stage5_texture     <= stage4_texture;  -- build #27
               stage5_dm8         <= stage4_dm8;  -- build #31
               stage5_dm3         <= stage4_dm3;  -- build #32
               stage5_dm7         <= stage4_dm7;  -- build #33
               stage5_transparent <= stage4_transparent;
               stage5_x           <= stage4_x;          
               stage5_y           <= stage4_y;
               stage5_oldPixel    <= stage4_oldPixel;               
               stage5_oldPixel2   <= stage4_oldPixel2;               
               if (stage4_texture = '1') then
                  stage5_alphacheck <= stage4_tex_alpha;
                  stage5_alphabit   <= stage4_tex_alpha;
                  if (stage4_tex_r(7 downto 3) = 0 and stage4_tex_g(7 downto 3) = 0 and stage4_tex_b(7 downto 3) = 0 and stage4_tex_alpha = '0' and stage4_useFilter = '0') then
                     stage5_valid <= '0';
                  end if;
                  if (stage4_rawTexture = '1') then
                     stage5_cr         <= stage4_tex_r;
                     stage5_cg         <= stage4_tex_g;
                     stage5_cb         <= stage4_tex_b;
                  else
                     colorTr := stage4_tex_r * stage4_cr;
                     colorTg := stage4_tex_g * stage4_cg;
                     colorTb := stage4_tex_b * stage4_cb;
                     if (stage4_dithering = '1') then
                        colorDr := (to_integer(colorTr) / 128) + stage4_ditherAdd;
                        colorDg := (to_integer(colorTg) / 128) + stage4_ditherAdd;
                        colorDb := (to_integer(colorTb) / 128) + stage4_ditherAdd;
                        if (colorDr < 0) then stage5_cr <= (others => '0'); elsif (colorDr > 255) then stage5_cr <= (others => '1'); else stage5_cr <= to_unsigned(colorDr, 8); end if;
                        if (colorDg < 0) then stage5_cg <= (others => '0'); elsif (colorDg > 255) then stage5_cg <= (others => '1'); else stage5_cg <= to_unsigned(colorDg, 8); end if;
                        if (colorDb < 0) then stage5_cb <= (others => '0'); elsif (colorDb > 255) then stage5_cb <= (others => '1'); else stage5_cb <= to_unsigned(colorDb, 8); end if;
                     else
                        if (colorTr(15 downto 7) > 255) then stage5_cr <= (others => '1'); else stage5_cr <= colorTr(14 downto 7); end if;
                        if (colorTb(15 downto 7) > 255) then stage5_cb <= (others => '1'); else stage5_cb <= colorTb(14 downto 7); end if;
                        if (colorTg(15 downto 7) > 255) then stage5_cg <= (others => '1'); else stage5_cg <= colorTg(14 downto 7); end if;
                     end if;
                  end if;
                  if (stage4_useFilter = '0' and render24 = '0') then
                     stage5_cr(2 downto 0) <= "000";
                     stage5_cg(2 downto 0) <= "000";
                     stage5_cb(2 downto 0) <= "000";
                  end if;
               else
                  if (render24 = '1') then
                     stage5_cr         <= stage4_cr;
                     stage5_cg         <= stage4_cg;
                     stage5_cb         <= stage4_cb;
                  elsif (stage4_dithering = '1') then
                     colorDr := to_integer(stage4_cr) + stage4_ditherAdd;
                     colorDg := to_integer(stage4_cg) + stage4_ditherAdd;
                     colorDb := to_integer(stage4_cb) + stage4_ditherAdd;
                     if (colorDr < 0) then stage5_cr <= (others => '0'); elsif (colorDr > 255) then stage5_cr <= x"F8"; else stage5_cr <= to_unsigned(colorDr / 8, 5) & "000"; end if;
                     if (colorDg < 0) then stage5_cg <= (others => '0'); elsif (colorDg > 255) then stage5_cg <= x"F8"; else stage5_cg <= to_unsigned(colorDg / 8, 5) & "000"; end if;
                     if (colorDb < 0) then stage5_cb <= (others => '0'); elsif (colorDb > 255) then stage5_cb <= x"F8"; else stage5_cb <= to_unsigned(colorDb / 8, 5) & "000"; end if;
                  else
                     stage5_cr         <= stage4_cr(7 downto 3) & "000";
                     stage5_cg         <= stage4_cg(7 downto 3) & "000";
                     stage5_cb         <= stage4_cb(7 downto 3) & "000";
                  end if;
                  stage5_alphacheck <= '1';
                  stage5_alphabit   <= '0';
               end if;
               
               -- stage 6 - apply alpha
               stage6_valid    <= stage5_valid;   
               stage6_alphabit <= stage5_alphabit or SetMask;
               stage6_x        <= stage5_x;       
               stage6_y        <= stage5_y;       

               if (stage5_transparent = '1' and stage5_alphacheck = '1') then
                  -- also check for mask bit
                  
                  colorBGr  := unsigned(stage5_oldPixel( 4 downto  0)) & "000";
                  colorBGg  := unsigned(stage5_oldPixel( 9 downto  5)) & "000";
                  colorBGb  := unsigned(stage5_oldPixel(14 downto 10)) & "000";
                  if (render24 = '1') then
                     colorBGr(2 downto 0) := unsigned(stage5_oldPixel2( 2 downto  0));
                     colorBGg(2 downto 0) := unsigned(stage5_oldPixel2( 5 downto  3));
                     colorBGb(2 downto 0) := unsigned(stage5_oldPixel2( 8 downto  6));
                  end if;
                  
                  case (drawMode(6 downto 5)) is
                     when "00" => --  (B+F)/2
                        colorMixr := (to_integer(colorBGr) + to_integer(stage5_cr)) / 2;
                        colorMixg := (to_integer(colorBGg) + to_integer(stage5_cg)) / 2;
                        colorMixb := (to_integer(colorBGb) + to_integer(stage5_cb)) / 2;
                        
                     when "01" => --  B+F
                        colorMixr := to_integer(colorBGr) + to_integer(stage5_cr);
                        colorMixg := to_integer(colorBGg) + to_integer(stage5_cg);
                        colorMixb := to_integer(colorBGb) + to_integer(stage5_cb);
                        
                     when "10" => -- B-F
                        colorMixr := to_integer(colorBGr) - to_integer(stage5_cr);
                        colorMixg := to_integer(colorBGg) - to_integer(stage5_cg);
                        colorMixb := to_integer(colorBGb) - to_integer(stage5_cb);
                        
                     when "11" => -- B+F/4
                        colorMixr := to_integer(colorBGr) + to_integer(stage5_cr(7 downto 2));
                        colorMixg := to_integer(colorBGg) + to_integer(stage5_cg(7 downto 2));
                        colorMixb := to_integer(colorBGb) + to_integer(stage5_cb(7 downto 2));
                  
                     when others => null;
                  end case;
                  
                  if (colorMixr > 255) then colorMixr := 255; elsif (colorMixr < 0) then colorMixr := 0; end if;
                  if (colorMixg > 255) then colorMixg := 255; elsif (colorMixg < 0) then colorMixg := 0; end if;
                  if (colorMixb > 255) then colorMixb := 255; elsif (colorMixb < 0) then colorMixb := 0; end if;
                  
                  stage6_cr       <= std_logic_vector(to_unsigned(colorMixr,8));
                  stage6_cg       <= std_logic_vector(to_unsigned(colorMixg,8));
                  stage6_cb       <= std_logic_vector(to_unsigned(colorMixb,8));
               else
                  stage6_cr       <= std_logic_vector(stage5_cr);      
                  stage6_cg       <= std_logic_vector(stage5_cg);      
                  stage6_cb       <= std_logic_vector(stage5_cb);     
               end if;
            
            end if; 
         
         end if;
         
      end if;
   end process; 
   
   pixelColor  <= stage6_alphabit & stage6_cb(7 downto 3) & stage6_cg(7 downto 3) & stage6_cr(7 downto 3);
   pixelColor2 <= "0000000" & stage6_cb(2 downto 0) & stage6_cg(2 downto 0) & stage6_cr(2 downto 0);
   pixelAddr   <= stage6_y & stage6_x & '0';
   pixelWrite  <= stage6_valid;

   -- build #7 DIAGNOSTIC: CLUT write happening AND data on bus is non-navy (any of 4 lanes != 0x4000 AND != 0x0000)
   dbg_clut_write_nonnavy <= '1' when (CLUTwrenA = '1' and
                                        ((vram_DOUT(15 downto  0) /= x"4000" and vram_DOUT(15 downto  0) /= x"0000") or
                                         (vram_DOUT(31 downto 16) /= x"4000" and vram_DOUT(31 downto 16) /= x"0000") or
                                         (vram_DOUT(47 downto 32) /= x"4000" and vram_DOUT(47 downto 32) /= x"0000") or
                                         (vram_DOUT(63 downto 48) /= x"4000" and vram_DOUT(63 downto 48) /= x"0000"))) else '0';
   -- build #7 DIAGNOSTIC: CLUT-fed texdata_palette is currently a non-navy, non-zero color
   dbg_clut_read_nonnavy <= '1' when (texdata_palette(0) /= x"4000" and texdata_palette(0) /= x"0000") else '0';
   -- build #7 DIAGNOSTIC: stage 4 is processing a textured pixel write (stage4_texture qualifies modulation/lookup paths)
   dbg_stage4_texture <= stage4_texture and stage4_valid;

   -- texel-read diagnostic: latch XOR + last of texdata_raw(0) when a textured pixel is in flight.
   -- Tells whether the FPGA reads real/varied texel data (non-zero XOR, real colors) for the
   -- title's 15-bit x>=512 textures, or empty/garbage (XOR=0 / all-navy 0x4000).
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (reset = '1') then
            dbg_texel_xor  <= (others => '0');
            dbg_texel_last <= (others => '0');
         elsif (ce = '1' and stage1_valid = '1' and stage1_texture = '1') then
            dbg_texel_last <= std_logic_vector(texdata_raw(0));
            dbg_texel_xor  <= dbg_texel_xor xor std_logic_vector(texdata_raw(0));
         end if;
      end if;
   end process;
   dbg_texel <= dbg_texel_xor & dbg_texel_last;

   -- U/V range diagnostic: max/last texture coords on textured pixels. For the title's 2x-stretch
   -- quads (uv 0..64 over 128px), max_u should be ~64; max_u>64 => U interpolation ignores the
   -- stretch and reads past the texture into the adjacent one => garbage.
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         if (reset = '1') then
            dbg_max_u <= (others => '0'); dbg_max_v <= (others => '0');
         elsif (ce = '1' and stage0_valid = '1' and stage0_texture = '1') then
            dbg_last_u <= stage0_u; dbg_last_v <= stage0_v;
            if (stage0_u > dbg_max_u) then dbg_max_u <= stage0_u; end if;
            if (stage0_v > dbg_max_v) then dbg_max_v <= stage0_v; end if;
         end if;
      end if;
   end process;
   dbg_uv <= std_logic_vector(dbg_max_u) & std_logic_vector(dbg_max_v) & std_logic_vector(dbg_last_u) & std_logic_vector(dbg_last_v);
   -- build #57: stage4 textured pixel whose RAW texel index (pre-CLUT) was non-zero => texture DATA present in VRAM
   dbg_stage4_texraw_nz <= stage4_texture and stage4_valid and stage4_texraw_nz;

   -- build #122: drive vram_DOUT capture outputs
   dbg_h22_anchor   <= h22_anchor;
   dbg_h22_clut3_r  <= h22_clut3_r;
   dbg_h22_clut3_g  <= h22_clut3_g;

   -- build #140: drive CLUT-RAM cube CLUT presence probes
   dbg_h40_cube_clut_loaded_ever <= h40_cube_clut_loaded_ever;
   dbg_h40_clut_read_7fff_ever   <= h40_clut_read_7fff_ever;
   dbg_h40_clut_read_023f_ever   <= h40_clut_read_023f_ever;
   -- build #158: H4 cache-staleness sticky outputs
   dbg_h58_x_stale_seen          <= h58_x_stale_seen;
   dbg_h58_y_stale_seen          <= h58_y_stale_seen;
   dbg_h58_pixel_seen            <= h58_pixel_seen;
   -- build #159: H7 capture outputs
   dbg_h59_loaded_entry0_lo      <= h59_loaded_entry0(8 downto 0);
   dbg_h59_loaded_y              <= std_logic_vector(h59_loaded_y(8 downto 0));
   dbg_h59_anchor                <= h59_anchor;

   -- build #140: sticky-on probes. Set-only; no reset path so they survive softReset/drawer_reset.
   -- (FPGA infers async-reset-free flip-flops; powers up at '0' per signal init).
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         -- LOAD probe: CLUTwrenA + addr 0 + cube CLUT word 0 signature in vram_DOUT.
         -- vram_DOUT[31:16] = entry 1 (expect 0x7FFF), vram_DOUT[47:32] = entry 2 (expect 0x023F).
         if (CLUTwrenA = '1' and CLUTaddrA = "000000"
             and vram_DOUT(31 downto 16) = x"7fff"
             and vram_DOUT(47 downto 32) = x"023f") then
            h40_cube_clut_loaded_ever <= '1';
         end if;
         -- READ probes: any of the 4 CLUTDataB lanes ever equals the target value.
         if (CLUTDataB(0) = x"7fff" or CLUTDataB(1) = x"7fff"
          or CLUTDataB(2) = x"7fff" or CLUTDataB(3) = x"7fff") then
            h40_clut_read_7fff_ever <= '1';
         end if;
         if (CLUTDataB(0) = x"023f" or CLUTDataB(1) = x"023f"
          or CLUTDataB(2) = x"023f" or CLUTDataB(3) = x"023f") then
            h40_clut_read_023f_ever <= '1';
         end if;
         -- build #158: H4 cache-staleness sticky bits.
         if (stage6_valid = '1') then
            h58_pixel_seen <= '1';
            if (textPalX /= textPalReqX) then
               h58_x_stale_seen <= '1';
            end if;
            if (textPalY /= textPalReqY) then
               h58_y_stale_seen <= '1';
            end if;
         end if;
         -- build #159: H7 data-staleness capture. Latch entry 0 of the FIRST non-trivial
         -- CLUT load — CLUTwrenA='1' with CLUTaddrA=0 (first dpram cell) and textPalReqY > 100.
         -- vram_DOUT(15:0) carries entry 0 of the CLUT being loaded. textPalReqY is the
         -- VRAM Y source of the load.
         if (h59_anchor = '0'
             and CLUTwrenA = '1'
             and CLUTaddrA = "000000"
             and textPalReqY > to_unsigned(100, 10)) then
            h59_loaded_entry0 <= vram_DOUT(15 downto 0);
            h59_loaded_y      <= textPalReqY;
            h59_anchor        <= '1';
         end if;
      end if;
   end process;

   -- build #63: textPalReqY in [460,500) — gates CLUT loads targeting lpadv's CLUT-Y region
   dbg_textPalReqY_clut <= '1' when (textPalReqY >= to_unsigned(460, 10) and textPalReqY < to_unsigned(500, 10)) else '0';
   -- build #68: split Y-range — [460,480) (working) vs [480,500) (failing range)
   dbg_textPalReqY_lo <= '1' when (textPalReqY >= to_unsigned(460, 10) and textPalReqY < to_unsigned(480, 10)) else '0';
   dbg_textPalReqY_hi <= '1' when (textPalReqY >= to_unsigned(480, 10) and textPalReqY < to_unsigned(500, 10)) else '0';
   -- build #67: latch (textPalReqX, textPalReqY) of LAST high-Y CLUT load that returned real color
   dbg_last_succ_palX <= std_logic_vector(last_succ_palX);
   dbg_last_succ_palY <= std_logic_vector(last_succ_palY);

   -- build #8 DIAGNOSTICS: CLUT-load chain pinpoint
   -- textPalReq_set: the exact line 632 gating - textPalInNew=1 AND drawMode_in(8)=0 AND (fetch-required) AND noTexture=0
   dbg_textPalReq_set <= '1' when (textPalInNew = '1' and drawMode_in(8) = '0' and
                                    (textPalFetched = '0' or textPalInX /= textPalX or textPalInY /= textPalY or palette8bit /= drawMode_in(7) or textPalReq = '1') and
                                    noTexture = '0') else '0';
   dbg_state_REQ_PAL  <= '1' when (state = REQUESTPALETTE) else '0';
   dbg_CLUTwrenA_any  <= CLUTwrenA;
   dbg_drawMode_8     <= drawMode_in(8);
   dbg_noTexture_pin  <= noTexture;
   -- build #13: CLUT load address inspection
   dbg_textPalReqX_nonzero  <= '1' when (textPalReqX /= 0) else '0';
   dbg_textPalReqY_nonzero  <= '1' when (textPalReqY /= 0) else '0';
   dbg_textPalReqX_high_bit <= textPalReqX(9);
   dbg_textPalReqY_high_bit <= textPalReqY(8);
   dbg_textPalReqX_bit8     <= textPalReqX(8);
   -- build #35: classify the 8-bit CLUT data AS LOADED FROM VRAM (vram_DOUT during WAITPALETTE, palette8bit).
   -- This is exactly the data being written into the CLUT RAM (CLUTwrenA = vram_DOUT_READY & state=WAITPALETTE),
   -- perfectly aligned (no pipeline timing ambiguity). Expected = GREEN ramp (R=0). vram_DOUT = 4 BGR15 lanes.
   --   RED loaded  -> VRAM(0,488) physically holds red -> cpu2vram upload dest wrong, or region overwritten.
   --   GREEN loaded-> VRAM holds the correct green ramp -> corruption is in the CLUT RAM (dpram) or its read.
   process (clk2x)
      variable any_red   : std_logic;
      variable any_green : std_logic;
   begin
      if rising_edge(clk2x) then
         if (reset = '1') then
            clutload_seen  <= '0';
            clutload_red   <= '0';
            clutload_green <= '0';
         elsif (state = WAITPALETTE and palette8bit = '1' and vram_DOUT_READY = '1'
                and reqVRAMYPos = to_unsigned(488, 10)) then  -- build #36: gate to the GREEN-ramp CLUT only
            clutload_seen <= '1';
            any_red := '0'; any_green := '0';
            -- lane 0
            if (vram_DOUT( 4 downto  0) /= "00000" and vram_DOUT( 9 downto  5) = "00000" and vram_DOUT(14 downto 10) = "00000") then any_red := '1'; end if;
            if (vram_DOUT( 9 downto  5) /= "00000" and vram_DOUT( 4 downto  0) = "00000") then any_green := '1'; end if;
            -- lane 1
            if (vram_DOUT(20 downto 16) /= "00000" and vram_DOUT(25 downto 21) = "00000" and vram_DOUT(30 downto 26) = "00000") then any_red := '1'; end if;
            if (vram_DOUT(25 downto 21) /= "00000" and vram_DOUT(20 downto 16) = "00000") then any_green := '1'; end if;
            -- lane 2
            if (vram_DOUT(36 downto 32) /= "00000" and vram_DOUT(41 downto 37) = "00000" and vram_DOUT(46 downto 42) = "00000") then any_red := '1'; end if;
            if (vram_DOUT(41 downto 37) /= "00000" and vram_DOUT(36 downto 32) = "00000") then any_green := '1'; end if;
            -- lane 3
            if (vram_DOUT(52 downto 48) /= "00000" and vram_DOUT(57 downto 53) = "00000" and vram_DOUT(62 downto 58) = "00000") then any_red := '1'; end if;
            if (vram_DOUT(57 downto 53) /= "00000" and vram_DOUT(52 downto 48) = "00000") then any_green := '1'; end if;
            if (any_red   = '1') then clutload_red   <= '1'; end if;
            if (any_green = '1') then clutload_green <= '1'; end if;
         end if;
      end if;
   end process;
   --   dbg_loclut_gb     (GREEN bar):  an 8-bit CLUT load word arrived (control, expect LIT)
   --   dbg_cubeclut_gb   (YELLOW bar): a loaded entry was RED-only  -> VRAM holds red (upload dest / overwrite)
   --   dbg_cubeclut_ronly(WHITE bar):  a loaded entry was GREEN (correct) -> VRAM holds green; corruption is in CLUT RAM/read
   dbg_loclut_gb      <= clutload_seen;
   dbg_cubeclut_gb    <= clutload_red;
   dbg_cubeclut_ronly <= clutload_green;

   -- build #107: B106 proved cache hits ARE happening for 4-bit. But B105 showed texdata=0.
   -- Therefore cache is being written with ZERO data OR there's a write/read mismatch.
   -- Capture vram_DOUT at the moment of texture cache writes (cache_wren_a='1').
   -- Display:
   --   RED bar   = last vram_DOUT(7:0)   at cache_wren_a event
   --   GREEN bar = last vram_DOUT(15:8)  at cache_wren_a event
   --   BLUE bar  = sticky "ever saw cache_wren_a with vram_DOUT(15:0) != 0x0000"
   -- INTERPRETATION:
   --   BLUE=full → cache got nonzero writes (vram delivered data sometimes)
   --   RED=0, GREEN=0, BLUE=full → latest writes are zero, but some nonzero happened
   --   ALL=0 → cache writes are always zero — VRAM source is broken for textures
   -- The OLD comment block below is for build #106 (sticky FF/empty bars) and is now superseded.
   -- build #106: B105 proved texdata_raw=0 and CLUTaddrB=0 for 4-bit textured pixels.
   -- Cube bug = texture cache returns zeros. Now determine WHY:
   --   (a) cache never filled (cache_wren_a never fires)
   --   (b) cache filled but lookups always miss → return uninitialized zero
   --   (c) cache filled correctly but reads from wrong address
   -- Sticky latches with explicit signals:
   --   RED bar (FF)   = sticky cache_wren_a ever fired (cache write ever happened)
   --   GREEN bar (FF) = sticky cachehit(0) ever true for 4-bit mode (4-bit hit ever happened)
   --   BLUE bar       = sticky stage1_valid ever true AND drawMode(7)='0' (4-bit render attempted)
   -- INTERPRETATION:
   --   RED=full, GREEN=full, BLUE=full → cache works, bug downstream
   --   RED=full, GREEN=empty, BLUE=full → cache fills but 4-bit always misses → tag bug
   --   RED=empty, BLUE=full → cache never fills despite 4-bit rendering attempts → FSM bug
   -- build #108: B107 proved latest cache writes are zero. Capture the VRAM READ ADDRESS
   -- being used for texture cache loads, to determine if FPGA is reading from the right
   -- VRAM region. reqVRAMXPos/YPos hold the address sent to the VRAM controller.
   -- Display:
   --   RED bar   = last reqVRAMXPos(9:2) at cache_wren_a event (~VRAM X / 4)
   --   GREEN bar = last reqVRAMYPos(7:0) at cache_wren_a event (low 8 bits of VRAM Y)
   --   BLUE bar  = sticky "ever cache_wren_a with vram_DOUT(15:0) != 0"
   -- INTERPRETATION (for cube texture lookup at texPage 512,0):
   --   reqVRAMXPos = 512 → RED = 0b10000000 = 128 (0x80)
   --   reqVRAMXPos = 640 → RED = 0b10100000 = 160 (0xA0)
   --   reqVRAMYPos = 0   → GREEN = 0
   --   reqVRAMYPos = 128 → GREEN = 128 (0x80)
   -- build #112: cpu2vram pixelColor capture at writes TO CUBE TEXTURE AREA specifically.
   -- Determines: when FPGA writes to (X=832-888, Y=143-255), what color is being written?
   -- If color is nonzero, write data is correct, bug is in storage persistence.
   -- If color is zero, cpu2vram_pixelColor is being corrupted somewhere upstream.
   -- Display:
   --   RED bar   = last cpu2vram_pixelColor[7:0] at write into cube tex area
   --   GREEN bar = last cpu2vram_pixelColor[15:8] at write into cube tex area
   --   BLUE bar  = sticky "wrote nonzero color to cube tex area"
   -- pulse_in = cpu2vram_pixelWrite
   -- fifodata_in = [31:16]=cpu2vram_pixelColor, [15:8]=Y[7:0], [7:0]=X[10:3] (X/8 byte index)
   -- build #113: B112 had a filter bug (X[9:2] vs X[10:3]). Drop the filter — just check
   -- if cpu2vram EVER writes nonzero colors at all. Pulse_in=cpu2vram_pixelWrite,
   -- fifodata_in(31:16)=cpu2vram_pixelColor.
   -- Display:
   --   RED bar   = last cpu2vram_pixelColor[7:0]
   --   GREEN bar = last cpu2vram_pixelColor[15:8]
   --   BLUE bar  = sticky "ever saw nonzero pixelColor at any write"
   b82_capture : block
      signal b113_color_lo : std_logic_vector(7 downto 0) := (others => '0');
      signal b113_color_hi : std_logic_vector(7 downto 0) := (others => '0');
      signal b113_nz_any   : std_logic := '0';
   begin
      process (clk2x)
      begin
         if rising_edge(clk2x) then
            if (reset = '1') then
               b113_color_lo <= (others => '0');
               b113_color_hi <= (others => '0');
               b113_nz_any   <= '0';
            elsif (dbg_b102_poly_y507_pulse_in = '1') then
               b113_color_lo <= dbg_b102_poly_fifodata_in(23 downto 16);
               b113_color_hi <= dbg_b102_poly_fifodata_in(31 downto 24);
               if (dbg_b102_poly_fifodata_in(31 downto 16) /= x"0000") then
                  b113_nz_any <= '1';
               end if;
            end if;
         end if;
      end process;
      dbg_b82_byte_redslot   <= b113_color_lo;
      dbg_b82_byte_greenslot <= b113_color_hi;
      dbg_b82_captured       <= b113_nz_any;
   end block;

end architecture;





