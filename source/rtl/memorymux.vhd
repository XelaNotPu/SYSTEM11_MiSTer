library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity memorymux is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      pauseNext            : in  std_logic;
      isIdle               : out std_logic;
      
      loadExe              : in  std_logic;
      exe_initial_pc       : in  unsigned(31 downto 0);
      exe_initial_gp       : in  unsigned(31 downto 0);
      exe_load_address     : in  unsigned(31 downto 0);
      exe_file_size        : in  unsigned(31 downto 0);
      exe_stackpointer     : in  unsigned(31 downto 0);
      reset_exe            : out std_logic := '0';
      
      fastboot             : in  std_logic;
      PATCHSERIAL          : in  std_logic;
      TURBO                : in  std_logic;
      region_in            : in  std_logic_vector(1 downto 0);

      ram_dataWrite        : out std_logic_vector(31 downto 0) := (others => '0');
      ram_dataRead         : in  std_logic_vector(31 downto 0);
      ram_Adr              : out std_logic_vector(26 downto 0) := (others => '0');
      ram_be               : out std_logic_vector(3 downto 0) := (others => '0');
      ram_rnw              : out std_logic := '0';
      ram_ena              : out std_logic := '0';
      ram_cache            : out std_logic := '0';
      ram_done             : in  std_logic;
      
      mem_in_request       : in  std_logic;
      mem_in_rnw           : in  std_logic; 
      mem_in_isData        : in  std_logic; 
      mem_in_isCache       : in  std_logic;
      mem_in_oldtagvalids  : in  std_logic_vector(3 downto 0);      
      mem_in_addressInstr  : in  unsigned(31 downto 0); 
      mem_in_addressData   : in  unsigned(31 downto 0); 
      mem_in_reqsize       : in  unsigned(1 downto 0); 
      mem_in_writeMask     : in  std_logic_vector(3 downto 0); 
      mem_in_dataWrite     : in  std_logic_vector(31 downto 0); 
      mem_dataRead         : out std_logic_vector(31 downto 0); 
      mem_done             : out std_logic;
      mem_fifofull         : out std_logic;
      mem_tagvalids        : out std_logic_vector(3 downto 0);
      
      bios_memctrl         : in  unsigned(13 downto 0);
      
      ex1_memctrl          : in  unsigned(13 downto 0);
      --bus_exp1_addr        : out unsigned(22 downto 0); 
      --bus_exp1_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp1_read        : out std_logic;
      --bus_exp1_write       : out std_logic;
      bus_exp1_dataRead    : in  std_logic_vector(7 downto 0);
      
      bus_memc_addr        : out unsigned(5 downto 0); 
      bus_memc_dataWrite   : out std_logic_vector(31 downto 0);
      bus_memc_read        : out std_logic;
      bus_memc_write       : out std_logic;
      bus_memc_dataRead    : in  std_logic_vector(31 downto 0);
      
      bus_pad_addr         : out unsigned(3 downto 0); 
      bus_pad_dataWrite    : out std_logic_vector(31 downto 0);
      bus_pad_read         : out std_logic;
      bus_pad_write        : out std_logic;
      bus_pad_writeMask    : out std_logic_vector(3 downto 0);
      bus_pad_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_sio_addr         : out unsigned(3 downto 0); 
      bus_sio_dataWrite    : out std_logic_vector(31 downto 0);
      bus_sio_read         : out std_logic;
      bus_sio_write        : out std_logic;
      bus_sio_writeMask    : out std_logic_vector(3 downto 0);
      bus_sio_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_memc2_addr       : out unsigned(3 downto 0); 
      bus_memc2_dataWrite  : out std_logic_vector(31 downto 0);
      bus_memc2_read       : out std_logic;
      bus_memc2_write      : out std_logic;
      bus_memc2_dataRead   : in  std_logic_vector(31 downto 0);
      
      bus_irq_addr         : out unsigned(3 downto 0); 
      bus_irq_dataWrite    : out std_logic_vector(31 downto 0);
      bus_irq_read         : out std_logic;
      bus_irq_write        : out std_logic;
      bus_irq_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_dma_addr         : out unsigned(6 downto 0); 
      bus_dma_dataWrite    : out std_logic_vector(31 downto 0);
      bus_dma_read         : out std_logic;
      bus_dma_write        : out std_logic;
      bus_dma_dataRead     : in  std_logic_vector(31 downto 0);
      
      bus_tmr_addr         : out unsigned(5 downto 0); 
      bus_tmr_dataWrite    : out std_logic_vector(31 downto 0);
      bus_tmr_read         : out std_logic;
      bus_tmr_write        : out std_logic;
      bus_tmr_dataRead     : in  std_logic_vector(31 downto 0);
      
      cd_memctrl           : in  unsigned(13 downto 0);
      bus_cd_addr          : out unsigned(3 downto 0); 
      bus_cd_dataWrite     : out std_logic_vector(7 downto 0);
      bus_cd_read          : out std_logic;
      bus_cd_write         : out std_logic;
      bus_cd_dataRead      : in  std_logic_vector(7 downto 0);
      
      bus_gpu_addr         : out unsigned(3 downto 0); 
      bus_gpu_dataWrite    : out std_logic_vector(31 downto 0);
      bus_gpu_read         : out std_logic;
      bus_gpu_write        : out std_logic;
      bus_gpu_dataRead     : in  std_logic_vector(31 downto 0);
      bus_gpu_stall        : in  std_logic;
      
      bus_mdec_addr        : out unsigned(3 downto 0);
      bus_mdec_dataWrite   : out std_logic_vector(31 downto 0);
      bus_mdec_read        : out std_logic;
      bus_mdec_write       : out std_logic;
      bus_mdec_dataRead    : in  std_logic_vector(31 downto 0);

      -- ZN-1 arcade I/O (0x1FA00000-0x1FAFFFFF)
      bus_znio_addr        : out unsigned(20 downto 0);
      bus_znio_dataWrite   : out std_logic_vector(31 downto 0);
      bus_znio_read        : out std_logic;
      bus_znio_write       : out std_logic;
      bus_znio_writeMask   : out std_logic_vector(3 downto 0);
      bus_znio_dataRead    : in  std_logic_vector(31 downto 0);

      -- ZN platform: 0=Visco, 1=Raizing, 2=Taito FX, 3=Atlus, 4=Tecmo
      zn_platform          : in  std_logic_vector(3 downto 0) := "0000";

      -- Namco System 11: when '1', boot from the 4MB game program @0x1FC00000
      -- (no PSX BIOS) and bank the ROM (16MB rom8 / 32MB rom8_64) as 8x1MB
      -- windows @0x1F000000. s11_bank = 8 packed 5-bit page selectors.
      zn_system11          : in  std_logic := '0';
      s11_bank             : in  std_logic_vector(39 downto 0) := (others => '0');
      -- rom8_64 upper-16MB latch (MAME rom8_64_upper_w @0x1F080000/2); consumed
      -- by zn1_io at bank-register write time.
      s11_up               : out std_logic := '0';

      spu_memctrl          : in  unsigned(13 downto 0);
      bus_spu_addr         : out unsigned(9 downto 0) := (others => '0'); 
      bus_spu_dataWrite    : out std_logic_vector(15 downto 0);
      bus_spu_read         : out std_logic;
      bus_spu_write        : out std_logic;
      bus_spu_dataRead     : in  std_logic_vector(15 downto 0);
      
      ex2_memctrl          : in  unsigned(13 downto 0);
      bus_exp2_addr        : out unsigned(12 downto 0); 
      bus_exp2_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp2_read        : out std_logic;
      bus_exp2_write       : out std_logic;
      bus_exp2_dataRead    : in  std_logic_vector(7 downto 0);
      
      ex3_memctrl          : in  unsigned(13 downto 0);
      --bus_exp3_dataWrite   : out std_logic_vector(7 downto 0);
      bus_exp3_read        : out std_logic;
      --bus_exp3_write       : out std_logic;
      bus_exp3_dataRead    : in  std_logic_vector(15 downto 0);
      
      com0_delay           : in  unsigned(3 downto 0);
      com1_delay           : in  unsigned(3 downto 0);
      com2_delay           : in  unsigned(3 downto 0);
      com3_delay           : in  unsigned(3 downto 0);
      
      loading_savestate    : in  std_logic;
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(18 downto 0);
      SS_wren_SDRam        : in  std_logic;
      SS_rden_SDRam        : in  std_logic;

      -- build #39: expose Tecmo bank register for debug instrumentation
      zn_bank_8mb_out      : out std_logic_vector(2 downto 0);

      -- build #47: TIGHT-window classify of banked-ROM data-read for the cube palette.
      -- GREEN window = ONLY the green row [0x1F644800,0x1F644A00) (256 entries) at bank 0.
      --   green -> read delivers green (read-path CLEAN, bug downstream: CPU store / DMA)
      --   red   -> SMOKING GUN: green row reads RED (SDRAM/read-path/byte-lane corruption)
      -- RED-ROW control = [0x1F645000,0x1F645200): proves instrument distinguishes rows
      --   (expect this read to return red -> dbg_palrd_redrow_red lit).
      dbg_palrd_green      : out std_logic := '0';
      dbg_palrd_red        : out std_logic := '0';
      dbg_palrd_any        : out std_logic := '0';
      dbg_palrd_redrow_red : out std_logic := '0';
      -- build #50: raw 32-bit SDRAM word latched at the green anchor (CPU 0x1F644810)
      dbg_palrd_value      : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #51: computed SDRAM byte address (ram_Adr) latched at the green anchor
      dbg_palrd_addr       : out std_logic_vector(31 downto 0) := (others => '0');
      -- build #52: 8 contiguous bank0 words [0x1F644800,0x1F644820) packed lo=word0..hi=word7
      dbg_palrd_words      : out std_logic_vector(255 downto 0) := (others => '0');
      -- build #135: CPU read at cube CLUT source address (0x1F7B610C in rp00.u0216)
      -- (1) any read in window [0x1F7B6000, 0x1F7B6200) (cube CLUT page)
      -- (2) exact read at 0x1F7B610C (the cube CLUT line)
      -- (3) at exact match AND bank=0 (correct bank selection)
      dbg_cubeclut_window_seen : out std_logic := '0';
      dbg_cubeclut_exact_seen  : out std_logic := '0';
      dbg_cubeclut_bank0_seen  : out std_logic := '0'
   );
end entity;

architecture arch of memorymux is
  
   type tState is
   (
      IDLE,
      WAITFORRAMREAD,
      WAITFORRAMWRITE,
      READBIOS,
      READROM,
      BUSWRITE,
      BUSWRITEEXTERNAL,
      BUSREADEXTERNAL,
      BUSREADREQUEST,
      BUSREAD,
      BUSREAD_CDSTUB,
      BUSREAD_UNKNOWNIO,
      WAITING,
      
      EXEPATCHBIOSWRITE,
      EXEPATCHBIOSWAIT,
      EXECOPYREAD,
      EXECOPYWRITE
   );
   signal state                  : tState := IDLE;
   signal dbg_state_num          : integer range 0 to 31 := 0;  -- sim probe: tState'pos(state)
      
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
   
   signal mem_save_request       : std_logic := '0'; 
   signal mem_save_rnw           : std_logic := '0'; 
   signal mem_save_isData        : std_logic := '0'; 
   signal mem_save_isCache       : std_logic := '0'; 
   signal mem_save_oldtagvalids  : std_logic_vector(3 downto 0) := (others => '0');
   signal mem_save_addressInstr  : unsigned(31 downto 0) := (others => '0'); 
   signal mem_save_addressData   : unsigned(31 downto 0) := (others => '0');
   signal mem_save_reqsize       : unsigned(1 downto 0) := (others => '0'); 
   signal mem_save_writeMask     : std_logic_vector(3 downto 0) := (others => '0');
   signal mem_save_dataWrite     : std_logic_vector(31 downto 0) := (others => '0'); 
   
   signal writeFifo_Din          : std_logic_vector(69 downto 0);
   signal writeFifo_Wr           : std_logic; 
   signal writeFifo_NearFull     : std_logic; 
   signal writeFifo_Dout         : std_logic_vector(69 downto 0);
   signal writeFifo_Rd           : std_logic;
   signal writeFifo_Empty        : std_logic;
   signal writeFifo_busy         : std_logic;
   signal writeFifo_Wr_1         : std_logic;
   
   signal bios_page_open         : std_logic;
   signal ram_page_open          : std_logic;
   signal ram_page_addr          : unsigned(11 downto 0);  -- 2026-06-27: was (10:0)=addr[20:10]; now
                                                           -- includes bit 21 so upper-2MB (4MB RAM) writes
                                                           -- don't alias to an open lower-2MB row.
   signal ram_load_last          : integer range 0 to 7 := 0;
   
   signal waitcnt                : integer range 0 to 127;
         
   signal mem_dataRead_buf       : std_logic_vector(31 downto 0);
   signal mem_done_buf           : std_logic := '0';
         
   signal readram                : std_logic := '0';
   signal writeram               : std_logic := '0';
   signal readrom_started        : std_logic := '0';   -- READROM saw the fresh read go busy
   -- READROM WAITING-hold cycles, latched per-entry to MATCH PSX READBIOS cadence
   -- (the CPU core is validated against READBIOS's 25/26 instr + 1/9/25 data timing).
   -- Banked-ROM READROM historically collapsed to a flat waitcnt=1 (up to 25x too fast)
   -- which the cpu.vhd mem_done/branch-resolution path was never validated against.
   signal readrom_hold           : integer range 0 to 63 := 1;
         
   signal data_ram               : std_logic_vector(31 downto 0);
   signal data_ram_rotate        : std_logic_vector(31 downto 0);
   signal ram_rotate_bits        : std_logic_vector(1 downto 0);
   signal region                 : std_logic_vector(1 downto 0);

   -- build #47: tight-window banked-ROM palette-read classifier (see entity ports)
   signal pal_read_pending       : std_logic := '0';   -- green-row window pending
   signal redrow_read_pending    : std_logic := '0';   -- red-row control window pending
   signal palrd_green_seen       : std_logic := '0';
   signal palrd_red_seen         : std_logic := '0';
   signal palrd_any_seen         : std_logic := '0';
   signal palrd_redrow_red_seen  : std_logic := '0';
   signal palrd_value_latch      : std_logic_vector(31 downto 0) := (others => '0'); -- build #50
   signal palrd_addr_latch       : std_logic_vector(31 downto 0) := (others => '0'); -- build #51
   -- DIAG 2026-06-16: decompressor-helper fetch-stream capture. Latches the actual
   -- instruction words READROM delivers for 0x1FC20280..0x1FC202A0 and flags the FIRST
   -- mismatch vs ground truth. Surfaced via dbg_palrd_value (hijacked) -> zn_debug_val.
   signal fcap_iaddr             : unsigned(21 downto 0) := (others => '0'); -- latched instr fetch ROM offset (4MB)
   signal fcap_pending           : std_logic := '0';                        -- this READROM is the latched instr fetch
   signal fcap_seen              : std_logic := '0';                        -- >=1 helper-window fetch completed
   signal fcap_mism              : std_logic := '0';                        -- a delivered word != ground truth (sticky)
   signal fcap_idx               : unsigned(3 downto 0) := (others => '0');  -- (addr-0x280)/4 of first mismatch
   signal fcap_word              : std_logic_vector(23 downto 0) := (others => '0'); -- low24 of first wrong word
   -- build #52: capture 8 contiguous bank0 words [0x1F644800,0x1F644820) by addr[4:2]
   -- build #52: flat 256-bit pack of 8 words; word N occupies bits [N*32+31 : N*32].
   -- (A named array-of-slv type introduces an implicit "&" that makes other slv
   --  concatenations in this file ambiguous, so keep this flat.)
   signal palrd_w                : std_logic_vector(255 downto 0) := (others => '0');

   -- build #135: cube CLUT source-address sticky-latches
   signal cubeclut_window_seen   : std_logic := '0';
   signal cubeclut_exact_seen    : std_logic := '0';
   signal cubeclut_bank0_seen    : std_logic := '0';

   signal addressData_buf        : unsigned(31 downto 0);
   signal dataWrite_buf          : std_logic_vector(31 downto 0);
   signal reqsize_buf            : unsigned(1 downto 0);   
   signal writeMask_buf          : std_logic_vector(3 downto 0);
            
   signal addressBIOS_buf        : unsigned(18 downto 0);
            
   signal bus_stall              : std_logic;
   signal dataFromBusses         : std_logic_vector(31 downto 0);
   signal rotate32               : std_logic;
   signal rotate16               : std_logic;
         
   -- EXE handling      
   signal loadExe_latched        : std_logic := '0';
   signal exestep                : integer range 0 to 8;
   signal execopycnt             : unsigned(31 downto 0);
   
   -- external busses
   type tExtState is
   (
      EXT_IDLE,
      EXE_WRITE_PREWAIT,
      EXT_WRITE,
      EXT_WRITE_WAIT,
      EXT_READ_NEXT,
      EXT_READ,
      EXT_READ_WAIT
   );
   signal ext_state              : tExtState := EXT_IDLE; 
   
   signal ext_done               : std_logic := '0';
   signal ext_finished           : std_logic := '0';
   signal ext_lastactive         : std_logic := '0';
   signal ext_recovered          : std_logic := '0';
   signal ext_data               : std_logic_vector(31 downto 0);
   signal ext_data_new           : std_logic_vector(31 downto 0);
   signal ext_dataWrite_buf      : std_logic_vector(31 downto 0);
   signal ext_writeMask_buf      : std_logic_vector(3 downto 0);
   
   signal ext_bus_addr           : unsigned(12 downto 0) := (others => '0'); 
   
   signal ext_memctrl            : unsigned(13 downto 0);
   signal ext_memctrl_WDelay     : unsigned(3 downto 0);
   signal ext_memctrl_RDelay     : unsigned(3 downto 0);
   signal ext_memctrl_RecP       : std_logic;
   signal ext_memctrl_Hold       : std_logic;
   signal ext_memctrl_Float      : std_logic;
   signal ext_memctrl_PStrobe    : std_logic;
   signal ext_memctrl_width      : std_logic;
   signal ext_memctrl_autoinc    : std_logic;
   signal ext_byteStep           : unsigned(1 downto 0);
   signal ext_waitcnt            : integer range 0 to 63;
   signal ext_reccount           : integer range 0 to 31;
   signal ext_write_ena          : std_logic;
   signal ext_dataWrite          : std_logic_vector(15 downto 0);
   
   signal ext_select_spu         : std_logic := '0';
   signal ext_select_spu_saved   : std_logic := '0';   
   signal ext_select_cd          : std_logic := '0';
   signal ext_select_cd_saved    : std_logic := '0';
   signal ext_select_ex1         : std_logic := '0';
   signal ext_select_ex1_saved   : std_logic := '0';   
   signal ext_select_ex2         : std_logic := '0';
   signal ext_select_ex2_saved   : std_logic := '0';   
   signal ext_select_ex3         : std_logic := '0';
   signal ext_select_ex3_saved   : std_logic := '0';     
         
   -- debug    
   signal stallcountRead         : integer;
   signal stallcountReadC        : integer;
   signal stallcountWrite        : integer;
   signal stallcountWriteF       : integer;
   signal stallcountIntBus       : integer;
         
   signal addressDataF           : std_logic := '0';

   -- ZN-1 ROM bank register (5-bit, selects 1MB bank window at 0x1FB00000, Visco only)
   signal zn_bank_reg            : std_logic_vector(4 downto 0) := (others => '0');
   -- ZN-1 8MB bank register (3-bit, selects 8MB bank at 0x1F000000, non-Visco platforms, banks 0-6)
   signal zn_bank_8mb            : std_logic_vector(2 downto 0) := (others => '0');
   signal s11_up_r               : std_logic := '0';  -- rom8_64 upper-16MB latch (0x1F080000/2)

begin

   isIdle <= '1' when (state = IDLE and readram = '0' and writeram = '0' and writeFifo_busy = '0' and mem_save_request = '0') else '0';

   process (state, addressData_buf, writeMask_buf, dataWrite_buf)
      variable address  : unsigned(28 downto 0);
      variable enableRead  : std_logic;
      variable enableWrite : std_logic;
   begin
   
      address := addressData_buf(28 downto 0);
   
      enableRead  := '0';
      enableWrite := '0';
      if (state = BUSREADREQUEST) then 
         enableRead := '1';
      end if;
      if (state = BUSWRITE) then 
         enableWrite := '1';
      end if;
      
      -- memc
      bus_memc_read      <= '0';
      bus_memc_write     <= '0';
      bus_memc_addr      <= address(5 downto 0);
      bus_memc_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801000# and address < 16#1F801040#) then
         bus_memc_read  <= enableRead;
         bus_memc_write <= enableWrite;
      end if;
      
      -- pad
      bus_pad_read      <= '0';
      bus_pad_write     <= '0';
      bus_pad_addr      <= address(3 downto 0);
      bus_pad_dataWrite <= dataWrite_buf;
      bus_pad_writeMask <= writeMask_buf;
      if (address >= 16#1F801040# and address < 16#1F801050#) then
         bus_pad_read  <= enableRead;
         bus_pad_write <= enableWrite;
      end if;
      
      -- sio
      bus_sio_read      <= '0';
      bus_sio_write     <= '0';
      bus_sio_addr      <= address(3 downto 0);
      bus_sio_dataWrite <= dataWrite_buf;
      bus_sio_writeMask <= writeMask_buf;
      if (address >= 16#1F801050# and address < 16#1F801060#) then
         bus_sio_read  <= enableRead;
         bus_sio_write <= enableWrite;
      end if;
      
      -- memc2
      bus_memc2_read      <= '0';
      bus_memc2_write     <= '0';
      bus_memc2_addr      <= address(3 downto 0);
      bus_memc2_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801060# and address < 16#1F801070#) then
         bus_memc2_read  <= enableRead;
         bus_memc2_write <= enableWrite;
      end if;
      
      -- irq
      bus_irq_read      <= '0';
      bus_irq_write     <= '0';
      bus_irq_addr      <= address(3 downto 0);
      bus_irq_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801070# and address < 16#1F801080#) then
         bus_irq_read  <= enableRead;
         bus_irq_write <= enableWrite;
      end if;
      
      -- dma
      bus_dma_read      <= '0';
      bus_dma_write     <= '0';
      bus_dma_addr      <= address(6 downto 0);
      bus_dma_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801080# and address < 16#1F801100#) then
         bus_dma_read  <= enableRead;
         bus_dma_write <= enableWrite;
      end if;
      
      -- timer
      bus_tmr_read      <= '0';
      bus_tmr_write     <= '0';
      bus_tmr_addr      <= address(5 downto 0);
      bus_tmr_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801100# and address < 16#1F801140#) then
         bus_tmr_read  <= enableRead;
         bus_tmr_write <= enableWrite;
      end if;
      
      -- gpu
      bus_gpu_read      <= '0';
      bus_gpu_write     <= '0';
      bus_gpu_addr      <= address(3 downto 0);
      bus_gpu_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801810# and address < 16#1F801820#) then
         bus_gpu_read  <= enableRead;
         bus_gpu_write <= enableWrite;
      end if;
      
      -- mdec
      bus_mdec_read      <= '0';
      bus_mdec_write     <= '0';
      bus_mdec_addr      <= address(3 downto 0);
      bus_mdec_dataWrite <= dataWrite_buf;
      if (address >= 16#1F801820# and address < 16#1F801830#) then
         bus_mdec_read  <= enableRead;
         bus_mdec_write <= enableWrite;
      end if;

      -- ZN-1 I/O (0x1FA00000-0x1FAFFFFF)
      bus_znio_read      <= '0';
      bus_znio_write     <= '0';
      bus_znio_addr      <= address(20 downto 0);
      bus_znio_dataWrite <= dataWrite_buf;
      bus_znio_writeMask <= writeMask_buf;
      if (address >= 16#1FA00000# and address < 16#1FB00000#) then
         bus_znio_read  <= enableRead;
         bus_znio_write <= enableWrite;
      end if;

   end process;
   
   bus_stall         <= bus_gpu_stall;
   
   dataFromBusses    <= bus_memc_dataRead or bus_pad_dataRead or bus_sio_dataRead or bus_memc2_dataRead or bus_irq_dataRead or
                        bus_dma_dataRead or bus_tmr_dataRead or bus_gpu_dataRead or bus_mdec_dataRead or bus_znio_dataRead;
   
   data_ram          <= ram_dataRead;
  
   data_ram_rotate   <= data_ram                            when ram_rotate_bits(1 downto 0) = "00" else
                        x"00" & data_ram(31 downto 8)       when ram_rotate_bits(1 downto 0) = "01" else
                        x"0000" & data_ram(31 downto 16)    when ram_rotate_bits(1 downto 0) = "10" else
                        x"000000" & data_ram(31 downto 24);

   -- build #47: expose latched palette-read classification to the debug bars
   dbg_palrd_green      <= palrd_green_seen;
   dbg_palrd_red        <= palrd_red_seen;
   dbg_palrd_any        <= palrd_any_seen;
   dbg_palrd_redrow_red <= palrd_redrow_red_seen;
   -- DIAG 2026-06-16: hijacked to carry the helper fetch-stream capture.
   --   [31]=seen (>=1 helper-window fetch completed; 0 => capture never ran)
   --   [30]=mism (a delivered word != ground truth)
   --   [27:24]=idx of first mismatch ((addr-0x280)/4); [23:0]=low24 of that wrong word
   dbg_palrd_value      <= fcap_seen & fcap_mism & "00" & std_logic_vector(fcap_idx) & fcap_word;
   dbg_palrd_addr       <= palrd_addr_latch;    -- build #51
   -- build #52: pack 8 words (word0 in low 32 bits .. word7 in high 32 bits)
   dbg_palrd_words      <= palrd_w;

   -- build #135: cube CLUT source-address sticky outputs
   dbg_cubeclut_window_seen <= cubeclut_window_seen;
   dbg_cubeclut_exact_seen  <= cubeclut_exact_seen;
   dbg_cubeclut_bank0_seen  <= cubeclut_bank0_seen;
      
   mem_dataRead      <= data_ram_rotate when (readram = '1' and ram_done = '1') else
                        ext_data_new    when (ext_done = '1') else
                        mem_dataRead_buf;
                        
   mem_done          <= '1'            when (readram = '1'  and ram_done = '1') else 
                        '1'            when (ext_done = '1') else 
                        mem_done_buf;
   
   
   -- write fifo
   iwritefifo: entity mem.SyncFifoFallThroughMLAB
   generic map
   (
      SIZE              => 8,
      DATAWIDTH         => 70,
      NEARFULLDISTANCE  => 4,
      NEAREMPTYDISTANCE => 2
   )
   port map
   ( 
      clk         => clk1x,
      reset       => reset,
                  
      Din         => writeFifo_Din,     
      Wr          => writeFifo_Wr,      
      Full        => open,                -- NearFull will stall cpu to have full 4 element size
      NearFull    => writeFifo_NearFull,
            
      Dout        => writeFifo_Dout,     
      Rd          => writeFifo_Rd,   
      Empty       => writeFifo_Empty,
      NearEmpty   => open
   );
   
   writeFifo_Din <= mem_in_writeMask & std_logic_vector(mem_in_reqsize) & std_logic_vector(mem_in_addressData) & mem_in_dataWrite;
   writeFifo_Wr  <= '1' when (ce = '1' and mem_in_request = '1' and mem_in_rnw = '0' and (pauseNext = '1' or state /= IDLE or writeFifo_busy = '1' or ((readram = '1' or writeram = '1') and ram_done = '0'))) else '0';
   
   writeFifo_Rd  <= '1' when (ce = '1' and pauseNext = '0' and state = IDLE and writeFifo_Empty = '0' and ((readram = '0' and writeram = '0') or ram_done = '1')) else '0';
   
   mem_fifofull  <= writeFifo_NearFull;
   
   -- input muxing with buffer and writefifo
   mem_request      <= mem_in_request or mem_save_request;
   mem_rnw          <= '0'                                    when writeFifo_Empty = '0' else mem_save_rnw          when mem_save_request = '1' else mem_in_rnw         ;
   mem_isData       <= '1'                                    when writeFifo_Empty = '0' else mem_save_isData       when mem_save_request = '1' else mem_in_isData      ;
   mem_isCache      <= '0'                                    when writeFifo_Empty = '0' else mem_save_isCache      when mem_save_request = '1' else mem_in_isCache     ;
   mem_oldtagvalids <= "0000"                                 when writeFifo_Empty = '0' else mem_save_oldtagvalids when mem_save_request = '1' else mem_in_oldtagvalids; 
   mem_addressInstr <= unsigned(writeFifo_Dout(63 downto 32)) when writeFifo_Empty = '0' else mem_save_addressInstr when mem_save_request = '1' else mem_in_addressInstr;
   mem_addressData  <= unsigned(writeFifo_Dout(63 downto 32)) when writeFifo_Empty = '0' else mem_save_addressData  when mem_save_request = '1' else mem_in_addressData ;
   mem_reqsize      <= unsigned(writeFifo_Dout(65 downto 64)) when writeFifo_Empty = '0' else mem_save_reqsize      when mem_save_request = '1' else mem_in_reqsize     ;
   mem_writeMask    <= writeFifo_Dout(69 downto 66)           when writeFifo_Empty = '0' else mem_save_writeMask    when mem_save_request = '1' else mem_in_writeMask   ;
   mem_dataWrite    <= writeFifo_Dout(31 downto  0)           when writeFifo_Empty = '0' else mem_save_dataWrite    when mem_save_request = '1' else mem_in_dataWrite   ;

   s11_up <= s11_up_r;

   process (clk1x)
      variable biosPatch  : std_logic_vector(31 downto 0);
      variable s11_page   : unsigned(4 downto 0);  -- selected 1MB page for current bank window
      variable fcap_exp   : std_logic_vector(31 downto 0);  -- DIAG: expected helper instruction word
   begin
      if rising_edge(clk1x) then
      
         ram_ena              <= '0';
         mem_done_buf         <= '0';
         reset_exe            <= '0';
         
         if (loadExe = '1') then
            loadExe_latched <= '1';
         end if;
         
         if (ram_done = '1') then
            readram  <= '0';
            writeram <= '0';
         end if;
      
         if (ram_load_last > 0) then
            ram_load_last <= ram_load_last - 1;
         end if;
      
         if (reset = '1') then

            state            <= IDLE;
            readrom_started  <= '0';
            region           <= region_in;
            mem_save_request <= '0';
            writeFifo_busy   <= '0';
            ram_page_open    <= '0';
            ext_lastactive   <= '0';
            zn_bank_reg      <= (others => '0');
            zn_bank_8mb      <= (others => '0');
            s11_up_r         <= '0';
            pal_read_pending      <= '0';   -- build #47
            redrow_read_pending   <= '0';   -- build #47
            palrd_green_seen      <= '0';   -- build #47
            palrd_red_seen        <= '0';   -- build #47
            palrd_any_seen        <= '0';   -- build #47
            palrd_redrow_red_seen <= '0';   -- build #47
            palrd_value_latch     <= (others => '0');  -- build #50
            fcap_pending          <= '0';   -- DIAG fetch-stream capture
            fcap_seen             <= '0';
            fcap_mism             <= '0';
            fcap_idx              <= (others => '0');
            fcap_word             <= (others => '0');
            palrd_addr_latch      <= (others => '0');  -- build #51
            palrd_w               <= (others => '0');  -- build #52
            cubeclut_window_seen  <= '0';   -- build #135
            cubeclut_exact_seen   <= '0';   -- build #135
            cubeclut_bank0_seen   <= '0';   -- build #135

         elsif (ce = '1') then
         
            if (mem_in_request = '1' and mem_in_rnw = '1') then
               mem_save_request      <= '1';
               mem_save_rnw          <= '1';         
               mem_save_isData       <= mem_in_isData;
               mem_save_isCache      <= mem_in_isCache;     
               mem_save_oldtagvalids <= mem_in_oldtagvalids;     
               mem_save_addressInstr <= mem_in_addressInstr;
               mem_save_addressData  <= mem_in_addressData; 
               mem_save_reqsize      <= mem_in_reqsize;     
               mem_save_writeMask    <= mem_in_writeMask;   
               mem_save_dataWrite    <= mem_in_dataWrite;   
            end if;
            
            writeFifo_Wr_1 <= writeFifo_Wr;
            if (writeFifo_Wr = '1') then
               writeFifo_busy <= '1';
            elsif (writeFifo_Wr_1 = '0' and writeFifo_Empty = '1') then
               writeFifo_busy <= '0';
            end if;
          
            case (state) is
               when IDLE =>

                  addressData_buf <= mem_addressData;
                  dataWrite_buf   <= mem_dataWrite;
                  reqsize_buf     <= mem_reqsize;
                  writeMask_buf   <= mem_writeMask;
                  
                  if (loadExe_latched = '1') then
                     
                     state      <= EXEPATCHBIOSWRITE;
                     exestep    <= 0;
                     execopycnt <= (others => '0');
               
                  elsif (pauseNext = '0' and ((readram = '0' and writeram = '0') or ram_done = '1') and ((mem_request = '1' and writeFifo_busy = '0') or writeFifo_Empty = '0')) then
                  
                     if (mem_request = '1' and writeFifo_busy = '0') then
                        mem_save_request <= '0';
                     end if;
                  
                     readram  <= '0';
                     writeram <= '0';
                     
                     ram_page_open  <= '0';
                     bios_page_open <= '0';
                  
                     if (mem_isData = '0') then
               
                        if (mem_addressInstr(28 downto 0) < 16#800000#) then -- RAM
                           ram_ena     <= '1';
                           ram_cache   <= mem_isCache;
                           ram_rnw     <= '1';
                           -- S11 has 4MB RAM (vs PSX 8MB region): force bit22=0 so 0x00400000+ mirrors low 4MB instead of aliasing the boot-program SDRAM image at 0x400000.
                           ram_Adr     <= "0000" & (mem_addressInstr(22) and not zn_system11) & std_logic_vector(mem_addressInstr(21 downto 2)) & "00";
                           state       <= IDLE;
                           readram     <= '1';
                           ram_rotate_bits <= "00";
                           if (mem_isCache = '0') then
                              if (TURBO = '0') then
                                 state   <= WAITFORRAMREAD;
                                 waitcnt <= 0;
                                 ram_ena <= '0';
                                 readram <= '0';
                              end if;
                           end if;
                           
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids <= "1111";
                              when "01" => mem_tagvalids <= "1110";
                              when "10" => mem_tagvalids <= "1100";
                              when "11" => mem_tagvalids <= "1000";
                              when others => null;
                           end case;
                           
                        elsif (zn_system11 = '1' and mem_addressInstr(28 downto 0) >= 16#1FC00000#) then -- S11 boot program
                           ram_ena         <= '1';
                           ram_rnw         <= '1';
                           ram_Adr         <= std_logic_vector(to_unsigned(16#400000#, 27) + resize(unsigned(mem_addressInstr(21 downto 2)) & "00", 27));
                           ram_rotate_bits <= "00";
                           if (mem_isCache = '1') then  -- decompressor region [0x1FC20000): ICACHE FILL (CPU marks it cacheable)
                              ram_cache    <= '1';
                              state        <= IDLE;
                              readram      <= '1';
                              case (mem_addressInstr(3 downto 2)) is
                                 when "00" => mem_tagvalids <= "1111";
                                 when "01" => mem_tagvalids <= "1110";
                                 when "10" => mem_tagvalids <= "1100";
                                 when "11" => mem_tagvalids <= "1000";
                                 when others => null;
                              end case;
                           else  -- early BIOS init etc.: uncached single read via READROM (original, proven)
                              ram_cache    <= '0';
                              state        <= READROM;
                              mem_tagvalids <= mem_oldtagvalids;
                              case (mem_addressInstr(3 downto 2)) is
                                 when "00" => mem_tagvalids(0) <= '1';
                                 when "01" => mem_tagvalids(1) <= '1';
                                 when "10" => mem_tagvalids(2) <= '1';
                                 when "11" => mem_tagvalids(3) <= '1';
                                 when others => null;
                              end case;
                           end if;
                        elsif (zn_system11 = '1' and mem_addressInstr(28 downto 0) >= 16#1F000000# and mem_addressInstr(28 downto 0) < 16#1F800000#) then -- S11 banked ROM (8x1MB windows)
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           case (mem_addressInstr(22 downto 20)) is
                              when "000" => s11_page := unsigned(s11_bank(4 downto 0));
                              when "001" => s11_page := unsigned(s11_bank(9 downto 5));
                              when "010" => s11_page := unsigned(s11_bank(14 downto 10));
                              when "011" => s11_page := unsigned(s11_bank(19 downto 15));
                              when "100" => s11_page := unsigned(s11_bank(24 downto 20));
                              when "101" => s11_page := unsigned(s11_bank(29 downto 25));
                              when "110" => s11_page := unsigned(s11_bank(34 downto 30));
                              when others => s11_page := unsigned(s11_bank(39 downto 35));
                           end case;
                           ram_Adr         <= std_logic_vector(to_unsigned(16#800000#, 27) + resize(s11_page & to_unsigned(0, 20), 27) + resize(unsigned(mem_addressInstr(19 downto 2)) & "00", 27));
                           state           <= READROM;
                           readrom_hold    <= 25;  -- match READBIOS instr (cache-line fill) cadence
                           ram_rotate_bits <= "00";
                           mem_tagvalids   <= mem_oldtagvalids;
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids(0) <= '1';
                              when "01" => mem_tagvalids(1) <= '1';
                              when "10" => mem_tagvalids(2) <= '1';
                              when "11" => mem_tagvalids(3) <= '1';
                              when others => null;
                           end case;
                        elsif (mem_addressInstr(28 downto 0) >= 16#1FC00000# and mem_addressInstr(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           ram_Adr         <= "00001000" & std_logic_vector(mem_addressInstr(18 downto 2)) & "00";
                           state           <= READBIOS;
                           addressBIOS_buf <= mem_addressInstr(18 downto 0);
                           ram_rotate_bits <= "00";
                           if (bios_page_open = '1') then
                              waitcnt        <= 25;
                           else
                              waitcnt        <= 26;
                              bios_page_open <= '1';
                           end if;
                           
                           mem_tagvalids <= mem_oldtagvalids;
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids(0) <= '1';
                              when "01" => mem_tagvalids(1) <= '1';
                              when "10" => mem_tagvalids(2) <= '1';
                              when "11" => mem_tagvalids(3) <= '1';
                              when others => null;
                           end case;
                        elsif ((zn_platform = "0000" and mem_addressInstr(28 downto 0) >= 16#1F000000# and mem_addressInstr(28 downto 0) < 16#1F280000#) or
                               (zn_platform /= "0000" and mem_addressInstr(28 downto 0) >= 16#1F000000# and mem_addressInstr(28 downto 0) < 16#1F800000#)) then -- ZN ROM
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           if (zn_platform = "0000") then
                              ram_Adr      <= "00" & std_logic_vector(to_unsigned(16#120000#, 23) + resize(unsigned(mem_addressInstr(22 downto 2)), 23)) & "00";
                           else
                              ram_Adr      <= "0" & std_logic_vector((unsigned(zn_bank_8mb) + 1) & unsigned(mem_addressInstr(22 downto 2))) & "00";
                           end if;
                           state           <= READROM;
                           readrom_hold    <= 25;  -- match READBIOS instr cadence
                           ram_rotate_bits <= "00";
                           mem_tagvalids   <= mem_oldtagvalids;
                           case (mem_addressInstr(3 downto 2)) is
                              when "00" => mem_tagvalids(0) <= '1';
                              when "01" => mem_tagvalids(1) <= '1';
                              when "10" => mem_tagvalids(2) <= '1';
                              when "11" => mem_tagvalids(3) <= '1';
                              when others => null;
                           end case;
                        else
                           report "should never happen" severity failure;
                        end if;
            
                     else
                     
                        if (mem_addressData(28 downto 0) < 16#800000#) then -- RAM
                           ext_lastactive  <= '0';
                           ram_cache       <= '0';
                           ram_rnw         <= mem_rnw;
                           -- S11 4MB RAM: force bit22=0 so 0x00400000+ mirrors low 4MB (see instr path above).
                           ram_Adr         <= "0000" & (mem_addressData(22) and not zn_system11) & std_logic_vector(mem_addressData(21 downto 2)) & "00";
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           if (mem_rnw = '1') then
                              ram_load_last <= 7;
                              if (TURBO = '1' or ram_load_last > 0) then
                                 state   <= IDLE;
                                 ram_ena <= '1';
                                 readram <= '1';
                              else
                                 state   <= WAITFORRAMREAD;
                                 waitcnt <= 0;
                              end if;
                           else
                              ram_page_open <= '1';
                              ram_page_addr <= mem_addressData(21 downto 10);
                              if (TURBO = '1' or (ram_page_open = '1' and mem_addressData(21 downto 10) = ram_page_addr)) then
                                 state    <= IDLE;
                                 ram_ena  <= '1';
                                 writeram <= '1';
                              else
                                 state   <= WAITFORRAMWRITE;
                                 waitcnt <= 0;
                                 if (ram_page_open = '1' and mem_addressData(21 downto 10) /= ram_page_addr) then
                                    waitcnt <= 3;
                                 end if;
                              end if;
                           end if;
                           ram_be        <= mem_writeMask;
                           ram_dataWrite <= mem_dataWrite;
                        elsif (zn_system11 = '1' and mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FC00000#) then -- S11 boot program DATA read
                           -- FIX 2026-06-16: use the PROVEN RAM uncached-read mechanism (live
                           -- data_ram_rotate + combinational mem_done, NO mem_dataRead_buf) instead
                           -- of READROM, whose buffered delivery occasionally clobbered on back-to-
                           -- back reads -> a wrong decompressor SOURCE byte -> residual decompression
                           -- error (CpU @0x80010170). Reads SDRAM 0x400000+offset (the boot image).
                           ext_lastactive  <= '0';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           ram_Adr         <= std_logic_vector(to_unsigned(16#400000#, 27) + resize(unsigned(mem_addressData(21 downto 2)) & "00", 27));
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           ram_load_last   <= 7;
                           if (TURBO = '1' or ram_load_last > 0) then
                              state   <= IDLE;
                              ram_ena <= '1';
                              readram <= '1';
                           else
                              state   <= WAITFORRAMREAD;
                              waitcnt <= 0;
                           end if;
                        elsif (zn_system11 = '1' and mem_rnw = '0' and mem_addressData(28 downto 0) >= 16#1F080000# and mem_addressData(28 downto 0) < 16#1F080004#) then
                           -- rom8_64 upper-bank latch (MAME rom8_64_upper_w): halfword write to
                           -- 0x1F080000 selects the lower 16MB (offset 0), 0x1F080002 the upper
                           -- (offset 1 -> bankoffset 16). Stores arrive word-aligned with the
                           -- halfword lane in the write mask; on a full-word store offset 1 wins
                           -- (MAME invokes offset 0 then 1, last call wins).
                           if (mem_writeMask(3 downto 2) /= "00") then
                              s11_up_r <= '1';
                           elsif (mem_writeMask(1 downto 0) /= "00") then
                              s11_up_r <= '0';
                           end if;
                           state <= BUSWRITE;
                        elsif (zn_system11 = '1' and mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1F000000# and mem_addressData(28 downto 0) < 16#1F800000#) then -- S11 banked ROM (8x1MB windows)
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           case (mem_addressData(22 downto 20)) is
                              when "000" => s11_page := unsigned(s11_bank(4 downto 0));
                              when "001" => s11_page := unsigned(s11_bank(9 downto 5));
                              when "010" => s11_page := unsigned(s11_bank(14 downto 10));
                              when "011" => s11_page := unsigned(s11_bank(19 downto 15));
                              when "100" => s11_page := unsigned(s11_bank(24 downto 20));
                              when "101" => s11_page := unsigned(s11_bank(29 downto 25));
                              when "110" => s11_page := unsigned(s11_bank(34 downto 30));
                              when others => s11_page := unsigned(s11_bank(39 downto 35));
                           end case;
                           ram_Adr         <= std_logic_vector(to_unsigned(16#800000#, 27) + resize(s11_page & to_unsigned(0, 20), 27) + resize(unsigned(mem_addressData(19 downto 2)) & "00", 27));
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           state           <= READROM;
                           case (mem_reqsize) is       -- match READBIOS data cadence (1/9/25 by size)
                              when "00"   => readrom_hold <= 1;
                              when "01"   => readrom_hold <= 9;
                              when "10"   => readrom_hold <= 25;
                              when others => readrom_hold <= 1;
                           end case;
                        elsif (mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FC00000# and mem_addressData(28 downto 0) < 16#1FC80000#) then -- BIOS
                           ram_ena         <= '1';
                           ram_cache       <= '0';
                           ram_rnw         <= '1';
                           ram_Adr         <= "00001000" & std_logic_vector(mem_addressData(18 downto 2)) & "00";
                           ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                           state           <= READBIOS;
                           addressBIOS_buf <= mem_addressData(18 downto 0);
                           case (mem_reqsize) is
                              when "00" => waitcnt <= 1;
                              when "01" => waitcnt <= 9;
                              when "10" => waitcnt <= 25;
                              when others => null;
                           end case;
                        else
                           ext_select_spu <= '0';
                           ext_select_cd  <= '0';
                           ext_select_ex1 <= '0';
                           ext_select_ex2 <= '0';
                           ext_select_ex3 <= '0';
                           if (mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1F000000# and
                               ((zn_platform = "0000" and mem_addressData(28 downto 0) < 16#1F280000#) or
                                (zn_platform /= "0000" and mem_addressData(28 downto 0) < 16#1F800000#))) then
                              -- ZN ROM read (Visco fixed ROM or non-Visco 8MB banked ROM)
                              ext_lastactive  <= '0';
                              ram_ena         <= '1';
                              ram_cache       <= '0';
                              ram_rnw         <= '1';
                              if (zn_platform = "0000") then
                                 ram_Adr     <= "00" & std_logic_vector(to_unsigned(16#120000#, 23) + resize(unsigned(mem_addressData(22 downto 2)), 23)) & "00";
                              else
                                 ram_Adr     <= "0" & std_logic_vector((unsigned(zn_bank_8mb) + 1) & unsigned(mem_addressData(22 downto 2))) & "00";
                              end if;
                              ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                              state           <= READROM;
                              case (mem_reqsize) is    -- match READBIOS data cadence
                                 when "00"   => readrom_hold <= 1;
                                 when "01"   => readrom_hold <= 9;
                                 when "10"   => readrom_hold <= 25;
                                 when others => readrom_hold <= 1;
                              end case;
                              -- build #49: MECHANISM SPLITTER. Single-word anchor on the green
                              -- cube-palette word at CPU 0x1F644810 (bank0, SDRAM 0xE44810 =
                              -- rp00:0x244810). In ROM this word = 0x00200000 (hi 0x0020=G1, lo
                              -- 0x0000=BLK). Classify the raw read value to tell apart:
                              --   CLEAN  -> 0x00200000 (hi=0x0020 G1, lo=BLK)
                              --   +0x800 -> reads red row 0xE45010 = 0x00010001 (hi R1, lo R1)
                              --   >>5    -> 0x00200000>>5 = 0x00010000 (hi R1, lo BLK)
                              -- build #52: widen to the 8-word line [0x1F644800,0x1F644820)
                              if (zn_platform = "0100" and zn_bank_8mb = "000"
                                  and mem_addressData(28 downto 0) >= 16#1F644800#
                                  and mem_addressData(28 downto 0) <  16#1F644820#) then
                                 pal_read_pending <= '1';
                                 -- build #51: latch the computed SDRAM byte address (mirror of
                                 -- the Tecmo ram_Adr formula on line 779). Expect 0x00E448xx.
                                 palrd_addr_latch <= "00000" & "0" & std_logic_vector((unsigned(zn_bank_8mb) + 1) & unsigned(mem_addressData(22 downto 2))) & "00";
                              else
                                 pal_read_pending <= '0';
                              end if;
                              redrow_read_pending <= '0';

                              -- build #136: cube CLUT source-address detectors (Tecmo only)
                              -- Verified cube CLUT location via full 16-byte signature match:
                              -- rp00.u0216 offset 0x3B61CC → CPU addr 0x1F7B61CC (bank=0).
                              -- VRAM destination (per MAME): X=256, Y=482, 4-bit CLUT 16×1.
                              -- MAME 20s trace shows NO direct CPU read at 0x1F7B61CC, so the
                              -- load likely happens via I/D-cache fill of a 32-byte line, or
                              -- via a bulk DMA copy. To catch either: instrument the cache
                              -- line containing the CLUT and 64-byte window covering 2 lines.
                              -- RED   = window [0x1F7B61C0, 0x1F7B6200)  — 2 cache lines
                              -- GREEN = exact 0x1F7B61CC                  — first CLUT word
                              -- BLUE  = cache-line aligned 0x1F7B61C0 with bank=0
                              if (zn_platform = "0100"
                                  and mem_addressData(28 downto 0) >= 16#1F7B61C0#
                                  and mem_addressData(28 downto 0) <  16#1F7B6200#) then
                                 cubeclut_window_seen <= '1';
                              end if;
                              if (zn_platform = "0100"
                                  and mem_addressData(28 downto 0) = 16#1F7B61CC#) then
                                 cubeclut_exact_seen <= '1';
                              end if;
                              if (zn_platform = "0100"
                                  and mem_addressData(28 downto 0) = 16#1F7B61C0#
                                  and zn_bank_8mb = "000") then
                                 cubeclut_bank0_seen <= '1';
                              end if;
                           elsif (zn_platform = "0000" and mem_addressData(28 downto 0) >= 16#1FB00000# and mem_addressData(28 downto 0) < 16#1FC00000#) then
                              -- Visco banked ROM (1MB banks × 24) at 0x1FB00000
                              if (mem_rnw = '1') then
                                 ext_lastactive  <= '0';
                                 ram_ena         <= '1';
                                 ram_cache       <= '0';
                                 ram_rnw         <= '1';
                                 ram_Adr         <= "00" & std_logic_vector(to_unsigned(16#200000#, 23) + unsigned(zn_bank_reg & std_logic_vector(mem_addressData(19 downto 2)))) & "00";
                                 ram_rotate_bits <= std_logic_vector(mem_addressData(1 downto 0));
                                 state           <= READROM;
                              else
                                 zn_bank_reg     <= mem_dataWrite(4 downto 0);
                                 state           <= BUSWRITE;
                              end if;
                           elsif (mem_rnw = '0' and zn_platform = "0010" and mem_addressData(28 downto 0) = 16#1FB40000#) then
                              -- Taito FX bank register write (bits[2:0])
                              zn_bank_8mb <= mem_dataWrite(2 downto 0);
                              state       <= BUSWRITE;
                           elsif (mem_rnw = '0' and zn_platform = "0011" and mem_addressData(28 downto 0) = 16#1FB00002#) then
                              -- Atlus bank register write: SH to byte-offset 2 → data in bits[31:16]
                              zn_bank_8mb <= mem_dataWrite(18 downto 16);
                              state       <= BUSWRITE;
                           elsif (mem_rnw = '0' and zn_platform = "0100" and
                                  (mem_addressData(28 downto 0) = 16#1FB00006# or
                                   mem_addressData(28 downto 0) = 16#1FB00004#)) then
                              -- Tecmo bank register write: bank data in bits[18:16] of dataWrite.
                              -- B129 showed bank stuck at 0 in lpadv. Per MAME's analysis, 109 bank switches happen
                              -- during cube attract via game code at 0x800504F0. Likely lpadv writes to 0x1FB00004
                              -- (word-aligned) instead of 0x1FB00006 (halfword), OR mem_addressData masks bit 1.
                              -- Match BOTH addresses for backward-compatible fix.
                              zn_bank_8mb <= mem_dataWrite(18 downto 16);
                              state       <= BUSWRITE;
                           elsif (mem_addressData(28 downto 0) >= 16#1FA00000# and mem_addressData(28 downto 0) < 16#1FB00000#) then
                              -- ZN-1 I/O: routed through internal bus (bus_znio_*)
                              -- Raizing: bank is also set by sec_select write (0x1FA10300 bits[1:0])
                              ext_lastactive  <= '0';
                              if (mem_rnw = '0') then
                                 state   <= BUSWRITE;
                                 if (zn_platform = "0001" and mem_addressData(28 downto 0) = 16#1FA10300#) then
                                    -- build #79 fix: Raizing bank is data & 3 (bits[1:0]) per MAME raizing_zn_state::znsecsel_w.
                                    -- Bit 2 of this data is CAT702 chip 0 select — must NOT be captured into the bank register
                                    -- or CAT702 verification toggles corrupt the bank → "CanNotFindProgramRom ERROR B930".
                                    zn_bank_8mb <= "0" & mem_dataWrite(1 downto 0);
                                 end if;
                              else
                                 state   <= BUSREADREQUEST;
                                 waitcnt <= 0;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F801800# and mem_addressData(28 downto 0) < 16#1F801810#) then
                              -- ZN-1 has no CD-ROM: return 0xFF for reads (matches MAME open-bus), ignore writes
                              if (mem_rnw = '1') then
                                 state <= BUSREAD_CDSTUB;
                              else
                                 state <= BUSWRITE;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F801C00# and mem_addressData(28 downto 0) < 16#1F802000#) then
                              ext_select_spu <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F000000# and mem_addressData(28 downto 0) < 16#1F800000#) then
                              ext_select_ex1 <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           elsif (mem_addressData(28 downto 0) >= 16#1F802000# and mem_addressData(28 downto 0) < 16#1F804000#) then
                              ext_select_ex2 <= '1';
                              if (mem_rnw = '1') then
                                 state    <= BUSREADEXTERNAL;
                              else
                                 state    <= BUSWRITEEXTERNAL;
                              end if;
                           elsif (mem_rnw = '1' and mem_addressData(28 downto 0) >= 16#1FB20000# and mem_addressData(28 downto 0) <= 16#1FB20007#) then
                              -- MAME: unknown_r() returns 0x0000FFFF for all ZN platforms
                              state <= BUSREAD_UNKNOWNIO;
                           else
                              ext_lastactive <= '0';
                              if (mem_rnw = '0') then
                                 state   <= BUSWRITE;
                              else
                                 state   <= BUSREADREQUEST;
                                 waitcnt <= 0;
                              end if;
                           end if;
                        end if;
            
                     end if;
                     
                  end if;        

               when WAITFORRAMREAD =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state   <= IDLE;
                     ram_ena <= '1';
                     readram <= '1';
                  end if;
                  
               when WAITFORRAMWRITE =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     state   <= IDLE;
                     ram_ena  <= '1';
                     writeram <= '1';
                  end if;
                  
               when READBIOS =>
                  if (ram_done = '1') then
                     if (fastboot = '1' and to_integer(addressBIOS_buf) >= 16#18000# and to_integer(addressBIOS_buf) <= 16#18013#) then
                        case (to_integer(addressBIOS_buf(4 downto 2))) is
                           when 0 => biosPatch := x"3C011F80";
                           when 1 => biosPatch := x"3C0A0300";
                           when 2 => biosPatch := x"AC2A1814";
                           when 3 => biosPatch := x"03E00008";
                           when 4 => biosPatch := x"00000000";
                           when others => null;
                        end case;
                        case (addressBIOS_buf(1 downto 0)) is
                           when "00" => mem_dataRead_buf <= biosPatch;
                           when "01" => mem_dataRead_buf <= x"00" & biosPatch(31 downto 8);
                           when "10" => mem_dataRead_buf <= x"0000" & biosPatch(31 downto 16);
                           when "11" => mem_dataRead_buf <= x"000000" & biosPatch(31 downto 24);
                           when others => null;
                        end case;
                     elsif (PATCHSERIAL = '1' and (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC3# or to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC5#)) then
                        if (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC3#) then mem_dataRead_buf <= x"24010001"; end if;
                        if (to_integer(addressBIOS_buf(18 downto 2)) = 16#1BC5#) then mem_dataRead_buf <= x"AF81A9C0"; end if;
                     else
                        mem_dataRead_buf <= data_ram_rotate;
                     end if;
                        
                     state    <= WAITING;
                  end if;
                  
               when READROM =>
                  if (ram_done = '1') then
                     mem_dataRead_buf <= data_ram_rotate;
                     -- DIAG 2026-06-16: helper fetch-stream capture. This completion belongs
                     -- to the instr fetch tagged at READROM entry (fcap_pending). If its addr
                     -- is in the helper window 0x?280..0x?2A0, compare the delivered word to
                     -- ground truth and latch the FIRST mismatch (idx + low24 of wrong word).
                     if (fcap_pending = '1') then
                        fcap_pending <= '0';
                        if (fcap_iaddr >= to_unsigned(16#20280#, 22) and fcap_iaddr <= to_unsigned(16#2029C#, 22)) then
                           fcap_seen <= '1';
                           case fcap_iaddr(5 downto 2) is
                              when "0000" => fcap_exp := x"30A20001"; -- 0x280 andi v0,a1,1
                              when "0001" => fcap_exp := x"10400006"; -- 0x284 beqz v0,0x2A0
                              when "0010" => fcap_exp := x"00041A00"; -- 0x288 sll v1,a0,8
                              when "0011" => fcap_exp := x"94C20000"; -- 0x28C lhu v0,0(a2)
                              when "0100" => fcap_exp := x"00000000"; -- 0x290 nop
                              when "0101" => fcap_exp := x"00431021"; -- 0x294 addu v0,v0,v1
                              when "0110" => fcap_exp := x"0BF080AB"; -- 0x298 j 0x2AC
                              when "0111" => fcap_exp := x"A4A2FFFF"; -- 0x29C sh v0,-1(a1) (faulting store)
                              when others => fcap_exp := x"308200FF"; -- 0x2A0 andi v0,a0,0xFF (even path; out of window now)
                           end case;
                           if (fcap_mism = '0' and data_ram_rotate /= fcap_exp) then
                              fcap_mism <= '1';
                              fcap_idx  <= fcap_iaddr(5 downto 2);
                              fcap_word <= data_ram_rotate(23 downto 0);
                           end if;
                        end if;
                     end if;
                     -- FIX 2026-06-13: do NOT signal done + free the bus in the same
                     -- cycle as the capture. The fork-original immediate (mem_done_buf<='1';
                     -- state<=IDLE) let a back-to-back fetch clobber mem_dataRead_buf before
                     -- the CPU latched it (proven: controller read of 0x420000 = 0x1FC20038
                     -- correct, yet CPU received 0x1FC20298 = a neighbouring pointer).
                     -- Mirror PSX_MiSTer's READBIOS: hold the bus in WAITING (waitcnt) so the
                     -- buffered word survives until the CPU consumes it.
                     -- FIX 2026-06-16: for boot-program UNCACHED INSTRUCTION fetches (fcap_pending,
                     -- = the path the decompressor helper runs on), hold 25 cycles to MATCH PSX
                     -- READBIOS uncached-instr timing (PSX sets waitcnt=25/26 at entry, cpu.vhd is
                     -- byte-identical & validated against THAT cadence). The flat waitcnt<=1 gave
                     -- the CPU a 25x-faster uncached fetch it never sees on PSX, exposing a branch-
                     -- resolution race => decompressor andi/beqz odd-path AdES @0xBFC2029C. Data/
                     -- banked-ROM reads keep waitcnt<=1 (unchanged).
                     -- (waitcnt=25 timing-match experiment reverted: it did not fix the AdES, and
                     --  the dense waitcnt=1 timing keeps the andi->beqz->sh window inside the 64-
                     --  sample in-core trace ring.)
                     -- 2026-07-01: hold for the per-entry-latched READBIOS-matched cadence
                     -- (readrom_hold: instr=25, data=1/9/25 by reqsize) instead of flat 1,
                     -- so banked-ROM reads present the mem_done timing cpu.vhd is validated for.
                     waitcnt          <= readrom_hold;
                     state            <= WAITING;
                     -- build #49: EXACT-VALUE classification of the raw SDRAM word at the
                     -- single-word green anchor (CPU 0x1F644810). data_ram = ram_dataRead (raw,
                     -- not rotated). ROM holds 0x00200000 here. Split the mechanism:
                     --   palrd_green ([1]GREEN)        = hi halfword == 0x0020 (G1) -> CLEAN read
                     --   palrd_red   ([3]YELLOW)       = hi halfword == 0x0001 (R1) -> corrupted
                     --   palrd_redrow_red ([2]BLUE)    = lo halfword == 0x0001 (R1) -> +0x800 addr
                     --                                    offset (clean & >>5 both leave lo=BLK)
                     --   palrd_any   ([4]WHITE)        = anchor read fired
                     if (pal_read_pending = '1') then
                        palrd_any_seen <= '1';
                        palrd_value_latch <= data_ram;   -- build #50: capture raw word
                        -- build #52: store into the 8-word slot indexed by SDRAM addr bits[4:2]
                        case palrd_addr_latch(4 downto 2) is
                           when "000"  => palrd_w( 31 downto   0) <= data_ram;
                           when "001"  => palrd_w( 63 downto  32) <= data_ram;
                           when "010"  => palrd_w( 95 downto  64) <= data_ram;
                           when "011"  => palrd_w(127 downto  96) <= data_ram;
                           when "100"  => palrd_w(159 downto 128) <= data_ram;
                           when "101"  => palrd_w(191 downto 160) <= data_ram;
                           when "110"  => palrd_w(223 downto 192) <= data_ram;
                           when others => palrd_w(255 downto 224) <= data_ram;
                        end case;
                        if (data_ram(31 downto 16) = x"0020") then
                           palrd_green_seen <= '1';
                        end if;
                        if (data_ram(31 downto 16) = x"0001") then
                           palrd_red_seen <= '1';
                        end if;
                        if (data_ram(15 downto 0) = x"0001") then
                           palrd_redrow_red_seen <= '1';
                        end if;
                        pal_read_pending <= '0';
                     end if;
                  end if;

               when BUSWRITE =>
                  state        <= IDLE;

               when BUSREAD_CDSTUB =>
                  mem_dataRead_buf <= x"FFFFFFFF";
                  mem_done_buf     <= '1';
                  state            <= IDLE;

               when BUSREAD_UNKNOWNIO =>
                  mem_dataRead_buf <= x"0000FFFF";
                  mem_done_buf     <= '1';
                  state            <= IDLE;

               when BUSWRITEEXTERNAL => 
                  if (ext_state = EXT_IDLE) then
                     state          <= IDLE;
                  end if;
                  
               when BUSREADEXTERNAL => 
                  if (ext_done = '1') then
                     state          <= IDLE;
                     ext_lastactive <= '1';
                  end if;
                  
               when BUSREADREQUEST =>
                  state <= BUSREAD;
                  rotate32       <= '0';
                  rotate16       <= '0';
                  if (bus_memc_read  = '1') then rotate32 <= '1'; end if;
                  if (bus_pad_read   = '1') then rotate16 <= '1'; end if;
                  if (bus_sio_read   = '1') then rotate16 <= '1'; end if;
                  if (bus_memc2_read = '1') then rotate32 <= '1'; end if;
                  if (bus_dma_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_tmr_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_irq_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_gpu_read   = '1') then rotate32 <= '1'; end if;
                  if (bus_mdec_read  = '1') then rotate32 <= '1'; end if;
                  if (bus_znio_read  = '1') then rotate32 <= '1'; end if;

               when BUSREAD =>
                  if (bus_stall = '0') then
                     if (rotate32 = '1') then
                        case (addressData_buf(1 downto 0)) is
                           when "00" => mem_dataRead_buf <= dataFromBusses;
                           when "01" => mem_dataRead_buf <= x"00" & dataFromBusses(31 downto 8);
                           when "10" => mem_dataRead_buf <= x"0000" & dataFromBusses(31 downto 16);
                           when "11" => mem_dataRead_buf <= x"000000" & dataFromBusses(31 downto 24);
                           when others => null;
                        end case;
                     elsif (rotate16 = '1') then
                        if (addressData_buf(0) = '1') then
                           mem_dataRead_buf <= x"00" & dataFromBusses(31 downto 8);
                        else
                           mem_dataRead_buf <= dataFromBusses;
                        end if;
                     else
                        mem_dataRead_buf <= dataFromBusses;
                     end if;
                     mem_done_buf <= '1';
                     state        <= IDLE;
                  end if;
                  
               when WAITING =>
                  if (waitcnt > 0) then
                     waitcnt <= waitcnt - 1;
                  else
                     mem_done_buf <= '1';
                     state        <= IDLE;
                  end if;
                  
-- #################################################
-- ##################### EXE loading 
-- #################################################
                  
               when EXEPATCHBIOSWRITE =>
                  state       <= EXEPATCHBIOSWAIT;
                  ram_ena     <= '1';
                  ram_cache   <= '0';
                  ram_rnw     <= '0';
                  ram_be      <= "1111";
                  case (exestep) is
                     -- load PC
                     when 0 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#6FF0#, 17)) & "00"; ram_dataWrite <= x"3C08" & std_logic_vector(exe_initial_pc(31 downto 16));
                     when 1 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#6FF4#, 17)) & "00"; ram_dataWrite <= x"3508" & std_logic_vector(exe_initial_pc(15 downto  0));
                     when 2 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#6FF8#, 17)) & "00"; ram_dataWrite <= x"3C1C" & std_logic_vector(exe_initial_gp(31 downto 16));
                     when 3 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#6FFC#, 17)) & "00"; ram_dataWrite <= x"379C" & std_logic_vector(exe_initial_gp(15 downto  0));
                     -- load sp
                     when 4 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#7000#, 17)) & "00"; ram_dataWrite <= x"3C1D" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 5 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#7004#, 17)) & "00"; ram_dataWrite <= x"37BD" & std_logic_vector(exe_stackpointer(15 downto  0));
                     -- load fp
                     when 6 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#7008#, 17)) & "00"; ram_dataWrite <= x"3C1E" & std_logic_vector(exe_stackpointer(31 downto 16));
                     when 7 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#700C#, 17)) & "00"; ram_dataWrite <= x"01000008";
                     when 8 => ram_Adr <= "00001000" & std_logic_vector(to_unsigned(16#7010#, 17)) & "00"; ram_dataWrite <= x"37DE" & std_logic_vector(exe_stackpointer(15 downto  0));
                     when others => null;
                  end case;
                  if (exe_stackpointer = 0 and (exestep = 4 or exestep = 5 or exestep = 6 or exestep = 8)) then
                     ram_dataWrite <= (others => '0');
                  end if;
                  
                  if (exestep < 8) then
                     state   <= EXEPATCHBIOSWAIT;
                     exestep <= exestep + 1;
                  else
                     state <= EXECOPYREAD;
                  end if;
                  
               when EXEPATCHBIOSWAIT =>
                  if (ram_done = '1') then
                     state   <= EXEPATCHBIOSWRITE;
                  end if;
                  
               when EXECOPYREAD =>
                  if (ram_done = '1') then
                     if (execopycnt >= (exe_file_size + 3)) then
                        state           <= IDLE;
                        reset_exe       <= '1';
                        loadExe_latched <= '0';
                     else
                        state      <= EXECOPYWRITE;
                        ram_ena    <= '1';
                        ram_rnw    <= '1';
                        ram_Adr    <= "0010" & std_logic_vector(to_unsigned(16#800#, 23) + execopycnt(22 downto 0));
                     end if;
                  end if;
                  
               when EXECOPYWRITE =>
                  if (ram_done = '1') then
                     state         <= EXECOPYREAD;
                     ram_ena       <= '1';
                     ram_rnw       <= '0';
                     ram_Adr       <= "0000" & std_logic_vector(exe_load_address(22 downto 0) + execopycnt(22 downto 0));
                     ram_dataWrite <= ram_dataRead(31 downto 0);
                     execopycnt    <= execopycnt + 4;
                  end if;
                  
               when others => null;
            
            end case;
            
         else
         
            case (state) is
               when IDLE =>
                  if (SS_wren_SDRam = '1') then
                     ram_ena       <= '1';
                     ram_cache     <= '0';
                     ram_rnw       <= '0';
                     ram_Adr       <= "000000" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                     ram_be        <= "1111";
                     ram_dataWrite <= SS_DataWrite;
                  end if;
                  if (SS_rden_SDRam = '1') then
                     ram_ena       <= '1';
                     ram_cache     <= '0';
                     ram_rnw       <= '1';
                     ram_Adr       <= "000000" & std_logic_vector(SS_Adr(18 downto 0)) & "00";
                  end if;
            
               when others => null;
            end case;

         end if;
      end if;
   end process;
   
--##############################################################
--############################### external busses
--##############################################################
   
   
   ext_memctrl <= spu_memctrl when (ext_select_spu = '1') else
                  cd_memctrl  when (ext_select_cd  = '1') else
                  ex1_memctrl when (ext_select_ex1 = '1') else
                  ex2_memctrl when (ext_select_ex2 = '1') else
                  ex3_memctrl when (ext_select_ex3 = '1') else
                  (others => '0');
   
   
   bus_spu_addr      <= ext_bus_addr(9 downto 0);
   bus_spu_write     <= '1' when (ext_write_ena = '1' and ext_select_spu_saved = '1') else '0';
   bus_spu_read      <= '1' when (ext_state = EXT_READ_NEXT and ext_select_spu_saved = '1') else '0';
   bus_spu_dataWrite <= ext_dataWrite;
   
   bus_cd_addr       <= ext_bus_addr(3 downto 0);
   bus_cd_write      <= '1' when (ext_write_ena = '1' and ext_select_cd_saved = '1') else '0';
   bus_cd_read       <= '1' when (ext_state = EXT_READ_NEXT and ext_select_cd_saved = '1') else '0';
   bus_cd_dataWrite  <= ext_dataWrite(7 downto 0);
   
   bus_exp2_addr      <= ext_bus_addr;
   bus_exp2_write     <= '1' when (ext_write_ena = '1' and ext_select_ex2_saved = '1') else '0';
   bus_exp2_read      <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex2_saved = '1') else '0';
   bus_exp2_dataWrite <= ext_dataWrite(7 downto 0);
   
   -- busses EXP1+3 are stubs that are working in general, but there is nothing connected to them, so unused parts are not implemented
   bus_exp1_read     <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex1_saved = '1') else '0';
   bus_exp3_read     <= '1' when (ext_state = EXT_READ_NEXT and ext_select_ex3_saved = '1') else '0';
   
   ext_done          <= '1' when (ext_state = EXT_READ and ext_finished = '1') else '0';
   
   
   process (ext_select_spu_saved, ext_select_cd_saved, ext_select_ex1_saved, ext_select_ex2_saved, ext_select_ex3_saved,
            bus_spu_dataRead, bus_cd_dataRead, bus_exp1_dataRead, bus_exp2_dataRead, bus_exp3_dataRead,
            ext_byteStep, addressData_buf, ext_data)
   begin
   
      ext_data_new <= ext_data;
   
      if (ext_select_spu_saved = '1') then
         case (ext_byteStep) is
            when "00" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new( 7 downto  0) <= bus_spu_dataRead(15 downto 8); 
               else 
                  ext_data_new(15 downto  0) <= bus_spu_dataRead; 
               end if;
            when "10" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new(23 downto  8) <= bus_spu_dataRead;
               else 
                  ext_data_new(31 downto 16) <= bus_spu_dataRead; 
               end if;  
            when others => null;
         end case;
      elsif (ext_select_cd_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_cd_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_cd_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_cd_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_cd_dataRead;
            when others => null;
         end case;                 
      elsif (ext_select_ex1_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_exp1_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_exp1_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_exp1_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_exp1_dataRead;
            when others => null;
         end case;
      elsif (ext_select_ex2_saved = '1') then
         case (ext_byteStep) is
            when "00" => ext_data_new( 7 downto  0) <= bus_exp2_dataRead;
            when "01" => ext_data_new(15 downto  8) <= bus_exp2_dataRead;
            when "10" => ext_data_new(23 downto 16) <= bus_exp2_dataRead;
            when "11" => ext_data_new(31 downto 24) <= bus_exp2_dataRead;
            when others => null;
         end case;
      elsif (ext_select_ex3_saved = '1') then
         case (ext_byteStep) is
            when "00" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new( 7 downto  0) <= bus_exp3_dataRead(15 downto 8); 
               else 
                  ext_data_new(15 downto  0) <= bus_exp3_dataRead; 
               end if;
            when "10" => 
               if (addressData_buf(0) = '1') then 
                  ext_data_new(23 downto  8) <= bus_exp3_dataRead;
               else 
                  ext_data_new(31 downto 16) <= bus_exp3_dataRead; 
               end if;  
            when others => null;
         end case;
      end if;
 
   end process;
   
   
   process (clk1x)
      variable newWait : integer range 0 to 63;
   begin
      if rising_edge(clk1x) then
      
         ext_write_ena        <= '0';
         ext_recovered        <= '0';
         
         if (reset = '1') then

            ext_state     <= EXT_IDLE;
            ext_reccount  <= 0;

         elsif (ce = '1') then
         
            if (ext_reccount > 0) then
               ext_reccount  <= ext_reccount - 1;
               ext_recovered <= '1';
            end if;
         
            case (ext_state) is
            
               when EXT_IDLE =>
                  ext_finished         <= '0';
                  ext_dataWrite_buf    <= dataWrite_buf;
                  ext_writeMask_buf    <= writeMask_buf;
                  ext_byteStep         <= (others => '0');
                  ext_data             <= (others => '0');
                  ext_bus_addr         <= addressData_buf(12 downto 0);
                  
                  ext_select_spu_saved <= ext_select_spu;
                  ext_select_cd_saved  <= ext_select_cd;
                  ext_select_ex1_saved <= ext_select_ex1;
                  ext_select_ex2_saved <= ext_select_ex2;
                  ext_select_ex3_saved <= ext_select_ex3;

                  ext_memctrl_WDelay   <= ext_memctrl(3 downto 0);
                  ext_memctrl_RDelay   <= ext_memctrl(7 downto 4);
                  ext_memctrl_RecP     <= ext_memctrl(8);
                  ext_memctrl_Hold     <= ext_memctrl(9);
                  ext_memctrl_Float    <= ext_memctrl(10);
                  ext_memctrl_PStrobe  <= ext_memctrl(11);
                  ext_memctrl_width    <= ext_memctrl(12);
                  ext_memctrl_autoinc  <= ext_memctrl(13);
                  
                  if (state = BUSWRITEEXTERNAL) then
                  
                     ext_state  <= EXT_WRITE;
                     if (ext_reccount > 1) then
                        ext_state   <= EXE_WRITE_PREWAIT;
                        ext_waitcnt <= ext_reccount - 1;
                     end if;
                     
                     if (ext_memctrl(12) = '0' and writeMask_buf(2 downto 0) = "000") then
                        ext_byteStep                   <= "11";
                        ext_bus_addr(1 downto 0)       <= "11";
                     elsif (writeMask_buf(1 downto 0) = "00") then
                        ext_byteStep                   <= "10";
                        ext_bus_addr(1 downto 0)       <= "10";
                     elsif (ext_memctrl(12) = '0' and writeMask_buf(0) = '0') then
                        ext_byteStep                   <= "01";
                        ext_bus_addr(1 downto 0)       <= "01";
                     end if;

                  elsif (state = BUSREADEXTERNAL and ext_reccount = 0) then
                  
                     newWait := 0;
                     if (ext_lastactive = '1' and ext_recovered = '0') then
                        newWait := 1;
                     end if;
                     if (ext_memctrl(7 downto 4) > 0) then
                        newWait := newWait + to_integer(ext_memctrl(7 downto 4));
                     end if;
                     if (ext_memctrl(11) = '1' and com3_delay > ext_memctrl(7 downto 4)) then -- assumption from cd test! 
                        newWait := newWait + to_integer(com3_delay) - to_integer(ext_memctrl(7 downto 4));
                     end if;
                     ext_waitcnt <= newWait;
                     
                     if (newWait > 0) then
                        ext_state    <= EXT_READ_WAIT;
                     else
                        ext_state    <= EXT_READ_NEXT;
                     end if;
                        
                  end if;
                  
               -- write
               when EXE_WRITE_PREWAIT =>
                  if (ext_waitcnt > 0) then
                     ext_waitcnt    <= ext_waitcnt - 1;
                  else
                     ext_state  <= EXT_WRITE; 
                  end if;
               
               when EXT_WRITE =>
                  case (ext_byteStep) is
                     when "00" => if (ext_writeMask_buf(0) = '1') then ext_write_ena <= '1'; ext_dataWrite <=         ext_dataWrite_buf(15 downto  0); end if;
                     when "01" => if (ext_writeMask_buf(1) = '1') then ext_write_ena <= '1'; ext_dataWrite <= x"00" & ext_dataWrite_buf(15 downto  8); end if;
                     when "10" => if (ext_writeMask_buf(2) = '1') then ext_write_ena <= '1'; ext_dataWrite <=         ext_dataWrite_buf(31 downto 16); end if;
                     when "11" => if (ext_writeMask_buf(3) = '1') then ext_write_ena <= '1'; ext_dataWrite <= x"00" & ext_dataWrite_buf(31 downto 24); end if;
                     when others => null;
                  end case;
                  ext_state   <= EXT_WRITE_WAIT;
                  
                  newWait := to_integer(ext_memctrl_WDelay);
                  if (ext_memctrl_PStrobe = '1' and com3_delay > ext_memctrl_WDelay) then -- assumption from cd test! 
                     newWait := newWait + to_integer(com3_delay) - to_integer(ext_memctrl_WDelay);
                  end if;
                  if (ext_memctrl_Hold = '1') then
                     newWait := newWait + to_integer(com1_delay);
                  end if;
                  ext_waitcnt <= newWait;
                  
                  if (ext_memctrl_width = '0' and ext_byteStep = "11") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "01" and ext_writeMask_buf(3 downto 2) = "00") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "00" and ext_writeMask_buf(3 downto 1) = "000") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '1' and (ext_byteStep = "10" or ext_writeMask_buf(2) = '0')) then
                     ext_finished       <= '1';
                  end if;
                  
                  if (ext_memctrl_RecP = '1') then 
                     if (ext_memctrl_PStrobe = '1') then  -- assumption from cd test! 
                        ext_reccount <= to_integer(com0_delay) + to_integer(ext_memctrl_WDelay);
                     else
                        ext_reccount <= to_integer(com0_delay);
                     end if;
                  end if;
                  
               when EXT_WRITE_WAIT =>
                  if (ext_waitcnt > 0) then
                     ext_waitcnt    <= ext_waitcnt - 1;
                  elsif (ext_finished = '1') then
                     ext_state      <= EXT_IDLE;
                  else
                     
                     if (ext_memctrl_RecP = '1' and com0_delay > 1) then 
                        ext_state   <= EXE_WRITE_PREWAIT;
                        ext_waitcnt <= to_integer(com0_delay) - 2; 
                     else
                        ext_state   <= EXT_WRITE;
                     end if;
                     
                     if (ext_memctrl_width = '1') then
                        ext_byteStep             <= ext_byteStep + 2;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 2;
                        end if;
                     else
                        ext_byteStep             <= ext_byteStep + 1;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 1;
                        end if;
                     end if;
                  end if;
                  
               -- read
               when EXT_READ_NEXT =>
                  ext_state <= EXT_READ;
                  
                  if (ext_memctrl_width = '0' and ext_byteStep = "11") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "01" and reqsize_buf = "01") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '0' and ext_byteStep = "00" and reqsize_buf = "00") then
                     ext_finished       <= '1';
                  elsif (ext_memctrl_width = '1' and (ext_byteStep = "10" or reqsize_buf /= "10")) then
                     ext_finished       <= '1';
                  end if;
                  
                  newWait := 0;
                  if (ext_memctrl_RecP = '1') then 
                     newWait := newWait + to_integer(com0_delay);
                  end if;
                  if (ext_memctrl_Float = '1') then 
                     newWait := newWait + to_integer(com2_delay) + 1;
                  end if;
                  ext_reccount <= newWait;
                  
               when EXT_READ =>
               
                  ext_data <= ext_data_new;
               
                  if (ext_finished = '1') then
                     ext_state      <= EXT_IDLE;
                  else
                  
                     newWait  := to_integer(ext_memctrl_RDelay);
                     if (ext_memctrl_RecP = '1' and com0_delay > 0) then 
                        newWait := newWait + (to_integer(com0_delay) - 1); 
                     end if;
                     if (ext_memctrl_PStrobe = '1') then 
                        if (ext_memctrl_RecP = '0') then
                           newWait := newWait + to_integer(com3_delay);
                        elsif (com3_delay > com0_delay) then
                           newWait := newWait + to_integer(com3_delay) - to_integer(com0_delay);  -- assumption from cd test! 
                        end if;
                     end if;
                     if (ext_memctrl_Float = '1') then 
                        newWait := newWait + to_integer(com2_delay);
                     end if;
                     if (ext_memctrl_RecP = '1' and ext_memctrl_Float = '1') then -- assumption from exp2 read test! 
                        newWait := newWait + 1;
                     end if;
                     ext_waitcnt  <= newWait;
                  
                     if (newWait > 0) then
                        ext_state    <= EXT_READ_WAIT;
                     else
                        ext_state    <= EXT_READ_NEXT;
                     end if;
                     
                     if (ext_memctrl_width = '1') then
                        ext_byteStep             <= ext_byteStep + 2;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 2;
                        end if;
                     else
                        ext_byteStep             <= ext_byteStep + 1;
                        if (ext_memctrl_autoinc = '1') then
                           ext_bus_addr(1 downto 0) <= ext_bus_addr(1 downto 0) + 1;
                        end if;
                     end if;
                  end if;
                  
               when EXT_READ_WAIT =>
                  if (ext_waitcnt > 1) then
                     ext_waitcnt <= ext_waitcnt - 1;
                  else
                     ext_state   <= EXT_READ_NEXT;
                  end if;
            
            end case;
   
         end if;
         
      end if;
   end process;
   
--##############################################################
--############################### debug
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (reset = '1') then
         
            stallcountRead    <= 0;
            stallcountReadC    <= 0;
            stallcountWrite   <= 0;
            stallcountWriteF  <= 0;
            stallcountIntBus  <= 0;
      
         elsif (ce = '1') then
         
            if (stallcountRead = 0 and stallcountReadC = 0 and stallcountWrite = 0 and stallcountIntBus = 0 and stallcountWriteF = 0) then
               stallcountRead <= 0;
            end if;
            
            if (readram = '1') then
               stallcountRead <= stallcountRead + 1;
               if (ram_cache = '1') then
                  stallcountReadC <= stallcountReadC + 1;
               end if;
            end if;            
            
            if (writeram = '1') then
               stallcountWrite <= stallcountWrite + 1;
               if (addressDataF = '1') then
                  stallcountWriteF <= stallcountWriteF + 1;
               end if;
            end if;
            
            if (mem_request = '1') then
               addressDataF <= '0';
               if (mem_addressData(30) = '0' and mem_rnw = '0' and mem_addressData(28 downto 0) < 16#800000#) then
                  addressDataF <= '1';
               end if;
            end if;
            
            --if (state = BUSREAD or state = BUSWRITE or state = SPU_WRITE or state = SPU_READ or state = SPU_READ_WAIT or state = CD_READ or state = CD_READ_WAIT or state = CD_WRITE) then
            --   stallcountIntBus <= stallcountIntBus + 1;
            --end if;

         end if;
      end if;
   end process;

   -- build #39: expose Tecmo bank register for debug instrumentation
   zn_bank_8mb_out <= zn_bank_8mb;

   -- sim-only state probe (synthesizes to nothing observable; harmless)
   dbg_state_num <= tState'pos(state);

end architecture;





