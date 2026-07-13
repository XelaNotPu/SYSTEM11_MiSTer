-- ============================================================================
-- spu_zn1stub -- inert replacement for the PSX SPU on the System 11 core
-- ----------------------------------------------------------------------------
-- System 11 uses the Namco C352 for ALL audio; the PSX SPU is unused. The full
-- spu.vhd (voice ADSR/gauss/volume/reverb + sample RAM) costs ~4k ALMs and the
-- 13 SPU DSP multipliers. This stub replaces it with the same entity interface
-- but no audio datapath: register reads return 0 (SPUSTAT busy=0 so the BIOS's
-- SPU init proceeds without hanging), all outputs are driven inactive, and the
-- SPU sample-RAM / DMA / DDR / savestate interfaces are tied off.
--
-- Mirrors the cd_top_zn1stub approach used to strip the (also unused) CD-ROM.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spu is
   port (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      SPUon                : in  std_logic;
      SPUIRQTrigger        : in  std_logic;
      useSDRAM             : in  std_logic;
      REPRODUCIBLESPUIRQ   : in  std_logic;
      REPRODUCIBLESPUDMA   : in  std_logic;
      REVERBOFF            : in  std_logic;
      cpuPaused            : in  std_logic;
      spu_tick             : out std_logic := '0';
      cd_left              : in  signed(15 downto 0);
      cd_right             : in  signed(15 downto 0);
      irqOut               : out std_logic := '0';
      sound_timeout        : out std_logic := '0';
      sound_out_left       : out std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right      : out std_logic_vector(15 downto 0) := (others => '0');
      bus_addr             : in  unsigned(9 downto 0);
      bus_dataWrite        : in  std_logic_vector(15 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(15 downto 0) := (others => '0');
      spu_dmaRequest       : out std_logic := '0';
      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(15 downto 0) := (others => '0');
      dma_write            : in  std_logic;
      dma_writedata        : in  std_logic_vector(15 downto 0);
      sdram_dataWrite      : out std_logic_vector(31 downto 0) := (others => '0');
      sdram_Adr            : out std_logic_vector(18 downto 0) := (others => '0');
      sdram_be             : out std_logic_vector(3 downto 0)  := (others => '0');
      sdram_rnw            : out std_logic := '1';
      sdram_ena            : out std_logic := '0';
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      sdram_done           : in  std_logic;
      mem_request          : out std_logic := '0';
      mem_BURSTCNT         : out std_logic_vector(7 downto 0)  := (others => '0');
      mem_ADDR             : out std_logic_vector(19 downto 0) := (others => '0');
      mem_DIN              : out std_logic_vector(63 downto 0) := (others => '0');
      mem_BE               : out std_logic_vector(7 downto 0)  := (others => '0');
      mem_WE               : out std_logic := '0';
      mem_RD               : out std_logic := '0';
      mem_ack              : in  std_logic;
      mem_DOUT             : in  std_logic_vector(63 downto 0);
      mem_DOUT_READY       : in  std_logic;
      SS_reset             : in  std_logic;
      loading_savestate    : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(8 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0) := (others => '0');
      SS_idle              : out std_logic := '1';
      SS_RAM_dataWrite     : in  std_logic_vector(15 downto 0);
      SS_RAM_Adr           : in  std_logic_vector(18 downto 0);
      SS_RAM_request       : in  std_logic;
      SS_RAM_rnw           : in  std_logic;
      SS_RAM_dataRead      : out std_logic_vector(15 downto 0) := (others => '0');
      SS_RAM_done          : out std_logic := '0'
   );
end entity;

architecture arch of spu is
   -- Track SPUCNT (0x1F801DAA = byte offset 0x1AA). The BIOS sets the transfer
   -- mode here, kicks an SPU-RAM-clear DMA, and polls SPUSTAT (0x1AE) for the
   -- mode bits / DMA-request / busy. The full SPU is gone, so we model just
   -- enough: echo CNT into SPUSTAT, assert spu_dmaRequest in DMA mode, busy=0.
   signal cnt    : std_logic_vector(5 downto 0) := (others => '0');  -- SPUCNT[5:0]
   signal spustat : std_logic_vector(15 downto 0);
begin
   -- all audio/IRQ/DDR outputs inactive
   spu_tick        <= '0';
   irqOut          <= '0';
   sound_timeout   <= '0';
   sound_out_left  <= (others => '0');
   sound_out_right <= (others => '0');
   dma_readdata    <= (others => '0');

   -- SPUSTAT model: bits[5:0]=CNT[5:0], [7]=DMA req, [8]=DMA-read req,
   -- [9]=DMA-write req, [10]=transfer busy (=0). All else 0.
   process(cnt)
   begin
      spustat <= (others => '0');
      spustat(5 downto 0) <= cnt;
      if cnt(5 downto 4) = "10" then spustat(9) <= '1'; spustat(7) <= '1'; end if; -- DMA write req
      if cnt(5 downto 4) = "11" then spustat(8) <= '1'; spustat(7) <= '1'; end if; -- DMA read req
   end process;

   bus_dataRead <= spustat when bus_addr = to_unsigned(16#1AE#, 10) else (others => '0');
   -- DMA request when SPUCNT is in DMA-write("10") or DMA-read("11") mode
   spu_dmaRequest <= '1' when (cnt(5 downto 4) = "10" or cnt(5 downto 4) = "11") else '0';
   sdram_dataWrite <= (others => '0');
   sdram_Adr       <= (others => '0');
   sdram_be        <= (others => '0');
   sdram_rnw       <= '1';
   sdram_ena       <= '0';
   mem_request     <= '0';
   mem_BURSTCNT    <= (others => '0');
   mem_ADDR        <= (others => '0');
   mem_DIN         <= (others => '0');
   mem_BE          <= (others => '0');
   mem_WE          <= '0';
   mem_RD          <= '0';
   SS_DataRead     <= (others => '0');
   SS_idle         <= '1';               -- always idle (pause/savestate never wait)
   SS_RAM_dataRead <= (others => '0');

   -- capture SPUCNT transfer mode; acknowledge savestate-RAM requests
   process(clk1x)
   begin
      if rising_edge(clk1x) then
         if reset = '1' then
            cnt <= (others => '0');
         elsif bus_write = '1' and bus_addr = to_unsigned(16#1AA#, 10) then
            cnt <= bus_dataWrite(5 downto 0);
         end if;
         SS_RAM_done <= SS_RAM_request;
      end if;
   end process;

end architecture;
