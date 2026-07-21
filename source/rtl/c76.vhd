-- ============================================================================
-- c76 -- Namco C76 sound/IO MCU wrapper (synthesizable)
-- ----------------------------------------------------------------------------
-- Wraps the m37702 core with the C76 on-chip memory map and forwards off-chip
-- accesses to the System 11 substrate. Internal regions are served here; the
-- external bus carries everything else (input ports, C352, shared RAM, SPROG).
--
-- C76 internal map (M37702M2, m37710.cpp m37702m2_device::map):
--   0x000000-0x00007F  SFR (peripheral regs)      -> stub here (read 0)  [*]
--   0x000080-0x00027F  internal RAM (512 B)        -> block RAM here
--   0x00C000-0x00FFFF  internal BIOS ROM (16 KB)   -> ROM here (c76.mif)
--   everything else                                -> external bus (ext_*)
--
-- [*] The on-chip peripherals (timers/UART/A-D/IRQ-ctrl/ports) are a later
--     phase (docs/system11-m37702-core-plan.md §5). For now SFR reads return 0
--     and writes are accepted, which is enough to bring up the BIOS init path.
--     IRQ0/IRQ2 are driven externally for the first cut.
--
-- Internal ROM/RAM use registered (1-cycle) reads; the core's bus handshake
-- waits on bus_ready, so the wrapper raises ready one cycle after an internal
-- access is issued. External accesses pass ext_ready/ext_din straight through.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
-- C76 internal BIOS is LOADED AT RUNTIME via MRA/ioctl (namcoc76.zip c76.bin, ioctl index 8).
-- No ROM contents are embedded in this source.

entity c76 is
   port (
      clk        : in  std_logic;
      ce         : in  std_logic;
      reset      : in  std_logic;

      -- C76 internal BIOS download port (ioctl index 8, byte stream)
      bios_wr    : in  std_logic := '0';
      bios_addr  : in  std_logic_vector(13 downto 0) := (others => '0');
      bios_din   : in  std_logic_vector(7 downto 0) := (others => '0');

      -- interrupt request lines (driven by the substrate; 60 Hz IRQ0/IRQ2 first cut)
      irq0       : in  std_logic;
      irq1       : in  std_logic;
      irq2       : in  std_logic;

      -- 2026-07-06: analog inputs (Tekken P1 kicks ride ADC ch1/ch2; idle = 0xFF)
      -- 2026-07-13: AN0 added — Pocket Racer's steering wheel (PADDLE, centre 0x80,
      -- legal range 0x38-0xC8 per MAME); AN1 doubles as its pedal (idle 0x00).
      in_adc0    : in  std_logic_vector(7 downto 0) := x"FF";
      in_adc1    : in  std_logic_vector(7 downto 0) := x"FF";
      in_adc2    : in  std_logic_vector(7 downto 0) := x"FF";

      -- external bus to the System 11 substrate (input ports, C352, shared RAM, SPROG)
      ext_addr   : out std_logic_vector(23 downto 0);
      ext_dout   : out std_logic_vector(7 downto 0);
      ext_din    : in  std_logic_vector(7 downto 0);
      ext_rd     : out std_logic;
      ext_wr     : out std_logic;
      ext_ready  : in  std_logic;

      -- debug / verification taps (passthrough from core)
      dbg_pc     : out std_logic_vector(23 downto 0);
      dbg_opcode : out std_logic_vector(7 downto 0);
      dbg_valid  : out std_logic;
      dbg_halted : out std_logic;
      dbg_x      : out std_logic_vector(15 downto 0);
      -- internal-RAM taps: 0x83 = the TB0 ISR's toggle byte the 0xC151 wait loop polls;
      -- 0x80 = the flag byte whose bit6 gates the toggle path (BBS #$40,$80 @0xC26D).
      dbg_ram80  : out std_logic_vector(7 downto 0);
      dbg_ram83  : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of c76 is

   -- core <-> wrapper bus
   signal cpu_addr  : std_logic_vector(23 downto 0);
   signal cpu_dout  : std_logic_vector(7 downto 0);
   signal cpu_din   : std_logic_vector(7 downto 0);
   signal cpu_rd    : std_logic;
   signal cpu_wr    : std_logic;
   signal cpu_ready : std_logic;

   -- region decode (on the live core address)
   signal sel_rom : std_logic;   -- 0xC000-0xFFFF
   signal sel_ram : std_logic;   -- 0x0080-0x027F
   signal sel_sfr : std_logic;   -- 0x0000-0x007F
   signal sel_int : std_logic;   -- any internal
   signal sel_ext : std_logic;   -- external bus

   -- internal ROM: 16 KB, initialised from c76.bin via the generated constant
   signal rom_q_ram : std_logic_vector(7 downto 0);
   signal rom_q : std_logic_vector(7 downto 0);

   -- internal RAM: 512 B
   type ram_t is array(0 to 511) of std_logic_vector(7 downto 0);
   -- HW-accurate: the inferred RAM has INIT_FILE=UNUSED -> M10K powers up to 0 on
   -- silicon. GHDL defaults to 'U' which can MASK a read-before-write bug, so init to
   -- 0 to match hardware (harmless on HW: it already powers up to 0).
   signal ram : ram_t := (others => (others => '0'));
   signal ram_q : std_logic_vector(7 downto 0);

   -- READ-AFTER-WRITE BYPASS (2026-06-25): the registered read ram_q reflects the address
   -- presented LAST cycle. When a write to X is immediately followed by a read of X (push then
   -- pull / stack-relative load), int_ready fires at once (addr_prev=X) but ram_q still holds the
   -- PRE-write value -> the read gets stale data, corrupting the C76 stack -> the BRK-handler RTI
   -- returns to garbage (HW derail to 0x12 that the simple sim model didn't expose). Forward the
   -- just-written byte when the registered write addr matches the address ram_q corresponds to.
   signal ram_wr_d    : std_logic := '0';
   signal ram_waddr_d : unsigned(8 downto 0) := (others => '0');
   signal ram_wdata_d : std_logic_vector(7 downto 0) := (others => '0');
   signal ram_raddr_d : unsigned(8 downto 0) := (others => '0');
   signal ram_q_bp    : std_logic_vector(7 downto 0);

   -- internal access pipeline: registered read => data + ready one cycle later.
   -- int_ready/sel_*_d are all the 1-cycle-delayed view of the issue cycle, so
   -- they line up with rom_q/ram_q (which also reflect the issue-cycle address).
   signal int_ready   : std_logic;
   signal sel_rom_d   : std_logic;
   signal sel_ram_d   : std_logic;
   signal addr_prev   : std_logic_vector(23 downto 0) := (others => '1');  -- prev issue addr (for data-valid gate)
   signal ram_idx     : unsigned(8 downto 0);  -- 0..511 index into internal RAM (addr-0x80)

   -- SFR (0x00-0x7F) register file. The C76 BIOS WRITES many internal peripheral
   -- regs (timer regs, mode, int-control) during init then READS THEM BACK; the old
   -- stub ignored writes + returned 0, so readbacks failed and the BIOS branched
   -- wrong (eventually JSR to unmapped 0x1C00 -> hang). Back the SFR space with a
   -- 128-byte register file (stores writes, returns them); A/D conv regs (0x20-0x2F)
   -- always read 0xFF (idle analog). Async read (small, not block RAM).
   type sfr_t is array(0 to 127) of std_logic_vector(7 downto 0);
   -- init: A/D region 0xFF, a few hardware-default read values seen in MAME.
   impure function sfr_init return sfr_t is
      variable s : sfr_t := (others => x"00");
   begin
      for i in 16#20# to 16#2F# loop s(i) := x"FF"; end loop;  -- A/D idle
      s(16#0E#) := x"1E"; s(16#40#) := x"4C"; s(16#70#) := x"05";
      return s;
   end function;
   signal sfr_mem     : sfr_t := sfr_init;
   signal sfr_idx     : integer range 0 to 127;
   signal sfr_q       : std_logic_vector(7 downto 0);

   -- Timer B0 (the C76's periodic service tick). The firmware enables IC_TB0 (SFR 0x7A,
   -- priority bits != 0) and the TB0 interrupt handler @0xC25E toggles dp 0x83 to release
   -- the main wait loop so the C76 processes MIPS commands. Minimal model: a prescaled
   -- 16-bit down-counter reloading from TB0 (SFR 0x50/0x51), pulsing tb0_tick on underflow.
   signal tb0_presc  : unsigned(5 downto 0) := (others => '0');  -- /64 prescaler
   signal tb0_cnt    : unsigned(15 downto 0) := (others => '0');
   signal tb0_tick   : std_logic := '0';
   signal tb0_armed  : std_logic := '0';

   -- Timer B1 (the C76's MAIN service tick). Armed at init from SPROG (reload SFR 0x52/0x53,
   -- started via SFR 0x40 bit6). Its handler @0xC31F (-> 0xB946 -> mailbox service) is the
   -- most-frequent ISR (357x/run in MAME) — it does the MIPS<->C76 mailbox handshake.
   signal tb1_presc  : unsigned(5 downto 0) := (others => '0');  -- /64 prescaler
   signal tb1_cnt    : unsigned(15 downto 0) := (others => '0');
   signal ad_cnt   : unsigned(11 downto 0) := (others=>'0');
   signal ad_tick  : std_logic := '0';
   signal ad_clear : std_logic := '0';
   signal tb1_tick   : std_logic := '0';
   signal tb1_armed  : std_logic := '0';

   -- Timer A2/A3 (2026-07-06): the MUSIC TEMPO timers. The SPROG sets TA2MODE/TA3MODE=0x11,
   -- reload 0x8000 (SFR 0x4B:0x4A / 0x4D:0x4C) and keeps count-start bits 2/3 of SFR 0x40 set
   -- (init 0x4C, runtime 0x6C). Without these ticking, the music sequencer never advances ->
   -- voices stay init-keyed with freq=0 -> total silence (the HW symptom). Clock = f2 (mode
   -- bits 7:6 = 00 -> ce/2), 16-bit down-counter, tick on underflow, reload (periodic model).
   signal ta2_presc  : std_logic := '0';
   signal ta2_cnt    : unsigned(15 downto 0) := (others => '0');
   signal ta2_tick   : std_logic := '0';
   signal ta2_armed  : std_logic := '0';
   signal ta3_presc  : std_logic := '0';
   signal ta3_cnt    : unsigned(15 downto 0) := (others => '0');
   signal ta3_tick   : std_logic := '0';
   signal ta3_armed  : std_logic := '0';

begin

   -- ---- region decode ----------------------------------------------------
   sel_rom <= '1' when (unsigned(cpu_addr) >= x"00C000" and unsigned(cpu_addr) <= x"00FFFF") else '0';
   sel_ram <= '1' when (unsigned(cpu_addr) >= x"000080" and unsigned(cpu_addr) <= x"00027F") else '0';
   sel_sfr <= '1' when (unsigned(cpu_addr) <= x"00007F") else '0';
   sel_int <= sel_rom or sel_ram or sel_sfr;
   sel_ext <= not sel_int;
   ram_idx <= resize(unsigned(cpu_addr(9 downto 0)) - 16#80#, 9);  -- low 9 bits of (addr-0x80)

   -- ---- external bus is just the core bus, gated to external addresses ----
   ext_addr <= cpu_addr;
   ext_dout <= cpu_dout;
   ext_rd   <= cpu_rd and sel_ext;
   ext_wr   <= cpu_wr and sel_ext;

   -- C76 internal BIOS RAM: loaded at runtime via MRA/ioctl (bios_* port, index 8).
   -- Write port is RAW clk — MUST NOT be reset/ce gated (the download happens during core reset).
   ibiosram : entity work.dpram
   generic map (addr_width => 14, data_width => 8)
   port map (
      clock_a   => clk,
      address_a => bios_addr,
      data_a    => bios_din,
      wren_a    => bios_wr,
      clock_b   => clk,
      address_b => cpu_addr(13 downto 0),
      q_b       => rom_q_ram
   );

   -- ---- internal ROM/RAM (registered read) + SFR + ready timing ----------
   process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' then
            sel_rom_d  <= '0';
            sel_ram_d  <= '0';
            addr_prev  <= (others => '1');   -- != any first addr -> int_ready starts 0
         elsif ce = '1' then
            -- ROM: unconditional registered read (clean block-ROM inference; the
            -- mux downstream selects it only when sel_rom_d). ram_init_file loads c76.bin.
            rom_q <= rom_q_ram;
            -- RAM: registered write + unconditional registered read (block-RAM inference)
            if sel_ram = '1' and cpu_wr = '1' then
               ram(to_integer(ram_idx)) <= cpu_dout;
            end if;
            ram_q <= ram(to_integer(ram_idx));
            -- registered write info for the read-after-write bypass (lines up with ram_q's address)
            ram_wr_d    <= sel_ram and cpu_wr;
            ram_waddr_d <= ram_idx;
            ram_wdata_d <= cpu_dout;
            ram_raddr_d <= ram_idx;

            -- SFR register file: store BIOS writes so readbacks return them.
            -- A/D region (0x20-0x2F) is read-only 0xFF (handled in sfr_q), so don't
            -- let writes clobber its idle value.
            -- A-D one-shot completion: clear the ADCON start bit (bit6 of SFR 0x1E) when the
            -- conversion finishes (ad_clear pulse from the AD model below). CPU writes win.
            if ad_clear = '1' then
               sfr_mem(16#1E#)(6) <= '0';
            end if;
            if sel_sfr = '1' and cpu_wr = '1'
               and not (unsigned(cpu_addr(7 downto 0)) >= x"20" and unsigned(cpu_addr(7 downto 0)) <= x"2F") then
               sfr_mem(to_integer(unsigned(cpu_addr(6 downto 0)))) <= cpu_dout;
               -- synthesis translate_off
-- synthesis translate_off
               if (unsigned(cpu_addr(7 downto 0)) >= x"40" and unsigned(cpu_addr(7 downto 0)) <= x"5F")
                  or (unsigned(cpu_addr(7 downto 0)) >= x"70" and unsigned(cpu_addr(7 downto 0)) <= x"7F") then
                  report "SFRWR " & to_hstring(cpu_addr(7 downto 0)) & " " & to_hstring(cpu_dout);
               end if;
-- synthesis translate_on
               if unsigned(cpu_addr(7 downto 0)) = x"40" or unsigned(cpu_addr(7 downto 0)) = x"52"
                  or unsigned(cpu_addr(7 downto 0)) = x"53" then
                  report "DBG SFR WR [" & to_hstring(cpu_addr(7 downto 0)) & "]=" & to_hstring(cpu_dout);
               end if;
               -- synthesis translate_on
            end if;

            -- one-cycle internal access: data (rom_q/ram_q) and ready both land
            -- the cycle after the access is issued, so register the issue-cycle
            -- selection straight through (no extra delay stage).
            sel_rom_d <= sel_rom;
            sel_ram_d <= sel_ram;
            addr_prev <= cpu_addr;   -- 1-cycle-delayed issue address (data-valid gate)
         end if;
      end if;
   end process;

   -- ---- read data + ready back to the core -------------------------------
   -- SFR read model (combinational): A/D conv 0x20-0x2F -> 0xFF (idle analog),
   -- everything else from the register file (returns what the BIOS wrote / init).
   sfr_idx <= to_integer(unsigned(cpu_addr(6 downto 0)));
   -- A/D result regs: ADi low byte at 0x20+2i (8-bit conversions). Tekken: ch1 = P1
   -- BTN4/right kick, ch2 = P1 BTN3/left kick (MAME tekken INPUT_PORTS); rest idle 0xFF.
   sfr_q   <= in_adc0 when (unsigned(cpu_addr(7 downto 0)) = x"20")
              else in_adc1 when (unsigned(cpu_addr(7 downto 0)) = x"22")
              else in_adc2 when (unsigned(cpu_addr(7 downto 0)) = x"24")
              -- Pocket Racer fix: AD0 high byte (10-bit A-D result bits 9:8) must be 0 for an 8-bit
              -- reading. It was 0xFF, so a 16-bit AD0 read of the steering (AN0) saw 0xFF80 (pegged
              -- past legal max) -> the C76 flagged a steering fault at shram 0xBD32 -> game hung
              -- polling 0xBD32. AN1/AN2 high bytes stay 0xFF (Tekken kicks read the low byte only).
              else x"00" when (unsigned(cpu_addr(7 downto 0)) = x"21")
              else x"FF" when (unsigned(cpu_addr(7 downto 0)) >= x"20" and unsigned(cpu_addr(7 downto 0)) <= x"2F")
              -- 2026-07-06 MUSIC-TEMPO FIX: timer COUNTER reads must return the LIVE down-count
              -- (the SPROG's sequencer POLLS TA2/TA3 for tempo -- their IC priorities stay 0, no
              -- IRQ; a static readback froze musical time -> no notes -> silence).
              else std_logic_vector(ta2_cnt(7 downto 0))  when (unsigned(cpu_addr(7 downto 0)) = x"4A")
              else std_logic_vector(ta2_cnt(15 downto 8)) when (unsigned(cpu_addr(7 downto 0)) = x"4B")
              else std_logic_vector(ta3_cnt(7 downto 0))  when (unsigned(cpu_addr(7 downto 0)) = x"4C")
              else std_logic_vector(ta3_cnt(15 downto 8)) when (unsigned(cpu_addr(7 downto 0)) = x"4D")
              else std_logic_vector(tb0_cnt(7 downto 0))  when (unsigned(cpu_addr(7 downto 0)) = x"50")
              else std_logic_vector(tb0_cnt(15 downto 8)) when (unsigned(cpu_addr(7 downto 0)) = x"51")
              else std_logic_vector(tb1_cnt(7 downto 0))  when (unsigned(cpu_addr(7 downto 0)) = x"52")
              else std_logic_vector(tb1_cnt(15 downto 8)) when (unsigned(cpu_addr(7 downto 0)) = x"53")
              else sfr_mem(sfr_idx);

   -- A CURRENT external access must win over the 1-cycle-DELAYED internal selects
   -- (sel_rom_d/sel_ram_d). Otherwise, on an internal(ROM/RAM)->external transition,
   -- sel_rom_d/sel_ram_d are still 1 from the prior internal fetch and wrongly steer
   -- cpu_din to the STALE rom_q/ram_q instead of ext_din. (This corrupted the low
   -- byte of JMP ($bef2): the prior ROM fetch's byte leaked in. Found via trace-diff.)
   -- read-after-write bypass: if the registered write targets the same cell ram_q reflects,
   -- forward the just-written byte (ram_q would be the stale pre-write value).
   ram_q_bp <= ram_wdata_d when (ram_wr_d = '1' and ram_waddr_d = ram_raddr_d) else ram_q;
   cpu_din <= ext_din when sel_ext = '1' else
              rom_q   when sel_rom_d = '1' else
              ram_q_bp when sel_ram_d = '1' else
              sfr_q;                          -- SFR peripheral reads
   -- Internal access ready (combinational): the registered rom_q/ram_q reflect the
   -- address presented ONE cycle ago, so the data is only valid for the current
   -- access once the issue address has been stable a cycle (cpu_addr = addr_prev).
   -- This forces exactly a 1-cycle stall per internal access and stops the core
   -- from completing a back-to-back read on stale (previous-byte) data. The old
   -- `int_ready <= sel_int and (cpu_rd or cpu_wr)` stayed high across consecutive
   -- internal accesses -> stale reads -> divergence (only visible vs the m37702-direct
   -- sim because that one used combinational zero-wait memory). Found via tb_c76full.
   int_ready <= '1' when (sel_int = '1' and (cpu_rd = '1' or cpu_wr = '1')
                          and cpu_addr = addr_prev) else '0';

   cpu_ready <= ext_ready when sel_ext = '1' else int_ready;

   -- debug taps into internal RAM (combinational): 0x80 -> ram(0), 0x83 -> ram(3)
   dbg_ram80 <= ram(0);
   dbg_ram83 <= ram(3);

   -- ---- core -------------------------------------------------------------
   -- M37702 RE-INSTATED 2026-06-18: posedge cache fixed the kernel derail (the congestion timing
   -- fails were non-boot-critical), so restore the C76 to test whether the post-decompressor panic
   -- is a C76 handshake/POST check (M37702 was stubbed during the congestion test).
   icpu : entity work.m37702
      port map (
         clk => clk, ce => ce, reset => reset,
         bus_addr => cpu_addr, bus_dout => cpu_dout, bus_din => cpu_din,
         bus_rd => cpu_rd, bus_wr => cpu_wr, bus_ready => cpu_ready,
         irq0 => irq0, irq1 => irq1, irq2 => irq2, irq_tb0 => tb0_tick, irq_tb1 => tb1_tick,
         irq_ta2 => ta2_tick, irq_ta3 => ta3_tick,
         irq_ad => ad_tick,
         -- per-source interrupt PRIORITY from the IC registers (SFR 0x7A..0x7F bits[2:0]):
         -- TB0=0x7A TB1=0x7B INT0=0x7D INT1=0x7E INT2=0x7F. Enables IPL priority masking so a
         -- low-priority source (TB1=2) cannot nest inside a higher ISR (INT0/INT2/TB0=3/4).
         prio_tb0  => unsigned(sfr_mem(16#7A#)(2 downto 0)),
         prio_tb1  => unsigned(sfr_mem(16#7B#)(2 downto 0)),
         prio_ta2  => unsigned(sfr_mem(16#77#)(2 downto 0)),
         prio_ta3  => unsigned(sfr_mem(16#78#)(2 downto 0)),
         prio_int0 => unsigned(sfr_mem(16#7D#)(2 downto 0)),
         prio_int1 => unsigned(sfr_mem(16#7E#)(2 downto 0)),
         prio_int2 => unsigned(sfr_mem(16#7F#)(2 downto 0)),
         -- A-D conversion interrupt: IC_AD @SFR 0x70 (M37702 SFR map), vector 0xFFD6 -> ISR 0xC30D.
         prio_ad   => unsigned(sfr_mem(16#70#)(2 downto 0)),
         dbg_pc => dbg_pc, dbg_opcode => dbg_opcode,
         dbg_valid => dbg_valid, dbg_halted => dbg_halted, dbg_x => dbg_x
      );

   -- ---- A-D converter (2026-07-05): minimal MAME-equivalent model -------------
   -- M37702 ADCON = SFR 0x1E: bit6 = conversion START, bit7? repeat mode bits vary; MAME's
   -- m37710 completes a conversion ~57 cycles after the start bit and raises the AD IRQ
   -- (vector 0xFFD6 -> firmware ISR 0xC30D — the C76's periodic input/publish service that
   -- cycles shram 0xBDA4 in MAME every ~2ms; it was DEAD here because the ADC was a stub,
   -- which parked Tekken's AV-synced attract/movie sequencer). Result registers 0x20-0x2F
   -- already read 0xFF (idle analog) from the SFR read model. On completion: pulse ad_tick
   -- and clear the start bit (one-shot; the ISR restarts it — matching m37710's behavior
   -- of re-arming per scan). If the firmware uses repeat mode the restart comes from its ISR.
   process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' then
            ad_cnt  <= (others=>'0');
            ad_tick <= '0';
         elsif ce = '1' then
            ad_tick <= '0';
            ad_clear <= '0';
            if sfr_mem(16#1E#)(6) = '1' then
               -- golden timing (MAME m37710): 8-channel sweep = 8 x 228 clocks = 1824 (~108us
               -- @16.9MHz); one-shot IRQ at sweep end (subagent-verified vs MAME :c76 trace)
               if ad_cnt = 1824 then
                  ad_cnt   <= (others=>'0');
                  ad_tick  <= '1';
                  ad_clear <= '1';               -- 1-cycle pulse: SFR process clears ADCON bit6
               else
                  ad_cnt <= ad_cnt + 1;
               end if;
            else
               ad_cnt <= (others=>'0');
            end if;
         end if;
      end if;
   end process;

   -- ---- Timer B0: periodic tick interrupt (the C76 service-loop clock) -------
   -- Armed when the firmware has enabled the TB0 interrupt (IC_TB0 @SFR 0x7A priority
   -- bits[2:0] != 0). Counts down a /64-prescaled clock from the TB0 reload (SFR 0x51:0x50);
   -- on underflow pulses tb0_tick (taken by the m37702 at vector 0xFFE4 -> handler 0xC25E).
   process(clk)
      variable reload : unsigned(15 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            tb0_presc <= (others=>'0'); tb0_cnt <= (others=>'0');
            tb0_tick <= '0'; tb0_armed <= '0';
         elsif ce = '1' then
            tb0_tick <= '0';
            reload := unsigned(sfr_mem(16#51#)) & unsigned(sfr_mem(16#50#));
            -- Gate on count_start (SFR 0x40) bit 5 = the TB0 START bit, exactly as the
            -- m37710 hardware does. The C76's INT0 handler sets up [0x80] then STARTS the
            -- timer via SEB #$20,$40 @0xC37B — so the timer only runs AFTER that setup,
            -- ensuring the INT0 service ran first (else the TB0 handler crashes). reload!=0
            -- guards against a not-yet-configured count register.
            if sfr_mem(16#40#)(5) = '1' and reload /= 0 then
               if tb0_armed = '0' then                       -- just enabled: load
                  -- synthesis translate_off
                  report "DBG TB0 ARMED reload=" & to_hstring(reload);
                  -- synthesis translate_on
                  tb0_armed <= '1'; tb0_presc <= (others=>'0');
                  tb0_cnt <= reload;
               else
                  if tb0_presc = 63 then
                     tb0_presc <= (others=>'0');
                     if tb0_cnt = 0 then
                        tb0_cnt  <= reload;                   -- reload
                        tb0_tick <= '1';                      -- fire the TB0 interrupt
                     else
                        tb0_cnt <= tb0_cnt - 1;
                     end if;
                  else
                     tb0_presc <= tb0_presc + 1;
                  end if;
               end if;
            else
               tb0_armed <= '0';
            end if;
         end if;
      end if;
   end process;

   -- ---- Timer A2/A3: music tempo timers (see signal comments) ---------------
   process(clk)
      variable reload2 : unsigned(15 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            ta2_presc <= '0'; ta2_cnt <= (others=>'0'); ta2_tick <= '0'; ta2_armed <= '0';
         elsif ce = '1' then
            ta2_tick <= '0';
            reload2 := unsigned(sfr_mem(16#4B#)) & unsigned(sfr_mem(16#4A#));
            if sfr_mem(16#40#)(2) = '1' and reload2 /= 0 then
               if ta2_armed = '0' then
                  ta2_armed <= '1'; ta2_presc <= '0'; ta2_cnt <= reload2;
-- synthesis translate_off
                  report "DBG TA2 ARMED reload=" & to_hstring(reload2);
-- synthesis translate_on
               else
                  ta2_presc <= not ta2_presc;
                  if ta2_presc = '1' then
                     if ta2_cnt = 0 then
                        ta2_cnt <= reload2; ta2_tick <= '1';
                     else
                        ta2_cnt <= ta2_cnt - 1;
                     end if;
                  end if;
               end if;
            else
               ta2_armed <= '0';
            end if;
         end if;
      end if;
   end process;

   process(clk)
      variable reload3 : unsigned(15 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            ta3_presc <= '0'; ta3_cnt <= (others=>'0'); ta3_tick <= '0'; ta3_armed <= '0';
         elsif ce = '1' then
            ta3_tick <= '0';
            reload3 := unsigned(sfr_mem(16#4D#)) & unsigned(sfr_mem(16#4C#));
            if sfr_mem(16#40#)(3) = '1' and reload3 /= 0 then
               if ta3_armed = '0' then
                  ta3_armed <= '1'; ta3_presc <= '0'; ta3_cnt <= reload3;
-- synthesis translate_off
                  report "DBG TA3 ARMED reload=" & to_hstring(reload3);
-- synthesis translate_on
               else
                  ta3_presc <= not ta3_presc;
                  if ta3_presc = '1' then
                     if ta3_cnt = 0 then
                        ta3_cnt <= reload3; ta3_tick <= '1';
                     else
                        ta3_cnt <= ta3_cnt - 1;
                     end if;
                  end if;
               end if;
            else
               ta3_armed <= '0';
            end if;
         end if;
      end if;
   end process;

   -- ---- Timer B1: the C76's MAIN service tick (mailbox handshake) -----------
   -- Mirror of TB0 but reload = SFR 0x53:0x52 and start = SFR 0x40 bit6. Pulses tb1_tick
   -- on underflow -> m37702 irq_tb1 -> vector 0xFFE2 -> handler 0xC31F (service ISR).
   process(clk)
      variable reload1 : unsigned(15 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            tb1_presc <= (others=>'0'); tb1_cnt <= (others=>'0');
            tb1_tick <= '0'; tb1_armed <= '0';
         elsif ce = '1' then
            tb1_tick <= '0';
            reload1 := unsigned(sfr_mem(16#53#)) & unsigned(sfr_mem(16#52#));
            if sfr_mem(16#40#)(6) = '1' and reload1 /= 0 then
               if tb1_armed = '0' then
                  -- synthesis translate_off
                  report "DBG TB1 ARMED reload=" & to_hstring(reload1);
                  -- synthesis translate_on
                  tb1_armed <= '1'; tb1_presc <= (others=>'0');
                  tb1_cnt <= reload1;
               else
                  if tb1_presc = 63 then
                     tb1_presc <= (others=>'0');
                     if tb1_cnt = 0 then
                        tb1_cnt  <= reload1;
                        tb1_tick <= '1';
                     else
                        tb1_cnt <= tb1_cnt - 1;
                     end if;
                  else
                     tb1_presc <= tb1_presc + 1;
                  end if;
               end if;
            else
               tb1_armed <= '0';
            end if;
         end if;
      end if;
   end process;

end architecture;
