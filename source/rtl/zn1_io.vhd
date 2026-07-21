-- ZN-1 Arcade I/O block
--
-- KEYCUS attribution:
--   The Namco System 11 KEYCUS protection chips (C406, C409, ...) are emulated
--   here as reverse-engineered algorithms — small game-specific challenge/response
--   checks (e.g. C406: p1=0x1234, p2=0x5678, p3=0x000F -> 0x3256). Those algorithms
--   were reverse-engineered and documented by the MAME project (smf et al.) in
--   src/mame/namco/ns11prot.cpp (BSD-3-Clause); the logic below is an independent
--   VHDL re-implementation of that documented behaviour. Credit to MAME and its
--   contributors for the reverse-engineering.
--
-- Handles the arcade-specific memory-mapped I/O at 0x1FA00000-0x1FAFFFFF.
-- All reads are 32-bit; addresses are the low 21 bits of the physical address.
--
-- Address map (CPU physical):
--   0x1FA00000  P1 inputs   [31:0]  active-low button bits
--   0x1FA00100  P2 inputs   [31:0]
--   0x1FA00200  Service     [31:0]
--   0x1FA00300  System      [31:0]  (coin counters, test, system)
--   0x1FA10000  P3 inputs   [31:0]  (unused for 2-player Visco games)
--   0x1FA10100  P4 inputs   [31:0]  (unused)
--   0x1FA10200  Board cfg   [7:0]   R/O: vmem/smem/ram size + rev bits
--   0x1FA10300  Sec select  [7:0]   R/W: selects CAT702 instance or ZNMCU
--   0x1FA20000  Coin I/O    [7:0]   R/W: coin counter / lockout outputs
--   0x1FAF0000  AT28C16     [7:0]   R/W: 2KB EEPROM (settings, high scores)
--
-- Input bit encoding for P1/P2 (active-low, matches ZN MAME driver):
--   [0]  Up       [1]  Down    [2]  Left   [3]  Right
--   [4]  Button1  [5]  Button2 [6]  Button3 [7]  Button4
--   [8]  Button5  [9]  Button6  all other bits: 1 (unused)
--   Start/Coin are NOT in P1/P2 — they are in the SYSTEM register (0x1FA00300).
--
-- SYSTEM register (0x1FA00300, active-low):
--   [0]  Start1   [1]  Start2   [4]  Coin1   [5]  Coin2  all other bits: 1

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

entity zn1_io is
   port (
      clk          : in  std_logic;
      reset        : in  std_logic;
      -- Bus interface (address = CPU[20:0], aligned to 32-bit)
      addr         : in  unsigned(20 downto 0);
      data_write   : in  std_logic_vector(31 downto 0);
      write_mask   : in  std_logic_vector(3 downto 0);   -- byte enables [3:0]=byte[3:0]
      read_en      : in  std_logic;
      write_en     : in  std_logic;
      data_read    : out std_logic_vector(31 downto 0);
      -- Player inputs (active high from MiSTer joystick)
      p1_right     : in  std_logic;
      p1_left      : in  std_logic;
      p1_down      : in  std_logic;
      p1_up        : in  std_logic;
      p1_btn       : in  std_logic_vector(5 downto 0);  -- buttons 1-6
      p1_start     : in  std_logic;
      p1_coin      : in  std_logic;
      p2_right     : in  std_logic;
      p2_left      : in  std_logic;
      p2_down      : in  std_logic;
      p2_up        : in  std_logic;
      p2_btn       : in  std_logic_vector(5 downto 0);
      p2_start     : in  std_logic;
      p2_coin      : in  std_logic;
      service      : in  std_logic;
      test_mode    : in  std_logic;
      -- Platform: 0=Visco, 1=Raizing, 2=Taito FX, 3=Atlus, 4=Tecmo. Drives boardconfig.
      zn_platform  : in  std_logic_vector(3 downto 0) := "0000";
      -- Security select: {data[7], data[3], data[2]} from 0x1FA10300 write
      -- [2]=bit7, [1]=bit3 (cat702[1]/KN02), [0]=bit2 (cat702[0]/KN01)
      sec_select   : out std_logic_vector(2 downto 0);
      -- Coin outputs (to coin counter LEDs if desired)
      coin_out     : out std_logic_vector(7 downto 0);

      -- ==== Namco System 11 mode ====
      -- When high, the 0x1FA00000 region uses the System 11 map instead of the
      -- Tecmo/ZN-1 map: shared-RAM mailbox @0x1FA04000, bank reg @0x1FA10020,
      -- KEYCUS @0x1FA20000 (Tekken = none), EEPROM @0x1FA30000.
      zn_system11  : in  std_logic := '0';
      -- KEYCUS type from the MRA (ioctl index 1, byte[1]). Algorithms ported from MAME
      -- src/mame/namco/ns11prot.cpp:
      --   0 = none (Tekken 1)          5 = C430 (Xevious 3D/G)
      --   1 = C406 (Tekken 2)          6 = C431 (Dancing Eyes)
      --   2 = C409 (Soul Edge)         7 = C432 (Pocket Racer)
      --   3 = C410 (Dunk Mania)        8 = C442 (Star Sweep)
      --   4 = C411 (Prime Goal EX)     9 = C443 (My Angel 3 / Point Blank 2)
      keycus_id    : in  std_logic_vector(7 downto 0) := x"00";
      -- 8 independent 1 MB bank windows (0x1F000000..0x1F700000). Each 5-bit field w
      -- is the page (0-31) selected for window w from the banked ROM.
      -- rom8 (default):        entry = ((d&0xC0)>>4)+(d&0x03) = d[7:6]&d[1:0] (16MB max)
      -- rom8_64 (keycus C443): entry = (d[7:6]&d[2:0]) XOR (s11_up ? 16 : 0)  (32MB max)
      -- Written via 0x1FA10020+2*w. The XOR is applied AT WRITE TIME (MAME set_entry
      -- semantics): a later upper-latch change does not remap already-set windows.
      s11_bank     : out std_logic_vector(39 downto 0) := (others => '0');
      -- rom8_64 upper-16MB latch, held by memorymux (written at 0x1F080000/2)
      s11_up       : in  std_logic := '0';
      -- C76 shared-RAM mailbox, MIPS side (16-bit words; 16K words = 32 KB)
      mb_addr      : out std_logic_vector(13 downto 0) := (others => '0');
      mb_wdata     : out std_logic_vector(15 downto 0) := (others => '0');
      mb_we        : out std_logic := '0';
      mb_rdata     : in  std_logic_vector(15 downto 0) := (others => '0');
      -- DIAGNOSTIC (System 11 boot triage): capture the value the MIPS reads at the
      -- 0x1FA0BD32 handshake poll (mailbox word 0x3E99, high lane). dbg_poll_bit80
      -- latches if bit 0x80 is ever set there (the bit that makes the MIPS early-exit
      -- the timeout poll and hang before game code).
      dbg_poll_val   : out std_logic_vector(15 downto 0) := (others => '0');
      dbg_poll_bit80 : out std_logic := '0';
      -- DIAG 2026-06-25: {last-written EEPROM byte, last EEPROM read-back byte (lane0), busy_count}
      -- latched on each EEPROM read to diagnose the stuck data-poll verify @0x8003E690.
      dbg_eeprom     : out std_logic_vector(23 downto 0) := (others => '0');
      -- DIAG 2026-07-06: do the MIPS bank-register writes (sh 0x1FA10020-2F) ever ARRIVE here?
      -- [31:28]=count of writes hitting the 0x10020-0x1002F compare, [27:24]=count of ANY write
      -- with addr(16)=1, [23:16]=last data_write(23:16), [15:8]=last data_write(7:0), [7:0]=last addr(7:0).
      dbg_bankwr     : out std_logic_vector(31 downto 0) := (others => '0');
      -- EEPROM download port (MRA nvram index 9). On first boot the BRAM inits to 0xFF (init_file);
      -- if a saved .nvram exists the framework downloads it here (MIPS held in reset -> no contention).
      ee_dl_wr     : in  std_logic := '0';
      ee_dl_addr   : in  std_logic_vector(9 downto 0) := (others => '0');
      ee_dl_data   : in  std_logic_vector(31 downto 0) := (others => '0');
      -- EEPROM upload/read-back port (nvram SAVE): when ee_up_rd=1 the BRAM read address is muxed
      -- to ee_up_addr and the 32-bit word appears on ee_up_q (single-port; a MIPS EEPROM read during
      -- the brief save window is a harmless rare glitch).
      ee_up_rd     : in  std_logic := '0';
      ee_up_addr   : in  std_logic_vector(9 downto 0) := (others => '0');
      ee_up_q      : out std_logic_vector(31 downto 0) := (others => '0');
      -- 1-cycle pulse whenever the MIPS writes the EEPROM (debounced upstream to request a save)
      ee_wr_pulse  : out std_logic := '0'
   );
end entity;

architecture arch of zn1_io is

   -- Keep the KEYCUS arithmetic (C409) out of the DSP blocks: the design is DSP-critical,
   -- and the operands are tiny (5x5), so LUTs are the cheaper home for them.
   attribute multstyle : string;
   attribute multstyle of arch : architecture is "logic";

   signal sec_sel_r : std_logic_vector(2 downto 0) := "000";  -- default: 0 (nothing selected)
   signal coin_r    : std_logic_vector(7 downto 0) := x"FF";
   -- build #117b: store the full znsecsel byte for verifiable readback (MAME returns whatever
   -- was written). Without this, Taito BIOS write-verifies znsecsel and sees a mismatch.
   signal znsecsel_byte : std_logic_vector(7 downto 0) := x"00";
   -- System 11: register file for the 8 bank-window page selectors (8x 4-bit).
   signal s11_bank_r : std_logic_vector(39 downto 0) := (others => '0');
   -- DIAG 2026-07-06 bank-write arrival probe
   signal bankwr_cnt  : unsigned(3 downto 0) := (others => '0');
   signal wr16_cnt    : unsigned(3 downto 0) := (others => '0');
   signal bankwr_d23  : std_logic_vector(7 downto 0) := (others => '0');
   signal bankwr_d7   : std_logic_vector(7 downto 0) := (others => '0');
   signal bankwr_addr : std_logic_vector(7 downto 0) := (others => '0');
   -- registered data_read (regular regs); the mailbox path overrides it combinationally
   signal data_read_r : std_logic_vector(31 downto 0) := (others => '0');
   -- mailbox read select, registered 1 cycle to match the dpram's 1-cycle read latency
   signal mb_sel_d    : std_logic := '0';
   -- registered addr(1) (halfword lane) aligned with mb_sel_d: selects which 16-bit
   -- bus lane the read data goes into so the CPU's lhu/lh extraction sees it.
   signal mb_hi_d     : std_logic := '0';
   -- KEYCUS parameter registers (game-written, chip-specific offsets)
   signal kc_p1, kc_p2, kc_p3 : std_logic_vector(15 downto 0) := (others => '0');
   -- DIAGNOSTIC: registered mb_addr (to detect the poll word 0x3E99 one cycle later,
   -- aligned with the dpram read latency) + the captured poll value / bit-0x80 latch.
   signal mb_addr_d   : std_logic_vector(13 downto 0) := (others => '0');
   signal poll_val_r    : std_logic_vector(15 downto 0) := (others => '0');
   signal poll_bit80_r  : std_logic := '0';

   -- AT28C16 EEPROM: 2KB (512×32-bit words) at 0x1FAF0000-0x1FAF07FF.
   -- Implemented as altsyncram M10K (0 LABs) with 4-bit byte-enable.
   -- Not reset on soft-reset — contents persist across game resets like real EEPROM.
   -- M10K initialises to 0x00 at power-on; game detects uninitialised and writes defaults.
   signal eeprom_cs   : std_logic;                      -- address in EEPROM range
   signal eeprom_addr_s : std_logic_vector(9 downto 0); -- word address within EEPROM (1024 words = 4KB region)
   signal eeprom_wr   : std_logic;                      -- write enable to altsyncram
   signal eeprom_dout : std_logic_vector(31 downto 0);  -- unregistered M10K output
   -- EEPROM BRAM port-A inputs, muxed between the download port (ee_dl_wr, active during
   -- ioctl load while the MIPS is in reset) and the live game bus path.
   signal ee_ram_addr    : std_logic_vector(9 downto 0);
   signal ee_ram_wren    : std_logic;
   signal ee_ram_byteena : std_logic_vector(3 downto 0);
   signal ee_ram_data    : std_logic_vector(31 downto 0);

   -- Build a 32-bit P1/P2 input register, active-low. Start/Coin go in SYSTEM register.
   function make_input(r, l, d, u : std_logic;
                       btn : std_logic_vector(5 downto 0))
      return std_logic_vector is
      variable v : std_logic_vector(31 downto 0) := (others => '1');
   begin
      v(0)  := not u;     -- bit0 = Up
      v(1)  := not d;     -- bit1 = Down
      v(2)  := not l;     -- bit2 = Left
      v(3)  := not r;     -- bit3 = Right
      v(4)  := not btn(0);
      v(5)  := not btn(1);
      v(6)  := not btn(2);
      v(7)  := not btn(3);
      v(8)  := not btn(4);
      v(9)  := not btn(5);
      return v;
   end function;

   -- ==== KEYCUS helpers ====
   -- Several System 11 KEYCUS chips answer with the DECIMAL digits of a 16-bit value
   -- (MAME ns11prot.cpp: "( value / 100 ) % 10" etc). kc_digits(k) = (value / 10**k) % 10.
   -- Implemented as a combinational double-dabble (no dividers, no DSP). One instance is
   -- shared by every chip: the per-chip value is muxed into it before the call.
   type bcd_digits_t is array(0 to 4) of unsigned(3 downto 0);

   function to_bcd(v : unsigned(15 downto 0)) return bcd_digits_t is
      variable d   : bcd_digits_t := (others => (others => '0'));
      variable c   : std_logic;
      variable t   : unsigned(4 downto 0);
   begin
      for i in 15 downto 0 loop
         -- add-3 on any digit >= 5, then shift the next source bit in at the bottom
         for k in 0 to 4 loop
            if d(k) > 4 then
               d(k) := d(k) + 3;
            end if;
         end loop;
         c := v(i);
         for k in 0 to 4 loop
            t    := d(k) & c;
            d(k) := t(3 downto 0);
            c    := t(4);
         end loop;
      end loop;
      return d;
   end function;

   -- C409 (Soul Edge) colour interpolation, one 5-bit channel (MAME keycus_c409_device::read):
   --   chan = ((v2 * a2) + (v3 * a3)) / 0x1f
   -- a2 = (p1-1) & 0x1f and a3 = (0x20-p1) & 0x1f always sum to exactly 31, so the numerator
   -- is bounded by 31*31 = 961. Divide-by-31 is therefore an exact reciprocal multiply:
   --   floor(n/31) = (n * 2115) >> 16  for all n <= 961   (verified exhaustively)
   -- and 2115 = 2048 + 64 + 2 + 1, i.e. three shift-adds — no divider, no multiplier.
   function c409_chan(v2, v3, a2, a3 : unsigned(4 downto 0)) return unsigned is
      variable num  : unsigned(10 downto 0);
      variable prod : unsigned(22 downto 0);
   begin
      num  := resize(v2 * a2, 11) + resize(v3 * a3, 11);          -- <= 961
      prod := shift_left(resize(num, 23), 11) + shift_left(resize(num, 23), 6)
              + shift_left(resize(num, 23), 1) + resize(num, 23); -- num * 2115
      return resize(shift_right(prod, 16), 5);
   end function;

   -- Board config register value (matches MAME zn_state::boardconfig_r):
   --   [7:5] = "011" → rev=1 (always for ZN-1)
   --   [3]   = vmem (1=2MB, 0=1MB) — set by m_gpu->vram_size() in MAME
   --   [2]   = smem (1=2MB SPU SGRAM) — MAME never sets this; left 0
   --   [1:0] = "01"  → RAM=4MB (ZN-1 standard)
   -- Per MAME zn.cpp: Taito FX-1A (coh1000ta) and FX-1B (coh1000tb) use zn1_1mb_vram (1MB).
   -- All other ZN-1 boards (Visco, Raizing, Atlus, Tecmo) use zn1_2mb_vram (2MB).
   -- Taito titles read this register at boot and use it to determine VRAM layout. Returning
   -- 0x69 (2MB) to a Taito BIOS expecting 0x61 (1MB) causes incorrect VRAM-Y addressing.
   signal board_cfg : std_logic_vector(7 downto 0);

   -- build #117: AT28C16 data-polling emulation. Real AT28C16 returns inverted bit 7 during
   -- 200μs write cycle (per MAME at28c16_device::read). Taito BIOS uses this to verify EEPROM
   -- is present (vs RAM). Without it, BIOS shows "EE-PROM ERROR". Track last-write addr/byte/data,
   -- 256-clk busy counter; reads to the busy byte return data XOR 0x80.
   signal eeprom_pending_addr : std_logic_vector(9 downto 0) := (others => '0');
   signal eeprom_pending_lane : std_logic_vector(1 downto 0) := (others => '0');
   signal eeprom_pending_data : std_logic_vector(7 downto 0) := (others => '0');
   signal eeprom_busy_count   : unsigned(7 downto 0) := (others => '0');
   signal eeprom_dout_polled  : std_logic_vector(31 downto 0);
   -- DIAG latches for the EEPROM verify
   signal ee_rd_pulse_d : std_logic := '0';
   signal dbg_ee_rd     : std_logic_vector(7 downto 0) := (others => '0');
   signal dbg_ee_pend   : std_logic_vector(7 downto 0) := (others => '0');
   signal dbg_ee_busy   : std_logic_vector(7 downto 0) := (others => '0');

begin

   sec_select <= sec_sel_r;
   coin_out   <= coin_r;

   -- Board config: clear bit 3 (vmem) for Taito (1MB VRAM), set otherwise.
   board_cfg <= "01100001" when zn_platform = "0010" else  -- 0x61: Taito FX-1A/FX-1B (1MB VRAM)
                "01101001";                                  -- 0x69: all others (2MB VRAM)

   -- EEPROM address decode and write enable (combinatorial).
   -- FIX 2026-06-25: Namco System 11 maps the AT28C16 at 0x1FA30000-0x1FA30FFF (MAME namcos11.cpp
   -- map(0x1fa30000,0x1fa30fff) at28c16), NOT the Taito ZN BIOS address 0x1FAF0000. Tekken writes
   -- 1312 bytes here (a0=0x1FA30200) and DATA-POLLS the read-back per byte; with the wrong decode
   -- the region was unmapped → the poll loop @0x8003E690 never matched → MIPS hung at boot.
   -- 0x30000-0x30FFF = addr(20:12)="000110000"; word index = addr(11:2) (1024 words covers the 4KB).
   eeprom_cs     <= '1' when std_logic_vector(addr(20 downto 12)) = "000110000" else '0';
   eeprom_addr_s <= std_logic_vector(addr(11 downto 2));
   eeprom_wr     <= write_en and eeprom_cs;

   -- build #117: data-polling state machine
   process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' then
            eeprom_busy_count <= (others => '0');
         else
            if eeprom_wr = '1' then
               -- Capture last byte written. For multi-byte writes (SH/SW), priority is byte 0.
               eeprom_pending_addr <= eeprom_addr_s;
               if write_mask(0) = '1' then
                  eeprom_pending_lane <= "00";
                  eeprom_pending_data <= data_write(7 downto 0);
               elsif write_mask(1) = '1' then
                  eeprom_pending_lane <= "01";
                  eeprom_pending_data <= data_write(15 downto 8);
               elsif write_mask(2) = '1' then
                  eeprom_pending_lane <= "10";
                  eeprom_pending_data <= data_write(23 downto 16);
               else
                  eeprom_pending_lane <= "11";
                  eeprom_pending_data <= data_write(31 downto 24);
               end if;
               eeprom_busy_count <= to_unsigned(255, 8);
            elsif eeprom_busy_count > 0 then
               eeprom_busy_count <= eeprom_busy_count - 1;
            end if;
         end if;
      end if;
   end process;

   -- Override the BRAM output byte for the busy address with inverted bit 7.
   -- Per MAME: read returns m_last_write XOR 0x80 during write-in-progress.
   eeprom_dout_polled <=
      eeprom_dout(31 downto 24) & eeprom_dout(23 downto 16) & eeprom_dout(15 downto 8)
         & (eeprom_pending_data xor x"80")
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "00") else
      eeprom_dout(31 downto 24) & eeprom_dout(23 downto 16)
         & (eeprom_pending_data xor x"80") & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "01") else
      eeprom_dout(31 downto 24)
         & (eeprom_pending_data xor x"80") & eeprom_dout(15 downto 8) & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "10") else
      (eeprom_pending_data xor x"80")
         & eeprom_dout(23 downto 16) & eeprom_dout(15 downto 8) & eeprom_dout(7 downto 0)
            when (eeprom_busy_count > 0 and eeprom_pending_addr = eeprom_addr_s
                  and eeprom_pending_lane = "11") else
      eeprom_dout;

   -- AT28C16: 512×32-bit M10K BRAM, 4-bit byte-enable, unregistered output.
   -- UNREGISTERED output: q_a reflects data at address_a with 1 clock cycle latency
   -- (addr sampled at rising edge → q_a valid before next edge), which matches the
   -- BUSREADREQUEST→BUSREAD 2-cycle window in memorymux.
   -- EEPROM BRAM (AT28C16). init_file = all-FF (eeprom_ff.mif) so a FRESH board (no saved .nvram)
   -- powers up to the AT28C16 factory state 0xFF that the titles expect on first read; the all-FF
   -- image is not proprietary captured-nvram (it is literally blank). If a saved .nvram EXISTS the
   -- framework downloads it via ee_dl_wr while the MIPS is held in reset (overwriting the FF init).
   -- Port-A single-port mux, in priority: download write > upload read-back > live game bus.
   -- The three are temporally exclusive in practice (download only during ioctl load; upload only
   -- during the brief nvram save; any MIPS EEPROM read coinciding with a save is a rare glitch).
   ee_ram_addr    <= ee_dl_addr when ee_dl_wr = '1'
                     else ee_up_addr when ee_up_rd = '1'
                     else eeprom_addr_s;
   ee_ram_wren    <= '1'    when ee_dl_wr = '1'
                     else '0' when ee_up_rd = '1'
                     else eeprom_wr;
   ee_ram_byteena <= "1111" when ee_dl_wr = '1' else write_mask;
   ee_ram_data    <= ee_dl_data when ee_dl_wr = '1' else data_write;
   ee_up_q        <= eeprom_dout;                       -- read-back for the nvram SAVE upload
   ee_wr_pulse    <= eeprom_wr;                         -- MIPS EEPROM write (debounced upstream to save)

   ieeprom : altsyncram
   generic map (
      operation_mode      => "SINGLE_PORT",
      width_a             => 32,
      widthad_a           => 10,
      numwords_a          => 1024,
      width_byteena_a     => 4,
      outdata_reg_a       => "UNREGISTERED",
      init_file           => "eeprom_ff.mif",
      ram_block_type      => "M10K",
      lpm_type            => "altsyncram"
   )
   port map (
      clock0    => clk,
      address_a => ee_ram_addr,
      wren_a    => ee_ram_wren,
      byteena_a => ee_ram_byteena,
      data_a    => ee_ram_data,
      q_a       => eeprom_dout
   );

   s11_bank <= s11_bank_r;

   -- System 11 C76 mailbox (combinational): the dpram has a 1-cycle registered-address
   -- read, and memorymux's BUSREADREQUEST->BUSREAD gives only 1 cycle, so the address
   -- must be presented immediately and the read data muxed in combinationally (gated by
   -- the 1-cycle-delayed mb_sel_d) rather than through zn1_io's registered data_read_r.
   -- addr carries bit 1 (halfword resolution), so (addr-0x4000)>>1 selects the EXACT
   -- 16-bit shared word (even or odd). The MIPS bus places sh data positionally:
   -- addr(1)=1 -> data in [31:16], addr(1)=0 -> [15:0] (cpu.vhd SH). Pick that lane
   -- for the write, and on read place mb_rdata into the lane the CPU's lhu extracts
   -- (using mb_hi_d = addr(1) registered to align with the dpram's 1-cycle read).
   mb_addr   <= std_logic_vector(resize(shift_right(unsigned(addr) - 16#4000#, 1), 14));
   mb_wdata  <= data_write(31 downto 16) when addr(1) = '1' else data_write(15 downto 0);
   mb_we     <= '1' when (zn_system11 = '1' and write_en = '1'
                          and unsigned(addr) >= 16#4000# and unsigned(addr) <= 16#BFFF#) else '0';
   -- FIX 2026-06-27: deliver the EEPROM read COMBINATIONALLY on ee_rd_pulse_d (the read select delayed
   -- 1 cycle to align with the altsyncram's 1-cycle q_a latency), exactly like the C76 mailbox above.
   -- Previously the EEPROM went through the REGISTERED data_read_r, which latched eeprom_dout_polled one
   -- cycle too early (before q_a was valid) -> the CPU received stale data and the AT28C16 data-poll loop
   -- @0x8003E690 never saw the written byte (HW JTAG: eeprom readback=0x02 but CPU kept spinning).
   data_read <= (mb_rdata & x"0000")  when (mb_sel_d = '1' and mb_hi_d = '1') else
                (x"0000" & mb_rdata)  when (mb_sel_d = '1')                   else
                eeprom_dout_polled    when (ee_rd_pulse_d = '1')             else
                data_read_r;

   dbg_poll_val   <= poll_val_r;
   dbg_poll_bit80 <= poll_bit80_r;

   -- DIAG: latch EEPROM verify values one cycle after each EEPROM read (eeprom_dout_polled valid then)
   process(clk) begin
      if rising_edge(clk) then
         ee_rd_pulse_d <= read_en and eeprom_cs;
         if ee_rd_pulse_d = '1' then
            dbg_ee_rd   <= eeprom_dout_polled(7 downto 0);
            dbg_ee_pend <= eeprom_pending_data;
            dbg_ee_busy <= std_logic_vector(eeprom_busy_count);
         end if;
      end if;
   end process;
   dbg_eeprom <= dbg_ee_pend & dbg_ee_rd & dbg_ee_busy;

   -- DIAG 2026-07-06: bank-write arrival probe. Counts saturate at 15 (sticky).
   -- Deliberately OUTSIDE the zn_system11 guard so an arrival is counted even if
   -- the handler branch were somehow not taken.
   process(clk) begin
      if rising_edge(clk) then
         if write_en = '1' and addr(16) = '1' then
            if wr16_cnt /= x"F" then wr16_cnt <= wr16_cnt + 1; end if;
         end if;
         if write_en = '1' and unsigned(addr) >= 16#10020# and unsigned(addr) <= 16#1002F# then
            if bankwr_cnt /= x"F" then bankwr_cnt <= bankwr_cnt + 1; end if;
            bankwr_d23  <= data_write(23 downto 16);
            bankwr_d7   <= data_write(7 downto 0);
            bankwr_addr <= std_logic_vector(addr(7 downto 0));
         end if;
      end if;
   end process;
   dbg_bankwr <= std_logic_vector(bankwr_cnt) & std_logic_vector(wr16_cnt) & bankwr_d23 & bankwr_d7 & bankwr_addr;

   process(clk)
      variable p1_v, p2_v, svc_v, sys_v : std_logic_vector(31 downto 0);
      variable bank_w : integer range 0 to 7;
      -- KEYCUS working values (combinational, recomputed every cycle; one shared instance
      -- of the double-dabble / C409 datapath feeds every chip's read mux).
      variable kc_val    : unsigned(15 downto 0);
      variable kc_d      : bcd_digits_t;
      variable kc_a2     : unsigned(4 downto 0);
      variable kc_a3     : unsigned(4 downto 0);
      variable kc_c409   : std_logic_vector(15 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            sec_sel_r <= "000";  -- reset: nothing selected (distinguishes from BIOS 0x0C write)
            coin_r    <= x"FF";
            data_read_r <= (others => '1');
            s11_bank_r <= (others => '0');  -- all windows → page 0 at reset
            kc_p1 <= (others => '0');       -- MAME ns11_keycus_device::device_reset
            kc_p2 <= (others => '0');
            kc_p3 <= (others => '0');
            mb_sel_d   <= '0';
            mb_hi_d    <= '0';
            mb_addr_d  <= (others => '0');
            poll_val_r   <= (others => '0');
            poll_bit80_r <= '0';
         else
            p1_v  := make_input(p1_right, p1_left, p1_down, p1_up, p1_btn);
            p2_v  := make_input(p2_right, p2_left, p2_down, p2_up, p2_btn);

            -- Service register 0x1FA00200: bit0=test(SERVICE2), bit1=service(SERVICE1)
            svc_v := (others => '1');
            svc_v(0) := not test_mode;
            svc_v(1) := not service;

            -- System register 0x1FA00300: bit0=START1, bit1=START2, bit4=COIN1, bit5=COIN2
            sys_v := (others => '1');
            sys_v(0) := not p1_start;
            sys_v(1) := not p2_start;
            sys_v(4) := not p1_coin;
            sys_v(5) := not p2_coin;

            data_read_r <= (others => '0');  -- must be 0: dataFromBusses in memorymux is OR-reduced
            mb_sel_d <= '0';

            -- ==== KEYCUS datapath (System 11) ====
            -- The digit-returning chips (C410/C411/C430/C431/C432) answer with the decimal
            -- digits of a 16-bit "value". That value is normally the chip's own part number,
            -- but the game can hand the chip a value of its own via a magic parameter, and the
            -- chip then converts THAT (MAME ns11prot.cpp). So the digit conversion must be a
            -- real binary->BCD, not a constant. Mux the value first, convert once.
            kc_val := (others => '0');
            case keycus_id is
               when x"03" =>   -- C410: value = p1, but 410 when p1 = 0xfffe
                  if kc_p1 = x"FFFE" then kc_val := to_unsigned(410, 16);
                  else                    kc_val := unsigned(kc_p1);      end if;
               when x"04" =>   -- C411: value = p3 when p1 = 0x7256, else 411
                  if kc_p1 = x"7256" then kc_val := unsigned(kc_p3);
                  else                    kc_val := to_unsigned(411, 16); end if;
               when x"05" =>   -- C430: value = p1 when p3 = 0xe296, else 430
                  if kc_p3 = x"E296" then kc_val := unsigned(kc_p1);
                  else                    kc_val := to_unsigned(430, 16); end if;
               when x"06" =>   -- C431: value = p3 when p1 = 0x9e61, else 431
                  if kc_p1 = x"9E61" then kc_val := unsigned(kc_p3);
                  else                    kc_val := to_unsigned(431, 16); end if;
               when x"07" =>   -- C432: value = p2 when p3 = 0x2f15, else 432
                  if kc_p3 = x"2F15" then kc_val := unsigned(kc_p2);
                  else                    kc_val := to_unsigned(432, 16); end if;
               when others => null;
            end case;
            kc_d := to_bcd(kc_val);   -- kc_d(k) = (value / 10**k) % 10

            -- C409 (Soul Edge): interpolate the 3 5-bit colour channels of p2 and p3 by p1.
            kc_a2   := unsigned(kc_p1(4 downto 0)) - 1;                   -- (p1 - 0x01) & 0x1f
            kc_a3   := to_unsigned(0, 5) - unsigned(kc_p1(4 downto 0));   -- (0x20 - p1) & 0x1f
            kc_c409 := "0"
               & std_logic_vector(c409_chan(unsigned(kc_p2(14 downto 10)),
                                            unsigned(kc_p3(14 downto 10)), kc_a2, kc_a3))   -- b << 10
               & std_logic_vector(c409_chan(unsigned(kc_p2( 9 downto  5)),
                                            unsigned(kc_p3( 9 downto  5)), kc_a2, kc_a3))   -- g << 5
               & std_logic_vector(c409_chan(unsigned(kc_p2( 4 downto  0)),
                                            unsigned(kc_p3( 4 downto  0)), kc_a2, kc_a3));  -- r

            -- DIAGNOSTIC poll capture: when the registered mailbox read completes
            -- (mb_sel_d=1) for the high-lane poll word 0x3E99 (= MIPS lhu 0x1FA0BD32),
            -- record exactly what the MIPS sees and sticky-latch bit 0x80.
            if mb_sel_d = '1' and mb_hi_d = '1' and unsigned(mb_addr_d) = 16#3E99# then
               poll_val_r <= mb_rdata;
               if mb_rdata(7) = '1' then
                  poll_bit80_r <= '1';
               end if;
            end if;

            if zn_system11 = '1' then
               -- ==== Namco System 11 memory map ====
               -- shared RAM @0x04000-0x0BFFF (mailbox, 16-bit words), bank reg
               -- @0x10020, KEYCUS @0x20000 (Tekken=none), EEPROM @0x30000 (TODO).
               -- mb_addr/mb_wdata/mb_be/mb_we are driven COMBINATIONALLY (below) so the
               -- dpram registers the address as soon as memorymux presents it; the read
               -- data comes back 1 cycle later (dpram latency) and is muxed into data_read
               -- via mb_sel_d (registered here to align with that latency).
               mb_hi_d   <= addr(1);   -- latch halfword lane with the read select
               mb_addr_d <= mb_addr;   -- latch mb_addr to detect the poll word next cycle
               if read_en = '1' and unsigned(addr) >= 16#4000# and unsigned(addr) <= 16#BFFF# then
                  mb_sel_d <= '1';                                      -- mailbox read this cycle
               else
                  mb_sel_d <= '0';                                      -- KEYCUS/unmapped via data_read_r
               end if;
               -- ==== KEYCUS @0x20000-0x2001F ====
               if read_en = '1' and unsigned(addr) >= 16#20000# and unsigned(addr) <= 16#2001F# then
                  data_read_r <= (others => '0');
                  -- MAME 16-bit offset n = byte 2n: word = addr(4:2) = n/2, lane = n&1
                  -- (even offset -> low lane [15:0], odd offset -> high lane [31:16]).
                  -- MAME logs and returns machine().rand() on an unexpected read; games never
                  -- take that path, so we return 0 (no randomness emulated).
                  case keycus_id is
                     when x"01" =>   -- C406 (Tekken 2): read16[0] = 0x3256 iff p1/p2/p3 match
                        if addr(4 downto 2) = "000" and
                           kc_p1 = x"1234" and kc_p2 = x"5678" and kc_p3 = x"000F" then
                           data_read_r <= x"0000" & x"3256";
                        end if;

                     when x"02" =>   -- C409 (Soul Edge): read16[7] = colour interpolation
                        if addr(4 downto 2) = "011" then
                           data_read_r(31 downto 16) <= kc_c409;               -- offset 7
                        end if;

                     when x"03" =>   -- C410 (Dunk Mania): digits of value, guarded by p2 = 0
                        if kc_p2 = x"0000" then
                           if addr(4 downto 2) = "000" then                    -- offset 1: d0
                              data_read_r(31 downto 16) <= x"000" & std_logic_vector(kc_d(0));
                           end if;
                           if addr(4 downto 2) = "001" then                    -- offset 2: d2 | d3<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(3))
                                                         & x"0" & std_logic_vector(kc_d(2));
                              data_read_r(31 downto 16) <= x"0" & std_logic_vector(kc_d(1))
                                                         & x"0" & std_logic_vector(kc_d(4));
                           end if;                                             -- offset 3: d4 | d1<<8
                        end if;

                     when x"04" =>   -- C411 (Prime Goal EX)
                        if kc_p2 = x"0000" and
                           ( ( (kc_p1 = x"0000" or kc_p1 = x"0100") and kc_p3 = x"FF7F" )
                             or kc_p1 = x"7256" ) then
                           if addr(4 downto 2) = "000" then                    -- offset 0: d0 | d1<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(1))
                                                         & x"0" & std_logic_vector(kc_d(0));
                           end if;
                           if addr(4 downto 2) = "001" then                    -- offset 2: d2 | d3<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(3))
                                                         & x"0" & std_logic_vector(kc_d(2));
                           end if;
                           if addr(4 downto 2) = "100" then                    -- offset 8: d4
                              data_read_r(15 downto  0) <= x"000" & std_logic_vector(kc_d(4));
                           end if;
                        end if;

                     when x"05" =>   -- C430 (Xevious 3D/G)
                        if kc_p2 = x"0000" and
                           ( (kc_p1 = x"BFFF" and kc_p3 = x"0000") or kc_p3 = x"E296" ) then
                           if addr(4 downto 2) = "000" then                    -- offset 1: d4
                              data_read_r(31 downto 16) <= x"000" & std_logic_vector(kc_d(4));
                           end if;
                           if addr(4 downto 2) = "010" then                    -- offset 4: d2 | d3<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(3))
                                                         & x"0" & std_logic_vector(kc_d(2));
                              data_read_r(31 downto 16) <= x"0" & std_logic_vector(kc_d(1))
                                                         & x"0" & std_logic_vector(kc_d(0));
                           end if;                                             -- offset 5: d0 | d1<<8
                        end if;

                     when x"06" =>   -- C431 (Dancing Eyes)
                        if kc_p2 = x"0000" and
                           ( ( (kc_p1 = x"0000" or kc_p1 = x"AB50") and kc_p3 = x"7FFF" )
                             or kc_p1 = x"9E61" ) then
                           if addr(4 downto 2) = "000" then                    -- offset 0: d0 | d1<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(1))
                                                         & x"0" & std_logic_vector(kc_d(0));
                           end if;
                           if addr(4 downto 2) = "010" then                    -- offset 4: d2 | d3<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(3))
                                                         & x"0" & std_logic_vector(kc_d(2));
                           end if;
                           if addr(4 downto 2) = "100" then                    -- offset 8: d4
                              data_read_r(15 downto  0) <= x"000" & std_logic_vector(kc_d(4));
                           end if;
                        end if;

                     when x"07" =>   -- C432 (Pocket Racer)
                        if kc_p1 = x"0000" and
                           ( ( (kc_p3 = x"0000" or kc_p3 = x"00DC") and kc_p2 = x"EFFF" )
                             or kc_p3 = x"2F15" ) then
                           if addr(4 downto 2) = "001" then                    -- offset 2: d0 | d1<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(1))
                                                         & x"0" & std_logic_vector(kc_d(0));
                           end if;
                           if addr(4 downto 2) = "010" then                    -- offset 4: d2 | d3<<8
                              data_read_r(15 downto  0) <= x"0" & std_logic_vector(kc_d(3))
                                                         & x"0" & std_logic_vector(kc_d(2));
                           end if;
                           if addr(4 downto 2) = "011" then                    -- offset 6: d4 | d5<<8
                              data_read_r(15 downto  0) <= x"000" & std_logic_vector(kc_d(4));
                           end if;   -- d5 = (value/100000)%10 = 0 for any 16-bit value
                        end if;

                     when x"08" =>   -- C442 (Star Sweep): read16[1] = 0xc442 for the magic p2.
                        if addr(4 downto 2) = "000" and                        -- offset 1
                           kc_p1 = x"0020" and kc_p2 = x"0021" then
                           data_read_r(31 downto 16) <= x"C442";
                        end if;      -- the other accepted C442 reads all return 0x0000

                     when x"09" =>   -- C443 (My Angel 3 / Point Blank 2)
                        if addr(4 downto 2) = "000" then
                           if kc_p1 = x"0020" and                              -- offset 0: 0x0020
                              (kc_p2 = x"0000" or kc_p2 = x"FFFF" or kc_p2 = x"FFE0") then
                              data_read_r(15 downto  0) <= x"0020";
                           end if;
                           if kc_p1 = x"0020" and                              -- offset 1: 0xc443
                              (kc_p2 = x"FFFF" or kc_p2 = x"FFE0") then
                              data_read_r(31 downto 16) <= x"C443";
                           end if;  -- p2 = 0xffdf answers 0x0000 at offset 1
                        end if;

                     when others => null;   -- no keycus: reads return 0
                  end case;
               end if;
               if write_en = '1' and unsigned(addr) >= 16#20000# and unsigned(addr) <= 16#2001F# then
                  -- 16-bit regs, word-aligned stores, lane in write_mask (same convention
                  -- as bank regs/mailbox). MAME 16-bit offset n = byte 2n:
                  --   offset = addr(4:2)*2 (+1 for the high lane).
                  case keycus_id is
                     when x"01" =>   -- C406 writes: offset1->p1, offset2->p2, offset3->p3
                        if addr(4 downto 2) = "000" and write_mask(3 downto 2) /= "00" then
                           kc_p1 <= data_write(31 downto 16);            -- offset 1
                        end if;
                        if addr(4 downto 2) = "001" then
                           if write_mask(1 downto 0) /= "00" then
                              kc_p2 <= data_write(15 downto 0);          -- offset 2
                           end if;
                           if write_mask(3 downto 2) /= "00" then
                              kc_p3 <= data_write(31 downto 16);         -- offset 3
                           end if;
                        end if;

                     when x"02" =>   -- C409 writes: offset1->p1, offset3->p2, offset7->p3
                        if write_mask(3 downto 2) /= "00" then
                           if addr(4 downto 2) = "000" then kc_p1 <= data_write(31 downto 16); end if;
                           if addr(4 downto 2) = "001" then kc_p2 <= data_write(31 downto 16); end if;
                           if addr(4 downto 2) = "011" then kc_p3 <= data_write(31 downto 16); end if;
                        end if;

                     when x"03" =>   -- C410 writes: offset0->p1, offset2->p2
                        if write_mask(1 downto 0) /= "00" then
                           if addr(4 downto 2) = "000" then kc_p1 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "001" then kc_p2 <= data_write(15 downto 0); end if;
                        end if;

                     when x"04" =>   -- C411 writes: offset2->p1, offset8->p2, offset10->p3
                        if write_mask(1 downto 0) /= "00" then
                           if addr(4 downto 2) = "001" then kc_p1 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "100" then kc_p2 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "101" then kc_p3 <= data_write(15 downto 0); end if;
                        end if;

                     when x"05" =>   -- C430 writes: offset0->p1, offset1->p2, offset4->p3
                        if addr(4 downto 2) = "000" then
                           if write_mask(1 downto 0) /= "00" then
                              kc_p1 <= data_write(15 downto 0);          -- offset 0
                           end if;
                           if write_mask(3 downto 2) /= "00" then
                              kc_p2 <= data_write(31 downto 16);         -- offset 1
                           end if;
                        end if;
                        if addr(4 downto 2) = "010" and write_mask(1 downto 0) /= "00" then
                           kc_p3 <= data_write(15 downto 0);             -- offset 4
                        end if;

                     when x"06" =>   -- C431 writes: offset0->p1, offset4->p2, offset12->p3
                        if write_mask(1 downto 0) /= "00" then
                           if addr(4 downto 2) = "000" then kc_p1 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "010" then kc_p2 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "110" then kc_p3 <= data_write(15 downto 0); end if;
                        end if;

                     when x"07" =>   -- C432 writes: offset0->p1, offset2->p2, offset6->p3
                        if write_mask(1 downto 0) /= "00" then
                           if addr(4 downto 2) = "000" then kc_p1 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "001" then kc_p2 <= data_write(15 downto 0); end if;
                           if addr(4 downto 2) = "011" then kc_p3 <= data_write(15 downto 0); end if;
                        end if;

                     when x"08" | x"09" =>   -- C442 / C443 writes: offset0->p1, offset1->p2
                        if addr(4 downto 2) = "000" then
                           if write_mask(1 downto 0) /= "00" then
                              kc_p1 <= data_write(15 downto 0);          -- offset 0
                           end if;
                           if write_mask(3 downto 2) /= "00" then
                              kc_p2 <= data_write(31 downto 16);         -- offset 1
                           end if;
                        end if;

                     when others => null;
                  end case;
               end if;
               if write_en = '1' then
                  if unsigned(addr) >= 16#10020# and unsigned(addr) <= 16#1002F# then
                     -- ROM8 bank registers. ★ 2026-07-06 ROOT-CAUSE FIX: CPU stores arrive
                     -- WORD-ALIGNED (cpu.vhd:2361 forces addr(1:0)="00"); the halfword lane
                     -- is carried in write_mask ("0011"=even reg 0x20/24/28/2C, "1100"=odd
                     -- reg 0x22/26/2A/2E, "1111"=sw covers both), data positional — the same
                     -- convention the mailbox (write_mask) and EEPROM (byteena) already use.
                     -- The old addr(1) decode could never see odd regs (addr(1) always 0):
                     -- each odd-reg sh aliased onto the EVEN window with lane-0 zeros,
                     -- wiping windows right after the mapper set them -> s11_bank stuck 0
                     -- -> movie chunk header read from page 0 (bit31 set) -> attract park.
                     -- page: rom8 = d[7:6] & d[1:0] (MAME rom8_w, 4 bits);
                     -- rom8_64 (C443) = (d[7:6] & d[2:0]) XOR upper-latch<<4 (MAME rom8_64_w,
                     -- 5 bits; the XOR happens here at write time, per set_entry semantics).
                     for w in 0 to 3 loop
                        if to_integer(unsigned(addr(3 downto 2))) = w then
                           if write_mask(1 downto 0) /= "00" then
                              if keycus_id = x"09" then
                                 s11_bank_r(w*10+4 downto w*10) <=
                                    (data_write(7) xor s11_up) & data_write(6) & data_write(2 downto 0);
                              else
                                 s11_bank_r(w*10+4 downto w*10) <=
                                    '0' & data_write(7 downto 6) & data_write(1 downto 0);
                              end if;
                           end if;
                           if write_mask(3 downto 2) /= "00" then
                              if keycus_id = x"09" then
                                 s11_bank_r(w*10+9 downto w*10+5) <=
                                    (data_write(23) xor s11_up) & data_write(22) & data_write(18 downto 16);
                              else
                                 s11_bank_r(w*10+9 downto w*10+5) <=
                                    '0' & data_write(23 downto 22) & data_write(17 downto 16);
                              end if;
                           end if;
                        end if;
                     end loop;
                  end if;
               end if;

            elsif eeprom_cs = '1' then
               if read_en = '1' then
                  data_read_r <= eeprom_dout_polled;  -- build #117: data-polling overlay
               end if;
               -- writes handled combinatorially via eeprom_wr → altsyncram
            else

               if read_en = '1' then
                  -- addr(20 downto 2) = word index = byte_offset/4; patterns: format(byte>>2, '019b')
                  case addr(20 downto 2) is
                     when "0000000000000000000" =>  -- 0x000000 P1
                        data_read_r <= p1_v;
                     when "0000000000001000000" =>  -- 0x000100 P2
                        data_read_r <= p2_v;
                     when "0000000000010000000" =>  -- 0x000200 Service
                        data_read_r <= svc_v;
                     when "0000000000011000000" =>  -- 0x000300 System
                        data_read_r <= sys_v;
                     when "0000100000000000000" =>  -- 0x010000 P3 (unused, all not-pressed)
                        data_read_r <= (others => '1');
                     when "0000100000001000000" =>  -- 0x010100 P4 (unused, all not-pressed)
                        data_read_r <= (others => '1');
                     when "0000100000010000000" =>  -- 0x010200 Board config
                        data_read_r <= x"000000" & board_cfg;
                     when "0000100000011000000" =>  -- 0x010300 Sec select
                        -- build #117b: return full byte (MAME returns m_znsecsel verbatim)
                        data_read_r <= x"000000" & znsecsel_byte;
                     when "0001000000000000000" =>  -- 0x020000 Coin I/O
                        data_read_r <= x"000000" & coin_r;
                     when others =>
                        null;  -- MAME: noprw/nopr returns 0 for unrecognised ZN I/O addresses
                  end case;
               end if;

               if write_en = '1' then
                  case addr(20 downto 2) is
                     when "0000100000011000000" =>  -- 0x010300 Sec select
                        sec_sel_r <= data_write(7) & data_write(3 downto 2);
                        znsecsel_byte <= data_write(7 downto 0);  -- build #117b
                     when "0001000000000000000" =>  -- 0x020000 Coin I/O
                        coin_r <= data_write(7 downto 0);
                     when others => null;
                  end case;
               end if;

            end if;
         end if;
      end if;
   end process;

end architecture;
