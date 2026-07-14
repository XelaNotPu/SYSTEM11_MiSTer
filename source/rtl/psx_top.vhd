library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pexport.all;
use work.pJoypad.all;

entity psx_top is
   generic
   (
      is_simu               : std_logic := '0'
   );
   port 
   (
      clk1x                 : in  std_logic;  
      clk2x                 : in  std_logic;   
      clk3x                 : in  std_logic;   
      clkvid                : in  std_logic;   
      reset                 : in  std_logic; 
      isPaused              : out std_logic;
      -- commands 
      pause                 : in  std_logic;
      hps_busy              : in  std_logic;
      loadExe               : in  std_logic;
      exe_initial_pc        : in  unsigned(31 downto 0);
      exe_initial_gp        : in  unsigned(31 downto 0);
      exe_load_address      : in  unsigned(31 downto 0);
      exe_file_size         : in  unsigned(31 downto 0);
      exe_stackpointer      : in  unsigned(31 downto 0);
      fastboot              : in  std_logic;
      ram8mb                : in  std_logic;
      TURBO_MEM             : in  std_logic;
      TURBO_COMP            : in  std_logic;
      TURBO_CACHE           : in  std_logic;
      TURBO_CACHE50         : in  std_logic;
      REPRODUCIBLEGPUTIMING : in  std_logic;
      INSTANTSEEK           : in  std_logic;
      FORCECDSPEED          : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED        : in  std_logic;
      IGNORECDDMATIMING     : in  std_logic;
      ditherOff             : in  std_logic;
      interlaced480pHack    : in  std_logic;
      showGunCrosshairs     : in  std_logic;
      enableNeGconRumble    : in  std_logic;
      fpscountOn            : in  std_logic;
      cdslowOn              : in  std_logic;
      testSeek              : in  std_logic;
      pauseOnCDSlow         : in  std_logic;
      errorOn               : in  std_logic;
      LBAOn                 : in  std_logic;
      PATCHSERIAL           : in  std_logic;
      noTexture             : in  std_logic;
      textureFilter         : in  std_logic_vector(1 downto 0);
      textureFilterStrength : in  std_logic_vector(1 downto 0);
      textureFilter2DOff    : in  std_logic;
      dither24              : in  std_logic;
      render24              : in  std_logic;
      drawSlow              : in  std_logic;
      syncVideoOut          : in  std_logic;
      syncInterlace         : in  std_logic;
      rotate180             : in  std_logic;
      fixedVBlank           : in  std_logic;
      vCrop                 : in  std_logic_vector(1 downto 0);
      hCrop                 : in  std_logic;
      SPUon                 : in  std_logic;
      SPUIRQTrigger         : in  std_logic;
      SPUSDRAM              : in  std_logic;
      REVERBOFF             : in  std_logic;
      REPRODUCIBLESPUDMA    : in  std_logic;
      WIDESCREEN            : in  std_logic_vector(1 downto 0);
	  oldGPU                : in  std_logic;
      -- RAM/BIOS interface  
      biosregion            : in  std_logic_vector(1 downto 0);      
      ram_refresh           : out std_logic;
      ram_dataWrite         : out std_logic_vector(31 downto 0);
      ram_dataRead32        : in  std_logic_vector(31 downto 0);
      ram_Adr               : out std_logic_vector(26 downto 0);
      ram_cntDMA            : out std_logic_vector(1 downto 0);
      ram_be                : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw               : out std_logic;
      ram_ena               : out std_logic;
      ram_dma               : out std_logic;
      ram_cache             : out std_logic;
      ram_done              : in  std_logic;
      ram_dmafifo_adr       : out std_logic_vector(22 downto 0);
      ram_dmafifo_data      : out std_logic_vector(31 downto 0);
      ram_dmafifo_empty     : out std_logic;
      ram_dmafifo_read      : in  std_logic;
      cache_wr              : in  std_logic_vector(3 downto 0);
      cache_data            : in  std_logic_vector(31 downto 0);
      cache_addr            : in  std_logic_vector(7 downto 0);
      dma_wr                : in  std_logic;
      dma_reqprocessed      : in  std_logic;
      dma_data              : in  std_logic_vector(31 downto 0);
      -- vram/savestate interface
      ddr3_BUSY             : in  std_logic;                    
      ddr3_DOUT             : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY       : in  std_logic;
      ddr3_BURSTCNT         : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR             : out std_logic_vector(27 downto 0) := (others => '0');                       
      ddr3_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE               : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE               : out std_logic := '0';
      ddr3_RD               : out std_logic := '0'; 
      -- cd
      region                : in  std_logic_vector(1 downto 0);
      region_out            : out std_logic_vector(1 downto 0);
      hasCD                 : in  std_logic;
      fastCD                : in  std_logic;
      LIDopen               : in  std_logic;
      trackinfo_data        : in  std_logic_vector(31 downto 0);
      trackinfo_addr        : in  std_logic_vector(8 downto 0);
      trackinfo_write       : in  std_logic;
      resetFromCD           : out std_logic;
      cd_hps_req            : out std_logic := '0';
      cd_hps_lba            : out std_logic_vector(31 downto 0);
      cd_hps_lba_sim        : out std_logic_vector(31 downto 0);
      cd_hps_ack            : in  std_logic;
      cd_hps_write          : in  std_logic;
      cd_hps_data           : in  std_logic_vector(15 downto 0);
      -- spuram
      spuram_dataWrite      : out std_logic_vector(31 downto 0);
      spuram_Adr            : out std_logic_vector(18 downto 0);
      spuram_be             : out std_logic_vector(3 downto 0);
      spuram_rnw            : out std_logic;
      spuram_ena            : out std_logic;
      spuram_dataRead       : in  std_logic_vector(31 downto 0);
      spuram_done           : in  std_logic;
      -- memcard
      memcard_changed       : out std_logic;
      saving_memcard        : out std_logic;
      memcard1_load         : in  std_logic;
      memcard2_load         : in  std_logic;
      memcard_save          : in  std_logic;
      memcard1_mounted      : in  std_logic;
      memcard1_available    : in  std_logic;
      memcard1_rd           : out std_logic := '0';
      memcard1_wr           : out std_logic := '0';
      memcard1_lba          : out std_logic_vector(6 downto 0);
      memcard1_ack          : in  std_logic;
      memcard1_write        : in  std_logic;
      memcard1_addr         : in  std_logic_vector(8 downto 0);
      memcard1_dataIn       : in  std_logic_vector(15 downto 0);
      memcard1_dataOut      : out std_logic_vector(15 downto 0);
      memcard2_mounted      : in  std_logic;               
      memcard2_available    : in  std_logic;               
      memcard2_rd           : out std_logic := '0';
      memcard2_wr           : out std_logic := '0';
      memcard2_lba          : out std_logic_vector(6 downto 0);
      memcard2_ack          : in  std_logic;
      memcard2_write        : in  std_logic;
      memcard2_addr         : in  std_logic_vector(8 downto 0);
      memcard2_dataIn       : in  std_logic_vector(15 downto 0);
      memcard2_dataOut      : out std_logic_vector(15 downto 0);
      -- video
      videoout_on           : in  std_logic;
      isPal                 : in  std_logic;
      pal60                 : in  std_logic;
      hsync                 : out std_logic;
      vsync                 : out std_logic;
      hblank                : out std_logic;
      vblank                : out std_logic;
      DisplayWidth          : out unsigned(10 downto 0);
      DisplayHeight         : out unsigned( 9 downto 0);
      DisplayOffsetX        : out unsigned( 9 downto 0);
      DisplayOffsetY        : out unsigned( 8 downto 0);
      video_ce              : out std_logic;
      video_interlace       : out std_logic;
      video_r               : out std_logic_vector(7 downto 0);
      video_g               : out std_logic_vector(7 downto 0);
      video_b               : out std_logic_vector(7 downto 0);
      video_isPal           : out std_logic;
      video_fbmode          : out std_logic;
      video_fb24            : out std_logic;
      video_hResMode        : out std_logic_vector(2 downto 0);
      video_frameindex      : out std_logic_vector(3 downto 0);

      DSAltSwitchMode       : in  std_logic;
      joypad1               : in  joypad_t;
      joypad2               : in  joypad_t;
      joypad3               : in  joypad_t;
      joypad4               : in  joypad_t;
      multitap              : in  std_logic;
      multitapDigital       : in  std_logic;
      multitapAnalog        : in  std_logic;
      neGconRumble          : in  std_logic;
      joypad1_rumble        : out std_logic_vector(15 downto 0);
      joypad2_rumble        : out std_logic_vector(15 downto 0);
      joypad3_rumble        : out std_logic_vector(15 downto 0);
      joypad4_rumble        : out std_logic_vector(15 downto 0);
      padMode               : out std_logic_vector(1 downto 0);

      MouseEvent            : in  std_logic;
      MouseLeft             : in  std_logic;
      MouseRight            : in  std_logic;
      MouseX                : in  signed(8 downto 0);
      MouseY                : in  signed(8 downto 0);
      --snac
      snacPort1             : in  std_logic;
      snacPort2             : in  std_logic;
      irq10Snac             : in  std_logic;
      actionNextSnac        : in  std_logic;
      receiveValidSnac      : in  std_logic;
      ackSnac               : in  std_logic;
      snacMC                : in  std_logic;
      receiveBufferSnac	    : in  std_logic_vector(7 downto 0);
      transmitValueSnac     : out std_logic_vector(7 downto 0);		
      selectedPort1Snac     : out std_logic;
      selectedPort2Snac     : out std_logic;
      clk9Snac              : out std_logic;
      beginTransferSnac     : out std_logic;

      -- sound                            
      sound_out_left        : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right       : out std_logic_vector(15 downto 0) := (others => '0');
       -- savestates
      increaseSSHeaderCount : in  std_logic;
      save_state            : in  std_logic;
      load_state            : in  std_logic;
      savestate_number      : in  integer;
      state_loaded          : out std_logic;
      validSStates          : out std_logic_vector(3 downto 0);
      rewind_on             : in  std_logic;
      rewind_active         : in  std_logic;
      -- cheats
      cheat_clear           : in  std_logic;
      cheats_enabled        : in  std_logic;
      cheat_on              : in  std_logic;
      cheat_in              : in  std_logic_vector(127 downto 0);
      cheats_active         : out std_logic := '0';

      Cheats_BusAddr        : buffer std_logic_vector(20 downto 0);
      Cheats_BusRnW         : out    std_logic;
      Cheats_BusByteEnable  : out    std_logic_vector(3 downto 0);
      Cheats_BusWriteData   : out    std_logic_vector(31 downto 0);
      Cheats_Bus_ena        : out    std_logic := '0';
      Cheats_BusReadData    : in     std_logic_vector(31 downto 0);
      Cheats_BusDone        : in     std_logic;

      -- ZN-1 Arcade I/O inputs
      zn_p1_right     : in  std_logic;
      zn_p1_left      : in  std_logic;
      zn_p1_down      : in  std_logic;
      zn_p1_up        : in  std_logic;
      zn_p1_btn       : in  std_logic_vector(5 downto 0);
      zn_p1_start     : in  std_logic;
      zn_p1_coin      : in  std_logic;
      zn_p2_right     : in  std_logic;
      zn_p2_left      : in  std_logic;
      zn_p2_down      : in  std_logic;
      zn_p2_up        : in  std_logic;
      zn_p2_btn       : in  std_logic_vector(5 downto 0);
      zn_p2_start     : in  std_logic;
      zn_p2_coin      : in  std_logic;
      zn_service      : in  std_logic;
      zn_test_mode    : in  std_logic;
      zn_dsw          : in  std_logic_vector(7 downto 0);
      zn_cat702_key   : in  std_logic_vector(63 downto 0);
      zn_cat702_key_b : in  std_logic_vector(63 downto 0);
      zn_platform     : in  std_logic_vector(3 downto 0) := "0000";
      zn_system11     : in  std_logic := '0';  -- Namco System 11 memory map + boot-from-program
      keycus_id       : in  std_logic_vector(7 downto 0) := x"00";  -- System 11 KEYCUS type (0=none, 1=C406)
      -- EEPROM blank-image download (MRA ioctl index 9, all-FF) -> zn1_io EEPROM BRAM
      ee_dl_wr        : in  std_logic := '0';
      ee_dl_addr      : in  std_logic_vector(9 downto 0) := (others => '0');
      ee_dl_data      : in  std_logic_vector(31 downto 0) := (others => '0');
      -- System 11 C76 shared-RAM mailbox, MIPS side (16-bit word) -> c76_sound at top level
      mb_mips_addr    : out std_logic_vector(13 downto 0) := (others => '0');
      mb_mips_wdata   : out std_logic_vector(15 downto 0) := (others => '0');
      mb_mips_we      : out std_logic := '0';
      mb_mips_rdata   : in  std_logic_vector(15 downto 0) := (others => '0');
      -- C76 liveness diag from top level (ZN1.sv): bit0=c76_c352_seen (C76 wrote C352
      -- during BIOS init = alive), bit1=c76_halted (C76 hit an unimplemented opcode = crashed)
      dbg_c76_in      : in  std_logic_vector(1 downto 0) := "00";
      dbg_c76_pc      : in  std_logic_vector(23 downto 0) := (others => '0');  -- live C76 PC -> value display
      dbg_reached_game : out std_logic := '0';  -- MIPS reached game code -> top-level overlay auto-hide
      -- Debug: {sio_ever_seen, check2_seen, check1_seen, sec_select[1:0]}
      zn_debug_out    : out std_logic_vector(6 downto 0);
      -- build #50: raw 32-bit SDRAM word latched at green anchor (CPU 0x1F644810)
      zn_debug_val    : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_a0       : out std_logic_vector(31 downto 0) := (others => '0');  -- spin-loop a0 register
      zn_dbg_a1       : out std_logic_vector(31 downto 0) := (others => '0');  -- spin-loop a1 register
      zn_dbg_eeprom_o : out std_logic_vector(23 downto 0) := (others => '0');  -- {pend, readback, busy}
      zn_dbg_gpu      : out std_logic_vector(31 downto 0) := (others => '0');  -- GPU activity latches
      zn_dbg_disp     : out std_logic_vector(31 downto 0) := (others => '0');  -- {DispW, DispOffY, drawOffY}
      zn_dbg_dma      : out std_logic_vector(31 downto 0) := (others => '0');  -- {gpu_dmaReq, dma_wrEna, cnt}
      zn_dbg_madr     : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_nextaddr : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_gpustat  : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_procst   : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_pv0      : out std_logic_vector(31 downto 0) := (others => '0');
      zn_dbg_mipspc   : out std_logic_vector(31 downto 0) := (others => '0');  -- 2026-07-10: live MIPS PC (boot-hang triage)
      zn_dbg_pause    : out std_logic_vector(31 downto 0) := (others => '0');  -- 2026-07-10: pause/ce/stall forensics
      zn_dbg_pv2      : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_vram_coord  : in  std_logic_vector(31 downto 0) := (others => '0');  -- JTAG VRAM readback coord
      -- In-core trace buffer (JTAG-free logic analyzer) passthrough from cpu -> SYSTEM11.sv renderer
      trace_flat      : out std_logic_vector(2047 downto 0) := (others => '0');
      trace_meta      : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #51: computed SDRAM byte address latched at green anchor (expect 0x00E44810)
      zn_debug_addr   : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #52: 8 contiguous bank0 words [0x1F644800,0x1F644820)
      zn_debug_words  : out std_logic_vector(255 downto 0) := (others => '0')
   );
end entity;

architecture arch of psx_top is

   signal reset_in               : std_logic := '0';
   signal reset_intern           : std_logic := '0';
   signal reset_exe              : std_logic;
   
   signal ce                     : std_logic := '0';
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';

   signal clk1xToggle3X          : std_logic := '0';
   signal clk1xToggle3X_1        : std_logic := '0';
   signal clk3xIndex             : std_logic := '0';
   
   signal Pause_Idle             : std_logic;
   signal pausing                : std_logic := '0';
   signal pausingSS              : std_logic := '0';
   signal allowunpause           : std_logic;
   
   signal pauseCD                : std_logic;
   signal Pause_idle_cd          : std_logic;
   
   -- ddr3 arbiter
   type tddr3State is
   (
      ARBITERIDLE,
      WAITGPUPAUSED,
      REQUEST,
      WAITDONE
   );
   signal ddr3state              : tddr3State := ARBITERIDLE;
   
   signal arbiter_active         : std_logic := '0';
   
   signal memDDR3card1_acknext   : std_logic := '0';
   signal memDDR3card2_acknext   : std_logic := '0';
   signal memHPScard1_acknext    : std_logic := '0';
   signal memHPScard2_acknext    : std_logic := '0';
   signal memSPU_acknext         : std_logic := '0';
   
   signal arbiter_BURSTCNT       : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_ADDR           : std_logic_vector(27 downto 0) := (others => '0');                       
   signal arbiter_DIN            : std_logic_vector(63 downto 0) := (others => '0');
   signal arbiter_BE             : std_logic_vector(7 downto 0) := (others => '0'); 
   signal arbiter_WE             : std_logic := '0';
   signal arbiter_RD             : std_logic := '0';
   
   signal memDDR3card1_request   : std_logic;
   signal memDDR3card1_ack       : std_logic := '0';
   signal memDDR3card1_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card1_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card1_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card1_WE        : std_logic := '0';
   signal memDDR3card1_RD        : std_logic := '0';
   
   signal memDDR3card2_request   : std_logic;
   signal memDDR3card2_ack       : std_logic := '0';
   signal memDDR3card2_BURSTCNT  : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_ADDR      : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memDDR3card2_DIN       : std_logic_vector(63 downto 0) := (others => '0');
   signal memDDR3card2_BE        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memDDR3card2_WE        : std_logic := '0';
   signal memDDR3card2_RD        : std_logic := '0';
   
   signal memSPU_request         : std_logic;
   signal memSPU_ack             : std_logic := '0';
   signal memSPU_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_ADDR            : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memSPU_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal memSPU_BE              : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memSPU_WE              : std_logic := '0';
   signal memSPU_RD              : std_logic := '0';

   -- Busses
   signal bios_memctrl           : unsigned(13 downto 0);
   
   signal ex1_memctrl            : unsigned(13 downto 0);
   --signal bus_exp1_addr          : unsigned(22 downto 0); 
   --signal bus_exp1_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_exp1_read          : std_logic;
   --signal bus_exp1_write         : std_logic;
   signal bus_exp1_dataRead      : std_logic_vector(7 downto 0);
   
   signal bus_memc_addr          : unsigned(5 downto 0); 
   signal bus_memc_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_memc_read          : std_logic;
   signal bus_memc_write         : std_logic;
   signal bus_memc_dataRead      : std_logic_vector(31 downto 0);
   
   signal bus_pad_addr           : unsigned(3 downto 0); 
   signal bus_pad_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_pad_read           : std_logic;
   signal bus_pad_write          : std_logic;
   signal bus_pad_writeMask      : std_logic_vector(3 downto 0);
   signal bus_pad_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_sio_addr           : unsigned(3 downto 0); 
   signal bus_sio_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_sio_read           : std_logic;
   signal bus_sio_write          : std_logic;
   signal bus_sio_writeMask      : std_logic_vector(3 downto 0);
   signal bus_sio_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_memc2_addr         : unsigned(3 downto 0); 
   signal bus_memc2_dataWrite    : std_logic_vector(31 downto 0);
   signal bus_memc2_read         : std_logic;
   signal bus_memc2_write        : std_logic;
   signal bus_memc2_dataRead     : std_logic_vector(31 downto 0);
   
   signal bus_irq_addr           : unsigned(3 downto 0); 
   signal bus_irq_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_irq_read           : std_logic;
   signal bus_irq_write          : std_logic;
   signal bus_irq_dataRead       : std_logic_vector(31 downto 0);   
   
   signal bus_dma_addr           : unsigned(6 downto 0); 
   signal bus_dma_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_dma_read           : std_logic;
   signal bus_dma_write          : std_logic;
   signal bus_dma_dataRead       : std_logic_vector(31 downto 0);
   
   signal bus_tmr_addr           : unsigned(5 downto 0); 
   signal bus_tmr_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_tmr_read           : std_logic;
   signal bus_tmr_write          : std_logic;
   signal bus_tmr_dataRead       : std_logic_vector(31 downto 0);
   
   signal cd_memctrl             : unsigned(13 downto 0);
   signal bus_cd_addr            : unsigned(3 downto 0); 
   signal bus_cd_dataWrite       : std_logic_vector(7 downto 0);
   signal bus_cd_read            : std_logic;
   signal bus_cd_write           : std_logic;
   signal bus_cd_dataRead        : std_logic_vector(7 downto 0);
   
   signal bus_gpu_addr           : unsigned(3 downto 0); 
   signal bus_gpu_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_gpu_read           : std_logic;
   signal bus_gpu_write          : std_logic;
   signal bus_gpu_dataRead       : std_logic_vector(31 downto 0);
   signal bus_gpu_stall          : std_logic;
   
   signal bus_mdec_addr          : unsigned(3 downto 0); 
   signal bus_mdec_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_mdec_read          : std_logic;
   signal bus_mdec_write         : std_logic;
   signal bus_mdec_dataRead      : std_logic_vector(31 downto 0);
   
   signal spu_memctrl            : unsigned(13 downto 0);
   signal bus_spu_addr           : unsigned(9 downto 0); 
   signal bus_spu_dataWrite      : std_logic_vector(15 downto 0);
   signal bus_spu_read           : std_logic;
   signal bus_spu_write          : std_logic;
   signal bus_spu_dataRead       : std_logic_vector(15 downto 0);
   signal spustub_cnt            : std_logic_vector(15 downto 0) := (others => '0'); -- SPU stub v2: last SPUCNT written
   
   signal ex2_memctrl            : unsigned(13 downto 0);
   signal bus_exp2_addr          : unsigned(12 downto 0); 
   signal bus_exp2_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp2_read          : std_logic;
   signal bus_exp2_write         : std_logic;
   signal bus_exp2_dataRead      : std_logic_vector(7 downto 0);  
   
   signal ex3_memctrl            : unsigned(13 downto 0);
   --signal bus_exp3_dataWrite     : std_logic_vector(7 downto 0);
   signal bus_exp3_read          : std_logic;
   --signal bus_exp3_write         : std_logic;
   signal bus_exp3_dataRead      : std_logic_vector(15 downto 0);
   
   signal com0_delay             : unsigned(3 downto 0);
   signal com1_delay             : unsigned(3 downto 0);
   signal com2_delay             : unsigned(3 downto 0);
   signal com3_delay             : unsigned(3 downto 0);
   
   signal dma_spu_timing_on      : std_logic;
   signal dma_spu_timing_value   : unsigned(3 downto 0);
   
   -- Memory mux
   signal memMuxIdle             : std_logic;
   
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_isData             : std_logic; 
   signal mem_isCache            : std_logic; 
   signal mem_oldtagvalids       : std_logic_vector(3 downto 0);
   signal mem_addressInstr       : unsigned(31 downto 0); 
   signal mem_addressData        : unsigned(31 downto 0); 
   signal mem_reqsize            : unsigned(1 downto 0); 
   signal mem_writeMask          : std_logic_vector(3 downto 0);
   signal mem_dataWrite          : std_logic_vector(31 downto 0); 
   signal mem_dataRead           : std_logic_vector(31 downto 0); 
   signal mem_done               : std_logic;
   signal mem_fifofull           : std_logic;
   signal mem_tagvalids          : std_logic_vector(3 downto 0);
   
   signal ram_next_cpu           : std_logic;
   
   signal ram_cpu_dataWrite      : std_logic_vector(31 downto 0);
   signal ram_cpu_Adr            : std_logic_vector(26 downto 0);
   signal ram_cpu_be             : std_logic_vector(3 downto 0);
   signal ram_cpu_rnw            : std_logic;
   signal ram_cpu_ena            : std_logic;
   signal ram_cpu_cache          : std_logic;
   signal ram_cpu_done           : std_logic;
   
   -- gpu
   signal vblank_tmr             : std_logic;
   signal hblank_tmr             : std_logic;
   signal dotclock               : std_logic;
   
   signal vram_pause             : std_logic; 
   signal vram_paused            : std_logic; 
   signal vram_BURSTCNT          : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_ADDR              : std_logic_vector(27 downto 0) := (others => '0');                       
   signal vram_DIN               : std_logic_vector(63 downto 0) := (others => '0');
   signal vram_BE                : std_logic_vector(7 downto 0) := (others => '0'); 
   signal vram_WE                : std_logic := '0';
   signal vram_RD                : std_logic := '0'; 
   
   -- irq
   signal irqRequest             : std_logic;
   signal irq_VBLANK             : std_logic;
   signal gpustat31_sig          : std_logic;  -- build #169: GPUSTAT bit 31 from gpu.vhd
   signal gpustat_sig            : std_logic_vector(31 downto 0);  -- S11 GPU-hang diag: full GPUSTAT
   signal fifoIn_empty_sig       : std_logic;  -- S11 GPU-hang diag: GPU input-FIFO empty
   signal gpu_fifo_empty_ever    : std_logic := '0';  -- latches if the GPU FIFO is EVER empty (=did it ever drain)
   signal drawingAreaBottom_sig  : std_logic_vector(9 downto 0);   -- build #172
   signal drawingOffsetY_sig     : std_logic_vector(10 downto 0);  -- build #172
   signal b172_drawArea_high_ever  : std_logic := '0';
   signal b172_drawOffset_high_ever: std_logic := '0';
   signal irq_GPU                : std_logic;
   signal irq_CDROM              : std_logic;
   signal irq_DMA                : std_logic;
   signal irq_TIMER0             : std_logic;
   signal irq_TIMER1             : std_logic;
   signal irq_TIMER2             : std_logic;
   signal irq_PAD                : std_logic;
   signal irq_SIO                : std_logic;
   signal irq_SPU                : std_logic;
   signal irq_LIGHTPEN           : std_logic;
   
   -- dma
   signal cpuPaused              : std_logic := '0';
   signal dbg_cpu_stall          : std_logic_vector(4 downto 0);
   signal dmaOn                  : std_logic;
   signal dmaRequest             : std_logic;
   signal dmaStallCPU            : std_logic;
   signal canDMA                 : std_logic;
   signal ignoreDMACDTiming      : std_logic;
   
   signal ram_dma_Adr            : std_logic_vector(22 downto 0);
   signal ram_dma_ena            : std_logic;
   
   signal dma_cache_Adr          : std_logic_vector(21 downto 0);
   signal dma_cache_data         : std_logic_vector(31 downto 0);
   signal dma_cache_write        : std_logic;
   
   signal gpu_dmaRequest         : std_logic;
   signal dma_gpu_wr_cnt         : unsigned(23 downto 0) := (others => '0');
   -- write-path forensics (2026-07-05): live DDR3 vram traffic counters + last write address
   signal dbg_vramwe_cnt         : unsigned(15 downto 0) := (others => '0');
   signal dbg_vramrd_cnt         : unsigned(15 downto 0) := (others => '0');
   signal dbg_vramwe_lastaddr    : std_logic_vector(27 downto 0) := (others => '0');
   signal dbg_c2vpix_cnt         : unsigned(15 downto 0) := (others => '0');
   signal dbg_piogp0_cnt         : unsigned(15 downto 0) := (others => '0');
   signal dbg_vramwe_xhi_cnt     : unsigned(15 downto 0) := (others => '0');
   signal dma2_madr              : std_logic_vector(23 downto 0);
   signal dma2_nextaddr          : std_logic_vector(23 downto 0);
   signal dma2_state             : std_logic_vector(2 downto 0);
   signal dma2_chan              : std_logic_vector(2 downto 0);
   signal dma2_chcr2             : std_logic_vector(31 downto 0);
   -- mailbox-read forensics
   signal mbrd_sel_d             : std_logic := '0';
   signal mbrd_addr_d            : std_logic_vector(15 downto 0) := (others => '0');
   signal dbg_mbrd               : std_logic_vector(31 downto 0) := (others => '0');
   signal dma2_corrupt_hdr       : std_logic_vector(31 downto 0);  -- op#10: corrupt list header word
   signal dma2_corrupt_src       : std_logic_vector(31 downto 0);  -- op#10: [31]seen [23:0]=src D_MADR
   signal DMA_GPU_waiting        : std_logic;
   signal DMA_GPU_writeEna       : std_logic;
   signal DMA_GPU_readEna        : std_logic;
   signal DMA_GPU_write          : std_logic_vector(31 downto 0);
   signal DMA_GPU_read           : std_logic_vector(31 downto 0);
   
   signal mdec_dmaWriteRequest   : std_logic;
   signal mdec_dmaReadRequest    : std_logic;
   signal DMA_MDEC_writeEna      : std_logic := '0';
   signal DMA_MDEC_readEna       : std_logic := '0';
   signal DMA_MDEC_write         : std_logic_vector(31 downto 0);
   signal DMA_MDEC_read          : std_logic_vector(31 downto 0);
   
   signal DMA_CD_readEna         : std_logic;
   signal DMA_CD_read            : std_logic_vector(7 downto 0);
   
   signal spu_dmaRequest         : std_logic;
   signal DMA_SPU_writeEna       : std_logic := '0';
   signal DMA_SPU_readEna        : std_logic := '0';
   signal DMA_SPU_write          : std_logic_vector(15 downto 0);
   signal DMA_SPU_read           : std_logic_vector(15 downto 0);
   
   -- SPU
   signal spu_tick               : std_logic;
   signal cd_left                : signed(15 downto 0);
   signal cd_right               : signed(15 downto 0);
   
   -- cpu
   signal ce_intern              : std_logic := '0';
   signal stallNext              : std_logic;
   
   -- GTE
   signal gte_busy               : std_logic;
   signal gte_readEna            : std_logic;
   signal gte_readAddr           : unsigned(5 downto 0);
   signal gte_readData           : unsigned(31 downto 0);
   signal gte_writeAddr          : unsigned(5 downto 0);
   signal gte_writeData          : unsigned(31 downto 0);
   signal gte_writeEna           : std_logic; 
   signal gte_cmdData            : unsigned(31 downto 0);
   signal gte_cmdEna             : std_logic; 

   -- overlay + error codes
   signal cdSlow                 : std_logic;
   signal cdslowEna              : std_logic;
   signal errorEna               : std_logic;
   signal errorCode              : unsigned(3 downto 0) := (others => '0');
   signal LBAdisplay             : unsigned(19 downto 0);
   
   signal errorCD                : std_logic;
   signal errorCPU               : std_logic;
   signal errorCPU2              : std_logic;
   signal errorLINE              : std_logic;
   signal errorRECT              : std_logic;
   signal errorPOLY              : std_logic;
   signal errorGPU               : std_logic;
   signal errorMASK              : std_logic;
   signal errorCHOP              : std_logic;
   signal errorGPUFIFO           : std_logic;
   signal errorSPUTIME           : std_logic;
   signal errorDMACPU            : std_logic;
   signal errorDMAFIFO           : std_logic;
   signal errorTimer             : std_logic;
   signal errorBuswidth          : std_logic;
   
   signal debugmodeOn            : std_logic;

   signal Gun1CrosshairOn        : std_logic;
   signal Gun2CrosshairOn        : std_logic;
   signal Gun1X                  : unsigned(7 downto 0);
   signal Gun1Y                  : unsigned(7 downto 0);
   signal Gun2X                  : unsigned(7 downto 0);
   signal Gun2Y                  : unsigned(7 downto 0);
   signal Gun1Y_scanlines        : unsigned(8 downto 0);
   signal Gun2Y_scanlines        : unsigned(8 downto 0);
   signal Gun1AimOffscreen       : std_logic;
   signal Gun2AimOffscreen       : std_logic;   
   signal Gun1offscreen          : std_logic;
   signal Gun2offscreen          : std_logic;
   signal Gun1IRQ10              : std_logic;
   signal Gun2IRQ10              : std_logic;
   signal JustifierIrqEnable     : std_logic_vector(1 downto 0);

   -- memcard
   signal memcard1_pause         : std_logic;
   signal memcard2_pause         : std_logic;
   
   signal MemCard_changePending1 : std_logic;
   signal MemCard_changePending2 : std_logic;   
   
   signal MemCard_saving_memcard1: std_logic;
   signal MemCard_saving_memcard2: std_logic;
   
   signal memHPScard1_request    : std_logic;
   signal memHPScard1_ack        : std_logic := '0';
   signal memHPScard1_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard1_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard1_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard1_WE         : std_logic := '0';
   signal memHPScard1_RD         : std_logic := '0';
                                 
   signal memHPScard2_request    : std_logic;
   signal memHPScard2_ack        : std_logic := '0';
   signal memHPScard2_BURSTCNT   : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_ADDR       : std_logic_vector(19 downto 0) := (others => '0');                       
   signal memHPScard2_DIN        : std_logic_vector(63 downto 0) := (others => '0');
   signal memHPScard2_BE         : std_logic_vector(7 downto 0) := (others => '0'); 
   signal memHPScard2_WE         : std_logic := '0';
   signal memHPScard2_RD         : std_logic := '0';

   -- ZN-1 I/O bus signals (connects memorymux to zn1_io)
   signal bus_znio_addr          : unsigned(20 downto 0);
   signal bus_znio_dataWrite     : std_logic_vector(31 downto 0);
   signal bus_znio_read          : std_logic;
   signal bus_znio_write         : std_logic;
   signal bus_znio_writeMask     : std_logic_vector(3 downto 0);
   -- DIAG 2026-06-25: count distinct EEPROM (0x1FA30000-0xFFF) write transactions to tell
   -- whether the boot EEPROM-init is PROGRESSING (climbs to ~1312 then stops) vs RE-WRITING
   -- (climbs past 1312 = data not persisting) vs STUCK (plateaus < 1312 while MIPS spins).
   signal eeprom_wr_count        : unsigned(10 downto 0) := (others => '0');
   signal znio_wr_prev           : std_logic := '0';
   signal zn_dbg_eeprom          : std_logic_vector(23 downto 0);
   signal bus_znio_dataRead      : std_logic_vector(31 downto 0);
   signal zn_sec_select          : std_logic_vector(2 downto 0);  -- {data[7],data[3],data[2]}
   signal zn_coin_out            : std_logic_vector(7 downto 0);
   -- System 11: bank selectors (zn1_io -> memorymux) + C76 mailbox (zn1_io <-> c76_sound)
   signal zn_s11_bank            : std_logic_vector(39 downto 0);
   signal zn_s11_up              : std_logic;
   signal s11_gputype1           : std_logic;
   signal zn_dbg_bankwr          : std_logic_vector(31 downto 0);
   signal zn_mb_addr             : std_logic_vector(13 downto 0);
   signal zn_mb_wdata            : std_logic_vector(15 downto 0);
   signal zn_mb_we               : std_logic;
   signal zn_mb_rdata            : std_logic_vector(15 downto 0) := (others => '0');
   -- DIAGNOSTIC: value the MIPS reads at the 0x1FA0BD32 handshake poll + bit-0x80 latch
   signal zn_poll_val            : std_logic_vector(15 downto 0) := (others => '0');
   signal zn_poll_bit80          : std_logic := '0';

   -- ZN SNAC intermediaries (joypad outputs → zn_sio inputs, zn_sio outputs → joypad inputs)
   signal zn_beginTransfer       : std_logic;
   signal zn_txbyte              : std_logic_vector(7 downto 0);
   signal zn_action_next         : std_logic;
   signal zn_receive_valid       : std_logic;
   signal zn_ack                 : std_logic;
   signal zn_rxbyte              : std_logic_vector(7 downto 0);
   signal zn_sel_p2              : std_logic := '0';  -- selectedPort2Snac; also drives chip_sel
   signal ram_accessed_seen      : std_logic := '0';  -- latches on any CPU RAM request (read or write)
   signal ram_done_seen          : std_logic := '0';  -- latches when SDRAM completes a CPU transaction
   signal nonzero_read_seen      : std_logic := '0';  -- latches when SDRAM returns non-zero data (BIOS loaded)
   signal gpu_accessed_seen      : std_logic := '0';  -- latches on any GPU bus access
   signal ram_exec_seen          : std_logic := '0';  -- latches when CPU fetches instruction from physical RAM
   signal s11_mb_seen            : std_logic := '0';  -- latches when MIPS writes the System 11 C76 mailbox
   signal s11_reached_1fc2       : std_logic := '0';  -- latches when CPU fetches from the late-boot ROM region 0x1FC20000..0x1FC30000 (Tekken handshake/GPU init)
   signal dbg_last_ram_pc        : std_logic_vector(31 downto 0) := (others => '0');  -- last RAM instruction-fetch address (hang-loop locator)
   signal dbg_last_any_pc        : std_logic_vector(31 downto 0) := (others => '0');  -- ABSOLUTE last instr-fetch (any region) — pins the hang loop wherever it is
   -- RENDER-HANG DIAG: latch the most-recent BIOS call-table read address. A-call dispatcher
   -- (0xA00005C4) does t0=MEM[0x200+t1*4]; so a data read in [0x200,0x280) = the A-fn table,
   -- addr-0x200)/4 = the A-function number the game loops on. (B-table @0x6D4, C-table @0x600.)
   signal dbg_call_taddr         : std_logic_vector(23 downto 0) := (others => '0');
   signal dbg_last_wr_addr       : std_logic_vector(31 downto 0) := (others => '0');  -- HEAP DIAG: last data-write address (= kernel memset dest when stuck @0xBFC03Fxx)
   signal memset_seen            : std_logic := '0';                                  -- HEAP DIAG: CPU fetched the bzero store 0xBFC01A70
   signal wr_seen                : std_logic := '0';                                  -- HEAP DIAG: any data write occurred
   signal heap_init_val          : std_logic_vector(31 downto 0) := (others => '0');  -- HEAP DIAG: first NON-zero value written to heap ptr 0xa0005d10 (= InitHeap base)
   signal heap_init_seen         : std_logic := '0';                                  -- HEAP DIAG: a non-zero heap base was written
   signal heap_advanced          : std_logic := '0';                                  -- HEAP DIAG: 0xa0005d10 written a 2nd distinct value (B0(0) advanced it)
   -- DERAIL-BRACKET milestones (2026-06-14): "reached" latches in MAME execution order
   signal rch_decomp             : std_logic := '0';  -- m074: 0xBFC00074 (end of first early block)
   signal rch_kernel             : std_logic := '0';  -- m140: 0xBFC00140 (HW init routine)
   signal rch_b0handler          : std_logic := '0';  -- m1B8: 0xBFC001B8
   signal rch_initheap           : std_logic := '0';  -- m484: 0xBFC00484 (kernel ROM->RAM copy loop)
   signal rch_alloc              : std_logic := '0';  -- unused
   signal m_gpuinit              : std_logic := '0';  -- reached 0xBFC097EC (GPU init)
   signal m_strcmp               : std_logic := '0';  -- reached 0xBFC03298 (license strcmp)
   signal m_strfail              : std_logic := '0';  -- reached 0xBFC09054 (strcmp FAILED branch)
   signal m_launch               : std_logic := '0';  -- reached 0xBFC004B8 (game launch = strcmp PASSED)
   signal m_decomp2              : std_logic := '0';  -- reached 0x1FC202B4 (decompressor)
   signal dbg_bios_pc            : std_logic_vector(31 downto 0) := (others => '0'); -- last instr-fetch in BIOS ROM [0xBFC08000,0xBFC30000) = the loop's BIOS code location
   signal derail_src             : std_logic_vector(31 downto 0) := (others => '0'); -- PC just before the 1st fetch into wild loop 0xBFC07xxx
   signal lowsled_seen           : std_logic := '0';                                 -- MIPS wild-jumped into the low NOP sled (phys 0x10..0x7F)
   signal lowsled_src            : std_logic_vector(31 downto 0) := (others => '0');  -- the jr that did it (pc_hist2 at the first low-sled fetch)
   signal dbg_ctable_seen        : std_logic := '0';                                 -- first C-table pointer read captured
   signal dbg_ctable_val         : std_logic_vector(31 downto 0) := (others => '0');  -- the C-function pointer value read (corrupt => derail)
   signal dbg_ctable_fn          : std_logic_vector(7 downto 0)  := (others => '0');  -- funcnum = (addr-0x65C)/4
   signal dbg_ctw_seen           : std_logic := '0';                                 -- the CPU ever WROTE the C-table region [0x65C,0x6BC)
   signal dbg_ctw_val            : std_logic_vector(31 downto 0) := (others => '0');  -- value written there (= install). correct ~0xA000xxxx; never => install skipped
   signal dbg_w65_seen           : std_logic := '0';                                 -- the SDRAM-interface write of 0xA0001078 (the C(0) install) was seen
   signal dbg_w65_be             : std_logic_vector(3 downto 0)  := (others => '0');  -- ram_be at that write (1111=ok; masked => no-op)
   signal dbg_w65_adr            : std_logic_vector(26 downto 0) := (others => '0');  -- ram_Adr at that write (the SDRAM word address)
   signal dbg_rb_seen            : std_logic := '0';                                 -- CPU ever READ back exactly 0x65C
   signal dbg_rb_val             : std_logic_vector(31 downto 0) := (others => '0'); -- the value read (0xA0001078=correct, 0xAD400070=stale)
   signal derail_captured        : std_logic := '0';
   signal cpu_dbg_exc_epc        : unsigned(31 downto 0);            -- first CPU fault EPC (faulting PC)
   signal cpu_dbg_exc_code       : unsigned(3 downto 0);             -- first CPU fault ExcCode (4/5=AdE,6=PCoob,A=RI)
   signal cpu_dbg_fault_a1       : unsigned(31 downto 0);            -- architectural a1 (reg[5]) at the first fault
   signal cpu_dbg_fault_ra       : unsigned(31 downto 0);            -- return address (reg[31]) at the first fault
   signal cpu_dbg_fault_addr     : unsigned(31 downto 0);            -- faulting store/load addr (bad pointer) at first fault
   signal cpu_dbg_fault_s1s2     : std_logic_vector(31 downto 0);    -- [31:16]=$s1[15:0] [15:0]=$s2[15:0] at first fault
   signal cpu_dbg_fault_sp       : std_logic_vector(31 downto 0);    -- $sp(r29) at first fault
   signal cpu_dbg_wrcap_pc       : std_logic_vector(31 downto 0);    -- PC storing the garbage ptr to 0x803FFE04
   signal cpu_dbg_wrcap_data     : std_logic_vector(31 downto 0);    -- the garbage ptr value stored
   signal cpu_dbg_instr_word     : unsigned(31 downto 0);            -- fetched word @0xBFC20280 (expected 0x30A20001)
   signal cpu_dbg_t0             : std_logic_vector(31 downto 0);    -- now carries a1 (regs5)
   signal cpu_dbg_a3             : std_logic_vector(31 downto 0);    -- now carries v0 (regs2)
   signal cpu_dbg_a0r            : std_logic_vector(31 downto 0);    -- a0 (regs4)
   signal dbg_cyc                : unsigned(24 downto 0) := (others => '0');
   signal helper_entry_seen      : std_logic := '0';                 -- MIPS ever fetched the helper entry 0xBFC20280
   signal pc_hist1               : std_logic_vector(31 downto 0) := (others => '0');  -- fetch PC 1 ago
   signal pc_hist2               : std_logic_vector(31 downto 0) := (others => '0');  -- fetch PC 2 ago (the jr)
   signal kuseg_src              : std_logic_vector(31 downto 0) := (others => '0');  -- source of the jump into KUSEG fault region
   signal kuseg_seen             : std_logic := '0';
   signal panic_reached          : std_logic := '0';                 -- MIPS fetched the BIOS panic loop 0xBFC08DE0
   -- build 10: for the lw of 0x1FC20000 — the SDRAM data memorymux INGESTS (ram_dataRead32)
   -- and the value DELIVERED to the CPU (mem_dataRead). Splits SDRAM-connection vs delivery.
   signal dbg_lw_input           : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_lw_output          : std_logic_vector(31 downto 0) := (others => '0');
   signal dbg_lw_seen            : std_logic := '0';
   signal dbg_last_io_rd         : std_logic_vector(31 downto 0) := (others => '0');  -- last CPU data-read addr in the hardware/IO range (poll target; data reads aren't cached)
   -- System 11 boot diagnostic: MAME's Tekken reaches GAME code at physical 0x18654
   -- (= 0x80018654), which is BELOW ram_exec_seen's 0x40000 threshold — so ram_exec
   -- would stay dim even when the game runs. s11_reached_game catches [0x10000,0x40000).
   signal s11_reached_game       : std_logic := '0';  -- latches CPU instr-fetch in physical [0x10000,0x40000) (early game code @0x18654)
   signal dbg_boot_pc            : std_logic_vector(31 downto 0) := (others => '0');  -- last CPU instr-fetch in 0x1FC20000..0x1FC30000 (boot/handshake stuck-PC locator)
   signal io_ever_seen           : std_logic := '0';  -- latches when any ZN I/O access occurs
   signal spu_ever_seen          : std_logic := '0';  -- latches when SPU registers accessed
   signal cd_ever_seen           : std_logic := '0';  -- latches when CD-ROM registers accessed
   signal dma_ever_seen          : std_logic := '0';  -- latches when DMA registers written
   signal dma_gpu_write_seen     : std_logic := '0';  -- latches when DMA ch2 actually wrote a word to GPU
   signal dma2_e5_write_seen    : std_logic := '0';  -- latches when DMA ch2 wrote a word with cmd byte 0xE5
   signal dma2_prim_seen         : std_logic := '0';  -- latches when DMA ch2 wrote a word whose upper byte is a drawing primitive (0x20..0x7F: polygon/line/rect)
   signal pio_prim_seen          : std_logic := '0';  -- latches when CPU PIO wrote GP0 with upper byte 0x20..0x7F (any primitive)
   -- build #150: sticky latches for CPU PC at the cube CLUT PIO upload site (MAME PC 0x8003CB20).
   --   h50_pc_cube_loop_seen : CPU fetched instruction at exactly 0x8003CB20 ever (the load-store body of the loop)
   --   h50_pc_cube_area_seen : CPU fetched any instruction in [0x8003CB00, 0x8003CB60) ever (the surrounding function)
   --   h50_game_ram_exec_seen : CPU fetched any instruction in [0x80050000, 0x80060000) ever (positive control: game code is running)
   signal h50_pc_cube_loop_seen  : std_logic := '0';
   signal h50_pc_cube_area_seen  : std_logic := '0';
   signal h50_game_ram_exec_seen : std_logic := '0';
   -- build #151: sticky latches on CPU PIO writes to GP0 (bus_gpu_addr="0000")
   --   h51_gp0_cubeclut_seen : CPU ever wrote 0x7FFF0000 to GP0 (cube CLUT entries 0+1 packed)
   --   h51_gp0_a0cmd_seen    : CPU ever wrote 0xA0xxxxxx to GP0 (CPU2VRAM mode command)
   --   h51_gp0_r31_seen      : CPU ever wrote a value with R=31 in upper-halfword pixel (PIO upload of any R=31 pixel)
   signal h51_gp0_cubeclut_seen  : std_logic := '0';
   signal h51_gp0_a0cmd_seen     : std_logic := '0';
   signal h51_gp0_r31_seen       : std_logic := '0';
   -- build #152: sticky latches on cube CLUT data words 1-3 at GP0 PIO.
   signal h52_gp0_word1_seen     : std_logic := '0';
   signal h52_gp0_word2_seen     : std_logic := '0';
   signal h52_gp0_word3_seen     : std_logic := '0';
   -- build #153: bisect cube CLUT init step. CPU init copies banked ROM → PSX RAM.
   signal h53_rd_cubesrc_seen    : std_logic := '0';
   signal h53_wr_staging_seen    : std_logic := '0';
   signal h53_data_7fff0000_seen : std_logic := '0';
   -- build #154: bank-value capture at the cube CLUT read.
   --   h54_bank0_at_read : zn_bank_8mb = "000" when CPU reads 0x1F7B61CC ever
   --   h54_bank1_at_read : zn_bank_8mb = "001" when CPU reads 0x1F7B61CC ever
   --   h54_bankhi_at_read: zn_bank_8mb >= "010" when CPU reads 0x1F7B61CC ever
   signal h54_bank0_at_read      : std_logic := '0';
   signal h54_bank1_at_read      : std_logic := '0';
   signal h54_bankhi_at_read     : std_logic := '0';
   signal dbg_pipeline_pixelWrite: std_logic;          -- live from GPU: rasterizer produced a pixel write
   signal raster_pixel_seen      : std_logic := '0';  -- latches when GPU rasterizer ever produced a VRAM pixel write
   signal dbg_pipeline_write_in_top : std_logic;        -- live from GPU: rasterizer wrote to Y<256
   signal dbg_vram_WE_tap        : std_logic;          -- live from GPU: vram_WE asserted toward DDR3
   signal raster_pixel_top_seen  : std_logic := '0';  -- latches when rasterizer pixel landed in Y<256 (visible top half)
   signal vram_actual_write_seen : std_logic := '0';  -- latches when vram_WE was actually asserted to DDR3
   signal dbg_pipeline_color_varied : std_logic;       -- live: rasterizer produced non-navy color
   signal dbg_vram_din_non_navy : std_logic;           -- live: vram_DIN contained non-navy data on a write
   signal pipeline_color_varied_seen : std_logic := '0';  -- latches when rasterizer ever produced non-navy color
   signal vram_din_non_navy_seen   : std_logic := '0';  -- latches when vram_DIN ever had non-navy data on write
   signal dbg_vram_dout_nonnavy           : std_logic; -- live: DDR3 returned non-navy lane on a GPU read
   signal dbg_videoout_linebuf_nonnavy    : std_logic; -- live: videoout line buffer 16-bit read != navy
   -- build #56: per-frame pixel COUNTS (uncontaminated by sticky text). Magnitude discriminates
   -- full-scene rendering (~150-245K/frame) from text-only (~few K). Sampled in clk1x (half-rate;
   -- relative magnitudes preserved across all three). Latched to disp_* at VBLANK rising edge.
   signal cnt_stage4       : unsigned(17 downto 0) := (others => '0');  -- textured pixels reaching stage4 this frame
   signal cnt_pxwr         : unsigned(17 downto 0) := (others => '0');  -- rasterizer pixel writes this frame
   signal cnt_texraw      : unsigned(17 downto 0) := (others => '0');  -- build #57: stage4 textured pixels w/ non-zero RAW texel index (texture DATA present pre-CLUT)
   signal disp_cnt_stage4  : unsigned(17 downto 0) := (others => '0');
   signal disp_cnt_pxwr    : unsigned(17 downto 0) := (others => '0');
   signal disp_cnt_texraw : unsigned(17 downto 0) := (others => '0');
   signal dbg_videoout_pixeldata_nonnavy  : std_logic; -- live: videoout pixelData_R/G/B != pure navy
   signal vram_dout_nonnavy_seen          : std_logic := '0';  -- (unused now; kept for reference) sticky version
   signal videoout_linebuf_nonnavy_seen   : std_logic := '0';  -- (unused now)
   signal videoout_pixeldata_nonnavy_seen : std_logic := '0';  -- (unused now)
   signal hblank_i                        : std_logic;  -- internal copy of videoout hblank (readable)
   signal vblank_i                        : std_logic;  -- internal copy of videoout vblank (readable)
   signal de_active_seen                  : std_logic := '0';  -- DE ever active (not hbl & not vbl)
   signal visible_nonnavy_seen            : std_logic := '0';  -- non-navy videoout pixel DURING active DE
   signal visible_color_seen              : std_logic := '0';  -- TRUE nonblack (real color) pixel DURING active DE
   signal video_r_i                       : std_logic_vector(7 downto 0);  -- readable copies of videoout RGB
   signal video_g_i                       : std_logic_vector(7 downto 0);
   signal video_b_i                       : std_logic_vector(7 downto 0);
   -- Frame-windowed latches (build #7: pipeline color-path narrowing).
   signal vblank_d                        : std_logic := '0';
   signal dbg_rast_display_nonnavy        : std_logic;
   signal dbg_rast_offdisp_nonnavy        : std_logic;
   signal dbg_vramdin_display_nonnavy     : std_logic;
   signal dbg_clut_write_nonnavy          : std_logic;
   signal dbg_clut_read_nonnavy           : std_logic;
   signal dbg_stage4_texture              : std_logic;
   signal dbg_stage4_texraw_nz            : std_logic;  -- build #57: stage4 textured pixel w/ non-zero raw texel index
   signal dbg_textPalReqY_clut            : std_logic;  -- build #63: textPalReqY in [460,500)
   signal dbg_last_succ_palX              : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_last_succ_palY              : std_logic_vector(9 downto 0);  -- build #67
   signal dbg_textPalReqY_lo              : std_logic;  -- build #68: textPalReqY in [460,480)
   signal dbg_textPalReqY_hi              : std_logic;  -- build #68: textPalReqY in [480,500)
   signal dbg_b82_byte_redslot            : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_byte_greenslot          : std_logic_vector(7 downto 0);  -- build #82
   signal dbg_b82_captured                : std_logic;                      -- build #82
   signal clut_succ_lo_seen               : std_logic := '0';  -- build #68: sticky for Y<480 success
   signal clut_succ_hi_seen               : std_logic := '0';  -- build #68: sticky for Y>=480 success
   -- 2026-07-03 TEXTURE-BLACK pipeline trace: sticky "non-navy seen" at each stage -> find where content dies
   signal tx_stage4_seen  : std_logic := '0';  -- a textured pixel reached stage4
   signal tx_texnz_seen   : std_logic := '0';  -- textured pixel with NON-ZERO raw texel index (texture data present)
   signal tx_clutrd_seen  : std_logic := '0';  -- CLUT/palette read returned NON-navy (palette lookup produced color)
   signal tx_rastdisp_seen: std_logic := '0';  -- rasterizer wrote NON-navy into the DISPLAY region
   signal tx_rastoff_seen : std_logic := '0';  -- rasterizer wrote NON-navy OFF the display region (content going elsewhere)
   signal tx_vramdin_seen : std_logic := '0';  -- VRAM write DIN NON-navy in the display region
   signal tx_vramdout_seen: std_logic := '0';  -- VRAM read DOUT returned NON-navy
   signal tx_volinebuf_seen:std_logic := '0';  -- videoout line buffer read NON-navy
   signal tx_vopixel_seen : std_logic := '0';  -- videoout final pixel NON-navy
   signal latch_lo_y_fan                  : std_logic_vector(17 downto 0);  -- build #68: latch fanned for bar
   signal latch_hi_y_fan                  : std_logic_vector(17 downto 0);  -- build #68: latch fanned for bar
   -- build #80: generic triage bars (any title) — RED=ram_exec_seen, GREEN=raster_pixel_seen, BLUE=gpu_accessed_seen
   signal triage_red_fan                  : std_logic_vector(8 downto 0);
   signal triage_green_fan                : std_logic_vector(8 downto 0);
   signal triage_blue_fan                 : std_logic_vector(8 downto 0);
   -- build #119: CAT702 byte-exchange diagnostics from zn_sio
   signal dbg_first_kn01_rx               : std_logic_vector(7 downto 0);
   -- build #157: BR2 CAT702 byte-0/byte-3 captures
   signal b157_byte0_sig                  : std_logic_vector(7 downto 0);
   signal b157_byte3_sig                  : std_logic_vector(7 downto 0);
   signal b157_anchor_sig                 : std_logic;
   signal dbg_first_kn02_rx               : std_logic_vector(7 downto 0);
   signal dbg_kn02_ever                   : std_logic;
   -- build #114 H1+H2: cube 0x64 rect path test
   signal h12_red_anchor_sig              : std_logic;
   signal h12_green_dm_ok_sig             : std_logic;
   signal h12_blue_dm_stale_sig           : std_logic;
   signal h12_yellow_busy0_sig            : std_logic;
   signal h12_white_dm_chg_sig            : std_logic;
   signal h12_cyan_emit_busy0_sig         : std_logic;
   signal h12_magenta_busy_long_sig       : std_logic;
   -- build #115: H1 race-frequency counters (9-bit upper portion of 16-bit counter)
   signal h12_stale_count_hi_sig          : std_logic_vector(8 downto 0);
   signal h12_ok_count_hi_sig             : std_logic_vector(8 downto 0);
   signal h12_stale_gt_ok_sig             : std_logic;
   -- build #117: G+B stripping locator stickys
   signal h17_anchor_sig                  : std_logic;
   signal h17_g_sig                       : std_logic;
   signal h17_b_sig                       : std_logic;
   -- build #119: vram_DIN G+B locator
   signal h19_anchor_sig                  : std_logic;
   signal h19_g_sig                       : std_logic;
   signal h19_b_sig                       : std_logic;
   -- build #120: counter-based G+B prevalence at cube area writes
   signal h20_anchor_count_hi_sig         : std_logic_vector(8 downto 0);
   signal h20_g_count_hi_sig              : std_logic_vector(8 downto 0);
   signal h20_b_count_hi_sig              : std_logic_vector(8 downto 0);
   -- build #122: vram_DOUT capture at hi-Y CLUT[3] load
   signal h22_anchor_sig                  : std_logic;
   signal h22_clut3_r_sig                 : std_logic_vector(4 downto 0);
   signal h22_clut3_g_sig                 : std_logic_vector(4 downto 0);
   -- build #124: SDRAM round-trip self-test
   signal h24_write_r_sig                 : std_logic_vector(4 downto 0);
   signal h24_read_r_sig                  : std_logic_vector(4 downto 0);
   signal h24_both_anchors_sig            : std_logic;
   -- build #128: cpu2vram vs vram_DIN comparison
   signal h28_cpu_r_sig                   : std_logic_vector(4 downto 0);
   signal h28_vram_r_sig                  : std_logic_vector(4 downto 0);
   signal h28_both_anchors_sig            : std_logic;
   -- build #129: Tecmo bank verification
   signal h29_bank_sig                    : std_logic_vector(2 downto 0);
   signal h29_bank_anchor_sig             : std_logic;
   signal h29_bank_ever_changed_sig       : std_logic;
   -- build #131: DMA delivery instrumentation
   signal h31_pixel1_r_sig                : std_logic_vector(4 downto 0);
   signal h31_pixel2_r_sig                : std_logic_vector(4 downto 0);
   signal h31_rich_ever_sig               : std_logic;
   -- build #132: DMA R-value sticky detectors
   signal h32_r31_ever_sig                : std_logic;
   signal h32_r_high_ever_sig             : std_logic;
   signal h32_pixel1_nonzero_ever_sig     : std_logic;
   -- build #133: fifo_data_1 vs cpu2vram_pixelColor at cube CLUT lane-3
   signal h33_fifo_data_1_r_sig           : std_logic_vector(4 downto 0);
   signal h33_cpu_color_r_sig             : std_logic_vector(4 downto 0);
   signal h33_anchor_sig                  : std_logic;
   signal h33_r31_ever_sig                : std_logic;
   -- build #134: fifoIn_Dout halfword R bits stickys
   signal h34_lower_r31_ever_sig          : std_logic;
   signal h34_upper_r31_ever_sig          : std_logic;
   signal h34_upper_msb_ever_sig          : std_logic;
   -- build #137: cpu2vram FSM latch-chain probes
   signal h37_input_r31_ever_sig          : std_logic;
   signal h37_writing_r31_ever_sig        : std_logic;
   signal h37_latch_r31_ever_sig          : std_logic;
   -- build #138: cube-CLUT-specific lane probes
   signal h38_lane2_input_r31_ever_sig    : std_logic;
   signal h38_lane3_latch_r31_ever_sig    : std_logic;
   signal h38_lane3_anchor_ever_sig       : std_logic;
   -- build #139: cube-shape Y observability probes
   signal h39_cubeshape_any_ever_sig      : std_logic;
   signal h39_cubeshape_y482_ever_sig     : std_logic;
   signal h39_cubeshape_y488_ever_sig     : std_logic;
   -- build #140: CLUT-RAM cube CLUT presence probes
   signal h40_cube_clut_loaded_ever_sig   : std_logic;
   signal h40_clut_read_7fff_ever_sig     : std_logic;
   signal h40_clut_read_023f_ever_sig     : std_logic;
   -- build #158: H4 cache-staleness sticky probes
   signal h58_x_stale_seen_sig            : std_logic;
   signal h58_y_stale_seen_sig            : std_logic;
   signal h58_pixel_seen_sig              : std_logic;
   -- build #159: H7 CLUT load value capture
   signal h59_loaded_entry0_lo_sig        : std_logic_vector(8 downto 0);
   signal h59_loaded_y_sig                : std_logic_vector(8 downto 0);
   signal h59_anchor_sig                  : std_logic;
   -- build #145: Y=482/480 pixelWrite probes
   signal h45_y482_anchor_sig             : std_logic;
   signal h45_y482_pixwrite_sig           : std_logic;
   signal h45_y480_pixwrite_sig           : std_logic;
   -- build #146-149: cpu2vram value-capture probes
   signal h46_y_minus_240_sig             : std_logic_vector(8 downto 0);
   signal h46_y_high_bit_sig              : std_logic;
   signal h46_anchor_sig                  : std_logic;
   signal h49_entry1_low_sig              : std_logic_vector(8 downto 0);
   -- build #63: sticky latches for CLUT-RAM ever receiving real data, by Y range (still updated, not displayed in #65)
   signal clut_real_data_hi_y_seen        : std_logic := '0';
   signal clut_real_data_lo_y_seen        : std_logic := '0';
   -- build #8 CLUT-load chain pinpoint taps
   signal dbg_textPalNew                  : std_logic;
   signal dbg_textPalReq_set              : std_logic;
   signal dbg_state_REQ_PAL               : std_logic;
   signal dbg_CLUTwrenA_any               : std_logic;
   signal dbg_drawMode_8                  : std_logic;
   signal dbg_noTexture_pin               : std_logic;
   -- derived events
   signal evt_ram_exec                    : std_logic;
   -- per-frame accumulators (one per bar — build #7 layout)
   signal frame_ram_exec                  : std_logic := '0';
   signal frame_clut_write_nonnavy        : std_logic := '0';
   signal frame_clut_read_nonnavy         : std_logic := '0';
   signal frame_stage4_texture            : std_logic := '0';
   signal frame_pipeline_color_varied     : std_logic := '0';
   signal frame_pixeldata_nonnavy         : std_logic := '0';
   signal frame_pipeline_write_any        : std_logic := '0';
   -- build #8 frame accumulators (CLUT-load chain pinpoint)
   signal frame_b8_textPalNew             : std_logic := '0';
   signal frame_b8_textPalReq_set         : std_logic := '0';
   signal frame_b8_state_REQ_PAL          : std_logic := '0';
   signal frame_b8_CLUTwrenA_any          : std_logic := '0';
   signal frame_b8_drawMode_8             : std_logic := '0';
   signal frame_b8_noTexture_pin          : std_logic := '0';
   -- displayed snapshots
   signal disp_ram_exec                   : std_logic := '0';
   signal disp_clut_write_nonnavy         : std_logic := '0';
   signal disp_clut_read_nonnavy          : std_logic := '0';
   signal disp_stage4_texture             : std_logic := '0';
   signal disp_pipeline_color_varied      : std_logic := '0';
   signal disp_pixeldata_nonnavy          : std_logic := '0';
   signal disp_pipeline_write_any         : std_logic := '0';
   -- build #8 displayed snapshots (latched-forever sticky to make missed events catchable)
   signal disp_b8_textPalNew              : std_logic := '0';
   signal disp_b8_textPalReq_set          : std_logic := '0';
   signal disp_b8_state_REQ_PAL           : std_logic := '0';
   signal disp_b8_CLUTwrenA_any           : std_logic := '0';
   signal disp_b8_drawMode_8              : std_logic := '0';
   signal disp_b8_noTexture_pin           : std_logic := '0';
   -- build #10 LATCHED-FOREVER VRAM data taps
   signal disp_vram_dout_nonnavy_b10      : std_logic := '0';
   signal disp_vram_din_nonnavy_b10       : std_logic := '0';
   -- build #11 CPU2VRAM taps
   signal dbg_cpu2vram_pixelWrite         : std_logic;
   signal dbg_cpu2vram_color_nonnavy      : std_logic;
   signal disp_cpu2vram_active_ever       : std_logic := '0';
   signal disp_cpu2vram_nonnavy_ever      : std_logic := '0';
   -- build #12 readback chain LATCHED-FOREVER
   signal disp_clut_write_nv_ever         : std_logic := '0';
   signal disp_clut_read_nv_ever          : std_logic := '0';
   signal disp_pipeline_color_var_ever    : std_logic := '0';
   signal disp_pixeldata_nv_ever          : std_logic := '0';
   signal disp_pipeline_pxwr_ever         : std_logic := '0';
   -- build #13 CLUT addressing
   signal dbg_textPalReqX_nz              : std_logic;
   signal dbg_textPalReqY_nz              : std_logic;
   signal dbg_cpu2vram_dstY_bit8          : std_logic;
   signal dbg_cpu2vram_dstY_nz            : std_logic;
   signal disp_clut_X_nz_ever             : std_logic := '0';
   signal disp_clut_Y_nz_ever             : std_logic := '0';
   signal disp_cpu2vram_dstY_bit8_ever    : std_logic := '0';
   signal disp_cpu2vram_dstY_nz_ever      : std_logic := '0';
   -- build #14 CPU2VRAM destination X
   signal dbg_cpu2vram_dstX_zero          : std_logic;
   signal dbg_cpu2vram_dstX_nz            : std_logic;
   signal disp_cpu2vram_dstX_zero_ever    : std_logic := '0';
   signal disp_cpu2vram_dstX_nz_ever      : std_logic := '0';
   -- build #15 ANY write at X=0
   signal dbg_vram_we_x_zero              : std_logic;
   signal dbg_vram_we_x_zero_nv           : std_logic;
   signal dbg_vram2vram_active            : std_logic;
   signal dbg_vramFill_active             : std_logic;
   signal dbg_procstate_sig               : std_logic_vector(31 downto 0);
   signal dbg_polyv0_sig                   : std_logic_vector(31 downto 0);
   signal dbg_polyv2_sig                   : std_logic_vector(31 downto 0);
   signal disp_vram_we_x_zero_ever        : std_logic := '0';
   signal disp_vram_we_x_zero_nv_ever     : std_logic := '0';
   signal disp_vram2vram_active_ever      : std_logic := '0';
   signal disp_vramFill_active_ever       : std_logic := '0';
   -- build #17 verify Y-wrap fix
   signal dbg_pixelAddr_Y_hi              : std_logic;
   signal dbg_cpu2vram_Y_hi               : std_logic;
   signal dbg_vram_addr_Y_hi_we           : std_logic;
   signal dbg_vram_addr_Y_hi_rd           : std_logic;
   signal disp_pixelAddr_Y_hi_ever        : std_logic := '0';
   signal disp_cpu2vram_Y_hi_ever         : std_logic := '0';
   signal disp_vram_addr_Y_hi_we_ever     : std_logic := '0';
   signal disp_vram_addr_Y_hi_rd_ever     : std_logic := '0';
   -- build #19: lpadv-tuned diagnostics
   signal dbg_textPalReqX_ge_256          : std_logic;
   signal dbg_textPalReqX_hi              : std_logic;
   signal dbg_cpu2vram_dstX_hi            : std_logic;
   signal dbg_cpu2vram_parsed_dstX_hi     : std_logic;  -- build #21
   signal dbg_texwrite_xhi                : std_logic_vector(31 downto 0);  -- texture-write (X>=512) probe
   signal dbg_pipeline_g_set              : std_logic;  -- build #23
   signal dbg_pipeline_b_set              : std_logic;  -- build #23
   signal dbg_vram_din_gb                 : std_logic;  -- build #23
   signal dbg_cpu2vram_color_gb           : std_logic;  -- build #23
   -- build #24: live + frame-windowed textured-rect drawMode tracking
   signal dbg_rect_tex_4bit               : std_logic;
   signal dbg_rect_tex_8bit               : std_logic;
   signal dbg_rect_tex_15bit              : std_logic;
   signal zn_dbg_desync                   : std_logic_vector(31 downto 0);
   signal dbg_rect_tex_pixel_gb           : std_logic;
   signal frame_rect_tex_4bit             : std_logic := '0';
   signal frame_rect_tex_8bit             : std_logic := '0';
   signal frame_rect_tex_15bit            : std_logic := '0';
   signal frame_rect_tex_pixel_gb         : std_logic := '0';
   signal disp_rect_tex_4bit              : std_logic := '0';
   signal disp_rect_tex_8bit              : std_logic := '0';
   signal disp_rect_tex_15bit             : std_logic := '0';
   signal disp_rect_tex_pixel_gb          : std_logic := '0';
   signal cpu2vram_parsed_dstX_hi_seen    : std_logic := '0';
   signal cpu2vram_color_nonnavy_seen     : std_logic := '0';  -- build #22
   signal pixelcolor_g_seen               : std_logic := '0';  -- build #23: any VRAM pixel write had G bits non-zero
   signal pixelcolor_b_seen               : std_logic := '0';  -- build #23: any VRAM pixel write had B bits non-zero
   signal texpal_gb_seen                  : std_logic := '0';  -- build #23: texdata_palette had G or B bit non-zero ever
   signal vram_din_gb_seen                : std_logic := '0';  -- build #23: vram_DIN had G or B bit non-zero (any lane)
   signal cmd_64_seen_ever                : std_logic := '0';  -- any GP0 write (PIO+DMA) with upper byte 0x64
   signal cmd_2C_seen_ever                : std_logic := '0';  -- any GP0 write (PIO+DMA) with upper byte 0x2C
   signal cmd_A0_seen_ever                : std_logic := '0';  -- build #20: any GP0 write with upper byte 0xA0 (cpu2vram dispatch)
   signal textPalX_ge_256_seen            : std_logic := '0';
   signal textPalX_hi_seen                : std_logic := '0';  -- X>=512 (CLUT X=768)
   signal cpu2vram_dstX_hi_seen           : std_logic := '0';
   -- build #26: cube-CLUT (X>=512) readback color forensics
   signal dbg_cubeclut_gb                 : std_logic;
   signal dbg_cubeclut_ronly              : std_logic;
   signal dbg_loclut_gb                   : std_logic;
   signal cubeclut_gb_seen                : std_logic := '0';  -- cube CLUT (X>=512) ever read back colorful
   signal cubeclut_ronly_seen             : std_logic := '0';  -- cube CLUT (X>=512) ever read back red-only
   signal loclut_gb_seen                  : std_logic := '0';  -- low-X CLUT ever read back colorful (positive control)
   signal dma_gpu_waiting_seen   : std_logic := '0';  -- latches when DMA ch2 was waiting for GPU (potential stall)
   signal irq_dma_seen           : std_logic := '0';  -- latches when DMA IRQ fires (DMA completed a transfer)
   signal dma_spu_write_seen     : std_logic := '0';  -- latches when DMA ch4 (SPU) wrote data
   signal irq_stat_read_seen     : std_logic := '0';  -- latches when CPU reads I_STAT/I_MASK (IRQ polling)
   signal irq_stat_write_seen    : std_logic := '0';  -- latches when CPU writes I_STAT/I_MASK (IRQ acknowledge)
   signal irq_cdrom_seen         : std_logic := '0';  -- latches when CD-ROM module generates an IRQ
   signal irq_timer_seen         : std_logic := '0';  -- latches when any timer (0/1/2) generates an IRQ
   signal vblank_irq_seen        : std_logic := '0';  -- latches when irq_VBLANK fires (VBLANK IRQ reached I_STAT[0])
   signal irqreq_seen            : std_logic := '0';  -- latches when irqRequest ever asserts to the CPU (IRQ reached CPU)
   signal imask0_write_seen      : std_logic := '0';  -- latches when CPU writes I_MASK (bus_addr=4) with bit0(VBLANK)=1
   signal istat_ack_seen         : std_logic := '0';  -- latches when CPU writes I_STAT (bus_addr=0) i.e. acknowledges an IRQ
   signal pc_reached_mid         : std_logic := '0';  -- PC ever in [0x1FC01000,0x1FC09000) (boot past early-init, before GPU-init)
   signal pc_reached_gpuinit     : std_logic := '0';  -- PC ever in [0x1FC09000,0x1FC0C000) (MAME's GPU-init region @0xBFC097F8)
   -- ZN security debug latches
   signal zn_sio_ever_seen       : std_logic := '0';  -- any SIO byte started on port 2
   signal zn_check1_seen         : std_logic := '0';  -- sec_select="110" (0x88=KN01) ever written
   signal zn_check2_seen         : std_logic := '0';  -- sec_select="101" (0x84=KN02) ever written
   signal zn_kn02_rx_nonzero    : std_logic := '0';  -- KN02 returned non-trivial byte (not 0x00/0xFF)

   -- build #168: sanity-check the detection mechanism by probing 3 known-good addresses.
   -- All 3 should light up bright if detection works; any dark indicates a wiring issue.
   --   RED   = ANY write to 0x000969E0 (state byte — what B167 tried; expected dark from prior data)
   --   GREEN = ANY write to 0x000C6D0 (wait_vsync flag — B166 verified fires ~240/4s)
   --   BLUE  = ANY write to 0x1FB00006 (Tecmo bank reg — B130 verified fires ~40/4s)
   signal b163_win_cnt           : unsigned(26 downto 0) := (others => '0');
   signal b163_win_tick          : std_logic := '0';
   signal b163_dma2_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: state=3 writes
   signal b163_dma4_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: state=5 writes
   signal b163_bank_cnt          : unsigned(8 downto 0) := (others => '0');  -- B167: any state write
   signal b163_dma2_disp         : std_logic_vector(8 downto 0) := (others => '0');
   signal b163_dma4_disp         : std_logic_vector(8 downto 0) := (others => '0');
   signal b163_bank_disp         : std_logic_vector(8 downto 0) := (others => '0');
   signal b163_DMA_GPU_writeEna_d : std_logic := '0';  -- B167: state=3 edge
   signal b163_DMA_SPU_writeEna_d : std_logic := '0';  -- B167: state=5 edge
   signal b163_bank_write_d       : std_logic := '0';  -- B167: any state write edge

   -- savestates
   signal loading_savestate      : std_logic;
   signal savestate_pause        : std_logic;
   signal ddr3_savestate         : std_logic;
   
   signal SS_reset               : std_logic;
   
   signal savestate_savestate    : std_logic; 
   signal savestate_loadstate    : std_logic; 
   signal savestate_address      : integer; 
   signal savestate_busy         : std_logic; 
   
   signal SS_DataWrite           : std_logic_vector(31 downto 0);
   signal SS_Adr                 : unsigned(18 downto 0);
   signal SS_wren                : std_logic_vector(16 downto 0);
   signal SS_rden                : std_logic_vector(16 downto 0);
   signal SS_DataRead_CPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPU        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GPUTiming  : std_logic_vector(31 downto 0);
   signal SS_DataRead_DMA        : std_logic_vector(31 downto 0);
   signal SS_DataRead_GTE        : std_logic_vector(31 downto 0);
   signal SS_DataRead_JOYPAD     : std_logic_vector(31 downto 0);
   signal SS_DataRead_MDEC       : std_logic_vector(31 downto 0);
   signal SS_DataRead_MEMORY     : std_logic_vector(31 downto 0);
   signal SS_DataRead_TIMER      : std_logic_vector(31 downto 0);
   signal SS_DataRead_SOUND      : std_logic_vector(31 downto 0);
   signal SS_DataRead_IRQ        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SIO        : std_logic_vector(31 downto 0);
   signal SS_DataRead_SCP        : std_logic_vector(31 downto 0);
   signal SS_DataRead_CD         : std_logic_vector(31 downto 0);
   
   signal ss_ram_BUSY            : std_logic;                    
   signal ss_ram_DOUT            : std_logic_vector(63 downto 0);
   signal ss_ram_DOUT_READY      : std_logic;
   signal ss_ram_BURSTCNT        : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_ADDR            : std_logic_vector(25 downto 0) := (others => '0');                       
   signal ss_ram_DIN             : std_logic_vector(63 downto 0) := (others => '0');
   signal ss_ram_BE              : std_logic_vector(7 downto 0) := (others => '0'); 
   signal ss_ram_WE              : std_logic := '0';
   signal ss_ram_RD              : std_logic := '0'; 
   
   signal SS_SPURAM_dataWrite    : std_logic_vector(15 downto 0);
   signal SS_SPURAM_Adr          : std_logic_vector(18 downto 0);
   signal SS_SPURAM_request      : std_logic;
   signal SS_SPURAM_rnw          : std_logic;
   signal SS_SPURAM_dataRead     : std_logic_vector(15 downto 0);
   signal SS_SPURAM_done         : std_logic;
   
   signal SS_Idle                : std_logic; 
   signal SS_Idle_gpu            : std_logic; 
   signal SS_Idle_mdec           : std_logic; 
   signal SS_Idle_cd             : std_logic; 
   signal SS_Idle_spu            : std_logic; 
   signal SS_idle_pad            : std_logic; 
   signal SS_idle_irq            : std_logic; 
   signal SS_idle_cpu            : std_logic; 
   signal SS_idle_gte            : std_logic; 
   signal SS_idle_dma            : std_logic; 

-- synthesis translate_off
   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
   signal export_8               : std_logic_vector(7 downto 0);
   signal export_16              : std_logic_vector(15 downto 0);
   signal export_32              : std_logic_vector(31 downto 0);
   signal export_irq             : unsigned(15 downto 0);
   signal export_gtm             : unsigned(11 downto 0);
   signal export_line            : unsigned(11 downto 0);
   signal export_gpus            : unsigned(31 downto 0);
   signal export_gobj            : unsigned(15 downto 0);
   signal export_t_current0      : unsigned(15 downto 0);
   signal export_t_current1      : unsigned(15 downto 0);
   signal export_t_current2      : unsigned(15 downto 0);
-- synthesis translate_on
   
   signal debug_firstGTE         : std_logic;

   -- build #39: Tecmo bank register exposed from memorymux for debug instrumentation in gpu
   signal zn_bank_8mb_dbg        : std_logic_vector(2 downto 0);
   signal dbg_palrd_green        : std_logic;  -- build #47
   signal dbg_palrd_red          : std_logic;  -- build #47
   signal dbg_palrd_any          : std_logic;  -- build #47
   signal dbg_palrd_redrow_red   : std_logic;  -- build #47 red-row control
   signal dbg_palrd_value        : std_logic_vector(31 downto 0);  -- build #50
   signal dbg_palrd_addr         : std_logic_vector(31 downto 0);  -- build #51
   signal dbg_palrd_words        : std_logic_vector(255 downto 0); -- build #52
   signal dbg_cubeclut_window_seen : std_logic;  -- build #135
   signal dbg_cubeclut_exact_seen  : std_logic;  -- build #135
   signal dbg_cubeclut_bank0_seen  : std_logic;  -- build #135

begin
   
   -- reset
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         reset_in <= reset or reset_exe;
      end if;
   end process;
   

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;

   process (clk3x)
   begin
      if rising_edge(clk3x) then
         clk1xToggle3x   <= clk1xToggle;
         clk1xToggle3X_1 <= clk1xToggle3X;
         clk3xIndex    <= '0';
         if (clk1xToggle3X_1 = clk1xToggle) then
            clk3xIndex <= '1';
         end if;
      end if;
   end process;

   -- Expose ZN SNAC intermediary signals through entity ports
   transmitValueSnac <= zn_txbyte;
   beginTransferSnac <= zn_beginTransfer;

   -- busses
   process (clk1x)
   begin
      if rising_edge(clk1x) then

         bus_exp1_dataRead <= (others => '0');
         if (bus_exp1_read = '1') then
            bus_exp1_dataRead <= (others => '1');
         end if;

         bus_exp3_dataRead <= (others => '0');
         if (bus_exp3_read = '1') then
            bus_exp3_dataRead <= (others => '1');
         end if;

      end if;
   end process;
 
   SS_idle    <= SS_Idle_gpu and SS_Idle_mdec and SS_Idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma;
   
   Pause_Idle <= SS_Idle_gpu and SS_Idle_mdec and Pause_idle_cd and SS_idle_spu and SS_idle_pad and SS_idle_irq and SS_idle_cpu and SS_idle_gte and SS_idle_dma; 
   
   -- ce generation
   canDMA <= memMuxIdle;
   
   isPaused <= pausing;
   -- 2026-07-10 boot-hang forensics: full pause/clock-enable state
   zn_dbg_pause <= x"0000" & '0' & dbg_cpu_stall & pauseCD & memcard2_pause & memcard1_pause &
                   savestate_pause & pause & allowunpause & cpuPaused & dmaOn & pausing & ce;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (reset = '1' or pausing = '1') then
         
            ce        <= '0';
            if (reset_intern = '1') then
               cpuPaused <= '0';
            end if;
            
            if (pause = '1') then
               pausing   <= '1';
            end if;
            
            if (pause = '0' and savestate_pause = '0' and memcard1_pause = '0' and memcard2_pause = '0' and pauseCD = '0' and allowunpause = '1') then
               pausing   <= '0';
               pausingSS <= '0';
            end if;
            
            if (savestate_pause = '1' and pausingSS = '0' and allowunpause = '1') then -- must go out of pause for savestate if not in a saveable state
               pausing <= '0';
            end if;
         
         else
      
            ce        <= '1';
         
            if (reset_intern = '1') then
               cpuPaused <= '0';
            else
         
               -- switch to pause when CD data fetch is slow
               if ((pauseCD = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and Pause_Idle = '1') then
                  pausing   <= '1';
                  ce        <= '0';
               -- switch to pause/savestate pausing
               elsif ((pause = '1' or savestate_pause = '1' or memcard1_pause = '1' or memcard2_pause = '1') and cpuPaused = '0' and dmaRequest = '0' and canDMA = '1' and stallNext = '0' and SS_idle = '1') then
                  pausing   <= '1';
                  pausingSS <= '1';
                  ce        <= '0';
               elsif ((cpuPaused = '1' and dmaOn = '1') or (dmaRequest = '1' and canDMA = '1')) then -- switch to dma
                  cpuPaused <= '1';
               elsif (dmaOn = '0') then -- switch to CPU
                  cpuPaused <= '0';
               end if;
               
            end if;
            
         end if;   
         
         if (reset_in = '1') then
            pausing   <= '0';
            pausingSS <= '0';
         end if;
         
      end if;
   end process;
   
   -- error codes
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset_intern = '1') then
            errorEna  <= '0';
            errorCode <= x"0";
         else
         
            if (errorEna = '0') then
               if (errorCD       = '1') then errorEna  <= '1'; errorCode <= x"1"; end if;
               if (errorCPU      = '1') then errorEna  <= '1'; errorCode <= x"2"; end if;
               if (errorGPU      = '1') then errorEna  <= '1'; errorCode <= x"3"; end if;
               if (errorMASK     = '1') then errorEna  <= '1'; errorCode <= x"7"; end if;
               if (errorCHOP     = '1') then errorEna  <= '1'; errorCode <= x"8"; end if;
               if (errorGPUFIFO  = '1') then errorEna  <= '1'; errorCode <= x"9"; end if;
               if (errorSPUTIME  = '1') then errorEna  <= '1'; errorCode <= x"A"; end if;
               if (errorDMACPU   = '1') then errorEna  <= '1'; errorCode <= x"B"; end if;
               if (errorDMAFIFO  = '1') then errorEna  <= '1'; errorCode <= x"C"; end if;
               if (errorCPU2     = '1') then errorEna  <= '1'; errorCode <= x"D"; end if;
               if (errorTimer    = '1') then errorEna  <= '1'; errorCode <= x"E"; end if;
               if (errorBuswidth = '1') then errorEna  <= '1'; errorCode <= x"F"; end if;
            end if;
            
            if (errorEna = '0' or errorCode = x"3") then
               if (errorLINE = '1') then errorEna  <= '1'; errorCode <= x"4"; end if;
               if (errorRECT = '1') then errorEna  <= '1'; errorCode <= x"5"; end if;
               if (errorPOLY = '1') then errorEna  <= '1'; errorCode <= x"6"; end if;
            end if;
            
         end if;
         
         debugmodeOn <= '0';
         if (REPRODUCIBLEGPUTIMING = '1') then debugmodeOn <= '1'; end if;
         if (noTexture             = '1') then debugmodeOn <= '1'; end if;
         if (SPUon                 = '0') then debugmodeOn <= '1'; end if;
         if (REVERBOFF             = '1') then debugmodeOn <= '1'; end if;
         if (REPRODUCIBLESPUDMA    = '1') then debugmodeOn <= '1'; end if;
         if (PATCHSERIAL           = '1') then debugmodeOn <= '1'; end if;
         
      end if;
   end process;
   
   -- DDR3 arbiter
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         memDDR3card1_ack    <= '0';
         memDDR3card2_ack    <= '0';         
         memHPScard1_ack     <= '0';
         memHPScard2_ack     <= '0';
         memSPU_ack          <= '0';
      
         if (reset_intern = '1') then
            arbiter_active    <= '0';
            vram_pause        <= '0';
            ddr3state         <= ARBITERIDLE;
            
            memDDR3card1_acknext  <= '0';
            memDDR3card2_acknext  <= '0';            
            memHPScard1_acknext   <= '0';
            memHPScard2_acknext   <= '0';
            memSPU_acknext        <= '0';
         else
         
            case (ddr3state) is
            
               when ARBITERIDLE =>
                  memDDR3card1_acknext  <= '0';
                  memDDR3card2_acknext  <= '0';                  
                  memHPScard1_acknext   <= '0';
                  memHPScard2_acknext   <= '0';
                  memSPU_acknext        <= '0';
                  if (memDDR3card1_request = '1' or memDDR3card2_request = '1' or memHPScard1_request = '1' or memHPScard2_request = '1' or memSPU_request = '1') then
                     vram_pause <= '1';
                     ddr3state  <= WAITGPUPAUSED;
                  end if;
                  
               when WAITGPUPAUSED =>
                  if (vram_paused = '1' and ddr3_savestate = '0') then
                     ddr3state      <= REQUEST; 
                     arbiter_active <= '1';
                     if (memDDR3card1_request = '1') then
                        memDDR3card1_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memDDR3card1_ADDR;    
                        arbiter_DIN          <= memDDR3card1_DIN;     
                        arbiter_BE           <= memDDR3card1_BE;      
                        arbiter_WE           <= memDDR3card1_WE;      
                        arbiter_RD           <= memDDR3card1_RD;
                     elsif (memDDR3card2_request = '1') then
                        memDDR3card2_acknext <= '1';
                        arbiter_BURSTCNT     <= memDDR3card2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memDDR3card2_ADDR;    
                        arbiter_DIN          <= memDDR3card2_DIN;     
                        arbiter_BE           <= memDDR3card2_BE;      
                        arbiter_WE           <= memDDR3card2_WE;      
                        arbiter_RD           <= memDDR3card2_RD;
                     elsif (memHPScard1_request = '1') then
                        memHPScard1_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard1_BURSTCNT;
                        arbiter_ADDR         <= x"01" & memHPScard1_ADDR;    
                        arbiter_DIN          <= memHPScard1_DIN;     
                        arbiter_BE           <= memHPScard1_BE;      
                        arbiter_WE           <= memHPScard1_WE;      
                        arbiter_RD           <= memHPScard1_RD;
                     elsif (memHPScard2_request = '1') then
                        memHPScard2_acknext <= '1';
                        arbiter_BURSTCNT     <= memHPScard2_BURSTCNT;
                        arbiter_ADDR         <= x"02" & memHPScard2_ADDR;    
                        arbiter_DIN          <= memHPScard2_DIN;     
                        arbiter_BE           <= memHPScard2_BE;      
                        arbiter_WE           <= memHPScard2_WE;      
                        arbiter_RD           <= memHPScard2_RD;
                     elsif (memSPU_request = '1') then
                        memSPU_acknext       <= '1';
                        arbiter_BURSTCNT     <= memSPU_BURSTCNT;
                        arbiter_ADDR         <= x"03" & memSPU_ADDR;    
                        arbiter_DIN          <= memSPU_DIN;     
                        arbiter_BE           <= memSPU_BE;      
                        arbiter_WE           <= memSPU_WE;      
                        arbiter_RD           <= memSPU_RD;
                     end if;
                  end if;
               
               when REQUEST =>
                  if (ddr3_BUSY = '0') then
                     ddr3state  <= WAITDONE; 
                     arbiter_WE <= '0';     
                     arbiter_RD <= '0';
                     if (memDDR3card1_acknext = '1') then memDDR3card1_ack <= '1'; end if;
                     if (memDDR3card2_acknext = '1') then memDDR3card2_ack <= '1'; end if;                    
                     if (memHPScard1_acknext  = '1') then memHPScard1_ack <= '1';  end if;
                     if (memHPScard2_acknext  = '1') then memHPScard2_ack <= '1';  end if;
                     if (memSPU_acknext       = '1') then memSPU_ack <= '1';       end if;
                  end if;
               
               when WAITDONE =>
                  if (
                      (memDDR3card1_request and memDDR3card1_acknext) = '0' and 
                      (memDDR3card2_request and memDDR3card2_acknext) = '0' and 
                      (memHPScard1_request  and memHPScard1_acknext ) = '0' and 
                      (memHPScard2_request  and memHPScard2_acknext ) = '0' and
                      (memSPU_request       and memSPU_acknext      ) = '0'
                     ) then
                     ddr3state      <= ARBITERIDLE;
                     arbiter_active <= '0';
                     vram_pause     <= '0';
                  end if;
               
            end case;
         end if;
      end if;
   end process;
   
   
   imemctrl : entity work.memctrl
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,

      bus_addr             => bus_memc_addr,     
      bus_dataWrite        => bus_memc_dataWrite,
      bus_read             => bus_memc_read,     
      bus_write            => bus_memc_write,    
      bus_dataRead         => bus_memc_dataRead,      
      
      bus2_addr            => bus_memc2_addr,     
      bus2_dataWrite       => bus_memc2_dataWrite,
      bus2_read            => bus_memc2_read,     
      bus2_write           => bus_memc2_write,    
      bus2_dataRead        => bus_memc2_dataRead,
      
      errorBuswidth        => errorBuswidth,
      
      spu_memctrl          => spu_memctrl, 
      cd_memctrl           => cd_memctrl, 
      bios_memctrl         => bios_memctrl, 
      ex1_memctrl          => ex1_memctrl, 
      ex2_memctrl          => ex2_memctrl, 
      ex3_memctrl          => ex3_memctrl, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      dma_spu_timing_on    => dma_spu_timing_on,   
      dma_spu_timing_value => dma_spu_timing_value,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(4 downto 0),      
      SS_wren              => SS_wren(7),     
      SS_rden              => SS_rden(7),     
      SS_DataRead          => SS_DataRead_MEMORY      
   );

   -- =====================================================================
   -- SYSTEM 11 LEAN: PSX joypad subsystem (ijoypad : entity work.joypad)
   -- REMOVED (build: lean/system11-only).
   --
   -- WHY IT IS SAFE:
   --   Namco System 11 arcade inputs do NOT travel over the PSX controller
   --   port (SIO0 @ 0x1F801040-0x1F80104F). They are direct input ports of
   --   psx_top (zn_p1_right, zn_p1_btn, ...) wired straight into zn1_io.
   --   Verified with MAME (60s run, positive controls proving the tap works:
   --   GPU writes = 2111, ROM-bank writes = 9): Tekken performs ZERO reads
   --   and ZERO writes to SIO0. The PSX joypad state machine, the multitap,
   --   the memory-card protocol (+ its two DDR3 masters) and the rumble
   --   outputs are therefore all dead weight on a design sitting at 97%
   --   logic utilisation.
   --
   -- WHAT WENT WITH IT:
   --   - joypad.vhd instance + its SIO0 bus slave  (bus_pad_dataRead -> 0)
   --   - memory-card DDR3 masters 1 & 2           (memDDR3card*_* -> idle)
   --   - GunCon / Justifier light-gun handling    (Gun* -> constants below,
   --     Justifier IRQ term dropped from irq_LIGHTPEN)
   --   - joypad savestate block (savestates module itself is KEPT, so its
   --     SS_DataRead_JOYPAD / SS_idle_pad inputs are tied off below)
   --
   -- TO RESTORE:
   --   git checkout release/20260712 -- rtl/psx_top.vhd
   -- =====================================================================

   -- Gun tie-offs. The GPU still consumes these for its crosshair overlay
   -- (see igpu port map below), so they must be driven. No gun is present:
   -- offscreen = '1', crosshair off, coordinates zero.
   Gun1X            <= (others => '0');
   Gun2X            <= (others => '0');
   Gun1Y            <= (others => '0');
   Gun2Y            <= (others => '0');
   Gun1Y_scanlines  <= (others => '0');
   Gun2Y_scanlines  <= (others => '0');
   Gun1AimOffscreen <= '0';
   Gun2AimOffscreen <= '0';
   Gun1offscreen    <= '1';
   Gun2offscreen    <= '1';
   Gun1CrosshairOn  <= '0';
   Gun2CrosshairOn  <= '0';
   JustifierIrqEnable <= (others => '0');

   -- SIO0 / joypad bus slave: register stub, no device attached, never IRQs.
   -- 2026-07-13: MUST NOT be a zero tie-off. SIO0 lives inside the CXD8530 on
   -- real System 11 hardware, and Namco's library runs stock PSX pad init at
   -- boot on several titles (dunkmnia/souledge/primglex/pocketrc): it polls
   -- JOY_STAT bit0 (TX Ready) forever if the registers read as zero -> black
   -- screen with a healthy C76. The stub answers like silicon with an empty
   -- controller port, so pad detection times out and boot proceeds.
   irq_PAD          <= '0';
   isio0stub : entity work.sio0_stub
   port map
   (
      clk1x         => clk1x,
      ce            => ce,
      reset         => reset_intern,
      bus_addr      => bus_pad_addr,
      bus_dataWrite => bus_pad_dataWrite,
      bus_read      => bus_pad_read,
      bus_write     => bus_pad_write,
      bus_writeMask => bus_pad_writeMask,
      bus_dataRead  => bus_pad_dataRead
   );

   -- Joypad savestate outputs (savestates module is kept and reads these).
   SS_DataRead_JOYPAD <= (others => '0');
   SS_idle_pad        <= '1';

   -- Rumble / pad-mode outputs of psx_top (were driven by joypad).
   joypad1_rumble   <= (others => '0');
   joypad2_rumble   <= (others => '0');
   joypad3_rumble   <= (others => '0');
   joypad4_rumble   <= (others => '0');
   padMode          <= (others => '0');

   -- SNAC outputs of psx_top / ZN SNAC intermediaries (were driven by joypad).
   -- selectedPort2Snac + zn_sel_p2 are already tied off by the zn_sio removal.
   selectedPort1Snac <= '0';
   clk9Snac          <= '0';
   zn_txbyte         <= (others => '0');
   zn_beginTransfer  <= '0';

   -- Memory-card DDR3 masters: permanently idle (the DDR3 arbiter above still
   -- reads these request/addr/data signals, so they MUST be driven).
   memDDR3card1_request  <= '0';
   memDDR3card1_BURSTCNT <= (others => '0');
   memDDR3card1_ADDR     <= (others => '0');
   memDDR3card1_DIN      <= (others => '0');
   memDDR3card1_BE       <= (others => '0');
   memDDR3card1_WE       <= '0';
   memDDR3card1_RD       <= '0';

   memDDR3card2_request  <= '0';
   memDDR3card2_BURSTCNT <= (others => '0');
   memDDR3card2_ADDR     <= (others => '0');
   memDDR3card2_DIN      <= (others => '0');
   memDDR3card2_BE       <= (others => '0');
   memDDR3card2_WE       <= '0';
   memDDR3card2_RD       <= '0';
   
   -- 2026-07-10: cheats engine STUBBED (System 11 arcade — no game-genie use;
   -- reclaim LABs for the MDEC). Bus master idle, never active.
   cheats_active        <= '0';
   Cheats_BusAddr       <= (others => '0');
   Cheats_BusRnW        <= '1';
   Cheats_BusByteEnable <= (others => '0');
   Cheats_BusWriteData  <= (others => '0');
   Cheats_Bus_ena       <= '0';

   -- build #142: ZN-1 arcade — SIO1 (PSX link cable @ 0x1F801050) removed.
   -- Arcade boards have no link cable. Stub bus + savestate outputs.
   bus_sio_dataRead  <= (others => '0');
   SS_DataRead_SIO   <= (others => '0');
   
   irq_SIO       <= '0'; -- todo
   -- SYSTEM 11 LEAN: Justifier light-gun IRQ terms removed with the joypad
   -- (they referenced joypad1/joypad2.PadPortJustif). No Justifier can be
   -- connected, so that path is permanently false; only the SNAC terms remain.
   irq_LIGHTPEN  <= '1' when
                    (irq10Snac = '1' and snacport1 = '1') or
                    (irq10Snac = '1' and snacport2 = '1')
                 else '0';

   iirq : entity work.irq
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,     
      irq_CDROM            => irq_CDROM,   
      irq_DMA              => irq_DMA,     
      irq_TIMER0           => irq_TIMER0,  
      irq_TIMER1           => irq_TIMER1,  
      irq_TIMER2           => irq_TIMER2,  
      irq_PAD              => irq_PAD,     
      irq_SIO              => irq_SIO,     
      irq_SPU              => irq_SPU,     
      irq_LIGHTPEN         => irq_LIGHTPEN,
      
      bus_addr             => bus_irq_addr,     
      bus_dataWrite        => bus_irq_dataWrite,
      bus_read             => bus_irq_read,     
      bus_write            => bus_irq_write,    
      bus_dataRead         => bus_irq_dataRead,
      
      irqRequest           => irqRequest,

-- synthesis translate_off
      export_irq           => export_irq,
-- synthesis translate_on
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(0 downto 0),      
      SS_wren              => SS_wren(10),     
      SS_rden              => SS_rden(10),     
      SS_DataRead          => SS_DataRead_IRQ,
      SS_idle              => SS_idle_irq
   );
   
   ignoreDMACDTiming <= '1' when (TURBO_MEM = '1' or IGNORECDDMATIMING = '1' or unsigned(FORCECDSPEED) >= 3) else '0';
   
   idma : entity work.dma
   port map
   (
      clk1x                => clk1x,
      clk3x                => clk3x,
      clk3xIndex           => clk3xIndex,
      ce                   => ce,   
      reset                => reset_intern,

      errorCHOP            => errorCHOP,
      errorDMACPU          => errorDMACPU, 
      errorDMAFIFO         => errorDMAFIFO, 
      
      TURBO                => TURBO_COMP,
      TURBO_CACHE          => TURBO_CACHE,
      ram8mb               => ram8mb,
      ignoreCDTiming       => ignoreDMACDTiming,
      
      canDMA               => canDMA,
      cpuPaused            => cpuPaused,
      dmaRequest           => dmaRequest,
      dmaStallCPU          => dmaStallCPU,
      dmaOn                => dmaOn,
      irqOut               => irq_DMA,
      
      ram_Adr              => ram_dma_Adr,  
      ram_cnt              => ram_cntDMA,  
      ram_ena              => ram_dma_ena,
      
      dma_wr               => dma_wr, 
      dma_reqprocessed     => dma_reqprocessed,      
      dma_data             => dma_data,
      
      ram_dmafifo_adr      => ram_dmafifo_adr, 
      ram_dmafifo_data     => ram_dmafifo_data,
      ram_dmafifo_empty    => ram_dmafifo_empty,
      ram_dmafifo_read     => ram_dmafifo_read, 

      dma_cache_Adr        => dma_cache_Adr,  
      dma_cache_data       => dma_cache_data, 
      dma_cache_write      => dma_cache_write,      
      
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,   
      
      mdec_dmaWriteRequest => mdec_dmaWriteRequest,
      mdec_dmaReadRequest  => mdec_dmaReadRequest, 
      DMA_MDEC_writeEna    => DMA_MDEC_writeEna,   
      DMA_MDEC_readEna     => DMA_MDEC_readEna,    
      DMA_MDEC_write       => DMA_MDEC_write,      
      DMA_MDEC_read        => DMA_MDEC_read,   

      cd_memctrl           => cd_memctrl,
      com0_delay           => com0_delay,
      DMA_CD_readEna       => DMA_CD_readEna,
      DMA_CD_read          => DMA_CD_read,   
      
      spu_timing_on        => dma_spu_timing_on,   
      spu_timing_value     => dma_spu_timing_value,
      spu_dmaRequest       => spu_dmaRequest, 
      DMA_SPU_writeEna     => DMA_SPU_writeEna,   
      DMA_SPU_readEna      => DMA_SPU_readEna,    
      DMA_SPU_write        => DMA_SPU_write,    
      DMA_SPU_read         => DMA_SPU_read,
      
      bus_addr             => bus_dma_addr,     
      bus_dataWrite        => bus_dma_dataWrite,
      bus_read             => bus_dma_read,     
      bus_write            => bus_dma_write,    
      bus_dataRead         => bus_dma_dataRead,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),      
      SS_wren              => SS_wren(3),     
      SS_rden              => SS_rden(3),     
      SS_DataRead          => SS_DataRead_DMA,
      SS_idle              => SS_idle_dma,
      dbg_madr             => dma2_madr,
      dbg_chcr2            => dma2_chcr2,
      dbg_nextaddr         => dma2_nextaddr,
      dbg_dmastate         => dma2_state,
      dbg_chan             => dma2_chan,
      dbg_corrupt_hdr      => dma2_corrupt_hdr,
      dbg_corrupt_src      => dma2_corrupt_src
   );
   -- DMA-COMPLETION probe: mode-9 = ch2 (GPU) D_CHCR (game polls this at 0x1F8010A8). bit24=busy: if stuck at 1
   -- during the hang => DMA ch2 never completes op#10 => game's timeout-wait never satisfied.
   -- FRAMEBUFFER-WRITE probe (mode-9): [31]c2v_any [30]we_X>=512 [29]we_FB(X<512,Y<480 committed to DDR3)
   -- [28]parsed_xhi [19:10]=we_minX [9:0]=we_maxX. we_FB=0 => framebuffer never written to DDR3 => display=noise.
   -- mode 9 REPURPOSED (DrawSync-wedge forensics): live ch2 D_CHCR — the exact register the game's
   -- DrawSync polls at 0x1F8010A8. bit24 stuck 1 = the wedge. bits 10:9 = syncmode of the stuck op.
   zn_dbg_madr     <= dma2_chcr2;
   -- DMA-COMPLETION probe (mode-A): ch2 DMA state. [31]isOn [30:28]dmaState(0=OFF 1=STARTING 2=READHEADER 3=SLOWDOWN
   -- 4=WORKING 5=STOPPING) [27:24]activeChannel [23:0]=ch2 D_MADR. If dmaState stuck !=OFF on channel 2 => stuck.
   -- FAULT-POINTER probe (mode-A): the faulting store/load ADDRESS latched at the FIRST CPU fault =
   -- $v0 at the SH @0x8002E78C = the odd/corrupt pointer that raised AdES. Compare vs MAME's slot value.
   zn_dbg_nextaddr <= std_logic_vector(cpu_dbg_fault_addr);
   zn_dbg_gpustat  <= gpustat_sig;
   -- EXCEPTION-CAUSE PROBE (2026-07-03): mode-C = full faulting-instruction EPC of the FIRST genuine CPU fault
   -- (ExcCode!=0,!=8). mode-E = [31]panic_reached(MIPS hit BIOS hang 0xBFC08DE0) [30:28]0 [27:24]=exc_code
   -- (4=AdEL 5=AdES 6=PCoob/IBE 7=DBE A=RI) [23:0]=fault_ra[23:0] (who called the faulting code).
   -- mode C REPURPOSED (wedge forensics): live GPU dispatcher state.
   -- [31]proc_idle [30]proc_requestFifo [29]pipeline_busy [28]fifoIn_Empty [27]fifoIn_Valid
   -- [26:24]vramState [23:17]unit requestFifos (22=cpu2vram) [16:9]last dispatched cmd
   -- [8:4]poly_dbg_state [3]ERRORFIFO sticky (fifoIn overflowed = words LOST)
   zn_dbg_procst   <= dbg_procstate_sig;
   -- (mode F repurposed below for upload forensics; dbg_polyv0_sig retired)
   -- mode-E = EXCEPTION detail (2026-07-04): [31:28]=exc_code (4=AdEL 5=AdES 6=PCoob 7=DBE A=RI)
   -- [27:24]=0 [23:0]=fault_ra[23:0] (return addr / caller at the first fault). Confirms the SH @0x8002E78C
   -- fault is AdES(5) and shows who called into the faulting routine.
   -- mode E REPURPOSED (upload forensics): {PIO GP0-write cnt[15:0], cpu2vram pixel-write cnt[15:0]} live
   zn_dbg_pv2      <= std_logic_vector(dbg_piogp0_cnt) & std_logic_vector(dbg_c2vpix_cnt);
   -- mode F REPURPOSED (upload forensics): {texwrite sticky bits[15:0]=dbg_texwrite_xhi[31:16], vram_WE-X>=512 cnt[15:0]}
   zn_dbg_pv0      <= dbg_polyv0_sig;   -- 2026-07-08: VRAM[ov_x,ov_y] JTAG readback (2 px)
   
   ram_refresh   <= reset_intern;
   
   ram_dataWrite <=                                                ram_cpu_dataWrite;
   ram_be        <=                                                ram_cpu_be;       
   ram_rnw       <= '1'                when (cpuPaused = '1') else ram_cpu_rnw;      
   ram_ena       <= ram_dma_ena        when (cpuPaused = '1') else ram_cpu_ena;      
   ram_dma       <= '1'                when (cpuPaused = '1') else '0';      
   ram_cache     <= '0'                when (cpuPaused = '1') else ram_cpu_cache;    
   
   -- System 11 has 4MB main RAM (vs PSX 8MB region): fold bit22=0 so the DMA path mirrors the low 4MB,
   -- matching the CPU path (memorymux). Without this, a DMA source address with bit22 set reads the BIOS
   -- image at SDRAM 0x400000 instead of the mirrored RAM -> BIOS code uploaded as textures (title garbage).
   ram_Adr       <=   "0000" & (ram_dma_Adr(22) and not zn_system11) & ram_dma_Adr(21 downto 0) when (cpuPaused = '1' and ram8mb = '1') else
                    "000000" & ram_dma_Adr(20 downto 0) when (cpuPaused = '1' and ram8mb = '0') else
                    ram_cpu_Adr(26 downto 0)                                    when (ram8mb = '1') else
                    ram_cpu_Adr(26 downto 23) & "00" & ram_cpu_Adr(20 downto 0);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (ram_ena = '1') then
            ram_next_cpu <= '0';
            if (cpuPaused = '0') then
               ram_next_cpu <= '1';
            end if;
         end if;

      end if;
   end process;

   ram_cpu_done <= ram_done and ram_next_cpu;
   
   itimer : entity work.timer
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      error                => errorTimer,
      
      dotclock             => dotclock,
      hblank               => hblank_tmr,
      vblank               => vblank_tmr,
      
      irqRequest0          => irq_TIMER0,
      irqRequest1          => irq_TIMER1,
      irqRequest2          => irq_TIMER2,
      
      bus_addr             => bus_tmr_addr,     
      bus_dataWrite        => bus_tmr_dataWrite,
      bus_read             => bus_tmr_read,     
      bus_write            => bus_tmr_write,       
      bus_dataRead         => bus_tmr_dataRead,
      
-- synthesis translate_off
      export_t_current0    => export_t_current0,
      export_t_current1    => export_t_current1,
      export_t_current2    => export_t_current2,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(3 downto 0),      
      SS_wren              => SS_wren(8),     
      SS_rden              => SS_rden(8),     
      SS_DataRead          => SS_DataRead_TIMER
   );
   
   -- build #25: stub out cd_top for ZN-1. ZN-1 arcades don't use CD-ROM (data via
   -- banked ROM at 0x1FB00006). The PSX_MiSTer-derived cd_top entity was a latent
   -- bug source (irq_CDROM, resetFromCD, DMA ch3 could spuriously fire) and consumed
   -- ~10-15% of ALMs. Replace with cd_top_zn1stub which drives all outputs inactive.
   icd_top : entity work.cd_top_zn1stub
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,
      reset                => reset_intern,
     
      INSTANTSEEK          => INSTANTSEEK,
      FORCECDSPEED         => FORCECDSPEED,
      LIMITREADSPEED       => LIMITREADSPEED,
      hasCD                => hasCD,
      fastCD               => fastCD,
      testSeek             => testSeek,
      pauseOnCDSlow        => pauseOnCDSlow,
      LIDopen              => LIDopen,
      region               => region,
      region_out           => region_out,	  
      
      pauseCD              => pauseCD,
      Pause_idle_cd        => Pause_idle_cd,
      cdSlow               => cdSlow,
      error                => errorCD,
      LBAdisplay           => LBAdisplay,
          
      irqOut               => irq_CDROM,
      
      spu_tick             => spu_tick,
      cd_left              => cd_left,
      cd_right             => cd_right,
      
      mdec_idle            => SS_Idle_mdec,
                            
      bus_addr             => bus_cd_addr,     
      bus_dataWrite        => bus_cd_dataWrite,
      bus_read             => bus_cd_read,     
      bus_write            => bus_cd_write,     
      bus_dataRead         => bus_cd_dataRead,
                            
      dma_read             => DMA_CD_readEna,
      dma_readdata         => DMA_CD_read,
      
      cd_hps_req           => cd_hps_req,  
      cd_hps_lba           => cd_hps_lba,
      cd_hps_lba_sim       => cd_hps_lba_sim,
      cd_hps_ack           => cd_hps_ack,
      cd_hps_write         => cd_hps_write,
      cd_hps_data          => cd_hps_data, 
      
      trackinfo_data       => trackinfo_data,
      trackinfo_addr       => trackinfo_addr, 
      trackinfo_write      => trackinfo_write,
      resetFromCD          => resetFromCD,
      
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(13 downto 0),      
      SS_wren              => SS_wren(13),     
      SS_rden              => SS_rden(13),     
      SS_DataRead          => SS_DataRead_CD,
      SS_Idle              => SS_Idle_cd
   );

   cdslowEna <= cdSlow and cdslowOn;

   igpu : entity work.gpu
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      clkvid               => clkvid,
      ce                   => ce,   
      reset                => reset_intern,
      
      allowunpause         => allowunpause,
      savestate_busy       => savestate_busy,
      system_paused        => pausing,
      
      ditherOff            => ditherOff,
      gpuType1             => s11_gputype1,  -- 2026-07-13: per-GAME, not per-platform. MAME namcos11.cpp:
                                     -- only Tekken 1 is a coh100 board (CXD8538Q = gputype1); every other
                                     -- System 11 game incl. Tekken 2 is coh110 (CXD8561Q = gputype2, the
                                     -- retail PSX GPU). Tekken 1 is exactly the keycus_id=0 game. Games
                                     -- that runtime-probe the GPU (Tekken 2, Dancing Eyes) adapt either
                                     -- way; the rest hardcode type-2 coordinate encodings and rendered
                                     -- black under forced type1 (display start y read as 60 vs 240 etc).
      interlaced480pHack   => interlaced480pHack,
      REPRODUCIBLEGPUTIMING=> REPRODUCIBLEGPUTIMING,
      videoout_on          => videoout_on,
      isPal                => isPal,
      pal60                => pal60,
      fpscountOn           => fpscountOn,
      noTexture            => noTexture,
      textureFilter        => textureFilter,
      textureFilterStrength=> textureFilterStrength,
      textureFilter2DOff   => textureFilter2DOff,
      dither24             => dither24,
      render24             => render24,
      drawSlow             => drawSlow,
      debugmodeOn          => debugmodeOn,
      syncVideoOut         => syncVideoOut,
      syncInterlace        => syncInterlace,
      rotate180            => rotate180,
      fixedVBlank          => fixedVBlank,
      vCrop                => vCrop,   
      hCrop                => hCrop,   
      
	  oldGPU               => oldGPU,
	  
      Gun1CrosshairOn      => Gun1CrosshairOn,
      Gun1X                => Gun1X,
      Gun1Y_scanlines      => Gun1Y_scanlines,
      Gun1offscreen        => Gun1offscreen,
      Gun1IRQ10            => Gun1IRQ10,

      Gun2CrosshairOn      => Gun2CrosshairOn,
      Gun2X                => Gun2X,
      Gun2Y_scanlines      => Gun2Y_scanlines,
      Gun2offscreen        => Gun2offscreen,
      Gun2IRQ10            => Gun2IRQ10,

      cdSlow               => cdslowEna,
      
      errorOn              => errorOn,  
      errorEna             => errorEna, 
      errorCode            => errorCode,
      
      LBAOn                => LBAOn,
      LBAdisplay           => LBAdisplay,
      
      errorLINE            => errorLINE,
      errorRECT            => errorRECT,
      errorPOLY            => errorPOLY,
      errorGPU             => errorGPU, 
      errorMASK            => errorMASK, 
      errorFIFO            => errorGPUFIFO,
      
      bus_addr             => bus_gpu_addr,     
      bus_dataWrite        => bus_gpu_dataWrite,
      bus_read             => bus_gpu_read,     
      bus_write            => bus_gpu_write,    
      bus_dataRead         => bus_gpu_dataRead, 
      bus_stall            => bus_gpu_stall, 
      
      dmaOn                => dmaOn,
      gpu_dmaRequest       => gpu_dmaRequest,  
      DMA_GPU_waiting      => DMA_GPU_waiting,
      DMA_GPU_writeEna     => DMA_GPU_writeEna,
      DMA_GPU_readEna      => DMA_GPU_readEna, 
      DMA_GPU_write        => DMA_GPU_write,   
      DMA_GPU_read         => DMA_GPU_read,  
      
      irq_VBLANK           => irq_VBLANK,
      irq_GPU              => irq_GPU,
      gpustat31_out        => gpustat31_sig,  -- build #169
      gpustat_out          => gpustat_sig,        -- S11 GPU-hang diag
      fifoIn_empty_out     => fifoIn_empty_sig,    -- S11 GPU-hang diag
      drawingAreaBottom_out => drawingAreaBottom_sig,  -- build #172
      drawingOffsetY_out    => drawingOffsetY_sig,     -- build #172

      vram_pause           => vram_pause,
      vram_paused          => vram_paused,
      vram_BUSY            => ddr3_BUSY,       
      vram_DOUT            => ddr3_DOUT,       
      vram_DOUT_READY      => ddr3_DOUT_READY,
      vram_BURSTCNT        => vram_BURSTCNT,  
      vram_ADDR            => vram_ADDR,      
      vram_DIN             => vram_DIN,       
      vram_BE              => vram_BE,        
      vram_WE              => vram_WE,        
      vram_RD              => vram_RD, 

      hblank_tmr           => hblank_tmr,
      vblank_tmr           => vblank_tmr,
      dotclock             => dotclock,
      
      video_hsync          => hsync, 
      video_vsync          => vsync, 
      video_hblank         => hblank_i,
      video_vblank         => vblank_i,
      video_DisplayWidth   => DisplayWidth,
      video_DisplayHeight  => DisplayHeight,
      video_DisplayOffsetX => DisplayOffsetX,
      video_DisplayOffsetY => DisplayOffsetY,
      video_ce             => video_ce,
      video_interlace      => video_interlace,
      video_r              => video_r_i,
      video_g              => video_g_i,
      video_b              => video_b_i,
      video_isPal          => video_isPal,
      video_fbmode         => video_fbmode, 
      video_fb24           => video_fb24, 
      video_hResMode       => video_hResMode, 
      video_frameindex     => video_frameindex,
      
-- synthesis translate_off
      export_gtm           => export_gtm,
      export_line          => export_line,
      export_gpus          => export_gpus,
      export_gobj          => export_gobj,
-- synthesis translate_on
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),
      SS_wren_GPU          => SS_wren(1),     
      SS_wren_Timing       => SS_wren(2),      
      SS_rden_GPU          => SS_rden(1),     
      SS_rden_Timing       => SS_rden(2),
      SS_DataRead_GPU      => SS_DataRead_GPU,
      SS_DataRead_Timing   => SS_DataRead_GPUTiming,
      SS_Idle              => SS_Idle_gpu,
      dbg_pipeline_pixelWrite => dbg_pipeline_pixelWrite,
      dbg_pipeline_write_in_top => dbg_pipeline_write_in_top,
      dbg_vram_WE              => dbg_vram_WE_tap,
      dbg_pipeline_color_varied => dbg_pipeline_color_varied,
      dbg_vram_din_non_navy    => dbg_vram_din_non_navy,
      dbg_vram_dout_nonnavy           => dbg_vram_dout_nonnavy,
      dbg_videoout_linebuf_nonnavy    => dbg_videoout_linebuf_nonnavy,
      dbg_videoout_pixeldata_nonnavy  => dbg_videoout_pixeldata_nonnavy,
      dbg_rast_display_nonnavy        => dbg_rast_display_nonnavy,
      dbg_rast_offdisp_nonnavy        => dbg_rast_offdisp_nonnavy,
      dbg_vramdin_display_nonnavy     => dbg_vramdin_display_nonnavy,
      dbg_clut_write_nonnavy          => dbg_clut_write_nonnavy,
      dbg_clut_read_nonnavy           => dbg_clut_read_nonnavy,
      dbg_stage4_texture              => dbg_stage4_texture,
      dbg_textPalNew                  => dbg_textPalNew,
      dbg_textPalReq_set              => dbg_textPalReq_set,
      dbg_state_REQ_PAL               => dbg_state_REQ_PAL,
      dbg_CLUTwrenA_any               => dbg_CLUTwrenA_any,
      dbg_drawMode_8                  => dbg_drawMode_8,
      dbg_noTexture_pin               => dbg_noTexture_pin,
      dbg_cpu2vram_pixelWrite         => dbg_cpu2vram_pixelWrite,
      dbg_cpu2vram_color_nonnavy      => dbg_cpu2vram_color_nonnavy,
      dbg_textPalReqX_nonzero         => dbg_textPalReqX_nz,
      dbg_textPalReqY_nonzero         => dbg_textPalReqY_nz,
      dbg_cpu2vram_dstY_bit8_LATCHED_src => dbg_cpu2vram_dstY_bit8,
      dbg_cpu2vram_dstY_nonzero       => dbg_cpu2vram_dstY_nz,
      dbg_cpu2vram_dstX_zero          => dbg_cpu2vram_dstX_zero,
      dbg_cpu2vram_dstX_nonzero       => dbg_cpu2vram_dstX_nz,
      dbg_vram_we_x_zero              => dbg_vram_we_x_zero,
      dbg_vram_we_x_zero_nonnavy      => dbg_vram_we_x_zero_nv,
      dbg_vram2vram_active            => dbg_vram2vram_active,
      dbg_vramFill_active             => dbg_vramFill_active,
      dbg_procstate                  => dbg_procstate_sig,
      dbg_polyv0                     => dbg_polyv0_sig,
      dbg_polyv2                     => dbg_polyv2_sig,
      dbg_vram_coord                 => dbg_vram_coord,
      dbg_pixelAddr_Y_hi              => dbg_pixelAddr_Y_hi,
      dbg_cpu2vram_Y_hi               => dbg_cpu2vram_Y_hi,
      dbg_vram_addr_Y_hi_we           => dbg_vram_addr_Y_hi_we,
      dbg_vram_addr_Y_hi_rd           => dbg_vram_addr_Y_hi_rd,
      -- build #19: lpadv-tuned
      dbg_textPalReqX_ge_256          => dbg_textPalReqX_ge_256,
      dbg_textPalReqX_hi              => dbg_textPalReqX_hi,
      dbg_cpu2vram_dstX_hi            => dbg_cpu2vram_dstX_hi,
      dbg_cpu2vram_parsed_dstX_hi     => dbg_cpu2vram_parsed_dstX_hi,
      dbg_texwrite_xhi                => dbg_texwrite_xhi,
      dbg_pipeline_g_set              => dbg_pipeline_g_set,
      dbg_pipeline_b_set              => dbg_pipeline_b_set,
      dbg_vram_din_gb                 => dbg_vram_din_gb,
      dbg_cpu2vram_color_gb           => dbg_cpu2vram_color_gb,
      dbg_rect_tex_4bit               => dbg_rect_tex_4bit,
      dbg_rect_tex_8bit               => dbg_rect_tex_8bit,
      dbg_rect_tex_15bit              => dbg_rect_tex_15bit,
      dbg_desync                      => zn_dbg_desync,
      dbg_rect_tex_pixel_gb           => dbg_rect_tex_pixel_gb,
      -- build #26
      dbg_cubeclut_gb                 => dbg_cubeclut_gb,
      dbg_cubeclut_ronly              => dbg_cubeclut_ronly,
      dbg_loclut_gb                   => dbg_loclut_gb,
      -- build #57
      dbg_stage4_texraw_nz            => dbg_stage4_texraw_nz,
      -- build #63
      dbg_textPalReqY_clut            => dbg_textPalReqY_clut,
      -- build #67
      dbg_last_succ_palX              => dbg_last_succ_palX,
      dbg_last_succ_palY              => dbg_last_succ_palY,
      -- build #68
      dbg_textPalReqY_lo              => dbg_textPalReqY_lo,
      dbg_textPalReqY_hi              => dbg_textPalReqY_hi,
      -- build #82
      dbg_b82_byte_redslot            => dbg_b82_byte_redslot,
      dbg_b82_byte_greenslot          => dbg_b82_byte_greenslot,
      dbg_b82_captured                => dbg_b82_captured,
      -- build #39: Tecmo bank register state for upstream-data forensic
      bank_8mb_in                     => zn_bank_8mb_dbg,
      -- build #114 H1+H2: cube rect path investigation
      dbg_h12_red_anchor              => h12_red_anchor_sig,
      dbg_h12_green_dm_ok             => h12_green_dm_ok_sig,
      dbg_h12_blue_dm_stale           => h12_blue_dm_stale_sig,
      dbg_h12_yellow_busy0            => h12_yellow_busy0_sig,
      dbg_h12_white_dm_chg            => h12_white_dm_chg_sig,
      dbg_h12_cyan_emit_busy0         => h12_cyan_emit_busy0_sig,
      dbg_h12_magenta_busy_long       => h12_magenta_busy_long_sig,
      -- build #115: H1 race-frequency counters
      dbg_h12_stale_count_hi          => h12_stale_count_hi_sig,
      dbg_h12_ok_count_hi             => h12_ok_count_hi_sig,
      dbg_h12_stale_gt_ok             => h12_stale_gt_ok_sig,
      -- build #117: G+B stripping locator
      dbg_h17_anchor                  => h17_anchor_sig,
      dbg_h17_g_set                   => h17_g_sig,
      dbg_h17_b_set                   => h17_b_sig,
      -- build #119: vram_DIN G+B locator
      dbg_h19_anchor                  => h19_anchor_sig,
      dbg_h19_g_in_din                => h19_g_sig,
      dbg_h19_b_in_din                => h19_b_sig,
      -- build #120: counter-based G+B prevalence
      dbg_h20_anchor_count_hi         => h20_anchor_count_hi_sig,
      dbg_h20_g_count_hi              => h20_g_count_hi_sig,
      dbg_h20_b_count_hi              => h20_b_count_hi_sig,
      -- build #122: vram_DOUT capture at hi-Y CLUT[3]
      dbg_h22_anchor                  => h22_anchor_sig,
      dbg_h22_clut3_r                 => h22_clut3_r_sig,
      dbg_h22_clut3_g                 => h22_clut3_g_sig,
      -- build #124: SDRAM round-trip self-test
      dbg_h24_write_r                 => h24_write_r_sig,
      dbg_h24_read_r                  => h24_read_r_sig,
      dbg_h24_both_anchors            => h24_both_anchors_sig,
      -- build #128: cpu2vram vs vram_DIN comparison
      dbg_h28_cpu_r                   => h28_cpu_r_sig,
      dbg_h28_vram_r                  => h28_vram_r_sig,
      dbg_h28_both_anchors            => h28_both_anchors_sig,
      -- build #129: Tecmo bank verification
      dbg_h29_bank                    => h29_bank_sig,
      dbg_h29_bank_anchor             => h29_bank_anchor_sig,
      dbg_h29_bank_ever_changed       => h29_bank_ever_changed_sig,
      -- build #131: DMA delivery instrumentation
      dbg_h31_pixel1_r                => h31_pixel1_r_sig,
      dbg_h31_pixel2_r                => h31_pixel2_r_sig,
      dbg_h31_rich_ever               => h31_rich_ever_sig,
      -- build #132: DMA R-value sticky detectors
      dbg_h32_r31_ever                => h32_r31_ever_sig,
      dbg_h32_r_high_ever             => h32_r_high_ever_sig,
      dbg_h32_pixel1_nonzero_ever     => h32_pixel1_nonzero_ever_sig,
      -- build #133: fifo_data_1 vs cpu2vram_pixelColor at cube CLUT lane-3
      dbg_h33_fifo_data_1_r           => h33_fifo_data_1_r_sig,
      dbg_h33_cpu_color_r             => h33_cpu_color_r_sig,
      dbg_h33_anchor                  => h33_anchor_sig,
      dbg_h33_r31_ever                => h33_r31_ever_sig,
      -- build #134: fifoIn_Dout halfword R bits stickys
      dbg_h34_lower_r31_ever          => h34_lower_r31_ever_sig,
      dbg_h34_upper_r31_ever          => h34_upper_r31_ever_sig,
      dbg_h34_upper_msb_ever          => h34_upper_msb_ever_sig,
      -- build #137: cpu2vram FSM latch-chain probes
      dbg_h37_input_r31_ever          => h37_input_r31_ever_sig,
      dbg_h37_writing_r31_ever        => h37_writing_r31_ever_sig,
      dbg_h37_latch_r31_ever          => h37_latch_r31_ever_sig,
      -- build #138: cube-CLUT-specific lane probes
      dbg_h38_lane2_input_r31_ever    => h38_lane2_input_r31_ever_sig,
      dbg_h38_lane3_latch_r31_ever    => h38_lane3_latch_r31_ever_sig,
      dbg_h38_lane3_anchor_ever       => h38_lane3_anchor_ever_sig,
      -- build #139: cube-shape Y observability probes
      dbg_h39_cubeshape_any_ever      => h39_cubeshape_any_ever_sig,
      dbg_h39_cubeshape_y482_ever     => h39_cubeshape_y482_ever_sig,
      dbg_h39_cubeshape_y488_ever     => h39_cubeshape_y488_ever_sig,
      -- build #140: CLUT-RAM cube CLUT presence probes
      dbg_h40_cube_clut_loaded_ever   => h40_cube_clut_loaded_ever_sig,
      dbg_h40_clut_read_7fff_ever     => h40_clut_read_7fff_ever_sig,
      dbg_h40_clut_read_023f_ever     => h40_clut_read_023f_ever_sig,
      -- build #158: H4 cache-staleness probes
      dbg_h58_x_stale_seen            => h58_x_stale_seen_sig,
      dbg_h58_y_stale_seen            => h58_y_stale_seen_sig,
      dbg_h58_pixel_seen              => h58_pixel_seen_sig,
      -- build #159: H7 CLUT load capture
      dbg_h59_loaded_entry0_lo        => h59_loaded_entry0_lo_sig,
      dbg_h59_loaded_y                => h59_loaded_y_sig,
      dbg_h59_anchor                  => h59_anchor_sig,
      -- build #145: Y=482/480 pixelWrite probes
      dbg_h45_y482_anchor   => h45_y482_anchor_sig,
      dbg_h45_y482_pixwrite => h45_y482_pixwrite_sig,
      dbg_h45_y480_pixwrite => h45_y480_pixwrite_sig,
      -- build #146-149: cpu2vram value-capture probes
      dbg_h46_y_minus_240   => h46_y_minus_240_sig,
      dbg_h46_y_high_bit    => h46_y_high_bit_sig,
      dbg_h46_anchor        => h46_anchor_sig,
      dbg_h49_entry1_low    => h49_entry1_low_sig
   );

   -- 2026-07-08 MDEC RESTORED (task #18): Tekken/System 11 intro FMVs are MDEC
   -- streams (MIPS feeds DMA0, reads decoded macroblocks via DMA1, blits to VRAM
   -- via cpu2vram). The build #142 ZN-1 stub made every decoded frame zero ->
   -- black movies. Area traded against the PSX SPU (System 11 sound = C352).
   imdec : entity work.mdec
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      clk2xIndex           => clk2xIndex,
      ce                   => ce,
      reset                => reset_intern,

      bus_addr             => bus_mdec_addr,
      bus_dataWrite        => bus_mdec_dataWrite,
      bus_read             => bus_mdec_read,
      bus_write            => bus_mdec_write,
      bus_dataRead         => bus_mdec_dataRead,

      dmaWriteRequest      => mdec_dmaWriteRequest,
      dmaReadRequest       => mdec_dmaReadRequest,
      dma_write            => DMA_MDEC_writeEna,
      dma_writedata        => DMA_MDEC_write,
      dma_read             => DMA_MDEC_readEna,
      dma_readdata         => DMA_MDEC_read,

      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(6 downto 0),
      SS_wren              => SS_wren(6),
      SS_rden              => SS_rden(6),
      SS_DataRead          => SS_DataRead_MDEC,
      SS_Idle              => SS_Idle_mdec
   );

   -- 2026-07-08 SPU STUBBED (area traded for the restored MDEC above): System 11
   -- sound is entirely C76+C352; the games/BIOS only write SPU volume registers.
   -- All outputs idle; SPU register reads return 0 (busy/transfer bits clear, so
   -- any BIOS wait-for-idle poll passes). Sound output zero (C352 carries audio).
   irq_SPU           <= '0';
   errorSPUTIME      <= '0';
   sound_out_left    <= (others => '0');
   sound_out_right   <= (others => '0');
   -- 2026-07-08 stub v2: the PSX sound library init polls SPUSTAT[5:0]==SPUCNT[5:0]
   -- after writing SPUCNT (and reads CNT back). All-zero reads never match -> the
   -- MIPS spins forever = the intermittent movie/boot hang on the first MDEC build.
   -- Echo CNT faithfully; transfer-busy bits stay 0 (idle) so waits pass.
   spustub : process(clk1x)
   begin
      if rising_edge(clk1x) then
         if reset_intern = '1' then
            spustub_cnt <= (others => '0');
         else
            if bus_spu_write = '1' and to_integer(bus_spu_addr) = 16#1AA# then
               spustub_cnt <= bus_spu_dataWrite;
            end if;
            bus_spu_dataRead <= (others => '0');
            if bus_spu_read = '1' then
               case to_integer(bus_spu_addr) is
                  when 16#1AA# => bus_spu_dataRead <= spustub_cnt;
                  when 16#1AE# => bus_spu_dataRead <= x"00" & spustub_cnt(5) & '0' & spustub_cnt(5 downto 0);
                  when others  => bus_spu_dataRead <= (others => '0');
               end case;
            end if;
         end if;
      end if;
   end process;
   spu_dmaRequest    <= '0';
   DMA_SPU_read      <= (others => '0');
   spuram_dataWrite  <= (others => '0');
   spuram_Adr        <= (others => '0');
   spuram_be         <= (others => '0');
   spuram_rnw        <= '1';
   spuram_ena        <= '0';
   memSPU_request    <= '0';
   memSPU_BURSTCNT   <= (others => '0');
   memSPU_ADDR       <= (others => '0');
   memSPU_DIN        <= (others => '0');
   memSPU_BE         <= (others => '0');
   memSPU_WE         <= '0';
   memSPU_RD         <= '0';
   SS_DataRead_SOUND <= (others => '0');
   SS_idle_spu       <= '1';
   -- SS_SPURAM_dataWrite/Adr/request/rnw are DRIVEN BY the savestates module
   -- (they were SPU inputs) — do NOT drive them here. The SPU's two outputs on
   -- this port must ack instantly or the boot-time savestate null-load waits
   -- forever on done -> savestate_pause stuck -> ce=0 -> total boot freeze
   -- (THE 'MDEC boot hang': it was this stub, not density/DQ margin).
   SS_SPURAM_dataRead  <= (others => '0');
   SS_SPURAM_done      <= SS_SPURAM_request;   -- immediate ack: transfers complete instantly
   
   iexp2 : entity work.exp2
   port map
   (
      clk1x                => clk1x,
      ce                   => ce,   
      reset                => reset_intern,
      
      bus_addr             => bus_exp2_addr,
      bus_dataWrite        => bus_exp2_dataWrite,
      bus_read             => bus_exp2_read,
      bus_write            => bus_exp2_write,
      bus_dataRead         => bus_exp2_dataRead
   );

   -- ZN-1 Arcade I/O register block
   izn1_io : entity work.zn1_io
   port map
   (
      clk          => clk1x,
      reset        => reset_intern,
      addr         => bus_znio_addr,
      data_write   => bus_znio_dataWrite,
      write_mask   => bus_znio_writeMask,
      read_en      => bus_znio_read,
      write_en     => bus_znio_write,
      data_read    => bus_znio_dataRead,
      p1_right     => zn_p1_right,
      p1_left      => zn_p1_left,
      p1_down      => zn_p1_down,
      p1_up        => zn_p1_up,
      p1_btn       => zn_p1_btn,
      p1_start     => zn_p1_start,
      p1_coin      => zn_p1_coin,
      p2_right     => zn_p2_right,
      p2_left      => zn_p2_left,
      p2_down      => zn_p2_down,
      p2_up        => zn_p2_up,
      p2_btn       => zn_p2_btn,
      p2_start     => zn_p2_start,
      p2_coin      => zn_p2_coin,
      service      => zn_service,  -- B126 hack reverted: service=1 didn't help, real bug is elsewhere
      test_mode    => zn_test_mode,
      zn_platform  => zn_platform,
      sec_select   => zn_sec_select,
      coin_out     => zn_coin_out,
      zn_system11  => zn_system11,
      keycus_id    => keycus_id,
      s11_bank     => zn_s11_bank,
      s11_up       => zn_s11_up,
      mb_addr      => zn_mb_addr,
      mb_wdata     => zn_mb_wdata,
      mb_we        => zn_mb_we,
      mb_rdata     => zn_mb_rdata,
      dbg_poll_val   => zn_poll_val,
      dbg_poll_bit80 => zn_poll_bit80,
      dbg_eeprom     => zn_dbg_eeprom,
      dbg_bankwr     => zn_dbg_bankwr,
      ee_dl_wr       => ee_dl_wr,
      ee_dl_addr     => ee_dl_addr,
      ee_dl_data     => ee_dl_data
   );

   -- 2026-07-05 MAILBOX-READ forensics: latch the last MIPS mailbox READ (addr halfwords + the data
   -- the CPU actually received). The C76 writes inputs/status (0xBD00=0x0080 etc.) into shram; if the
   -- game's reads return 0/stale, the attract gate never opens. [31:16]=byte-addr offset (addr-0x4000)
   -- low16, [15:0]=mb_rdata delivered.
   process(clk1x)
   begin
      if rising_edge(clk1x) then
         mbrd_sel_d  <= '0';
         if (bus_znio_read = '1' and unsigned(bus_znio_addr(15 downto 0)) >= 16#4000# and unsigned(bus_znio_addr(15 downto 0)) <= 16#BFFF#) then
            mbrd_sel_d  <= '1';
            mbrd_addr_d <= std_logic_vector(bus_znio_addr(15 downto 0));
         end if;
         if (mbrd_sel_d = '1') then
            dbg_mbrd <= mbrd_addr_d & mb_mips_rdata;
         end if;
      end if;
   end process;

   -- Bridge the System 11 mailbox (zn1_io) out to the top-level c76_sound and back.
   mb_mips_addr  <= zn_mb_addr;
   mb_mips_wdata <= zn_mb_wdata;
   mb_mips_we    <= zn_mb_we;
   zn_mb_rdata   <= mb_mips_rdata;

   -- SYSTEM 11 LEAN: zn_sio (CAT702 A/B + ZNMCU security over the SIO0 SNAC byte
   -- interface) REMOVED. CAT702 is a ZN-1 feature: MAME's namcos11 driver contains
   -- zero CAT702 references, and every System 11 title uses a KEYCUS C-chip
   -- (C406/C409/...) via zn1_io instead. Verified with MAME (60s, positive controls
   -- on GPU + ROM-bank writes): Tekken performs 0 reads and 0 writes to SIO0.
   -- Frees ~508 ALMs. Restore for ZN-1 support: git checkout release/20260712 -- rtl/psx_top.vhd
   zn_rxbyte        <= (others => '0');
   zn_ack           <= '0';
   zn_action_next   <= '0';
   zn_receive_valid <= '0';
   zn_sel_p2        <= '0';
   zn_sec_select    <= (others => '1');   -- CAT702 selects are active-low: all deselected
   selectedPort2Snac <= '0';
   -- DIAGNOSTIC build #15: does ANY mechanism (cpu2vram/vram2vram/vramFill/rasterizer) write at VRAM X=0?
   -- Build #14: CPU2VRAM never writes X=0 (GREEN dark). But CLUT reads X=0. Maybe vram2vram or vramFill writes there?
   -- [0]=disp_ram_exec                      RED:     PER-FRAME — CPU executing (sanity)
   -- [1]=disp_vram_we_x_zero_ever           GREEN:   LATCHED  — ANY vram_WE at X=0 ever (any source)
   -- [2]=disp_vram_we_x_zero_nv_ever        BLUE:    LATCHED  — ANY non-navy write at X=0 ever
   -- [3]=disp_vram2vram_active_ever         YELLOW:  LATCHED  — vram2vram_pixelWrite ever fired
   -- [4]=disp_vramFill_active_ever          WHITE:   LATCHED  — vramFill_pixelWrite ever fired
   -- [5]=disp_clut_write_nv_ever            CYAN:    LATCHED  — CLUT non-navy ever (control)
   -- [6]=disp_vram_dout_nonnavy_b10         MAGENTA: LATCHED  — DDR3 non-navy read ever (control)
   --
   -- Decision tree:
   --   GREEN dark → ZERO writes ever to X=0 column → game uses palettes at X != 0 (CLUT-X parser bug?) OR truly no X=0 use
   --   GREEN bright, BLUE dark → writes at X=0 always navy → fill or fastclear hitting X=0 column
   --   BLUE bright → real data IS in VRAM at X=0 but CLUT still reads navy → DDR3 read/write inconsistency
   --   WHITE bright → vramFill is active → could be clearing X=0 column with navy → check fill destinations
   evt_ram_exec  <= '1' when (mem_request = '1' and mem_isData = '0' and
                              mem_addressInstr(28 downto 0) >= to_unsigned(16#40000#, 29) and
                              mem_addressInstr(28 downto 0) <  to_unsigned(16#800000#, 29)) else '0';
   -- BUILD #17: verify Y-wrap fix. GREEN/BLUE/YELLOW expected DARK after fix (no Y>=512 anywhere).
   -- build #24: frame-windowed textured-rect drawMode mode tracking. Reset each VBLANK so the
   -- bars reflect the LAST FRAME's activity, not history. Screenshots during red-rectangle
   -- phase will show what mode the cube rendering frame was using.
   -- build #26: cube-CLUT (X>=512) forensics. All sticky. X=768 is the ONLY CLUT at X>=512 in
   -- lpadv's entire stream (MAME log: CLUT X in {0,256,768}), so a sticky latch firing == the cubes.
   -- Decision table after a full attract run (let it reach + pass the cube screen ~20s in):
   --   BLUE dark              -> FPGA never requested the X=768 CLUT read  -> UPSTREAM (rect CLUT pointer wrong)
   --   RED  dark              -> FPGA never wrote VRAM at X>=512            -> UPSTREAM (0xA0 dst wrong)
   --   BLUE+WHITE (GREEN on)  -> cube CLUT read RED-ONLY, low-X reads fine  -> X>=512 VRAM storage bug (RTL-fixable)
   --   BLUE+YELLOW            -> cube CLUT read COLORFUL but still renders red -> bug downstream of CLUT
   -- build #44 (DECISIVE cube-palette color probe at cpu2vram dest X<256,Y=488; banking+MRA proven OK):
   -- build #114 H1+H2 bar wiring:
   --   [0] RED     = h12_red_anchor       — cube rect emit ever (sanity; if DARK, instrument never fired)
   --   [1] GREEN   = h12_green_dm_ok      — drawMode[3:0]=0xA/0xB at cube rect emit (expected E1 texpage)
   --   [2] BLUE    = h12_blue_dm_stale    — drawMode[3:0]!=0xA/0xB at cube rect emit → H1 CONFIRMED
   --   [3] YELLOW  = h12_yellow_busy0     — pipeline_busy='0' ever during cube period (H2 refuted if lit)
   --   [4] WHITE   = h12_white_dm_chg     — drawMode register changed during cube (E1 processing OK if lit)
   --   [5] CYAN    = h12_cyan_emit_busy0  — cube rect emit happened with pipeline_busy='0' same cycle
   --   [6] MAGENTA = h12_magenta_busy_long — pipeline_busy held high ≥4096 cycles during cube → H2 strong
   -- CLEANUP 2026-06-13: stale build#1-155 debug bars retired; tying these three outputs
   -- to 0 makes their entire latch chains write-only so synthesis prunes them, freeing
   -- ALMs/congestion to restore the SDRAM capture margin. Only zn_debug_val is kept.
   zn_debug_out <= (others => '0');
   -- Build 10: value display = dbg_lw_input = the SDRAM data memorymux ingested for the lw of
   -- 0x1FC20000 (the boot jump-target load). 0x1FC20038=correct, 0x1FC20298=already-wrong input.
   -- EXC DIAG (2026-06-12): MIPS sits at the exception vector 0x80000080. Show the FIRST
   -- (=fatal, MAME takes zero) exception: value top nibble = ExcCode (4/5=AdEL/AdES,
   -- 6/7=bus err, A=RI, B=CpU, C=Ov, 0=IRQ), remaining 7 digits = faulting EPC[27:0].
   -- Bars encode EPC region: RED=KSEG0 RAM(0x8), GREEN=KSEG1 BIOS(0xB), BLUE=KUSEG(0x1).
   -- DECOUPLE DEBUG: value = dbg_last_any_pc (current MIPS fetch = where it's stuck).
   -- Bars = first-exception EPC region (RED=RAM 0x8, GREEN=BIOS 0xB, BLUE=KUSEG 0x1);
   -- all bars dim => NO exception fired => stuck in a wait loop (e.g. VBlank wait), not a crash.
   -- (A) FIRST-EXCEPTION readout at PSX-identical config: value top nibble = ExcCode
   -- (4/5=AdEL/AdES, 6/7=bus, A=RI, B=CpU, C=Ov, 0=IRQ), low 7 digits = faulting EPC[27:0].
   -- Bars = EPC region (RED=RAM 0x8, GREEN=BIOS 0xB, BLUE=KUSEG 0x1). All dim+val 0 => no exception.
   -- FIX-VALIDATION readout (2026-06-13): top 5 bits = progress latches (8px each,
   -- MSB/leftmost first), low 27 bits = exception EPC for context.
   --   px0-7   bit31 panic_reached         WHITE => boot hit 0xBFC08DE0 panic (FIX FAILED)
   --   px8-15  bit30 s11_reached_game      WHITE => CPU fetched early game code [0x10000,0x40000)
   --   px16-23 bit29 h50_game_ram_exec_seen WHITE => CPU ran [0x80050000,0x80060000) (game live)
   --   px24-31 bit28 ram_exec_seen         WHITE => CPU fetched from RAM >=0x40000
   --   px32-39 bit27 raster_pixel_seen      WHITE => GPU rasterizer wrote a VRAM pixel
   -- panel GRAY at px0-7 (panic clear) + any of bits30..27 lit = the lw delivery fix worked.
   -- RENDER-PIPELINE LOCATOR (2026-06-13): game runs, no raster. Trace GPU command path.
   --   px0-7   bit31 gpu_accessed_seen   WHITE => CPU touched GPU regs
   --   px8-15  bit30 dma_gpu_write_seen  WHITE => DMA2 wrote a word to GPU
   --   px16-23 bit29 dma2_prim_seen      WHITE => DMA2 sent a drawing primitive (0x20-0x7F)
   --   px24-31 bit28 pio_prim_seen       WHITE => CPU PIO sent a drawing primitive
   --   px32-39 bit27 dma2_e5_write_seen  WHITE => DMA2 sent E5 draw-offset cmd
   --   px40-47 bit26 raster_pixel_seen   WHITE => GPU rasterizer wrote a VRAM pixel
   --   px48-55 bit25 vblank_irq_seen     WHITE => VBLANK reached I_STAT
   --   px56-63 bit24 irqreq_seen         WHITE => irqRequest reached CPU
   --   px64-255 bits23:0 = dbg_last_any_pc[23:0] live PC. prim_seen=1 & raster=0 => clip/drawarea bug.
   -- IRQ-SETUP + EXCEPTION LOCATOR (2026-06-13): game runs but no GPU access, irqreq=0.
   --   px0-7   bit31 imask0_write_seen WHITE => game enabled VBLANK mask (I_MASK[0]<=1)
   --   px8-15  bit30 istat_ack_seen    WHITE => game wrote I_STAT (services IRQs)
   --   px16-23 bit29 vblank_irq_seen   WHITE => VBLANK reached I_STAT
   --   px24-31 bit28 irqreq_seen       WHITE => irqRequest reached CPU
   --   px32-55 bits27:24 = exc_code (4/5=AdE 6=PCoob 8=Sys 9=Bp A=RI 0=IRQ), 0=>no fault
   --   px56-255 bits23:0 = exc_epc[23:0] (faulting PC low24)
   -- imask0=1 & irqreq=0 => IRQ-deliver logic bug. imask0=0 => game never enabled VBLANK (stuck before).
   -- BOOT-DIVERGENCE LOCATOR (2026-06-13): how far does boot get vs MAME (GPU-init @0xBFC097F8 instr~1357)?
   --   px0-7   bit31 pc_reached_mid     WHITE => boot ran [0x1FC01000,0x1FC09000) (past the 0x1CC RI)
   --   px8-15  bit30 pc_reached_gpuinit WHITE => boot reached GPU-init region 0xBFC09xxx
   --   px16-23 bit29 gpu_accessed_seen  WHITE => CPU actually wrote/read GPU regs
   --   px24-31 bit28 imask0_write_seen  WHITE => game enabled VBLANK mask
   --   px32-55 bits27:24 = exc_code (A=RI), px56-255 bits23:0 = exc_epc[23:0]
   -- mid=0 => derailed at/before 0x1CC RI (SDRAM corruption). gpuinit=1 & gpu_acc=0 => latch lies.
   -- LIVE-PC LOCATOR (2026-06-13, post-decouple): SDRAM fixed (no fault); find the clean stall.
   --   px0-7 bit31 pc_reached_mid, px8-15 bit30 pc_reached_gpuinit, px16-23 bit29 gpu_accessed_seen,
   --   px24-31 bit28 imask0_write_seen, px32-255 bits27:0 = dbg_last_any_pc[27:0] (LIVE last fetch PC).
   -- DERAIL-BRACKET DIAGNOSTIC v2 (2026-06-14): bracket the Tekken ROM->RAM kernel copy+jump.
   -- b31 mid, b30 gpuinit, b29 copyloop(0xBFC00484), b28 copydone(0xBFC0049C),
   -- b27 jrkernel(0xBFC004B0), b26 kernelentry(0xA0000500), b25 b0handler(0xA00005E0),
   -- b24 heap_init_seen, bits23:0 = dbg_last_any_pc[23:0]. Last 1 before a 0 = derail point.
   -- v4 (beat-fix done; chase color-bar stall): b31 mid, b30 gpuinit, b29 game-KUSEG(0x0005),
   -- b28 kernel-copy(0xBFC00484), b27 game-0x8005, b26 game-0x8004, b25 jfix-ok(jump target captured),
   -- b24 spare, bits23:0 = dbg_last_any_pc[23:0] = LIVE last instruction-fetch PC (where it is now).
   -- v5: bits23:0 = derail_src[23:0] = PC that branched to the panic 0xBFC08DE0 (the failing check).
   -- v6 (2026-06-14): EXCEPTION CAPTURE. Post beat-fix the boot reaches POST stage ~13
   -- then a CPU exception inside the setjmp try-block (0xBFC08FBC) vectors to the BIOS
   -- abort handler (0xBFC09C6C -> longjmp 0xBFC021FC) -> setjmp returns !=0 -> panic
   -- 0xBFC08DE0. cpu.vhd now latches the FIRST genuine fault (ExcCode not in {0 int,8 sys}).
   -- Overlay: top nibble [31:28] = ExcCode (4/5=AdEL/AdES addr err, 6=PC OOB/wild jump,
   -- 7=DBE bus err, A=reserved instr), bits[27:0] = faulting EPC[27:0]
   -- (0xFCxxxxx=BIOS 0xBFCxxxxx, 0x005xxxx=game 0x8005xxxx, 0xFxxxxxx=I/O 0x1Fxxxxxx).
   -- v7 (2026-06-14): the AdES at EPC=0xBFC20298 (sh v0,-1(a1) in decompressor helper)
   -- is IMPOSSIBLE for a clean odd a1 (a1-1 would be even/aligned). Show the latched a1
   -- (reg[5] at the fault) to disambiguate: 0x8001xxxx-odd => core ALU/check bug;
   -- 0x8001xxxx-even => wrong branch taken; wild garbage => corrupt decompressor state
   -- (bad ROM source read at 0x1FC28000). Full 32-bit a1.
   -- v8 (2026-06-14): INSTRUCTION-FETCH PROBE. The off-by-one AdES is data-independent
   -- (first decompressor store has a1=s4=0x80010000 regardless of source), so the wrong
   -- odd-path branch points at corrupt FETCH of the helper code. Show the actual word the
   -- CPU received for the andi @0xBFC20280. Expected 0x30A20001; anything else = icache/
   -- fetch corruption on that ROM line (same class as the beat bug, rarer access pattern).
   -- v9 (2026-06-14): clk_3x SDRAM REVERT test. Show first-fault ExcCode+EPC again:
   -- if the decouple was the root, the decompressor AdES (code 5 @ 0xFC20298) is GONE
   -- (value 0 = no fault). Top nibble [31:28]=ExcCode, [27:0]=EPC[27:0].
   -- v10 (2026-06-16): AdES (0x5FC20298) confirmed unchanged on clean HW. Now show the a1
   -- operand captured at the decompressor andi (cpu_dbg_instr_word):
   --   0x80010001 (ODD)  => a1 stale-by-one at the andi => operand-forward / fetch bug
   --   0x80010000 (EVEN) => a1 correct => andi/beqz mis-execution (control), not the operand
   --   0x00000000        => never captured (andi never decoded under the armed condition)
   -- v12 (2026-06-16): READROM uncached-instr waitcnt=25 fix test. Show first-fault ExcCode+EPC:
   --   0x00000000 => AdES GONE (fix worked; E2 overlay should also vanish, FPS go non-zero)
   --   0x5FC20298 => AdES still firing (ExcCode 5 @ 0xBFC20298) => timing-match did not fix it
   -- first-fault ExcCode (top nibble) + EPC[27:0]. 0 => boot proceeded past all faults.
   -- RENDER/IRQ DIAGNOSTIC (2026-06-17, SDRAM fixed -> game runs but FPS=0/noise):
   -- bit31=imask0_write (game enabled VBLANK mask), 30=irqreq (IRQ reached CPU),
   -- 29=vblank_irq (VBLANK reached I_STAT), 28=istat_ack (game services IRQ),
   -- 27=gpu_accessed (CPU touches GPU), 26=raster_pixel (GPU drew a pixel),
   -- 25=dma2_prim (DMA sent a draw primitive), 24=pio_prim (PIO sent a primitive),
   -- SDRAM-interface write of 0xA0001078: bit31=seen, 30:27=ram_be, 26:0=ram_Adr. If seen but
   -- be /= 1111 => the write is BYTE-MASKED at the SDRAM (the drop). be=1111 => write reaches
   -- SDRAM intact (=> the SDRAM controller dropped it, or the read-back is wrong). not-seen(bit31=0)
   -- => the write never reached the SDRAM interface (memorymux/writeFifo dropped it).
   -- READBACK of 0x65C: [31]=seen, [30:0]=value. Color block: GREEN(val26:0=0x0001078)=cell holds
   -- 0xA0001078 (correct, write landed); RED(=0x5400070)=0xAD400070 stale (write-drop); BLUE=other.
   -- EXCEPTION readout: top nibble [31:28] = ExcCode (4=AdEL load-addr-err, 5=AdES store-addr-err,
   -- 6=IBE bus-err-instr, 8=Sys, 9=Bp, A=RI reserved-instr, B=CpU, C=Ov); bits[27:0] = EPC[27:0]
   -- (faulting PC; region inferable: ~0xFCxxxxx => ROM 0x1FCxxxxx, low => RAM 0x80xxxxxx). This is
   -- WHY the MIPS derailed to the 0x80000080 exception vector (live PC was 0xA0). Disassemble EPC.
   -- BOOT-PROGRESS BITMAP (read top->bottom on the bit-bars, MSB=bit31 on top):
   --  31 rch_kernel(0xBFC00484 kernel copy)  30 helper_entry(0xBFC20280 decompressor)
   --  29 panic(0xBFC08DE0 — want 0)          28 rch_decomp(KUSEG game 0x0005xxxx)
   --  27 game 0x8004xxxx                      26 game 0x8005xxxx
   --  25 gpu_accessed   24 pio_prim   23 dma2_prim   22 raster_pixel(GPU drew)
   --  21 imask0(VBLANK enabled) 20 irqreq(IRQ->CPU) 19 vblank_irq(I_STAT) 18 istat_ack(IRQ serviced)
   --  17 m_gpuinit(0xBFC097EC)  16 m_strcmp(0xBFC03298 license cmp)  15 m_strfail(0xBFC09054 FAIL)
   --  14 m_launch(0xBFC004B8 game launch=PASS)  13 m_decomp2(0x1FC202B4 decompressor)  12:0 zero
   -- BOOT-PROGRESS BITMAP (top->bottom, MSB=bit31): 31 rch_kernel  30 helper_entry(decompressor)
   --  29 panic  28 rch_decomp  27 game8004  26 game8005  25 gpu_accessed  24 pio_prim  23 dma2_prim
   --  22 raster_pixel  21 imask0(VBL en)  20 irqreq  19 vblank_irq  18 istat_ack
   --  17 m_gpuinit  16 m_strcmp  15 m_strfail  14 m_launch(game launch)  13 m_decomp2(decompressor)
   -- BOOT-PROGRESS BITMAP: 31 rch_kernel 30 helper_entry(decompressor) 29 panic 28 rch_decomp(KUSEG game)
   -- 27 game8004 26 game8005 25 gpu_accessed 24 pio_prim 23 dma2_prim 22 raster_pixel 21 imask0 20 irqreq
   -- 19 vblank_irq 18 istat_ack 17 m_gpuinit 16 m_strcmp 15 m_strfail 14 m_launch 13 m_decomp2
   -- BOOT-PROGRESS BITMAP: 31 rch_kernel 30 helper_entry(decompressor) 29 panic 28 rch_decomp(KUSEG game)
   -- 27 game8004 26 game8005 25 gpu_accessed 24 pio_prim 23 dma2_prim 22 raster_pixel 21 imask0 20 irqreq
   -- 19 vblank_irq 18 istat_ack 17 m_gpuinit 16 m_strcmp 15 m_strfail 14 m_launch 13 m_decomp2
   -- C76-BRINGUP DIAG 2026-06-20: MIPS-side state to see WHY the screen is black after the C76
   -- IPL fix (MIPS reached game code but isn't rendering). [31]panic_reached [30]s11_reached_game
   -- [29]m_gpuinit [28]m_launch [27]gpu_accessed_seen [26]raster_pixel_seen(GPU drew a pixel)
   -- [25]vblank_irq_seen [24]istat_ack_seen [27:24 dup avoided] [23:0]=cpu_dbg_exc_epc[23:0]
   -- (the first MIPS fault EPC; with exc_code in the next field). If panic_reached -> MIPS panicked
   -- (exc_epc shows where); if raster_pixel_seen=0 -> GPU never drew despite reaching game.
   -- C76-BRINGUP DIAG 2026-06-24: zn_debug_val now = the FULL 32-bit FAULTING INSTRUCTION WORD
   -- (cpu_dbg_fault_a1 repurposed to opcode0 at the first fault). Read over JTAG/ISSP and compare
   -- to MAME's 0xA420FB00 @0x10170: a COP-range top6 (0x10-0x13) or any != 0xA420FB00 = the
   -- SDRAM/icache delivered a CORRUPT instruction word (pinpoints the read-corruption bit pattern).
   -- 2026-06-25: repurpose to {irqVecCount[7:0], 000, LIVE committed PC offset[20:0]} to pin the
   -- early-init wait loop the MIPS is stuck in (maxRAMPC=0x42C80 is the *return* of a list-processor
   -- called from a lower outer loop; we need the live PC to find that outer loop and what it polls).
   -- {eeprom_wr_count[10:0], LIVE committed PC offset[20:0]} — CAS-3 test: if the SDRAM source read
   -- is now reliable, the EEPROM verify passes -> live PC leaves 0x3E6xx (and/or count climbs/skips).
   -- {irqVecCount[7:0], 000, maxRAMPC offset[20:0]} — how far past the EEPROM did the game get, and
   -- does irqVecCount climb (per-frame IRQs recurring => running) or stay 1 (stuck in first handler)?
   -- 2026-06-27: cycle the spin-loop's polled addresses t0 / a3 (~0.5s each via dbg_cyc(24)) so one
   -- build reveals both. Identify by value (t0/a3 are 0x8003xxxx RAM or 0x1FA0xxxx I/O addresses).
   -- gputype1 = coh100 board = CXD8538Q. Only Tekken 1 (the keycus-less game) uses it;
   -- all other System 11 boards are coh110 with the retail CXD8561Q (type 2).
   s11_gputype1 <= '1' when (zn_system11 = '1' and keycus_id = x"00") else '0';

   zn_debug_val <= std_logic_vector(cpu_dbg_instr_word);  -- live PC (pcOld1)
   zn_dbg_a0    <= cpu_dbg_fault_s1s2;  -- mode 1: [31:16]=$s1[15:0] [15:0]=$s2[15:0] at the fault (branch operands)
   -- mode 2: live s11_bank window regs — low nibble of each 5-bit page (window w in bits [4w+3:4w]).
   -- Page bit4 (rom8_64 upper half) is not visible here; windows are 5-bit since the rom8_64 change.
   zn_dbg_a1    <= zn_s11_bank(38 downto 35) & zn_s11_bank(33 downto 30) &
                   zn_s11_bank(28 downto 25) & zn_s11_bank(23 downto 20) &
                   zn_s11_bank(18 downto 15) & zn_s11_bank(13 downto 10) &
                   zn_s11_bank(8 downto 5)   & zn_s11_bank(3 downto 0);
   zn_dbg_eeprom_o <= zn_dbg_eeprom;
   -- GPU activity snapshot: [31]gpu_accessed [30]dma2_wrote_gpu [29]dma2_prim [28]pio_prim
   --   [27]dma2_e5 [26]raster_pixel(drew) [25]ram_exec [24]game_ram_exec
   -- mode 6 REPURPOSED (2026-07-06 desync detector): gpu dbg_desync =
   -- {unknown-GP0-cmd count[15:0], last unknown cmd byte[7:0], dispatch count[7:0]}.
   -- unkcmd_cnt climbing during fights = parser desync still happening.
   zn_dbg_gpu <= zn_dbg_desync;
   -- display/render config: [31:21]=DisplayWidth(11) [20:12]=DisplayOffsetY(9) [11:1]=drawingOffsetY(11) [0]=0
   -- mode 7 REPURPOSED (2026-07-05 write-path forensics): {vram_WE pulse count[15:0], vram_RD pulse count[15:0]}
   -- free-running counters — two JTAG reads N seconds apart give the LIVE DDR3 write/read rates.
   -- mode 7 REPURPOSED (2026-07-06 bank-write forensics): zn1_io dbg_bankwr =
   -- {bankreg_wr_cnt[3:0], addr16_wr_cnt[3:0], data23_16, data7_0, addr7_0}
   zn_dbg_disp <= zn_dbg_bankwr;
   -- DMA2/GPU drain monitor: [31]gpu_dmaRequest(live) [30]DMA_GPU_writeEna(live) [29:24]=0
   --   [23:0]=count of GPU DMA writes (frozen => DMA not sending => stuck in STOPPING/done not cleared;
   --   climbing => DMA actively transferring => list not terminating)
   -- mode 8 REPURPOSED (mailbox-read forensics): {addr_off16, mb_rdata16} of the last MIPS mailbox READ
   zn_dbg_dma <= dbg_mbrd;
   -- write-path forensics: count vram_WE / vram_RD pulses (gpu side of the ddr3 mux) on clk2x
   process(clk2x) begin
      if rising_edge(clk2x) then
         if vram_WE = '1' then
            dbg_vramwe_cnt      <= dbg_vramwe_cnt + 1;
            dbg_vramwe_lastaddr <= vram_ADDR;
         end if;
         if vram_RD = '1' then dbg_vramrd_cnt <= dbg_vramrd_cnt + 1; end if;
         -- upload forensics: cpu2vram pixel-write pulses (live count) + STICKY last cpu2vram addr with X>=512
         if dbg_cpu2vram_pixelWrite = '1' then
            dbg_c2vpix_cnt <= dbg_c2vpix_cnt + 1;
         end if;
         if vram_WE = '1' and vram_ADDR(10) = '1' then
            dbg_vramwe_xhi_cnt <= dbg_vramwe_xhi_cnt + 1;
         end if;
      end if;
   end process;
   -- upload forensics: PIO GP0-write pulses into the GPU bus (clk1x domain)
   process(clk1x) begin
      if rising_edge(clk1x) then
         if bus_gpu_write = '1' and bus_gpu_addr = x"0" then
            dbg_piogp0_cnt <= dbg_piogp0_cnt + 1;
         end if;
      end if;
   end process;

   process(clk1x) begin
      if rising_edge(clk1x) then
         if DMA_GPU_writeEna = '1' then dma_gpu_wr_cnt <= dma_gpu_wr_cnt + 1; end if;
      end if;
   end process;
   hblank <= hblank_i;  -- drive output ports from readable internal copies
   vblank <= vblank_i;
   video_r <= video_r_i;
   video_g <= video_g_i;
   video_b <= video_b_i;
   process(clk1x) begin  -- TEXTURE-BLACK pipeline trace sticky latches
      if rising_edge(clk1x) then
         -- DE (active display) diagnostics: is the active window ever open, and does content land in it?
         if (hblank_i = '0' and vblank_i = '0') then de_active_seen <= '1'; end if;
         if (dbg_videoout_pixeldata_nonnavy = '1' and hblank_i = '0' and vblank_i = '0') then
            visible_nonnavy_seen <= '1';
         end if;
         -- TRUE nonblack test (unconfounded by black): a real COLORED pixel in the active display window.
         if ((video_r_i /= x"00" or video_g_i /= x"00" or video_b_i /= x"00") and hblank_i = '0' and vblank_i = '0') then
            visible_color_seen <= '1';
         end if;
         if dbg_stage4_texture          = '1' then tx_stage4_seen   <= '1'; end if;
         if dbg_stage4_texraw_nz        = '1' then tx_texnz_seen    <= '1'; end if;
         if dbg_clut_read_nonnavy       = '1' then tx_clutrd_seen   <= '1'; end if;
         if dbg_rast_display_nonnavy    = '1' then tx_rastdisp_seen <= '1'; end if;
         if dbg_rast_offdisp_nonnavy    = '1' then tx_rastoff_seen  <= '1'; end if;
         if dbg_vramdin_display_nonnavy = '1' then tx_vramdin_seen  <= '1'; end if;
         if dbg_vram_dout_nonnavy       = '1' then tx_vramdout_seen <= '1'; end if;
         if dbg_videoout_linebuf_nonnavy= '1' then tx_volinebuf_seen<= '1'; end if;
         if dbg_videoout_pixeldata_nonnavy='1' then tx_vopixel_seen <= '1'; end if;
      end if;
   end process;
   process(clk1x) begin
      if rising_edge(clk1x) then
         dbg_cyc <= dbg_cyc + 1;
      end if;
   end process;
   zn_debug_addr <= (others => '0');  -- CLEANUP: retired (was dbg_palrd_addr)
   -- build #82: direct-VRAM-read capture bars — replaces B80 triage with diagnostic latches.
   --   RED slot [17:9]    = vram_DOUT(31:24) at first hi-Y CLUTwrenA (Y=482 CLUTaddrA=0). Expected 0x7F.
   --   GREEN slot [72:64] = vram_DOUT(23:16) at same event. Expected 0xFF.
   --   BLUE slot [136:128] = captured flag (full lit if latch fired, dark if not).
   -- Display: each byte is rendered as a magnitude bar (value 0..255 of a 9-bit slot 0..511).
   -- Diagnostic outcomes:
   --   BLUE lit, RED half-lit, GREEN full → DDR3 returns correct data (0x7FFF) → bug downstream of vram_DOUT.
   --   BLUE lit, RED dark, GREEN dark → DDR3 returns zero → write-doesn't-commit (old hypothesis).
   --   BLUE lit, RED dark, GREEN ≈0x01 → DDR3 returns index pattern.
   --   BLUE dark → latch never triggered (Y=482 CLUT never loaded — filter too restrictive).
   latch_hi_y_fan <= (others => clut_succ_hi_seen);  -- legacy retained
   latch_lo_y_fan <= (others => clut_succ_lo_seen);
   -- B82 bar values: 8-bit byte zero-extended to 9 bits.
   -- build #134: probe fifoIn_Dout halfword R bits — localize where R=31 is lost.
   -- build #140 bars: CLUT-RAM cube CLUT presence probes (sticky-once-set)
   -- Probes the GPU's internal CLUT cache directly inside gpu_pixelpipeline.vhd.
   -- RED   = h40_cube_clut_loaded_ever — CLUTwrenA + CLUTaddrA=0 + vram_DOUT[31:16]=0x7FFF + vram_DOUT[47:32]=0x023F
   --         (cube CLUT word 0 loaded into dpram with the EXACT MAME-verified values)
   -- GREEN = h40_clut_read_7fff_ever   — any CLUTDataB lane ever = 0x7FFF (cube entry 1, white)
   -- BLUE  = h40_clut_read_023f_ever   — any CLUTDataB lane ever = 0x023F (cube entry 2, R=31 G=1 B=0)
   -- Outcome matrix:
   --   all 3 LIT          → cube CLUT IS in CLUT-RAM and IS read out → bug downstream of CLUT lookup
   --   R LIT, G+B DARK    → loaded but never read back → CLUT-RAM read path broken
   --   R DARK, G+B either → cube CLUT word 0 never loaded with correct values → upload corrupts data
   --   all 3 DARK         → CLUT-RAM never sees cube CLUT values — load path entirely broken
   -- DECISIVE:
   --   RED=LIT, GREEN=LIT → R=31 reaches FIFO output in both halfwords → bug is in cpu2vram latch step
   --   RED=LIT, GREEN=DARK → upper halfword loses R=31 between DMA and FIFO output
   --   RED=DARK, GREEN=LIT → lower halfword stripped (less likely)
   --   BOTH=DARK → fifoIn corrupts ALL R=31 (rare)
   --   GREEN=DARK, BLUE=LIT → upper halfword has R≥16 sometimes but never exactly 31
   -- build #145 bars:
   --   RED   = h45_y482_anchor    — state=WRITING + copyDstY=482 ever (must fire; sanity)
   --   GREEN = h45_y482_pixwrite  — pixelWrite at row=482 ever (does FSM emit cube row?)
   --   BLUE  = h45_y480_pixwrite  — pixelWrite at row=480 ever (positive control)
   -- Outcomes:
   --   R lit, G dark, B lit → FSM enters WRITING for Y=482 but never emits pixelWrite at row 482.
   --     Bug in WRITING-state emit gating for that specific row.
   --   R lit, G lit, B lit → FSM emits writes. Bug downstream (vram_DIN, DDR3 path).
   --   R dark → FSM never enters WRITING for Y=482 — earlier-stage bug (REQUESTWORD2 parse?)
   -- build #154 bars: bank-value capture at cube CLUT read.
   --   RED   = h54_bank0_at_read   — zn_bank_8mb was "000" when CPU read 0x1F7B61CC
   --   GREEN = h54_bank1_at_read   — zn_bank_8mb was "001" when CPU read 0x1F7B61CC
   --   BLUE  = h54_bankhi_at_read  — zn_bank_8mb was ≥ "010" when CPU read 0x1F7B61CC
   -- Outcome:
   --   RED lit, GREEN+BLUE dark   → bank IS 0 at read → SDRAM at 0x0FB61CC has wrong data
   --                                  (MRA load problem or SDRAM controller bug)
   --   RED+GREEN+BLUE mixed       → multiple bank values at read times — game switches banks
   --                                  between attract iterations
   --   GREEN or BLUE only         → bank mis-selected at every read → cube CLUT code expects
   --                                  bank=0 but FPGA's bank is wrong at that moment
   -- build #159 bars: H7 CLUT-RAM data staleness test.
   --   RED  9-bit = h59_loaded_entry0_lo : bits 8:0 of the first CLUT entry 0 loaded
   --   GREEN 9-bit = h59_loaded_y         : bits 8:0 of textPalReqY at that load
   --   BLUE sticky = h59_anchor           : capture has fired
   -- After test, decode RED/GREEN bar widths and /dev/mem read VRAM at Y (low 9 bits +
   -- assumed Y high bit) at the suspected X. If RED bar matches VRAM[Y][X] low 9 bits,
   -- the CLUT load delivered correct VRAM data → H7 REFUTED.
   -- build #172: Raizing GPU buffer-swap probe.
   -- Hypothesis: Raizing games (Bloody Roar, Brave Blade, Beastorizer) only draw to the back
   -- buffer at VRAM Y=0..239; never set the draw area or offset to the front buffer at Y=240+.
   -- Display origin is at Y=240 per MAME GP1 0x05 trace, so screen shows the empty front buffer.
   --   RED   = sticky: drawingAreaBottom ever > 239 (game ever set draw area to extend into front buffer)
   --   GREEN = sticky: drawingOffsetY ever >= 240 (game ever shifted offset into front buffer region)
   --   BLUE  = b157_anchor_sig (CAT702 anchor — sanity that BIOS check passed)
   -- Outcome on Raizing titles: RED+GREEN dark → buffer swap never happens → black screen.
   --                            RED+GREEN lit + still black → swap works, display origin issue.
   -- System 11 bring-up triage (was stale DoA++ cube signals): RED=CPU executing from
   -- RAM, GREEN=CPU accessed GPU regs, BLUE=MIPS wrote the C76 mailbox.
   -- System 11 GPU-hang diagnostic: RED = reached early GAME code (did MIPS boot past
   -- the GPU-wait?), GREEN = reached_1fc2, BLUE = GPU input-FIFO ever empty (did the GPU
   -- ever drain? if DIM, the GPU never drains → GPUSTAT bit28 stuck low → MIPS hang).
   -- C76 mailbox-poll triage (2026-06-12): WHY does the MIPS hang before game code?
   -- MAME proved: the MIPS boots iff the 0x1FA0BD32 poll reads 0 (timeout); reading
   -- bit 0x80 takes the early-exit path that hangs. The golden C76 keeps 0xBD32 = 0.
   -- FIRST-EXCEPTION bars (build 6): which exception kicked off the cascade? (MAME takes 0.)
   --   RED   = any exception taken (EPC latched != 0)
   --   GREEN = first ExcCode == 0  => INTERRUPT was first (spurious early IRQ -> 0xBFC00180 reset)
   --   BLUE  = first ExcCode == 5  => AdES was first (no earlier exc; wild jump into KUSEG helper)
   -- Value = EPC of the FIRST exception. GREEN+EPC(late-boot) => an unexpected interrupt is the
   -- root; BLUE+EPC(0x1FC20298) => AdES is first; neither => other code (disasm EPC: 4=AdEL,6=PCoob,A=RI).
   -- WILD-JUMP-SOURCE bars (build 7): EPC=0x1FC20298 reached via a register jump to a garbage
   -- KUSEG address. Capture the source (the jr) and where it lives.
   --   RED   = kuseg_seen (a jump into 0x1FC2xxxx was detected)
   --   GREEN = kuseg_src top nibble == 0xB (the jr is in normal KSEG1 BIOS code 0xBFCxxxxx)
   --   BLUE  = panic_reached (same hang)
   -- Value = kuseg_src = PC of the jr that jumped into KUSEG. Disasm it in MAME (same bytes)
   -- to see `jr rX` and which register held the garbage 0x1FC20298 -> trace where rX was set.
   -- build 10 bars: RED=lw captured; GREEN=memorymux CORRUPTED it (input != output delivered
   -- to CPU); BLUE=panic_reached. Value=dbg_lw_input (SDRAM data memorymux ingested for the lw).
   --   value 0x1FC20038 + GREEN lit => memorymux delivery corrupts it
   --   value 0x1FC20038 + GREEN dim => memorymux passed it clean (corruption in CPU or capture)
   --   value 0x1FC20298          => the SDRAM data into memorymux is already wrong (connection)
   -- EXC DIAG bars: faulting-EPC region. RED=KSEG0 RAM (0x8xxxxxxx, game code),
   -- GREEN=KSEG1 BIOS (0xBxxxxxxx), BLUE=KUSEG (0x1xxxxxxx, boot program). All dim + value 0 => no exception.
   -- RED = dbg_lw_seen (the lw at 0x1FC20000 fired). GREEN = dbg_lw_input /= dbg_lw_output
   -- (delivery corrupted it between SDRAM-out and CPU). BLUE = panic_reached.
   triage_red_fan   <= (others => '1') when cpu_dbg_exc_epc(31 downto 28) = x"8" else (others => '0');
   triage_green_fan <= (others => '1') when cpu_dbg_exc_epc(31 downto 28) = x"B" else (others => '0');
   triage_blue_fan  <= (others => '1') when cpu_dbg_exc_epc(31 downto 28) = x"1" else (others => '0');
   dbg_reached_game <= s11_reached_game;   -- top-level overlay auto-hides once game code runs
   zn_debug_words <= (others => '0');  -- CLEANUP: retired (was triage_*_fan palette grid)

   process(clk1x)
   begin
      if rising_edge(clk1x) then
         if reset_intern = '1' then
            ram_accessed_seen <= '0';
            ram_done_seen     <= '0';
            nonzero_read_seen <= '0';
            gpu_accessed_seen <= '0';
            ram_exec_seen     <= '0';
            s11_mb_seen       <= '0';
            s11_reached_1fc2  <= '0';
            s11_reached_game  <= '0';
            dbg_boot_pc       <= (others => '0');
            dbg_last_any_pc   <= (others => '0');
            dbg_call_taddr    <= (others => '0');
            dbg_last_wr_addr  <= (others => '0');
            memset_seen       <= '0';
            wr_seen           <= '0';
            heap_init_val     <= (others => '0');
            heap_init_seen    <= '0';
            heap_advanced     <= '0';
            rch_decomp        <= '0';
            rch_kernel        <= '0';
            rch_b0handler     <= '0';
            rch_initheap      <= '0';
            rch_alloc         <= '0';
            derail_src        <= (others => '0');
            lowsled_seen      <= '0';
            lowsled_src       <= (others => '0');
            dbg_ctable_seen   <= '0';
            dbg_ctable_val    <= (others => '0');
            dbg_ctable_fn     <= (others => '0');
            dbg_ctw_seen      <= '0';
            dbg_ctw_val       <= (others => '0');
            dbg_w65_seen      <= '0';
            dbg_w65_be        <= (others => '0');
            dbg_w65_adr       <= (others => '0');
            dbg_rb_seen       <= '0';
            dbg_rb_val        <= (others => '0');
            derail_captured   <= '0';
            panic_reached     <= '0';
            helper_entry_seen <= '0';
            m_gpuinit         <= '0';
            m_strcmp          <= '0';
            m_strfail         <= '0';
            m_launch          <= '0';
            m_decomp2         <= '0';
            dbg_bios_pc       <= (others => '0');
            dbg_lw_input      <= (others => '0');
            dbg_lw_output     <= (others => '0');
            dbg_lw_seen       <= '0';
            pc_hist1          <= (others => '0');
            pc_hist2          <= (others => '0');
            kuseg_src         <= (others => '0');
            kuseg_seen        <= '0';
            gpu_fifo_empty_ever <= '0';
            io_ever_seen      <= '0';
            spu_ever_seen     <= '0';
            cd_ever_seen      <= '0';
            dma_ever_seen        <= '0';
            dma_gpu_write_seen   <= '0';
            dma2_e5_write_seen   <= '0';
            dma2_prim_seen       <= '0';
            pio_prim_seen        <= '0';
            raster_pixel_seen    <= '0';
            raster_pixel_top_seen <= '0';
            -- build #150: CPU PC sticky latches
            h50_pc_cube_loop_seen  <= '0';
            h50_pc_cube_area_seen  <= '0';
            h50_game_ram_exec_seen <= '0';
            -- build #151: CPU GP0 write sticky latches
            h51_gp0_cubeclut_seen <= '0';
            h51_gp0_a0cmd_seen    <= '0';
            h51_gp0_r31_seen      <= '0';
            -- build #152: cube CLUT data words 1-3 latches
            h52_gp0_word1_seen    <= '0';
            h52_gp0_word2_seen    <= '0';
            h52_gp0_word3_seen    <= '0';
            -- build #153: cube CLUT init-step bisect latches
            h53_rd_cubesrc_seen    <= '0';
            h53_wr_staging_seen    <= '0';
            h53_data_7fff0000_seen <= '0';
            -- build #154: bank-at-read latches
            h54_bank0_at_read      <= '0';
            h54_bank1_at_read      <= '0';
            h54_bankhi_at_read     <= '0';
            cnt_stage4       <= (others => '0');
            cnt_pxwr         <= (others => '0');
            cnt_texraw      <= (others => '0');
            disp_cnt_stage4  <= (others => '0');
            disp_cnt_pxwr    <= (others => '0');
            disp_cnt_texraw <= (others => '0');
            -- build #63
            clut_real_data_hi_y_seen <= '0';
            clut_real_data_lo_y_seen <= '0';
            -- build #68
            clut_succ_lo_seen <= '0';
            clut_succ_hi_seen <= '0';
            -- build #19: lpadv-tuned latches
            cmd_64_seen_ever      <= '0';
            cmd_2C_seen_ever      <= '0';
            cmd_A0_seen_ever      <= '0';
            cpu2vram_parsed_dstX_hi_seen <= '0';
            cpu2vram_color_nonnavy_seen <= '0';
            pixelcolor_g_seen <= '0';
            pixelcolor_b_seen <= '0';
            vram_din_gb_seen <= '0';
            texpal_gb_seen <= '0';
            textPalX_ge_256_seen  <= '0';
            textPalX_hi_seen      <= '0';
            cpu2vram_dstX_hi_seen <= '0';
            -- build #26
            cubeclut_gb_seen      <= '0';
            cubeclut_ronly_seen   <= '0';
            loclut_gb_seen        <= '0';
            vram_actual_write_seen <= '0';
            pipeline_color_varied_seen <= '0';
            vram_din_non_navy_seen <= '0';
            vram_dout_nonnavy_seen <= '0';
            videoout_linebuf_nonnavy_seen <= '0';
            videoout_pixeldata_nonnavy_seen <= '0';
            vblank_d                       <= '0';
            -- frame accumulators (build #7)
            frame_ram_exec                 <= '0';
            frame_clut_write_nonnavy       <= '0';
            frame_clut_read_nonnavy        <= '0';
            frame_stage4_texture           <= '0';
            frame_pipeline_color_varied    <= '0';
            -- build #24 frame/disp resets
            frame_rect_tex_4bit            <= '0';
            frame_rect_tex_8bit            <= '0';
            frame_rect_tex_15bit           <= '0';
            frame_rect_tex_pixel_gb        <= '0';
            disp_rect_tex_4bit             <= '0';
            disp_rect_tex_8bit             <= '0';
            disp_rect_tex_15bit            <= '0';
            disp_rect_tex_pixel_gb         <= '0';
            frame_pixeldata_nonnavy        <= '0';
            frame_pipeline_write_any       <= '0';
            -- displayed snapshots (build #7)
            disp_ram_exec                  <= '0';
            disp_clut_write_nonnavy        <= '0';
            disp_clut_read_nonnavy         <= '0';
            disp_stage4_texture            <= '0';
            disp_pipeline_color_varied     <= '0';
            disp_pixeldata_nonnavy         <= '0';
            disp_pipeline_write_any        <= '0';
            -- build #8 accumulators + displayed
            frame_b8_textPalNew            <= '0';
            frame_b8_textPalReq_set        <= '0';
            frame_b8_state_REQ_PAL         <= '0';
            frame_b8_CLUTwrenA_any         <= '0';
            frame_b8_drawMode_8            <= '0';
            frame_b8_noTexture_pin         <= '0';
            disp_b8_textPalNew             <= '0';
            disp_b8_textPalReq_set         <= '0';
            disp_b8_state_REQ_PAL          <= '0';
            disp_b8_CLUTwrenA_any          <= '0';
            disp_b8_drawMode_8             <= '0';
            disp_b8_noTexture_pin          <= '0';
            disp_vram_dout_nonnavy_b10     <= '0';
            disp_vram_din_nonnavy_b10      <= '0';
            disp_cpu2vram_active_ever      <= '0';
            disp_cpu2vram_nonnavy_ever     <= '0';
            disp_clut_write_nv_ever        <= '0';
            disp_clut_read_nv_ever         <= '0';
            disp_pipeline_color_var_ever   <= '0';
            disp_pixeldata_nv_ever         <= '0';
            disp_pipeline_pxwr_ever        <= '0';
            disp_clut_X_nz_ever            <= '0';
            disp_clut_Y_nz_ever            <= '0';
            disp_cpu2vram_dstY_bit8_ever   <= '0';
            disp_cpu2vram_dstY_nz_ever     <= '0';
            disp_cpu2vram_dstX_zero_ever   <= '0';
            disp_cpu2vram_dstX_nz_ever     <= '0';
            disp_vram_we_x_zero_ever       <= '0';
            disp_vram_we_x_zero_nv_ever    <= '0';
            disp_vram2vram_active_ever     <= '0';
            disp_vramFill_active_ever      <= '0';
            disp_pixelAddr_Y_hi_ever       <= '0';
            disp_cpu2vram_Y_hi_ever        <= '0';
            disp_vram_addr_Y_hi_we_ever    <= '0';
            disp_vram_addr_Y_hi_rd_ever    <= '0';
            dma_gpu_waiting_seen <= '0';
            irq_dma_seen         <= '0';
            irqreq_seen          <= '0';
            imask0_write_seen    <= '0';
            istat_ack_seen       <= '0';
            pc_reached_mid       <= '0';
            pc_reached_gpuinit   <= '0';
            dma_spu_write_seen   <= '0';
            irq_stat_read_seen   <= '0';
            irq_stat_write_seen  <= '0';
            irq_cdrom_seen       <= '0';
            irq_timer_seen       <= '0';
            vblank_irq_seen      <= '0';
            zn_sio_ever_seen  <= '0';
            zn_check1_seen    <= '0';
            zn_check2_seen    <= '0';
            zn_kn02_rx_nonzero <= '0';
            -- build #172: drawing-area sticky latches
            b172_drawArea_high_ever   <= '0';
            b172_drawOffset_high_ever <= '0';
            -- build #163: throughput counters reset
            b163_win_cnt      <= (others => '0');
            b163_win_tick     <= '0';
            b163_dma2_cnt     <= (others => '0');
            b163_dma4_cnt     <= (others => '0');
            b163_bank_cnt     <= (others => '0');
            b163_dma2_disp    <= (others => '0');
            b163_dma4_disp    <= (others => '0');
            b163_bank_disp    <= (others => '0');
            b163_DMA_GPU_writeEna_d <= '0';
            b163_DMA_SPU_writeEna_d <= '0';
            b163_bank_write_d <= '0';
         else
            -- ram_accessed_seen: CPU put any request on RAM bus (read or write)
            if ram_cpu_ena = '1' then
               ram_accessed_seen <= '1';
            end if;
            -- ram_done_seen: SDRAM completed a CPU transaction
            if ram_cpu_done = '1' then
               ram_done_seen <= '1';
            end if;
            -- nonzero_read_seen: SDRAM returned non-zero data on a CPU read (BIOS is loaded)
            if ram_cpu_done = '1' and ram_dataRead32 /= x"00000000" then
               nonzero_read_seen <= '1';
            end if;
            -- gpu_accessed_seen: CPU read or wrote GPU registers
            if bus_gpu_read = '1' or bus_gpu_write = '1' then
               gpu_accessed_seen <= '1';
            end if;
            -- ram_exec_seen: CPU fetch from physical RAM above 0x40000 (game at ~0x80050000, not 0xA0000500 stub)
            if mem_request = '1' and mem_isData = '0' and
               mem_addressInstr(28 downto 0) >= to_unsigned(16#40000#, 29) and
               mem_addressInstr(28 downto 0) < to_unsigned(16#800000#, 29) then
               ram_exec_seen <= '1';
               dbg_last_ram_pc <= std_logic_vector(resize(mem_addressInstr, 32));  -- capture hang-loop RAM address
            end if;
            -- boot-progress milestones (vs MAME ground truth): how far does the boot get?
            if mem_request = '1' and mem_isData = '0' then
               if mem_addressInstr(28 downto 0) >= to_unsigned(16#1FC01000#, 29) and
                  mem_addressInstr(28 downto 0) <  to_unsigned(16#1FC09000#, 29) then
                  pc_reached_mid <= '1';
               end if;
               if mem_addressInstr(28 downto 0) >= to_unsigned(16#1FC09000#, 29) and
                  mem_addressInstr(28 downto 0) <  to_unsigned(16#1FC0C000#, 29) then
                  pc_reached_gpuinit <= '1';
               end if;
            end if;
            -- ABSOLUTE last instruction fetch, ANY region (physical addr) — the hang loop
            -- jitters among its own PCs so this pins where the MIPS is actually stuck,
            -- whether boot ROM (0x1FC2xxxx), RAM (0x000xxxxx), or scratchpad (0x1F800xxx).
            -- HEAP/MEMSET DIAGNOSTIC (2026-06-13): last data-write address. If the boot is
            -- stuck in the kernel memset (0xBFC01A4C, called from 0xBFC03FD4) this is the
            -- memset dest — reveals bounded(~0xa000e0xx, MAME) vs runaway(huge) vs wrong-region.
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '0' then
               dbg_last_wr_addr <= std_logic_vector(mem_addressData);
               wr_seen <= '1';
               -- HEAP base capture: writes to the heap pointer 0xa0005d10. First non-zero
               -- value = InitHeap's base (should be 0xa000e000). A 2nd distinct value =
               -- B0(0) advancing it. If the base itself is 0x?C00AC28 => computed wrong.
               if mem_addressData(27 downto 0) = x"0005d10" and mem_dataWrite /= x"00000000" then
                  if heap_init_seen = '0' then
                     heap_init_val  <= mem_dataWrite;
                     heap_init_seen <= '1';
                  elsif mem_dataWrite /= heap_init_val then
                     heap_advanced <= '1';
                  end if;
               end if;
            end if;
            -- memset_seen: CPU ever fetched the bzero store at 0xBFC01A70
            if mem_request = '1' and mem_isData = '0' and mem_addressInstr = x"BFC01A70" then
               memset_seen <= '1';
            end if;
            -- RENDER-HANG: capture BIOS A/B/C call-table reads (0x200..0x780) -> names the looping fn
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '1'
               and mem_addressData(27 downto 0) >= to_unsigned(16#0000200#, 28)
               and mem_addressData(27 downto 0) <  to_unsigned(16#0000400#, 28) then
               dbg_call_taddr <= std_logic_vector(mem_addressData(23 downto 0));
            end if;
            if mem_request = '1' and mem_isData = '0' then
               dbg_last_any_pc <= std_logic_vector(resize(mem_addressInstr, 32));
               -- DERAIL-BRACKET (2026-06-14 v3): EARLY boot + capture the wild-jump source.
               -- PANIC-SOURCE: capture the instruction-fetch PC right before the FIRST fetch of
               -- the BIOS panic self-loop 0xBFC08DE0 (dbg_last_any_pc still holds the prior fetch).
               if derail_captured = '0' and mem_addressInstr = x"BFC08DE0" then
                  derail_src      <= dbg_last_any_pc;
                  derail_captured <= '1';
               end if;
               -- DERAIL-TO-LOW (2026-06-18): first instr-fetch from the exception-vector / low region
               -- (phys < 0x100, e.g. live PC 0xA0). derail_src = the PRIOR fetch PC = the jr/branch or
               -- faulting EPC that sent the MIPS there. Disassemble it to find the wild-jump origin.
               if derail_captured = '0'
                  and mem_addressInstr < to_unsigned(16#100#, mem_addressInstr'length) then
                  derail_src      <= dbg_last_any_pc;
                  derail_captured <= '1';
               end if;
               -- POST-GPU-INIT progress (chase the color-bar stall); overlay shows the LIVE PC.
               if    mem_addressInstr = x"BFC00484"           then rch_kernel    <= '1';  -- kernel ROM->RAM copy
               elsif mem_addressInstr(31 downto 16) = x"8005" then rch_b0handler <= '1';  -- game code @0x8005xxxx
               elsif mem_addressInstr(31 downto 16) = x"8004" then rch_initheap  <= '1';  -- game code @0x8004xxxx
               elsif mem_addressInstr(31 downto 16) = x"8001" then rch_decomp    <= '1';  -- GAME ENTRY @0x8001xxxx (decompressor dest = decompression COMPLETED + game running)
               end if;
               -- panic_reached: MIPS ever fetched the BIOS panic self-loop 0xBFC08DE0
               if mem_addressInstr = x"BFC08DE0" then
                  panic_reached <= '1';
               end if;
               -- GAME-LAUNCH path milestones (gate = license strcmp). MAME: GPU init -> strcmp
               -- (0xBFC03298, cmp 0x1FC20004 vs 0xBFC0D66C) -> 0xBFC0903C bnez: PASS=>0xBFC09044 jal
               -- 0xBFC004B8 launch -> 0x1FC202B4 decompressor; FAIL=>0xBFC09054 (skip launch).
               if mem_addressInstr = x"BFC097EC" then m_gpuinit <= '1'; end if;
               if mem_addressInstr = x"BFC03298" then m_strcmp  <= '1'; end if;
               -- last RAM-KERNEL fetch (KSEG1 0xA0000500..0xA0010000): the MIPS spins here after
               -- C0(0x1c) jumps into the RAM kernel (0xA0000540 table-copy). Pins the hung loop.
               -- mem_addressInstr is VIRTUAL (captured 0xBFC0CE88, 0xA0000540 etc.).
               if mem_addressInstr >= x"A0000500" and mem_addressInstr < x"A0010000" then
                  dbg_bios_pc <= std_logic_vector(resize(mem_addressInstr, 32));
               end if;
               if mem_addressInstr = x"BFC09054" then m_strfail <= '1'; end if;
               if mem_addressInstr = x"BFC004B8" then m_launch  <= '1'; end if;
               if mem_addressInstr = x"1FC202B4" then m_decomp2 <= '1'; end if;
               -- helper_entry_seen: MIPS ever fetched the unaligned-store helper ENTRY
               -- 0xBFC20280 (normal call) vs faulting at 0x29C without it (wild jump).
               if mem_addressInstr = x"BFC20280" then
                  helper_entry_seen <= '1';
               end if;
               -- build 7: capture the SOURCE of the first jump into the KUSEG fault region
               -- 0x1FC2xxxx. pc_hist2 = the instruction 2 fetches before the target = the jr
               -- (target's predecessor is the jr's delay slot). This is the wild jr.
               if kuseg_seen = '0' and mem_addressInstr(31 downto 16) = x"1FC2" then
                  kuseg_seen <= '1';
                  kuseg_src  <= pc_hist2;
               end if;
               -- WILD-JUMP into the low NOP sled (phys 0x00000010..0x0000007F): the game runs+renders
               -- then jumps here and loops. Capture the jr source (pc_hist2) the FIRST time.
               if lowsled_seen = '0' and mem_addressInstr(31 downto 7) = 0
                  and mem_addressInstr(6 downto 4) /= "000" then
                  lowsled_seen <= '1';
                  lowsled_src  <= pc_hist2;
               end if;
               pc_hist2 <= pc_hist1;
               pc_hist1 <= std_logic_vector(resize(mem_addressInstr, 32));
            end if;
            -- capture last CPU data-READ address in the hardware/IO/peripheral range
            -- [0x1F800000,0x1FC00000): scratchpad/hw regs/EXP2/SPU/timer/IRQ/0x1FA I-O/
            -- shared-RAM. A poll loop reads its target every iteration (no D-cache) so
            -- this stabilises at the dependency the core is waiting on.
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '1' and
               mem_addressData(28 downto 0) >= to_unsigned(16#1F800000#, 29) and
               mem_addressData(28 downto 0) < to_unsigned(16#1FC00000#, 29) then
               dbg_last_io_rd <= std_logic_vector(mem_addressData);
            end if;
            -- build 10: capture the lw of CPU 0x1FC20000 (boot's jump-target load). Latch
            -- BOTH the SDRAM data memorymux ingests (ram_dataRead32) and the value delivered
            -- to the CPU (mem_dataRead). MAME's correct value = 0x1FC20038; HW lw got 0x1FC20298.
            if dbg_lw_seen = '0' and ram_cpu_done = '1'
               and mem_addressData(28 downto 0) = to_unsigned(16#1FC20000#, 29) then
               dbg_lw_input  <= ram_dataRead32;
               dbg_lw_output <= mem_dataRead;
               dbg_lw_seen   <= '1';
            end if;
            -- C-TABLE pointer read: capture the value the C-dispatcher loads (lw from 0x65C+n*4)
            -- and jr's to. Corrupt (near-zero / high-bytes-zeroed) => the wild jump into the sled.
            if dbg_ctable_seen = '0' and ram_cpu_done = '1'
               and mem_addressData(27 downto 0) >= to_unsigned(16#000065C#, 28)
               and mem_addressData(27 downto 0) <  to_unsigned(16#00006DC#, 28) then
               dbg_ctable_val  <= mem_dataRead;
               dbg_ctable_fn   <= std_logic_vector(resize((mem_addressData(11 downto 0) - 16#65C#) srl 2, 8));
               dbg_ctable_seen <= '1';
            end if;
            -- READBACK of EXACTLY 0x65C (entry 0) AFTER the install (dbg_ctw_seen) — capture the LAST
            -- post-install read (the value the C-dispatcher actually loads + jr's to). Gating on
            -- dbg_ctw_seen avoids latching a PRE-install BIOS read of the stale leftover.
            -- 0xA0001078 => cell correct (write landed, derail is elsewhere); stale => true write-drop.
            -- Capture the SDRAM-SIDE value (ram_dataRead32) for the post-install 0x65C read.
            -- mem_dataRead here is known = 0xA0840004 (corrupt). If ram_dataRead32 also = 0xA0840004
            -- => SDRAM controller delivers corrupt (cell/read-capture). If = 0xA0001078 => the
            -- memorymux corrupts it downstream of the controller.
            if dbg_ctw_seen = '1' and ram_cpu_done = '1'
               and mem_addressData(27 downto 0) = to_unsigned(16#000065C#, 28) then
               dbg_rb_val  <= ram_dataRead32;
               dbg_rb_seen <= '1';
            end if;
            -- C-TABLE WRITE to ENTRY #0 (0x65C) specifically = the C(0)=EnqueueTimerAndVblankIrqs
            -- pointer (the VBLANK-setup fn the game likely calls). Compare to the derailing read.
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
               and mem_addressData(27 downto 0) = to_unsigned(16#000065C#, 28) then
               dbg_ctw_seen <= '1';
               dbg_ctw_val  <= mem_dataWrite;
            end if;
            -- LAST SDRAM-interface write to ram_Adr=0x65C (ANY source incl DMA). value 0xA0001078
            -- => install was the last write (=> drop inside the controller); 0xAD400070 => a LATER
            -- write OVERWROTE 0x65C with the leftover (ordering/DMA bug).
            if ram_ena = '1' and ram_rnw = '0'
               and ram_Adr = std_logic_vector(to_unsigned(16#65C#, 27)) then
               dbg_w65_seen <= '1';
               dbg_w65_be   <= ram_be;
               dbg_w65_adr  <= ram_dataWrite(26 downto 0);  -- show the VALUE written (low 27b)
            end if;
            -- s11_mb_seen: MIPS ever wrote the System 11 C76 shared-RAM mailbox
            if zn_mb_we = '1' then
               s11_mb_seen <= '1';
            end if;
            -- s11_reached_1fc2: CPU ever fetched an instruction from the late-boot ROM
            -- region 0x1FC20000..0x1FC30000 (where MAME's Tekken does GPU init + the C76
            -- handshake). Tells divergence-before vs reached-handshake-code.
            if mem_request = '1' and mem_isData = '0' and
               mem_addressInstr(28 downto 0) >= to_unsigned(16#1FC20000#, 29) and
               mem_addressInstr(28 downto 0) < to_unsigned(16#1FC30000#, 29) then
               s11_reached_1fc2 <= '1';
               dbg_boot_pc <= std_logic_vector(resize(mem_addressInstr, 32));  -- stuck-PC locator (I-cache: loop-entry fetch)
            end if;
            -- s11_reached_game: CPU ever fetched early GAME code in physical [0x10000,0x40000)
            -- (MAME reaches 0x80018654 after the handshake timeout — below ram_exec's 0x40000).
            if mem_request = '1' and mem_isData = '0' and
               mem_addressInstr(28 downto 0) >= to_unsigned(16#10000#, 29) and
               mem_addressInstr(28 downto 0) < to_unsigned(16#40000#, 29) then
               s11_reached_game <= '1';
            end if;
            -- GPU FIFO-drain diagnostic: latch if the GPU input FIFO is EVER empty.
            -- If this NEVER lights, the GPU never drains (not clocked / stuck on a cmd) and
            -- GPUSTAT bit28 stays 0 → MIPS hangs at 0xBFC099A8. If it lights, the FIFO drained
            -- at some point (so the hang is a later refill the GPU can't process).
            if fifoIn_empty_sig = '1' then
               gpu_fifo_empty_ever <= '1';
            end if;
            -- build #150: CPU PC sticky latches at the cube CLUT PIO upload site.
            if mem_request = '1' and mem_isData = '0' then
               if mem_addressInstr = x"8003CB20" then
                  h50_pc_cube_loop_seen <= '1';
               end if;
               if mem_addressInstr >= x"8003CB00" and mem_addressInstr < x"8003CB60" then
                  h50_pc_cube_area_seen <= '1';
               end if;
               if mem_addressInstr >= x"80050000" and mem_addressInstr < x"80060000" then
                  h50_game_ram_exec_seen <= '1';
               end if;
            end if;
            -- build #151+#152: CPU GP0 PIO write sticky latches.
            -- B151: word 0 (0x7FFF0000) was DARK → entries 0+1 not written together.
            -- B152: now also check words 1-3 to see whether ANY cube CLUT data is
            -- being written, or if the staging buffer is fully corrupted.
            if bus_gpu_write = '1' and bus_gpu_addr = "0000" then
               -- B151 detectors (kept for cross-reference at next read)
               if bus_gpu_dataWrite = x"7FFF0000" then
                  h51_gp0_cubeclut_seen <= '1';
               end if;
               if bus_gpu_dataWrite(31 downto 24) = x"A0" then
                  h51_gp0_a0cmd_seen <= '1';
               end if;
               if bus_gpu_dataWrite(20 downto 16) = "11111" then
                  h51_gp0_r31_seen <= '1';
               end if;
               -- B152 cube CLUT data words 1-3 (ground truth from rp00.u0216 0x3B61CC)
               if bus_gpu_dataWrite = x"3FFF023F" then
                  h52_gp0_word1_seen <= '1';
               end if;
               if bus_gpu_dataWrite = x"03FF033F" then
                  h52_gp0_word2_seen <= '1';
               end if;
               if bus_gpu_dataWrite = x"039F02DF" then
                  h52_gp0_word3_seen <= '1';
               end if;
            end if;
            -- build #153: cube CLUT init-step bisect at the CPU↔memory bus.
            -- (Outside the bus_gpu_write gate — these probe mem_addressData directly.)
            if mem_request = '1' and mem_isData = '1' then
               -- data READ from banked ROM at the cube CLUT source word
               if mem_rnw = '1' and mem_addressData = x"1F7B61CC" then
                  h53_rd_cubesrc_seen <= '1';
               end if;
               -- data WRITE at the staging buffer destination (lower 28 bits match
               -- both KSEG0 0x800BED40 and KUSEG 0x000BED40)
               if mem_rnw = '0' and mem_addressData(27 downto 0) = x"00BED40" then
                  h53_wr_staging_seen <= '1';
               end if;
            end if;
            -- mem_dataRead delivers 0x7FFF0000 on any completed data read
            -- (catches the cube CLUT first word arriving at the CPU from any source).
            if mem_done = '1' and mem_dataRead = x"7FFF0000" then
               h53_data_7fff0000_seen <= '1';
            end if;
            -- build #154: capture bank register value AT the moment CPU reads 0x1F7B61CC.
            -- Bank 0 + offset 0x7B61CC should map to FPGA SDRAM 0x0FB61CC (rp00 cube CLUT).
            -- If bank != 0 at the moment of the read, CPU reads from the wrong bank ROM region.
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '1'
               and mem_addressData = x"1F7B61CC" then
               if zn_bank_8mb_dbg = "000" then
                  h54_bank0_at_read <= '1';
               elsif zn_bank_8mb_dbg = "001" then
                  h54_bank1_at_read <= '1';
               else
                  h54_bankhi_at_read <= '1';
               end if;
            end if;
            -- io_ever_seen: any access to ZN I/O space
            if bus_znio_read = '1' or bus_znio_write = '1' then
               io_ever_seen <= '1';
            end if;
            -- DIAG: count distinct EEPROM write transactions (rising edge of bus_znio_write in
            -- the 0x30000-0x30FFF range). Saturates at 2047.
            znio_wr_prev <= bus_znio_write;
            if bus_znio_write = '1' and znio_wr_prev = '0'
               and std_logic_vector(bus_znio_addr(20 downto 12)) = "000110000" then
               if eeprom_wr_count /= to_unsigned(2047, 11) then
                  eeprom_wr_count <= eeprom_wr_count + 1;
               end if;
            end if;
            -- spu_ever_seen: any SPU register access (0x1F801C00-0x1F801FFF)
            if bus_spu_read = '1' or bus_spu_write = '1' then
               spu_ever_seen <= '1';
            end if;
            -- cd_ever_seen: any CD-ROM register access (0x1F801800-0x1F80180F)
            if bus_cd_read = '1' or bus_cd_write = '1' then
               cd_ever_seen <= '1';
            end if;
            -- dma_ever_seen: DMA registers written (0x1F801080-0x1F8010FF)
            if bus_dma_write = '1' then
               dma_ever_seen <= '1';
            end if;
            -- dma_gpu_write_seen: DMA ch2 (GPU) wrote a word to GPU (linked-list or block mode)
            if DMA_GPU_writeEna = '1' then
               dma_gpu_write_seen <= '1';
            end if;
            -- dma2_e5_write_seen: DMA ch2 wrote a word with cmd byte 0xE5 (drawing offset)
            if DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"E5" then
               dma2_e5_write_seen <= '1';
            end if;
            -- dma2_prim_seen: DMA ch2 wrote a word whose upper byte is a drawing primitive
            -- (0x20-0x3F polygon, 0x40-0x5F line, 0x60-0x7F rectangle). May false-positive on
            -- parameter words; sufficient for "did any primitive command ever reach the GPU".
            if DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) >= x"20" and DMA_GPU_write(31 downto 24) <= x"7F" then
               dma2_prim_seen <= '1';
            end if;
            -- pio_prim_seen: CPU PIO wrote GP0 (bus_gpu_addr=0) with upper byte 0x20-0x7F
            -- (any drawing primitive). Same false-positive caveat as dma2_prim_seen.
            if bus_gpu_write = '1' and bus_gpu_addr = "0000" and
               bus_gpu_dataWrite(31 downto 24) >= x"20" and bus_gpu_dataWrite(31 downto 24) <= x"7F" then
               pio_prim_seen <= '1';
            end if;
            -- build #19: cmd_64_seen — any GP0 write (DMA2 or PIO) with upper byte 0x64
            -- (lpadv's dominant primitive — variable-size textured opaque rect). False-positive caveat:
            -- a parameter word with bits 31:24 == 0x64 will also light this bar.
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"64") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"64") then
               cmd_64_seen_ever <= '1';
            end if;
            -- build #19: cmd_2C_seen — any GP0 write with upper byte 0x2C (textured 4-vertex poly)
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"2C") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"2C") then
               cmd_2C_seen_ever <= '1';
            end if;
            -- build #20: cmd_A0_seen — any GP0 write with upper byte 0xA0 (CPU2VRAM dispatch).
            -- False-positive caveat as with the 0x64/0x2C detectors: a parameter word whose
            -- upper byte happens to be 0xA0 will also light this. Sufficient to answer
            -- "did the game ever try to upload a texture via CPU2VRAM?"
            if (DMA_GPU_writeEna = '1' and DMA_GPU_write(31 downto 24) = x"A0") or
               (bus_gpu_write = '1' and bus_gpu_addr = "0000" and bus_gpu_dataWrite(31 downto 24) = x"A0") then
               cmd_A0_seen_ever <= '1';
            end if;
            -- build #44: DECISIVE cube-palette color probe. Banking + MRA ROM layout were proven
            -- correct vs MAME (byte-for-byte), so the upstream ROM->SDRAM->banked-read path is clean.
            -- The classification now happens in gpu.vhd gated on the cube CLUT's UNIQUE VRAM
            -- destination (X<256, Y=488 = MAME's exact cube-CLUT upload), removing the value/address
            -- ambiguity that contaminated builds #40-43. Here we just sticky-latch those results
            -- (gpu.vhd runs in clk2x; re-latch into the clk1x bar domain):
            -- build #47: TIGHT-window banked-ROM palette-read classifier (memorymux).
            --   [4] WHITE cubeclut_ronly_seen = dbg_palrd_any        (a read in the GREEN-row window [0x..4800,0x..4A00) completed = anchor)
            --   [1] GREEN loclut_gb_seen      = dbg_palrd_green      (green-row read returns GREEN -> read-path CLEAN, bug downstream: CPU-store/DMA)
            --   [3] YELLOW cubeclut_gb_seen   = dbg_palrd_red        (green-row read returns RED -> SMOKING GUN: read-path/SDRAM corrupts)
            --   [2] BLUE  textPalX_hi_seen    = dbg_palrd_redrow_red (CONTROL: red row [0x..5000,0x..5200) reads RED -> instrument distinguishes rows; expect lit)
            if dbg_palrd_any        = '1' then cubeclut_ronly_seen <= '1'; end if;
            if dbg_palrd_green      = '1' then loclut_gb_seen      <= '1'; end if;
            if dbg_palrd_red        = '1' then cubeclut_gb_seen    <= '1'; end if;
            if dbg_palrd_redrow_red = '1' then textPalX_hi_seen    <= '1'; end if;
            -- [0] RED sanity: any cpu2vram 0xA0 upload ever dispatched (confirms uploads occur)
            if cmd_A0_seen_ever = '1' then cpu2vram_parsed_dstX_hi_seen <= '1'; end if;
            -- build #22: cpu2vram ever wrote non-navy non-zero pixel data
            -- (dbg_cpu2vram_color_nonnavy already filters pixelColor /= 0x4000 and /= 0x0000)
            if dbg_cpu2vram_color_nonnavy = '1' then
               cpu2vram_color_nonnavy_seen <= '1';
            end if;
            -- build #23: G/B channel-bit detection
            if dbg_pipeline_g_set = '1' then
               pixelcolor_g_seen <= '1';
            end if;
            if dbg_pipeline_b_set = '1' then
               pixelcolor_b_seen <= '1';
            end if;
            if dbg_vram_din_gb = '1' then
               vram_din_gb_seen <= '1';
            end if;
            if dbg_cpu2vram_color_gb = '1' then
               texpal_gb_seen <= '1';  -- reusing the name; actually "cpu2vram color had G/B"
            end if;
            -- raster_pixel_seen: GPU rasterizer produced at least one pixel write to VRAM
            -- (does not include fast-fill or CPU->VRAM transfers — purely the primitive pipeline)
            if dbg_pipeline_pixelWrite = '1' then
               raster_pixel_seen <= '1';
            end if;
            -- raster_pixel_top_seen: rasterizer pixel write where Y < 256 (top half of VRAM)
            -- If raster_pixel_seen is bright but this stays dark, pixels are landing in Y >= 256 (off-screen).
            if dbg_pipeline_write_in_top = '1' then
               raster_pixel_top_seen <= '1';
            end if;
            -- vram_actual_write_seen: vram_WE actually asserted toward DDR3.
            -- If raster_pixel_seen is bright but this stays dark, pixel writes are killed
            -- between pipeline output and DDR3 (FIFO drop / stall / arbitration loss).
            if dbg_vram_WE_tap = '1' then
               vram_actual_write_seen <= '1';
            end if;
            -- pipeline_color_varied_seen: rasterizer produced any non-navy color
            if dbg_pipeline_color_varied = '1' then
               pipeline_color_varied_seen <= '1';
            end if;
            -- vram_din_non_navy_seen: vram_DIN contained non-navy data during a write
            if dbg_vram_din_non_navy = '1' then
               vram_din_non_navy_seen <= '1';
            end if;
            -- vram_dout_nonnavy_seen: DDR3 returned non-navy data on a GPU read (sticky — kept for reference)
            if dbg_vram_dout_nonnavy = '1' then
               vram_dout_nonnavy_seen <= '1';
            end if;
            if dbg_videoout_linebuf_nonnavy = '1' then
               videoout_linebuf_nonnavy_seen <= '1';
            end if;
            if dbg_videoout_pixeldata_nonnavy = '1' then
               videoout_pixeldata_nonnavy_seen <= '1';
            end if;
            -- Frame-windowed latches (build #7).
            vblank_d <= irq_VBLANK;
            if irq_VBLANK = '1' and vblank_d = '0' then
               -- build #65: per-frame counts — latch and reset all three
               disp_cnt_stage4  <= cnt_stage4;
               disp_cnt_pxwr    <= cnt_pxwr;
               disp_cnt_texraw  <= cnt_texraw;
               cnt_stage4       <= (others => '0');
               cnt_pxwr         <= (others => '0');
               cnt_texraw       <= (others => '0');
               disp_ram_exec              <= frame_ram_exec;
               disp_clut_write_nonnavy    <= frame_clut_write_nonnavy;
               disp_clut_read_nonnavy     <= frame_clut_read_nonnavy;
               disp_stage4_texture        <= frame_stage4_texture;
               disp_pipeline_color_varied <= frame_pipeline_color_varied;
               disp_pixeldata_nonnavy     <= frame_pixeldata_nonnavy;
               disp_pipeline_write_any    <= frame_pipeline_write_any;
               -- restart accumulators with this cycle's events
               frame_ram_exec              <= evt_ram_exec;
               frame_clut_write_nonnavy    <= dbg_clut_write_nonnavy;
               frame_clut_read_nonnavy     <= dbg_clut_read_nonnavy;
               frame_stage4_texture        <= dbg_stage4_texture;
               frame_pipeline_color_varied <= dbg_pipeline_color_varied;
               frame_pixeldata_nonnavy     <= dbg_videoout_pixeldata_nonnavy;
               frame_pipeline_write_any    <= dbg_pipeline_pixelWrite;
               -- build #8: per-frame transfer for textPalNew/Req/REQ_PAL/CLUTwrenA
               disp_b8_textPalNew          <= frame_b8_textPalNew;
               disp_b8_textPalReq_set      <= frame_b8_textPalReq_set;
               disp_b8_state_REQ_PAL       <= frame_b8_state_REQ_PAL;
               disp_b8_CLUTwrenA_any       <= frame_b8_CLUTwrenA_any;
               frame_b8_textPalNew         <= dbg_textPalNew;
               frame_b8_textPalReq_set     <= dbg_textPalReq_set;
               frame_b8_state_REQ_PAL      <= dbg_state_REQ_PAL;
               frame_b8_CLUTwrenA_any     <= dbg_CLUTwrenA_any;
               -- build #24: textured-rect drawMode tracking, frame-windowed.
               -- disp_* carries the PREVIOUS frame's state; frame_* accumulates the new frame.
               disp_rect_tex_4bit          <= frame_rect_tex_4bit;
               disp_rect_tex_8bit          <= frame_rect_tex_8bit;
               disp_rect_tex_15bit         <= frame_rect_tex_15bit;
               disp_rect_tex_pixel_gb      <= frame_rect_tex_pixel_gb;
               frame_rect_tex_4bit         <= dbg_rect_tex_4bit;
               frame_rect_tex_8bit         <= dbg_rect_tex_8bit;
               frame_rect_tex_15bit        <= dbg_rect_tex_15bit;
               frame_rect_tex_pixel_gb     <= dbg_rect_tex_pixel_gb;
            else
               -- build #56: per-frame stage4 textured pixel count (saturating at 18-bit max)
               if dbg_stage4_texture = '1' and cnt_stage4 < to_unsigned(262143, 18) then
                  cnt_stage4 <= cnt_stage4 + 1;
               end if;
               -- build #65: GREEN = PER-FRAME count of CLUT-RAM real-data writes targeting Y in [460,500)
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '1'
                  and cnt_pxwr < to_unsigned(262143, 18) then
                  cnt_pxwr <= cnt_pxwr + 1;
               end if;
               -- build #65: BLUE = PER-FRAME count of CLUT-RAM real-data writes targeting Y < 460 (low-Y, e.g., BIOS text)
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '0'
                  and cnt_texraw < to_unsigned(262143, 18) then
                  cnt_texraw <= cnt_texraw + 1;
               end if;
               if evt_ram_exec = '1' then frame_ram_exec <= '1'; end if;
               -- build #63: sticky latches for CLUT-RAM ever receiving real data, by Y range of textPalReqY
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '1' then
                  clut_real_data_hi_y_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_clut = '0' then
                  clut_real_data_lo_y_seen <= '1';
               end if;
               -- build #68: split sticky latches at Y=480 boundary
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_lo = '1' then
                  clut_succ_lo_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' and dbg_textPalReqY_hi = '1' then
                  clut_succ_hi_seen <= '1';
               end if;
               if dbg_clut_write_nonnavy = '1' then frame_clut_write_nonnavy <= '1'; end if;
               if dbg_clut_read_nonnavy = '1' then frame_clut_read_nonnavy <= '1'; end if;
               if dbg_stage4_texture = '1' then frame_stage4_texture <= '1'; end if;
               if dbg_pipeline_color_varied = '1' then frame_pipeline_color_varied <= '1'; end if;
               if dbg_videoout_pixeldata_nonnavy = '1' then frame_pixeldata_nonnavy <= '1'; end if;
               if dbg_pipeline_pixelWrite = '1' then frame_pipeline_write_any <= '1'; end if;
               -- build #8 frame accumulators
               if dbg_textPalNew = '1' then frame_b8_textPalNew <= '1'; end if;
               if dbg_textPalReq_set = '1' then frame_b8_textPalReq_set <= '1'; end if;
               if dbg_state_REQ_PAL = '1' then frame_b8_state_REQ_PAL <= '1'; end if;
               if dbg_CLUTwrenA_any = '1' then frame_b8_CLUTwrenA_any <= '1'; end if;
               -- build #24 frame accumulators (within-frame)
               if dbg_rect_tex_4bit = '1' then frame_rect_tex_4bit <= '1'; end if;
               if dbg_rect_tex_8bit = '1' then frame_rect_tex_8bit <= '1'; end if;
               if dbg_rect_tex_15bit = '1' then frame_rect_tex_15bit <= '1'; end if;
               if dbg_rect_tex_pixel_gb = '1' then frame_rect_tex_pixel_gb <= '1'; end if;
            end if;
            -- build #8 LATCHED-FOREVER confounders (drawMode_8 and noTexture):
            -- these should be 0 in normal operation; latch sticky-on to make any occurrence visible
            if dbg_drawMode_8 = '1' then disp_b8_drawMode_8 <= '1'; end if;
            if dbg_noTexture_pin = '1' then disp_b8_noTexture_pin <= '1'; end if;
            -- build #10 LATCHED-FOREVER VRAM data taps
            if dbg_vram_dout_nonnavy = '1' then disp_vram_dout_nonnavy_b10 <= '1'; end if;
            if dbg_vram_din_non_navy = '1' then disp_vram_din_nonnavy_b10 <= '1'; end if;
            -- build #11 LATCHED-FOREVER CPU2VRAM taps
            if dbg_cpu2vram_pixelWrite = '1' then disp_cpu2vram_active_ever <= '1'; end if;
            if dbg_cpu2vram_color_nonnavy = '1' then disp_cpu2vram_nonnavy_ever <= '1'; end if;
            -- build #12 LATCHED-FOREVER readback chain
            if dbg_clut_write_nonnavy = '1' then disp_clut_write_nv_ever <= '1'; end if;
            if dbg_clut_read_nonnavy = '1' then disp_clut_read_nv_ever <= '1'; end if;
            if dbg_pipeline_color_varied = '1' then disp_pipeline_color_var_ever <= '1'; end if;
            if dbg_videoout_pixeldata_nonnavy = '1' then disp_pixeldata_nv_ever <= '1'; end if;
            if dbg_pipeline_pixelWrite = '1' then disp_pipeline_pxwr_ever <= '1'; end if;
            -- build #13 CLUT addressing latches
            if dbg_textPalReqX_nz = '1' then disp_clut_X_nz_ever <= '1'; end if;
            if dbg_textPalReqY_nz = '1' then disp_clut_Y_nz_ever <= '1'; end if;
            if dbg_cpu2vram_dstY_bit8 = '1' then disp_cpu2vram_dstY_bit8_ever <= '1'; end if;
            if dbg_cpu2vram_dstY_nz = '1' then disp_cpu2vram_dstY_nz_ever <= '1'; end if;
            -- build #14 CPU2VRAM destination X
            if dbg_cpu2vram_dstX_zero = '1' then disp_cpu2vram_dstX_zero_ever <= '1'; end if;
            if dbg_cpu2vram_dstX_nz = '1' then disp_cpu2vram_dstX_nz_ever <= '1'; end if;
            -- build #15 ANY write at X=0
            if dbg_vram_we_x_zero = '1' then disp_vram_we_x_zero_ever <= '1'; end if;
            if dbg_vram_we_x_zero_nv = '1' then disp_vram_we_x_zero_nv_ever <= '1'; end if;
            if dbg_vram2vram_active = '1' then disp_vram2vram_active_ever <= '1'; end if;
            if dbg_vramFill_active = '1' then disp_vramFill_active_ever <= '1'; end if;
            -- build #17 Y-wrap verification
            if dbg_pixelAddr_Y_hi = '1' then disp_pixelAddr_Y_hi_ever <= '1'; end if;
            if dbg_cpu2vram_Y_hi = '1' then disp_cpu2vram_Y_hi_ever <= '1'; end if;
            if dbg_vram_addr_Y_hi_we = '1' then disp_vram_addr_Y_hi_we_ever <= '1'; end if;
            if dbg_vram_addr_Y_hi_rd = '1' then disp_vram_addr_Y_hi_rd_ever <= '1'; end if;
            -- dma_gpu_waiting_seen: DMA ch2 was blocked waiting for GPU (hangs here if GPU stalls)
            if DMA_GPU_waiting = '1' then
               dma_gpu_waiting_seen <= '1';
            end if;
            -- irq_dma_seen: DMA IRQ fired = DMA completed at least one transfer
            if irq_DMA = '1' then
               irq_dma_seen <= '1';
            end if;
            -- dma_spu_write_seen: DMA ch4 (SPU) wrote data to SPU RAM
            if DMA_SPU_writeEna = '1' then
               dma_spu_write_seen <= '1';
            end if;
            -- irq_stat_read_seen: CPU read the IRQ status register (I_STAT at 0x1F801070)
            if bus_irq_read = '1' then
               irq_stat_read_seen <= '1';
            end if;
            -- irq_stat_write_seen: CPU wrote to I_STAT or I_MASK (interrupt acknowledge)
            -- DARK → game reads I_STAT but never writes back → not doing proper IRQ acknowledge
            -- BRIGHT → game attempts IRQ acknowledge (write); irqRequest still bright = something re-fires
            if bus_irq_write = '1' then
               irq_stat_write_seen <= '1';
            end if;
            -- irq_cdrom_seen: CD-ROM module generated an interrupt
            -- BRIGHT → CD-ROM generating IRQs (spurious INT5 without disc = likely persistent irqRequest source)
            if irq_CDROM = '1' then
               irq_cdrom_seen <= '1';
            end if;
            -- irqreq_seen: irqRequest ever asserted to the CPU (the OR of all enabled IRQ sources)
            if irqRequest = '1' then
               irqreq_seen <= '1';
            end if;
            -- imask0_write_seen: CPU enabled the VBLANK interrupt mask (I_MASK[0]<=1 via 0x1F801074)
            if bus_irq_write = '1' and bus_irq_addr = 4 and bus_irq_dataWrite(0) = '1' then
               imask0_write_seen <= '1';
            end if;
            -- istat_ack_seen: CPU wrote I_STAT (0x1F801070) = acknowledges/services an IRQ
            if bus_irq_write = '1' and bus_irq_addr = 0 then
               istat_ack_seen <= '1';
            end if;
            -- irq_timer_seen: any timer (0/1/2) generated an interrupt
            if irq_TIMER0 = '1' or irq_TIMER1 = '1' or irq_TIMER2 = '1' then
               irq_timer_seen <= '1';
            end if;
            -- vblank_irq_seen: VBLANK IRQ source fired (feeds into I_STAT[0])
            if irq_VBLANK = '1' then
               vblank_irq_seen <= '1';
            end if;
            -- ZN security debug: latch security check initiations and any SIO byte
            if zn_beginTransfer = '1' then
               zn_sio_ever_seen <= '1';
            end if;
            if zn_sec_select = "110" then  -- 0x88: bit2=0→KN01 active-low (check 1)
               zn_check1_seen <= '1';
            end if;
            if zn_sec_select = "101" then  -- 0x84: bit3=0→KN02 active-low (check 2)
               zn_check2_seen <= '1';
            end if;
            -- kn02_rx_nonzero: KN02 replied with a byte that is not 0x00 or 0xFF
            if zn_receive_valid = '1' and zn_sec_select = "101" and
               zn_rxbyte /= x"00" and zn_rxbyte /= x"FF" then
               zn_kn02_rx_nonzero <= '1';
            end if;

            -- build #172: sticky latch — drawingAreaBottom > 239 (game ever drew to front buffer)
            if unsigned(drawingAreaBottom_sig) > to_unsigned(239, 10) then
               b172_drawArea_high_ever <= '1';
            end if;
            -- build #172: sticky latch — drawingOffsetY >= 240 (treating as signed; check positive)
            -- drawingOffsetY is signed(10:0); if MSB=0 (positive) and value >= 240
            if drawingOffsetY_sig(10) = '0' and unsigned(drawingOffsetY_sig(9 downto 0)) >= to_unsigned(240, 10) then
               b172_drawOffset_high_ever <= '1';
            end if;

            -- build #163: per-window throughput counters
            -- Window timer: 2^27 clk1x cycles ≈ 3.96s at 33.8688 MHz
            b163_win_cnt <= b163_win_cnt + 1;
            if b163_win_cnt = to_unsigned(16#7FFFFFF#, 27) then
               -- end of window: latch counts to display regs, reset counters
               b163_dma2_disp <= std_logic_vector(b163_dma2_cnt);
               b163_dma4_disp <= std_logic_vector(b163_dma4_cnt);
               b163_bank_disp <= std_logic_vector(b163_bank_cnt);
               b163_dma2_cnt  <= (others => '0');
               b163_dma4_cnt  <= (others => '0');
               b163_bank_cnt  <= (others => '0');
            else
               -- build #171: writes to Taito frame counter at RAM[0x000D8DD0]
               if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
                  and mem_addressData(28 downto 0) = to_unsigned(16#000D8DD0#, 29)
                  and b163_DMA_GPU_writeEna_d = '0' and b163_dma2_cnt /= "111111111" then
                  b163_dma2_cnt <= b163_dma2_cnt + 1;
               end if;
               -- build #171: writes to wait_vsync flag 0x000C6D0 (baseline known-good)
               if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
                  and mem_addressData(28 downto 0) = to_unsigned(16#0008C6D0#, 29)
                  and b163_DMA_SPU_writeEna_d = '0' and b163_dma4_cnt /= "111111111" then
                  b163_dma4_cnt <= b163_dma4_cnt + 1;
               end if;
               -- (BLUE bar driven by b157_anchor_sig directly via triage_blue_fan)
            end if;
            -- Edge-detect delay lines
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
               and mem_addressData(28 downto 0) = to_unsigned(16#000D8DD0#, 29) then
               b163_DMA_GPU_writeEna_d <= '1';
            else
               b163_DMA_GPU_writeEna_d <= '0';
            end if;
            if mem_request = '1' and mem_isData = '1' and mem_rnw = '0'
               and mem_addressData(28 downto 0) = to_unsigned(16#0008C6D0#, 29) then
               b163_DMA_SPU_writeEna_d <= '1';
            else
               b163_DMA_SPU_writeEna_d <= '0';
            end if;

         end if;
      end if;
   end process;

   imemorymux : entity work.memorymux
   port map
   (
      clk1x                => clk1x,
      clk2x                => clk2x,
      ce                   => ce,   
      reset                => reset_intern,
      
      pauseNext            => cpuPaused or (dmaRequest and canDMA),
      isIdle               => memMuxIdle,
         
      loadExe              => loadExe,
      exe_initial_pc       => exe_initial_pc,  
      exe_initial_gp       => exe_initial_gp,  
      exe_load_address     => exe_load_address,
      exe_file_size        => exe_file_size,   
      exe_stackpointer     => exe_stackpointer,
      reset_exe            => reset_exe,
      
      fastboot             => fastboot,
      TURBO                => TURBO_MEM,
      region_in            => biosregion,
      PATCHSERIAL          => PATCHSERIAL,
            
      ram_dataWrite        => ram_cpu_dataWrite,
      ram_dataRead         => ram_dataRead32,  
      ram_Adr              => ram_cpu_Adr,  
      ram_be               => ram_cpu_be,        
      ram_rnw              => ram_cpu_rnw,      
      ram_ena              => ram_cpu_ena,   
      ram_cache            => ram_cpu_cache,      
      ram_done             => ram_cpu_done,
      
      mem_in_request       => mem_request,  
      mem_in_rnw           => mem_rnw,      
      mem_in_isData        => mem_isData,      
      mem_in_isCache       => mem_isCache,      
      mem_in_oldtagvalids  => mem_oldtagvalids,  
      mem_in_addressInstr  => mem_addressInstr,  
      mem_in_addressData   => mem_addressData,  
      mem_in_reqsize       => mem_reqsize,  
      mem_in_writeMask     => mem_writeMask,
      mem_in_dataWrite     => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_done             => mem_done,
      mem_fifofull         => mem_fifofull,  
      mem_tagvalids        => mem_tagvalids,

      bios_memctrl         => bios_memctrl,

      ex1_memctrl          => ex1_memctrl,
      --bus_exp1_addr        => bus_exp1_addr,   
      --bus_exp1_dataWrite   => bus_exp1_dataWrite,
      bus_exp1_read        => bus_exp1_read,   
      --bus_exp1_write       => bus_exp1_write,  
      bus_exp1_dataRead    => bus_exp1_dataRead,
      
      bus_memc_addr        => bus_memc_addr,     
      bus_memc_dataWrite   => bus_memc_dataWrite,
      bus_memc_read        => bus_memc_read,     
      bus_memc_write       => bus_memc_write,    
      bus_memc_dataRead    => bus_memc_dataRead,   
      
      bus_pad_addr         => bus_pad_addr,     
      bus_pad_dataWrite    => bus_pad_dataWrite,
      bus_pad_read         => bus_pad_read,     
      bus_pad_write        => bus_pad_write,    
      bus_pad_writeMask    => bus_pad_writeMask,
      bus_pad_dataRead     => bus_pad_dataRead,       
      
      bus_sio_addr         => bus_sio_addr,     
      bus_sio_dataWrite    => bus_sio_dataWrite,
      bus_sio_read         => bus_sio_read,     
      bus_sio_write        => bus_sio_write,    
      bus_sio_writeMask    => bus_sio_writeMask,
      bus_sio_dataRead     => bus_sio_dataRead, 

      bus_memc2_addr       => bus_memc2_addr,     
      bus_memc2_dataWrite  => bus_memc2_dataWrite,
      bus_memc2_read       => bus_memc2_read,     
      bus_memc2_write      => bus_memc2_write,    
      bus_memc2_dataRead   => bus_memc2_dataRead, 

      bus_irq_addr         => bus_irq_addr,     
      bus_irq_dataWrite    => bus_irq_dataWrite,
      bus_irq_read         => bus_irq_read,     
      bus_irq_write        => bus_irq_write,    
      bus_irq_dataRead     => bus_irq_dataRead,       
      
      bus_dma_addr         => bus_dma_addr,     
      bus_dma_dataWrite    => bus_dma_dataWrite,
      bus_dma_read         => bus_dma_read,     
      bus_dma_write        => bus_dma_write,    
      bus_dma_dataRead     => bus_dma_dataRead,     

      bus_tmr_addr         => bus_tmr_addr,     
      bus_tmr_dataWrite    => bus_tmr_dataWrite,
      bus_tmr_read         => bus_tmr_read,     
      bus_tmr_write        => bus_tmr_write,    
      bus_tmr_dataRead     => bus_tmr_dataRead,  

      cd_memctrl           => cd_memctrl,
      bus_cd_addr          => bus_cd_addr,     
      bus_cd_dataWrite     => bus_cd_dataWrite,
      bus_cd_read          => bus_cd_read,     
      bus_cd_write         => bus_cd_write,    
      bus_cd_dataRead      => bus_cd_dataRead,      
      
      bus_gpu_addr         => bus_gpu_addr,     
      bus_gpu_dataWrite    => bus_gpu_dataWrite,
      bus_gpu_read         => bus_gpu_read,     
      bus_gpu_write        => bus_gpu_write,    
      bus_gpu_dataRead     => bus_gpu_dataRead,
      bus_gpu_stall        => bus_gpu_stall,
      
      bus_mdec_addr        => bus_mdec_addr,
      bus_mdec_dataWrite   => bus_mdec_dataWrite,
      bus_mdec_read        => bus_mdec_read,
      bus_mdec_write       => bus_mdec_write,
      bus_mdec_dataRead    => bus_mdec_dataRead,

      bus_znio_addr        => bus_znio_addr,
      bus_znio_dataWrite   => bus_znio_dataWrite,
      bus_znio_read        => bus_znio_read,
      bus_znio_write       => bus_znio_write,
      bus_znio_writeMask   => bus_znio_writeMask,
      bus_znio_dataRead    => bus_znio_dataRead,

      zn_platform          => zn_platform,
      zn_system11          => zn_system11,
      s11_bank             => zn_s11_bank,
      s11_up               => zn_s11_up,

      spu_memctrl          => spu_memctrl,
      bus_spu_addr         => bus_spu_addr,     
      bus_spu_dataWrite    => bus_spu_dataWrite,
      bus_spu_read         => bus_spu_read,     
      bus_spu_write        => bus_spu_write,    
      bus_spu_dataRead     => bus_spu_dataRead, 
      
      ex2_memctrl          => ex2_memctrl,
      bus_exp2_addr        => bus_exp2_addr,     
      bus_exp2_dataWrite   => bus_exp2_dataWrite,
      bus_exp2_read        => bus_exp2_read,     
      bus_exp2_write       => bus_exp2_write,    
      bus_exp2_dataRead    => bus_exp2_dataRead,
      
      ex3_memctrl          => ex3_memctrl,
      --bus_exp3_dataWrite   => bus_exp3_dataWrite,
      bus_exp3_read        => bus_exp3_read,     
      --bus_exp3_write       => bus_exp3_write,    
      bus_exp3_dataRead    => bus_exp3_dataRead, 
      
      com0_delay           => com0_delay,
      com1_delay           => com1_delay,
      com2_delay           => com2_delay,
      com3_delay           => com3_delay,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(18 downto 0),
      SS_wren_SDRam        => SS_wren(16),
      SS_rden_SDRam        => SS_rden(16),
      zn_bank_8mb_out      => zn_bank_8mb_dbg, -- build #39
      dbg_palrd_green      => dbg_palrd_green,  -- build #47
      dbg_palrd_red        => dbg_palrd_red,    -- build #47
      dbg_palrd_any        => dbg_palrd_any,    -- build #47
      dbg_palrd_redrow_red => dbg_palrd_redrow_red, -- build #47
      dbg_palrd_value      => dbg_palrd_value,      -- build #50
      dbg_palrd_addr       => dbg_palrd_addr,       -- build #51
      dbg_palrd_words      => dbg_palrd_words,        -- build #52
      dbg_cubeclut_window_seen => dbg_cubeclut_window_seen,  -- build #135
      dbg_cubeclut_exact_seen  => dbg_cubeclut_exact_seen,   -- build #135
      dbg_cubeclut_bank0_seen  => dbg_cubeclut_bank0_seen    -- build #135
   );

   icpu : entity work.cpu
   port map
   (
      dbg_pcOld1           => zn_dbg_mipspc,
      dbg_stall            => dbg_cpu_stall,
      clk1x             => clk1x,
      clk2x             => clk2x,
      clk3x             => clk3x,
      ce                => ce,   
      reset             => reset_intern,
      
      TURBO             => TURBO_COMP,
      TURBO_CACHE       => TURBO_CACHE,
      TURBO_CACHE50     => TURBO_CACHE50,
         
      irqRequest        => irqRequest,
      dmaStallCPU       => dmaStallCPU,
      cpuPaused         => cpuPaused,
      
      error             => errorCPU,
      error2            => errorCPU2,
         
      mem_request       => mem_request,  
      mem_rnw           => mem_rnw,      
      mem_isData        => mem_isData,      
      mem_isCache       => mem_isCache, 
      mem_oldtagvalids  => mem_oldtagvalids,      
      mem_addressInstr  => mem_addressInstr,  
      mem_addressData   => mem_addressData,  
      mem_reqsize       => mem_reqsize,  
      mem_writeMask     => mem_writeMask,
      mem_dataWrite     => mem_dataWrite,
      mem_dataRead      => mem_dataRead, 
      mem_done          => mem_done,
      mem_fifofull      => mem_fifofull,
      mem_tagvalids     => mem_tagvalids,
      
      cache_wr          => cache_wr,  
      cache_data        => cache_data,
      cache_addr        => cache_addr,
      
      stallNext         => stallNext,
      
      dma_cache_Adr     => dma_cache_Adr,  
      dma_cache_data    => dma_cache_data, 
      dma_cache_write   => dma_cache_write,  
      
      ram_dataRead      => ram_dataRead32,    
      ram_rnw           => ram_cpu_rnw,
      ram_done          => ram_cpu_done,
      
      gte_busy          => gte_busy, 
      gte_readEna       => gte_readEna,
      gte_readAddr      => gte_readAddr, 
      gte_readData      => gte_readData, 
      gte_writeAddr     => gte_writeAddr,
      gte_writeData     => gte_writeData,
      gte_writeEna      => gte_writeEna, 
      gte_cmdData       => gte_cmdData,  
      gte_cmdEna        => gte_cmdEna, 

      SS_reset          => SS_reset,
      SS_DataWrite      => SS_DataWrite,
      SS_Adr            => SS_Adr(7 downto 0),   
      SS_wren_CPU       => SS_wren(0),     
      SS_wren_SCP       => SS_wren(12),  
      SS_rden_CPU       => SS_rden(0),     
      SS_rden_SCP       => SS_rden(12),        
      SS_DataRead_CPU   => SS_DataRead_CPU,
      SS_DataRead_SCP   => SS_DataRead_SCP,
      SS_idle           => SS_idle_cpu,
      
-- synthesis translate_off
      cpu_done          => cpu_done,  
      cpu_export        => cpu_export,
-- synthesis translate_on
      
      debug_firstGTE    => debug_firstGTE,
      dbg_exc_epc       => cpu_dbg_exc_epc,
      dbg_exc_code      => cpu_dbg_exc_code,
      dbg_fault_a1      => cpu_dbg_fault_a1,
      dbg_fault_ra      => cpu_dbg_fault_ra,
      dbg_fault_addr    => cpu_dbg_fault_addr,
      dbg_fault_s1s2    => cpu_dbg_fault_s1s2,
      dbg_fault_sp      => cpu_dbg_fault_sp,
      dbg_wrcap_pc      => cpu_dbg_wrcap_pc,
      dbg_wrcap_data    => cpu_dbg_wrcap_data,
      dbg_instr_word    => cpu_dbg_instr_word,
      dbg_reg_v0        => cpu_dbg_a0r,
      dbg_reg_a0        => cpu_dbg_t0,
      dbg_reg_s2        => cpu_dbg_a3,
      trace_flat        => trace_flat,
      trace_meta        => trace_meta
   );

   igte : entity work.gte
   port map
   (
      clk1x                => clk1x,     
      clk2x                => clk2x,     
      clk2xIndex           => clk2xIndex,
      ce                   => ce,        
      reset                => reset_intern,     
      
      WIDESCREEN           => WIDESCREEN,
      TURBO                => TURBO_COMP,
      
      gte_busy             => gte_busy,     
      gte_readAddr         => gte_readAddr, 
      gte_readData         => gte_readData, 
      gte_readEna          => gte_readEna,
      gte_writeAddr_in     => gte_writeAddr,
      gte_writeData_in     => gte_writeData,
      gte_writeEna_in      => gte_writeEna, 
      gte_cmdData          => gte_cmdData,  
      gte_cmdEna           => gte_cmdEna,
      
      loading_savestate    => loading_savestate,
      SS_reset             => SS_reset,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(5 downto 0),
      SS_wren              => SS_wren(4),     
      SS_rden              => SS_rden(4),     
      SS_DataRead          => SS_DataRead_GTE,
      SS_idle              => SS_idle_gte,
      
      debug_firstGTE       => debug_firstGTE
   );
   
   ddr3_BURSTCNT <= ss_ram_BURSTCNT     when (ddr3_savestate = '1') else arbiter_BURSTCNT when (arbiter_active = '1') else  vram_BURSTCNT;  
   ddr3_ADDR     <= ss_ram_ADDR & "00"  when (ddr3_savestate = '1') else arbiter_ADDR     when (arbiter_active = '1') else  vram_ADDR;      
   ddr3_DIN      <= ss_ram_DIN          when (ddr3_savestate = '1') else arbiter_DIN      when (arbiter_active = '1') else  vram_DIN;       
   ddr3_BE       <= ss_ram_BE           when (ddr3_savestate = '1') else arbiter_BE       when (arbiter_active = '1') else  vram_BE;        
   ddr3_WE       <= ss_ram_WE           when (ddr3_savestate = '1') else arbiter_WE       when (arbiter_active = '1') else  vram_WE;        
   ddr3_RD       <= ss_ram_RD           when (ddr3_savestate = '1') else arbiter_RD       when (arbiter_active = '1') else  vram_RD;        
   
   -- build #141: ZN-1 arcade — memcard1/memcard2 instances removed.
   -- Arcade has no memory cards; PSX-console memcard logic was a candidate for SIO0
   -- bus contention with CAT702 reuse of the same SIO0 path (zn_sio module bridges
   -- joypad SNAC pins to CAT702). All memcard outputs stubbed to inert values so
   -- entity ports, pause arbitration, and DDR3 arbitration still get safe inputs.

   memcard_changed <= '0';
   saving_memcard  <= '0';

   -- pause-arbitration inputs (no memcard activity)
   memcard1_pause           <= '0';
   memcard2_pause           <= '0';
   MemCard_changePending1   <= '0';
   MemCard_changePending2   <= '0';
   MemCard_saving_memcard1  <= '0';
   MemCard_saving_memcard2  <= '0';

   -- entity-port outputs to sys layer (memcards never read/write)
   memcard1_rd      <= '0';
   memcard1_wr      <= '0';
   memcard1_lba     <= (others => '0');
   memcard1_dataOut <= (others => '0');
   memcard2_rd      <= '0';
   memcard2_wr      <= '0';
   memcard2_lba     <= (others => '0');
   memcard2_dataOut <= (others => '0');

   -- DDR3 arbiter inputs from memcards (no DDR3 traffic)
   memHPScard1_request  <= '0';
   memHPScard1_BURSTCNT <= (others => '0');
   memHPScard1_ADDR     <= (others => '0');
   memHPScard1_DIN      <= (others => '0');
   memHPScard1_BE       <= (others => '0');
   memHPScard1_WE       <= '0';
   memHPScard1_RD       <= '0';
   memHPScard2_request  <= '0';
   memHPScard2_BURSTCNT <= (others => '0');
   memHPScard2_ADDR     <= (others => '0');
   memHPScard2_DIN      <= (others => '0');
   memHPScard2_BE       <= (others => '0');
   memHPScard2_WE       <= '0';
   memHPScard2_RD       <= '0';
   
   isavestates : entity work.savestates
   generic map
   (
      FASTSIM                 => is_simu,
      Softmap_SaveState_ADDR  => 58720256
   )
   port map
   (
      clk1x                   => clk1x,
      clk2x                   => clk2x,
      clk2xIndex              => clk2xIndex,
      ce                      => ce,
      reset_in                => reset_in,
      reset_out               => reset_intern,
      ss_reset                => SS_reset,
      
      hps_busy                => hps_busy,
      loadExe                 => loadExe,
           
      load_done               => state_loaded,
      validSStates            => validSStates,
            
      savestate_number        => savestate_number,
      increaseSSHeaderCount   => increaseSSHeaderCount,
      save                    => savestate_savestate,
      load                    => savestate_loadstate,
      savestate_address       => savestate_address,  
      savestate_busy          => savestate_busy,    

      SS_idle                 => SS_idle,
      system_paused           => pausingSS,
      savestate_pause         => savestate_pause,
      ddr3_savestate          => ddr3_savestate,
      
      useSPUSDRAM             => SPUSDRAM,
      
      SS_DataWrite            => SS_DataWrite,   
      SS_Adr                  => SS_Adr,         
      SS_wren                 => SS_wren,       
      SS_rden                 => SS_rden,       
      SS_DataRead_CPU         => SS_DataRead_CPU,
      SS_DataRead_GPU         => SS_DataRead_GPU,
      SS_DataRead_GPUTiming   => SS_DataRead_GPUTiming,
      SS_DataRead_DMA         => SS_DataRead_DMA,
      SS_DataRead_GTE         => SS_DataRead_GTE,
      SS_DataRead_JOYPAD      => SS_DataRead_JOYPAD,
      SS_DataRead_MDEC        => SS_DataRead_MDEC,
      SS_DataRead_MEMORY      => SS_DataRead_MEMORY,
      SS_DataRead_TIMER       => SS_DataRead_TIMER,
      SS_DataRead_SOUND       => SS_DataRead_SOUND,
      SS_DataRead_IRQ         => SS_DataRead_IRQ,
      SS_DataRead_SIO         => SS_DataRead_SIO,
      SS_DataRead_SCP         => SS_DataRead_SCP,
      SS_DataRead_CD          => SS_DataRead_CD,

      sdram_done              => ram_done,
      
      loading_savestate       => loading_savestate,
      saving_savestate        => open,
            
      ddr3_BUSY               => ddr3_BUSY,      
      ddr3_DOUT               => ddr3_DOUT,      
      ddr3_DOUT_READY         => ddr3_DOUT_READY,
      ddr3_BURSTCNT           => ss_ram_BURSTCNT,
      ddr3_ADDR               => ss_ram_ADDR,    
      ddr3_DIN                => ss_ram_DIN,     
      ddr3_BE                 => ss_ram_BE,      
      ddr3_WE                 => ss_ram_WE,      
      ddr3_RD                 => ss_ram_RD,

      ram_done                => ram_cpu_done,   
      ram_data                => ram_dataRead32,
      
      SS_SPURAM_dataWrite     => SS_SPURAM_dataWrite,
      SS_SPURAM_Adr           => SS_SPURAM_Adr,      
      SS_SPURAM_request       => SS_SPURAM_request,  
      SS_SPURAM_rnw           => SS_SPURAM_rnw,      
      SS_SPURAM_dataRead      => SS_SPURAM_dataRead, 
      SS_SPURAM_done          => SS_SPURAM_done     
   );  

   istatemanager : entity work.statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => 58720256,
      Softmap_Rewind_ADDR      => 33554432
   )
   port map
   (
      clk                 => clk2x,  
      ce                  => ce,  
      reset               => reset_in,
                         
      rewind_on           => rewind_on,    
      rewind_active       => rewind_active,
                        
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
                       
      sleep_rewind        => open,
      vsync               => IRQ_VBlank,
      system_idle         => '1',
                 
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy    
   );
   
   -- export
-- synthesis translate_off
   gexport : if is_simu = '1' generate
   begin
   
      new_export <= cpu_done; 
      
      iexport : entity work.export
      port map
      (
         clk               => clk1x,
         ce                => ce,
         reset             => reset_intern,
            
         new_export        => cpu_done,
         export_cpu        => cpu_export,
            
         export_irq        => export_irq,
            
         export_gtm        => export_gtm,
         export_line       => export_line,
         export_gpus       => export_gpus,
         export_gobj       => export_gobj,
         
         export_t_current0 => export_t_current0,
         export_t_current1 => export_t_current1,
         export_t_current2 => export_t_current2,
            
         export_8          => export_8,
         export_16         => export_16,
         export_32         => export_32
      );
   
   
   end generate;
-- synthesis translate_on
   
end architecture;





