-- cd_top_zn1stub.vhd
--
-- Drop-in replacement for cd_top.vhd in the ZN-1 core.
--
-- ZN-1 arcade titles do not use the CD-ROM subsystem. They load all data
-- from banked ROM (via the bank register at 0x1FB00006) plus the Tecmo
-- COH-1002M BIOS in the lower region. Yet the parent PSX_MiSTer's cd_top
-- entity is still instantiated in psx_top.vhd, costing ~10-15% of the
-- Cyclone V's ALMs and providing a latent bug surface: irq_CDROM can fire,
-- resetFromCD can pulse, DMA channel 3 can sequence, all without the game
-- expecting any of it.
--
-- This stub matches cd_top's entity port-for-port but drives every output
-- to a safe inactive value. None of the bus reads return data, no IRQs are
-- generated, no DMA fires, the system never gets reset from CD.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cd_top_zn1stub is
   port
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;

      INSTANTSEEK          : in  std_logic;
      FORCECDSPEED         : in  std_logic_vector(2 downto 0);
      LIMITREADSPEED       : in  std_logic;
      hasCD                : in  std_logic;
      LIDopen              : in  std_logic;
      fastCD               : in  std_logic;
      testSeek             : in  std_logic;
      pauseOnCDSlow        : in  std_logic;
      region               : in  std_logic_vector(1 downto 0);
      region_out           : out std_logic_vector(1 downto 0);

      pauseCD              : out std_logic := '0';
      Pause_idle_cd        : out std_logic := '1';   -- always "idle" so anyone waiting on this proceeds
      fullyIdle            : out std_logic := '1';
      cdSlow               : out std_logic := '0';
      error                : out std_logic := '0';
      LBAdisplay           : out unsigned(19 downto 0) := (others => '0');

      irqOut               : out std_logic := '0';

      spu_tick             : in  std_logic;
      cd_left              : out signed(15 downto 0) := (others => '0');
      cd_right             : out signed(15 downto 0) := (others => '0');

      mdec_idle            : in  std_logic;

      bus_addr             : in  unsigned(3 downto 0);
      bus_dataWrite        : in  std_logic_vector(7 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(7 downto 0) := (others => '0');

      dma_read             : in  std_logic;
      dma_readdata         : out std_logic_vector(7 downto 0) := (others => '0');

      cd_hps_req           : out std_logic := '0';
      cd_hps_lba           : out std_logic_vector(31 downto 0) := (others => '0');
      cd_hps_lba_sim       : out std_logic_vector(31 downto 0) := (others => '0');
      cd_hps_ack           : in  std_logic;
      cd_hps_write         : in  std_logic;
      cd_hps_data          : in  std_logic_vector(15 downto 0);

      trackinfo_data       : in  std_logic_vector(31 downto 0);
      trackinfo_addr       : in  std_logic_vector(8 downto 0);
      trackinfo_write      : in  std_logic;
      resetFromCD          : out std_logic := '0';

      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(13 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0) := (others => '0');
      SS_idle              : out std_logic := '1'
   );
end entity;

architecture stub of cd_top_zn1stub is
begin
   region_out     <= region;       -- pass-through (consumer reads this on init)
   pauseCD        <= '0';
   Pause_idle_cd  <= '1';
   fullyIdle      <= '1';
   cdSlow         <= '0';
   error          <= '0';
   LBAdisplay     <= (others => '0');
   irqOut         <= '0';
   cd_left        <= (others => '0');
   cd_right       <= (others => '0');
   bus_dataRead   <= (others => '0');
   dma_readdata   <= (others => '0');
   cd_hps_req     <= '0';
   cd_hps_lba     <= (others => '0');
   cd_hps_lba_sim <= (others => '0');
   resetFromCD    <= '0';
   SS_DataRead    <= (others => '0');
   SS_idle        <= '1';
end architecture;
