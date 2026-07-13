-- ============================================================================
-- c352 (BRAM edition) -- Namco C352 32-voice PCM sound chip
-- ----------------------------------------------------------------------------
-- DROP-IN replacement for rtl/c352.vhd (same entity name + port list).
-- Functionally bit-exact to the register-array implementation (verified with
-- the tb_c352cmp dual-DUT GHDL harness, zero sample diff); the difference is
-- WHERE per-voice state lives:
--
--   * 7 MCU-programmed 16-bit params/voice (vol_f, vol_r, freq, wave_bank,
--     wave_start, wave_end, wave_loop)          -> 32x112 inferred block RAM
--   * runtime state (pos24, counter16, smp16, last_smp16, cvol0..3)
--                                               -> 32x104 inferred block RAM
--   * FLAGS stay a 32x16 register array: the MCU read-back (cs_rdata) is
--     COMBINATIONAL (c76_sound muxes c352_rdata straight into ext_din and acks
--     in 1 cycle) and the keyon commit touches all 32 voices in one cycle.
--     512 FF is cheap; everything else (6912 FF + the 32:1 mux trees) moves
--     to RAM.
--
-- The serial voice FSM reads a voice's whole state at slot start (prefetched
-- during the previous voice's S_MINT/S_MLR) and writes it back at S_MINT.
--
-- TIMING BUDGET (hardware: clk_1x = 33.87 MHz, sample_ce every 384 clk): the
-- slot pipeline is VSTART -> [FETCH_W x f] -> MINT -> MLR = 3+f clk per voice
-- (f = wave-ROM wait, 0 for idle/noise/no-overflow voices), cycle-for-cycle
-- IDENTICAL to the register-file original's VSTART/MIX/NEXT slot -- a full
-- 32-voice pass fits the 384-clk budget exactly when the original did, and
-- under momentary overload both drop the same ticks (no accumulating lag).
-- (An earlier revision serialized the two volume products through one
-- multiplier + a separate S_NEXT state = +2 clk per audible voice; that
-- overflowed 384 and lagged the sample stream one tick -> wrong pitch.)
--
-- MCU write arbitration: MCU byte writes to the param registers can arrive at
-- any time. They are queued in a small FIFO and drained by a 2-cycle
-- read-modify-write engine on the param RAM's spare port slots (the FSM read
-- has priority; an RMW write that would collide with the FSM's read of the
-- same voice word is retried the next cycle so a mixed-port read-during-write
-- to the same address never happens -> "no_rw_check" is safe). Flags writes
-- and the keyon commit (0x405) bypass the FIFO and hit the flag registers
-- immediately, exactly like the original.
--
-- Keyon/keyoff: flag effects (BUSY/KEYON/KEYOFF/LOOPHIST) are applied to the
-- flag registers in the commit cycle (identical to the original, incl. the
-- combinational readback the C76 firmware depends on). The runtime-state
-- effects (pos <- bank&start, counter <- 0xFFFF, smp/last/cvol <- 0) are
-- applied via per-voice pending bits when the FSM next visits the voice --
-- which produces the same output stream, since the original also only USES
-- that state when the voice's slot comes around.
--
-- Multipliers: TWO 18x18 signed multipliers, time-shared: mul1 does the
-- interpolation product (S_MINT) then the front-left volume (S_MLR); mul2
-- does the front-right volume (S_MLR). No DSP assumption -- soft logic
-- (~180 ALMs each), still frees the 3 DSPs the register-array version used.
--
-- Documented behavioral corners vs the original (see sim/c352bram/README-
-- level notes in the harness):
--   1. A keyon commit landing DURING the ~5-25 cycle slot of that same voice:
--      original had a partial-overwrite race (FSM slot-end writes clobbered
--      some of the keyon-initialized state); here the init cleanly applies at
--      the voice's next visit. The original's S_MIX in that race contributes
--      0 (smp/last/cvol just zeroed); we reproduce that by gating the mix on
--      "busy at slot start AND busy now".
--   2. Param writes landing inside a voice's active slot: the original read
--      wave_end/loop live in S_FETCH_W; here params are captured at slot
--      start (one-slot-earlier snapshot). Only observable if the MCU rewrites
--      a param in the exact slot window; the firmware programs voices between
--      samples.
--   3. After reset deasserts, 32 cycles are spent scrubbing the state RAM
--      (a sample_ce in that window is skipped; the original could start a
--      pass immediately). All voices are idle then, so only the sample COUNT
--      during reset-exit can differ, never a value.
--
-- ============================================================================
-- WAVE-FETCH ADAPTER + TICK CREDITS (2026-07-11) -- SDRAM-latency tolerance.
-- ----------------------------------------------------------------------------
-- On hardware the wave ROM lives in SDRAM behind the LOWEST-priority arbiter
-- channel (ch3, behind CPU ch1 + GPU ch2 + refresh). The mixer FSM blocks in
-- S_FETCH_W per fetch; its whole 32-voice pass must fit the 384-clk sample
-- period, so N_fetch x fetch_latency <= ~286 clk. Idle-bus ch3 latency
-- (~15 clk) fits ~19 fetches; under gameplay DMA storms ch3 latency bursts to
-- 50-600+ clk (worst measured >2500), so passes overran, sample_ce pulses were
-- missed, voices froze/repeated -> audible static that lessens when the OSD
-- pause gates the MIPS/GPU (= SDRAM contention drops). Fixed FETCH-SIDE ONLY;
-- the mixer FSM datapath/state semantics are untouched:
--
--   * the FSM's old byte-wide rom_* handshake is now internal (fs_*) and is
--     answered by a fetch adapter with a per-voice 32-bit LINE CACHE
--     (32 x {tag22,valid,word32}); the external rom_* port fetches whole
--     word-aligned 32-bit words (the SDRAM reader always read 32 bits and
--     threw 3 bytes away). Hits serve in 2 clk -> a full 32-voice all-hit
--     pass is ~162 clk, always inside the budget.
--   * EXACT-ADDRESS PREFETCH: after each served fetch the FSM has already
--     computed that voice's next fetch position (cur_pos, including loop/
--     reverse/ping-pong/LINK). If that word is not cached it is queued and
--     fetched in the BACKGROUND while the pass continues -> the next fetch of
--     that voice (>= 384 clk away, >= 768 at freq <= 0x8000) hits. Keyon
--     start addresses are prefetched too (walker reads pram via the spare
--     read-port slots). Wave ROM is immutable, so cached words can never go
--     stale, prefetch is only ever a performance hint, and correctness never
--     depends on prediction (tags are exact).
--   * TICK CREDITS (LAG_CREDITS generic, 0 disables): a sample_ce that lands
--     while a pass is still blocked on a demand miss is no longer DROPPED; up
--     to 7 ticks are queued and the FSM runs back-to-back catch-up passes.
--     The output sample SEQUENCE stays exactly the reference sequence; a
--     burst just delays (never skips) pass completion, bounded by 7 ticks.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity c352 is
   generic (
      -- max sample ticks queued while a pass is blocked on a wave fetch
      -- (0 = legacy behavior: a tick landing mid-pass is dropped)
      LAG_CREDITS : integer range 0 to 7 := 7
   );
   port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      sample_ce  : in  std_logic;                       -- pulse at the output sample rate

      -- register write port from the C76 (byte granularity, offset within 0x000-0xFFF)
      cs_addr    : in  std_logic_vector(11 downto 0);
      cs_din     : in  std_logic_vector(7 downto 0);
      cs_wr      : in  std_logic;
      cs_rdata   : out std_logic_vector(7 downto 0);

      -- wave ROM read interface: WORD fetches (32-bit little-endian data at a
      -- word-aligned byte address, rom_addr(1:0)="00"); rom_rd is held level
      -- until rom_ready. One SDRAM transaction now fills a whole 4-byte line.
      rom_addr   : out std_logic_vector(23 downto 0) := (others => '0');
      rom_rd     : out std_logic := '0';
      rom_data   : in  std_logic_vector(31 downto 0);
      rom_ready  : in  std_logic;

      -- audio output (signed 16-bit stereo, updated each sample_ce)
      dbg_busy_cnt : out std_logic_vector(5 downto 0) := (others => '0');  -- # voices with FLG_BUSY (silence triage)
      audio_l    : out std_logic_vector(15 downto 0);
      audio_r    : out std_logic_vector(15 downto 0)
   );
end entity;

architecture arch of c352 is

   -- flag bit positions (see MAME C352_FLG_*)
   constant FLG_BUSY    : integer := 15;
   constant FLG_KEYON   : integer := 14;
   constant FLG_KEYOFF  : integer := 13;
   constant FLG_LOOPHIST: integer := 11;
   constant FLG_PHASERL : integer := 9;
   constant FLG_PHASEFL : integer := 8;
   constant FLG_PHASEFR : integer := 7;
   constant FLG_LDIR    : integer := 6;
   constant FLG_LINK    : integer := 5;
   constant FLG_NOISE   : integer := 4;
   constant FLG_MULAW   : integer := 3;
   constant FLG_FILTER  : integer := 2;
   constant FLG_LOOP    : integer := 1;   -- C352_FLG_LOOP = 0x0002
   constant FLG_REVERSE : integer := 0;   -- C352_FLG_REVERSE = 0x0001

   type u16_arr is array(0 to 31) of unsigned(15 downto 0);

   -- flags stay registers (combinational MCU readback + 1-cycle keyon commit)
   signal flags : u16_arr := (others => (others => '0'));

   -- pending keyon/keyoff runtime-state init, applied at the voice's next slot
   signal pend_kon, pend_koff : std_logic_vector(31 downto 0) := (others => '0');

   signal noise_lfsr : unsigned(15 downto 0) := x"1234";

   ----------------------------------------------------------------------------
   -- param RAM: 32 x 112  (one word per voice)
   --   [111:96] vol_f  [95:80] vol_r  [79:64] freq  [63:48] wave_bank
   --   [47:32]  wave_start  [31:16] wave_end  [15:0] wave_loop
   ----------------------------------------------------------------------------
   subtype pword_t is std_logic_vector(111 downto 0);
   type pram_t is array(0 to 31) of pword_t;

   signal pram : pram_t := (others => (others => '0'));
   attribute ramstyle : string;
   attribute ramstyle of pram : signal is "M10K, no_rw_check";
   signal pram_we    : std_logic;
   signal pram_waddr : integer range 0 to 31;
   signal pram_wdata : pword_t;
   signal pram_re    : std_logic;
   signal pram_raddr : integer range 0 to 31;
   signal pram_q     : pword_t := (others => '0');

   ----------------------------------------------------------------------------
   -- state RAM: 32 x 104
   --   [103:80] pos  [79:64] counter  [63:48] smp  [47:32] last_smp
   --   [31:24] cvol0  [23:16] cvol1  [15:8] cvol2  [7:0] cvol3
   ----------------------------------------------------------------------------
   subtype sword_t is std_logic_vector(103 downto 0);
   type sram_t is array(0 to 31) of sword_t;

   signal sram : sram_t := (others => (others => '0'));
   attribute ramstyle of sram : signal is "M10K, no_rw_check";
   signal sram_we    : std_logic;
   signal sram_waddr : integer range 0 to 31;
   signal sram_wdata : sword_t;
   signal sram_re    : std_logic;
   signal sram_raddr : integer range 0 to 31;
   signal sram_q     : sword_t := (others => '0');

   ----------------------------------------------------------------------------
   -- MCU param-write FIFO + read-modify-write engine
   ----------------------------------------------------------------------------
   type fifo_t is array(0 to 7) of std_logic_vector(16 downto 0);  -- addr(8:0) & data(7:0)
   signal fifo : fifo_t := (others => (others => '0'));
   signal f_wp, f_rp : unsigned(2 downto 0) := (others => '0');

   type wst_t is (W_IDLE, W_MRG, W_WR2);
   signal wst      : wst_t := W_IDLE;
   signal rmw_word : pword_t := (others => '0');

   signal head       : std_logic_vector(16 downto 0);
   signal head_voice : integer range 0 to 31;
   signal rmw_req    : std_logic;
   signal wr_col     : std_logic;
   signal merged_comb: pword_t;

   -- mu-law decode table (ROM)
   type mulaw_t is array(0 to 255) of signed(15 downto 0);
   function gen_mulaw return mulaw_t is
      variable t : mulaw_t;
      variable j : integer := 0;
   begin
      for i in 0 to 127 loop
         t(i) := to_signed(j*32, 16);
         if    i < 16 then j := j + 1;
         elsif i < 24 then j := j + 2;
         elsif i < 48 then j := j + 4;
         elsif i < 100 then j := j + 8;
         else j := j + 16; end if;
      end loop;
      for i in 0 to 127 loop
         t(i+128) := signed((not unsigned(std_logic_vector(t(i)))) and x"ffe0");
      end loop;
      return t;
   end function;
   constant MULAW : mulaw_t := gen_mulaw;

   -- voice-processing FSM
   type st_t is (S_CLEAR, S_IDLE, S_VSTART, S_FETCH_W, S_MINT, S_MLR, S_DONE);
   signal st      : st_t := S_CLEAR;
   signal vidx    : integer range 0 to 31 := 0;
   signal clr_idx : integer range 0 to 31 := 0;
   signal acc_l, acc_r : signed(23 downto 0) := (others => '0');

   -- per-slot working registers (the ONLY per-voice state kept in FF, one copy)
   signal cur_pos     : unsigned(23 downto 0) := (others => '0');
   signal cur_counter : unsigned(15 downto 0) := (others => '0');
   signal cur_smp     : signed(15 downto 0) := (others => '0');
   signal cur_last    : signed(15 downto 0) := (others => '0');
   signal cur_c0, cur_c1, cur_c2, cur_c3 : unsigned(7 downto 0) := (others => '0');
   signal cur_end     : unsigned(15 downto 0) := (others => '0');   -- wave_end snapshot
   signal cur_loop    : unsigned(15 downto 0) := (others => '0');   -- wave_loop snapshot
   signal cur_startlo : unsigned(7 downto 0)  := (others => '0');   -- wave_start(7:0) snapshot (LINK)
   signal busy_v      : std_logic := '0';                           -- BUSY at slot start
   signal sgn_r       : signed(15 downto 0) := (others => '0');     -- interpolated sample for S_MLR

   -- FSM RAM prefetch (voice N+1 read during voice N's S_MINT/S_MLR)
   signal fsm_pre   : std_logic;
   signal fsm_raddr : integer range 0 to 31;

   -- the TWO shared multipliers (mul1: interpolation @S_MINT then vol-L
   -- @S_MLR; mul2: vol-R @S_MLR). Soft logic, no DSP assumption.
   signal mul_a, mul_b   : signed(17 downto 0) := (others => '0');
   signal mul_p          : signed(35 downto 0);
   signal mul2_a, mul2_b : signed(17 downto 0) := (others => '0');
   signal mul2_p         : signed(35 downto 0);

   -- volume ramp one channel toward its target
   function ramp1(cv : unsigned(7 downto 0); tgt : unsigned(7 downto 0)) return unsigned is
   begin
      if    cv = tgt then return cv;
      elsif cv > tgt then return cv - 1;
      else                return cv + 1;
      end if;
   end function;

   -- merge one MCU byte into a 112-bit param word.  a = cs_addr(3:0):
   -- reg = a(3:1) in {0,1,2,4,5,6,7} (3 = flags, never queued), hi = a(0).
   -- Statically-unrolled loop (no dynamic slice bounds -> synthesis-safe).
   function merge_byte(w : pword_t; a : std_logic_vector(3 downto 0);
                       d : std_logic_vector(7 downto 0)) return pword_t is
      variable r  : pword_t := w;
      variable rg : integer range 0 to 7;
      variable sl : integer range 0 to 6;
   begin
      rg := to_integer(unsigned(a(3 downto 1)));
      if rg < 3 then sl := rg; else sl := rg - 1; end if;
      -- static per-slice case (variable slice bounds provoke Quartus 10821 in the
      -- downstream RAM-input cone; keep every slice index a literal)
      if a(0) = '1' then
         case sl is
            when 0 => r(111 downto 104) := d;
            when 1 => r( 95 downto  88) := d;
            when 2 => r( 79 downto  72) := d;
            when 3 => r( 63 downto  56) := d;
            when 4 => r( 47 downto  40) := d;
            when 5 => r( 31 downto  24) := d;
            when 6 => r( 15 downto   8) := d;
         end case;
      else
         case sl is
            when 0 => r(103 downto  96) := d;
            when 1 => r( 87 downto  80) := d;
            when 2 => r( 71 downto  64) := d;
            when 3 => r( 55 downto  48) := d;
            when 4 => r( 39 downto  32) := d;
            when 5 => r( 23 downto  16) := d;
            when 6 => r(  7 downto   0) := d;
         end case;
      end if;
      return r;
   end function;

   ----------------------------------------------------------------------------
   -- wave-fetch adapter (fetch side ONLY -- see header). The mixer FSM keeps
   -- its original byte handshake, now on the internal fs_* signals.
   ----------------------------------------------------------------------------
   signal fs_addr   : std_logic_vector(23 downto 0) := (others => '0');  -- FSM byte address
   signal fs_rd     : std_logic := '0';                                  -- FSM fetch strobe (level)
   signal fs_data   : std_logic_vector(7 downto 0) := (others => '0');   -- byte back to FSM
   signal fs_ready  : std_logic := '0';                                  -- 1-cycle serve pulse

   -- per-voice line cache: one 32-bit wave-ROM word per voice.
   -- tags/valid in FF (combinational hit check); data in a 32x32 LUTRAM whose
   -- read address is ALWAYS vidx (q settled 1 clk after the slot starts).
   type wtag_t is array(0 to 31) of unsigned(21 downto 0);
   signal wc_tag    : wtag_t := (others => (others => '1'));
   signal wc_valid  : std_logic_vector(31 downto 0) := (others => '0');
   type wdat_t is array(0 to 31) of std_logic_vector(31 downto 0);
   signal wc_data   : wdat_t := (others => (others => '0'));
   attribute ramstyle of wc_data : signal is "MLAB, no_rw_check";
   signal wc_q      : std_logic_vector(31 downto 0) := (others => '0');
   signal wc_we     : std_logic;

   -- last-fill bypass: wc_q lags a same-entry write by 2 clk (registered read
   -- of a signal-array write); the newest fill is therefore also held in FFs
   -- and checked FIRST, so a just-filled line serves correctly.
   signal fb_v      : integer range 0 to 31 := 0;
   signal fb_tag    : unsigned(21 downto 0) := (others => '1');
   signal fb_word   : std_logic_vector(31 downto 0) := (others => '0');
   signal fb_valid  : std_logic := '0';

   signal f_hit_fb  : std_logic;
   signal f_hit     : std_logic;

   -- background prefetch: per-voice wanted-word (idempotent, no queue to
   -- overflow -- always the LATEST known next word of that voice)
   signal pf_want   : std_logic_vector(31 downto 0) := (others => '0');
   type ptag_t is array(0 to 31) of unsigned(21 downto 0);
   signal pf_addr   : ptag_t := (others => (others => '0'));

   -- keyon walker: on a keyon commit, read each keyon'd voice's pram word via
   -- the read port's spare slots and queue a prefetch of its start position
   signal kon_pend  : std_logic_vector(31 downto 0) := (others => '0');
   type kwst_t is (K_IDLE, K_REQ, K_WAITQ);
   signal kwst      : kwst_t := K_IDLE;
   signal kw_v      : integer range 0 to 31 := 0;
   signal kw_grant  : std_logic;

   -- external fill engine (one word fetch in flight; demand misses preempt
   -- the prefetch queue at issue time)
   type est_t is (E_IDLE, E_WAIT);
   signal est       : est_t := E_IDLE;
   signal e_dst     : integer range 0 to 31 := 0;
   signal e_tag     : unsigned(21 downto 0) := (others => '0');
   signal e_dem     : std_logic := '0';

   signal st_d      : st_t := S_IDLE;              -- FSM state delayed 1 clk (snoop edge)

   -- queued sample ticks (see LAG_CREDITS)
   signal tick_pend : unsigned(2 downto 0) := (others => '0');

   function bsel(w : std_logic_vector(31 downto 0);
                 a : std_logic_vector(1 downto 0)) return std_logic_vector is
   begin
      case a is
         when "00"   => return w(7 downto 0);
         when "01"   => return w(15 downto 8);
         when "10"   => return w(23 downto 16);
         when others => return w(31 downto 24);
      end case;
   end function;

begin

   ----------------------------------------------------------------------------
   -- Register read-back (combinational) -- IDENTICAL to the original.
   -- The C76 firmware drives its per-voice engine off C352 flag reads; only
   -- the FLAGS register (reg 3) is ever read, and it must be combinational
   -- (c76_sound acks the read in 1 cycle). Flags live in registers here.
   ----------------------------------------------------------------------------
   process(cs_addr, flags)
      variable off : unsigned(11 downto 0);
      variable w   : unsigned(15 downto 0);
   begin
      off := unsigned(cs_addr);
      w   := (others => '0');
      if off < x"200" and off(3 downto 1) = "011" then
         w := flags(to_integer(off(8 downto 4)));
      end if;
      if off(0) = '1' then cs_rdata <= std_logic_vector(w(15 downto 8));
      else                 cs_rdata <= std_logic_vector(w(7 downto 0));
      end if;
   end process;

   ----------------------------------------------------------------------------
   -- inferred block RAMs (simple dual port: 1 write + 1 read, registered q)
   ----------------------------------------------------------------------------
   -- Inferred simple-dual-port RAMs (unconditional registered reads — sim-verified
   -- bit-exact vs the register-array original at the HW 384-clk budget).
   pram_proc : process(clk)
   begin
      if rising_edge(clk) then
         if pram_we = '1' then pram(pram_waddr) <= pram_wdata; end if;
         pram_q <= pram(pram_raddr);
      end if;
   end process;

   sram_proc : process(clk)
   begin
      if rising_edge(clk) then
         if sram_we = '1' then sram(sram_waddr) <= sram_wdata; end if;
         sram_q <= sram(sram_raddr);
      end if;
   end process;

   ----------------------------------------------------------------------------
   -- RAM port scheduling (combinational)
   ----------------------------------------------------------------------------
   -- FSM prefetch: voice 0's word while idle-with-tick; voice N+1's words
   -- during voice N's S_MINT, with the address HELD through S_MLR -- the dpram
   -- registers address_b every cycle, so holding it for both cycles makes q_b
   -- carry voice N+1's word exactly when S_VSTART(N+1) consumes it (q_b =
   -- mem[address registered at the END of the previous cycle]).
   fsm_pre   <= '1' when (st = S_IDLE and (sample_ce = '1' or tick_pend /= 0)) or
                         ((st = S_MINT or st = S_MLR) and vidx /= 31) else '0';
   fsm_raddr <= 0 when st = S_IDLE else (vidx + 1) mod 32;

   -- state RAM: read = FSM prefetch; write = slot-end writeback / reset scrub.
   -- (read and write are in different FSM states -> never the same cycle)
   sram_re    <= fsm_pre;
   sram_raddr <= fsm_raddr;
   sram_we    <= '1' when st = S_MINT or st = S_CLEAR else '0';
   sram_waddr <= clr_idx when st = S_CLEAR else vidx;
   sram_wdata <= (others => '0') when st = S_CLEAR else
                 std_logic_vector(cur_pos) & std_logic_vector(cur_counter) &
                 std_logic_vector(cur_smp) & std_logic_vector(cur_last) &
                 std_logic_vector(cur_c0)  & std_logic_vector(cur_c1) &
                 std_logic_vector(cur_c2)  & std_logic_vector(cur_c3);

   -- param RAM read port: FSM prefetch has priority, RMW engine fills the gaps
   head       <= fifo(to_integer(f_rp));
   head_voice <= to_integer(unsigned(head(16 downto 12)));         -- cs_addr(8:4)
   rmw_req    <= '1' when wst = W_IDLE and f_wp /= f_rp else '0';

   -- keyon walker may borrow the port only when neither the FSM prefetch nor
   -- the RMW engine wants it AND no RMW write can land next cycle (wst=W_IDLE
   -- keeps the walker's registered read clear of any same-word pram_we edge)
   kw_grant   <= '1' when kwst = K_REQ and fsm_pre = '0' and rmw_req = '0'
                          and wst = W_IDLE else '0';
   pram_re    <= fsm_pre or rmw_req or kw_grant;
   pram_raddr <= fsm_raddr when fsm_pre = '1' else
                 head_voice when rmw_req = '1' else kw_v;

   -- param RAM write port: RMW result. Retried if it would collide with an
   -- FSM read of the same word this cycle (avoids mixed-port RDW entirely).
   wr_col      <= '1' when fsm_pre = '1' and fsm_raddr = head_voice else '0';
   merged_comb <= merge_byte(pram_q, head(11 downto 8), head(7 downto 0));
   pram_we     <= '1' when (wst = W_MRG or wst = W_WR2) and wr_col = '0' else '0';
   pram_waddr  <= head_voice;
   pram_wdata  <= merged_comb when wst = W_MRG else rmw_word;

   ----------------------------------------------------------------------------
   -- MCU param-write FIFO + RMW engine
   ----------------------------------------------------------------------------
   rmw_proc : process(clk)
      variable off : unsigned(11 downto 0);
   begin
      if rising_edge(clk) then
         if reset = '1' then
            f_wp <= (others => '0');
            f_rp <= (others => '0');
            wst  <= W_IDLE;
         else
            -- enqueue MCU byte writes to the 7 RAM-backed param registers
            if cs_wr = '1' then
               off := unsigned(cs_addr);
               if off < x"200" and off(3 downto 1) /= "011" then
                  fifo(to_integer(f_wp)) <= cs_addr(8 downto 0) & cs_din;
                  f_wp <= f_wp + 1;
                  -- pragma translate_off
                  assert (f_wp + 1) /= f_rp
                     report "c352 param write FIFO overflow" severity failure;
                  -- pragma translate_on
               end if;
            end if;

            case wst is
               when W_IDLE =>
                  -- read issued this cycle via pram_re/pram_raddr when granted
                  if rmw_req = '1' and fsm_pre = '0' then
                     wst <= W_MRG;
                  end if;
               when W_MRG =>
                  -- pram_q now holds our word; write merged word (concurrent
                  -- pram_we) unless the FSM reads this voice right now.
                  rmw_word <= merged_comb;
                  if wr_col = '1' then
                     wst <= W_WR2;                       -- retry the write
                  else
                     f_rp <= f_rp + 1;
                     wst  <= W_IDLE;
                  end if;
               when W_WR2 =>
                  if wr_col = '0' then
                     f_rp <= f_rp + 1;
                     wst  <= W_IDLE;
                  end if;
            end case;
         end if;
      end if;
   end process;

   ----------------------------------------------------------------------------
   -- the two shared 18x18 multipliers, operands muxed by FSM state.
   -- mul1: interpolation product in S_MINT, front-LEFT volume in S_MLR.
   -- mul2: front-RIGHT volume in S_MLR (second mult lets both channels mix in
   -- ONE cycle, keeping the slot at 3 clk = the register-file original's pace
   -- so a 32-voice pass fits the 384-clk sample period exactly like it did).
   ----------------------------------------------------------------------------
   process(st, cur_counter, cur_smp, cur_last, sgn_r, cur_c0, cur_c1)
   begin
      if st = S_MINT then    -- interpolation: counter * (smp - last)
         mul_a <= signed(resize(cur_counter, 18));
         mul_b <= resize(cur_smp, 18) - resize(cur_last, 18);
      else                   -- S_MLR: front-left volume
         mul_a <= resize(sgn_r, 18);
         mul_b <= signed(resize(cur_c0, 18));
      end if;
      mul2_a <= resize(sgn_r, 18);
      mul2_b <= signed(resize(cur_c1, 18));
   end process;
   mul_p  <= mul_a * mul_b;
   mul2_p <= mul2_a * mul2_b;

   ----------------------------------------------------------------------------
   -- main process: MCU flag writes + keyon commit + voice FSM
   ----------------------------------------------------------------------------
   process(clk)
      variable off      : unsigned(11 downto 0);
      variable vn       : integer range 0 to 31;
      variable do_keyon : boolean;
      variable nc       : unsigned(16 downto 0);
      variable v_cnt    : unsigned(15 downto 0);
      variable v_pos    : unsigned(23 downto 0);
      variable v_smp    : signed(15 downto 0);
      variable v_lst    : signed(15 downto 0);
      variable v_c0, v_c1, v_c2, v_c3 : unsigned(7 downto 0);
      variable v_fl     : unsigned(15 downto 0);
      variable subp     : unsigned(15 downto 0);
      variable nlfsr    : unsigned(15 downto 0);
      variable sgn_v    : signed(15 downto 0);
      variable prod     : signed(31 downto 0);
   begin
      if rising_edge(clk) then
         fs_rd <= '0';

         if reset = '1' then
            st      <= S_CLEAR;
            clr_idx <= 0;
            for i in 0 to 31 loop
               flags(i) <= (others => '0');
            end loop;
            pend_kon  <= (others => '0');
            pend_koff <= (others => '0');
            noise_lfsr <= x"1234";
            tick_pend <= (others => '0');
            audio_l <= (others => '0'); audio_r <= (others => '0');

         else
            -- TICK CREDITS: queue (don't drop) a sample tick that lands while
            -- a pass is still running/blocked; S_IDLE below runs catch-up
            -- passes back-to-back. S_CLEAR keeps the legacy skip (documented
            -- corner 3: the post-reset scrub window).
            if LAG_CREDITS > 0 and sample_ce = '1'
               and st /= S_IDLE and st /= S_CLEAR then
               if tick_pend /= LAG_CREDITS then
                  tick_pend <= tick_pend + 1;
               end if;
            end if;
            -- MCU register writes (byte granularity). Only FLAGS (reg 3) is
            -- register-backed; the other 7 params are queued to the RMW
            -- engine (rmw_proc). Keyon commit = byte write to 0x405.
            do_keyon := false;
            if cs_wr = '1' then
               off := unsigned(cs_addr);
               if off < x"200" then
                  if off(3 downto 1) = "011" then
                     vn := to_integer(off(8 downto 4));
                     if off(0) = '1' then flags(vn)(15 downto 8) <= unsigned(cs_din);
                     else                 flags(vn)(7 downto 0)  <= unsigned(cs_din);
                     end if;
                  end if;
               elsif off = x"405" then
                  do_keyon := true;
               end if;
            end if;

            -- keyon/keyoff FLAG effects: same cycle, all 32 voices (registers)
            if do_keyon then
               for i in 0 to 31 loop
                  if flags(i)(FLG_KEYON) = '1' then
                     flags(i)(FLG_BUSY)     <= '1';
                     flags(i)(FLG_KEYON)    <= '0';
                     flags(i)(FLG_LOOPHIST) <= '0';
                  end if;
                  if flags(i)(FLG_KEYOFF) = '1' then
                     flags(i)(FLG_BUSY)   <= '0';
                     flags(i)(FLG_KEYOFF) <= '0';
                  end if;
               end loop;
            end if;

            case st is
               -- scrub the state RAM once after reset (pos/counter/smp/last/
               -- cvol <- 0, matching the original's reset loop)
               when S_CLEAR =>
                  if clr_idx = 31 then st <= S_IDLE;
                  else clr_idx <= clr_idx + 1; end if;

               when S_IDLE =>
                  if sample_ce = '1' then
                     -- voice 0's RAM words are being read this cycle (fsm_pre)
                     vidx <= 0; acc_l <= (others => '0'); acc_r <= (others => '0');
                     st <= S_VSTART;
                  elsif tick_pend /= 0 then
                     -- catch-up pass for a tick queued while a fetch stalled
                     tick_pend <= tick_pend - 1;
                     vidx <= 0; acc_l <= (others => '0'); acc_r <= (others => '0');
                     st <= S_VSTART;
                  end if;

               -- slot start: pram_q/sram_q hold this voice's words. Apply any
               -- pending keyon/keyoff state init, then decide fetch/noise/mix.
               when S_VSTART =>
                  -- param snapshot needed by S_FETCH_W
                  cur_end     <= unsigned(pram_q(31 downto 16));
                  cur_loop    <= unsigned(pram_q(15 downto 0));
                  cur_startlo <= unsigned(pram_q(39 downto 32));

                  -- effective runtime state
                  v_pos := unsigned(sram_q(103 downto 80));
                  v_cnt := unsigned(sram_q(79 downto 64));
                  v_smp := signed(sram_q(63 downto 48));
                  v_lst := signed(sram_q(47 downto 32));
                  v_c0  := unsigned(sram_q(31 downto 24));
                  v_c1  := unsigned(sram_q(23 downto 16));
                  v_c2  := unsigned(sram_q(15 downto 8));
                  v_c3  := unsigned(sram_q(7 downto 0));
                  if pend_kon(vidx) = '1' then
                     v_pos := unsigned(pram_q(55 downto 48)) & unsigned(pram_q(47 downto 32)); -- bank(7:0) & start
                     v_smp := (others => '0'); v_lst := (others => '0');
                     v_cnt := x"ffff";
                     v_c0 := (others => '0'); v_c1 := (others => '0');
                     v_c2 := (others => '0'); v_c3 := (others => '0');
                  end if;
                  if pend_koff(vidx) = '1' then
                     v_cnt := x"ffff";
                  end if;
                  pend_kon(vidx)  <= '0';
                  pend_koff(vidx) <= '0';

                  -- defaults for the slot-end writeback
                  cur_pos <= v_pos; cur_counter <= v_cnt;
                  cur_smp <= v_smp; cur_last <= v_lst;
                  cur_c0 <= v_c0; cur_c1 <= v_c1; cur_c2 <= v_c2; cur_c3 <= v_c3;
                  busy_v <= flags(vidx)(FLG_BUSY);

                  if flags(vidx)(FLG_BUSY) = '1' then
                     nc := ('0' & v_cnt) + ('0' & unsigned(pram_q(79 downto 64)));  -- + freq
                     -- volume ramp when crossing the 0x18000 region boundary
                     if ((nc xor ('0' & v_cnt)) and "11000000000000000") /= 0 then
                        cur_c0 <= ramp1(v_c0, unsigned(pram_q(111 downto 104)));   -- vol_f hi
                        cur_c1 <= ramp1(v_c1, unsigned(pram_q(103 downto 96)));    -- vol_f lo
                        cur_c2 <= ramp1(v_c2, unsigned(pram_q(95 downto 88)));     -- vol_r hi
                        cur_c3 <= ramp1(v_c3, unsigned(pram_q(87 downto 80)));     -- vol_r lo
                     end if;
                     cur_counter <= nc(15 downto 0);
                     if nc(16) = '1' then        -- counter overflow -> fetch a sample
                        if flags(vidx)(FLG_NOISE) = '1' then
                           if noise_lfsr(0) = '1' then
                              nlfsr := ('0' & noise_lfsr(15 downto 1)) xor x"fff6";
                           else
                              nlfsr := ('0' & noise_lfsr(15 downto 1));
                           end if;
                           noise_lfsr <= nlfsr;
                           cur_last <= v_smp;
                           cur_smp  <= signed(nlfsr);
                           st <= S_MINT;
                        else
                           fs_addr <= std_logic_vector(v_pos);
                           fs_rd <= '1';
                           st <= S_FETCH_W;
                        end if;
                     else
                        st <= S_MINT;
                     end if;
                  else
                     st <= S_MINT;               -- idle voice contributes 0
                  end if;

               when S_FETCH_W =>
                  -- HOLD fs_rd (level, not pulse) until the fetch adapter
                  -- answers (cache hit: 2 clk; miss: one SDRAM word fetch)
                  fs_rd <= '1';
                  if fs_ready = '1' then
                     fs_rd <= '0';
                     cur_last <= cur_smp;
                     if flags(vidx)(FLG_MULAW) = '1' then
                        cur_smp <= MULAW(to_integer(unsigned(fs_data)));
                     else
                        cur_smp <= signed(fs_data) & x"00";   -- s8 << 8
                     end if;
                     -- advance pos with loop / reverse handling
                     v_pos := cur_pos; v_fl := flags(vidx); subp := cur_pos(15 downto 0);
                     if (v_fl(FLG_LOOP) = '1') and (v_fl(FLG_REVERSE) = '1') then
                        if v_fl(FLG_LDIR) = '1' and subp = cur_loop then
                           v_fl(FLG_LDIR) := '0';
                        elsif v_fl(FLG_LDIR) = '0' and subp = cur_end then
                           v_fl(FLG_LDIR) := '1';
                        end if;
                        if v_fl(FLG_LDIR) = '1' then v_pos := v_pos - 1; else v_pos := v_pos + 1; end if;
                     elsif subp = cur_end then
                        if v_fl(FLG_LINK) = '1' and v_fl(FLG_LOOP) = '1' then
                           v_pos := cur_startlo & cur_loop;
                           v_fl(FLG_LOOPHIST) := '1';
                        elsif v_fl(FLG_LOOP) = '1' then
                           v_pos := v_pos(23 downto 16) & cur_loop;
                           v_fl(FLG_LOOPHIST) := '1';
                        else
                           v_fl(FLG_KEYOFF) := '1'; v_fl(FLG_BUSY) := '0';
                           cur_smp <= (others => '0');
                        end if;
                     else
                        if v_fl(FLG_REVERSE) = '1' then v_pos := v_pos - 1; else v_pos := v_pos + 1; end if;
                     end if;
                     cur_pos <= v_pos; flags(vidx) <= v_fl;
                     st <= S_MINT;
                  end if;

               -- state writeback happens THIS cycle (concurrent sram_we);
               -- compute the interpolated sample with mul1; the next voice's
               -- RAM prefetch is issued this cycle too (fsm_pre).
               when S_MINT =>
                  -- MAME: s = last + ((counter * (sample - last)) >> 16), FILTER flag off.
                  -- gate on busy-at-slot-start AND busy-now: reproduces the
                  -- original's zero contribution both when the fetch just
                  -- ended the voice (busy-now=0) and when a keyon commit hit
                  -- mid-slot (original zeroed smp/last/cvol -> product 0).
                  if busy_v = '1' and flags(vidx)(FLG_BUSY) = '1' then
                     if flags(vidx)(FLG_FILTER) = '0' then
                        -- original: last + resize(shift_right(pr,16),16) with
                        -- pr = 34-bit product. numeric_std resize on a SHRINK
                        -- keeps the SIGN bit + low 15 bits -- i.e. the addend
                        -- is pr(33)&pr(30:16), NOT the plain slice pr(31:16).
                        -- mul_p is the 36-bit sign-extended same product, so
                        -- pr(33) == mul_p(35) and pr(30:16) == mul_p(30:16).
                        sgn_v := cur_last + signed(mul_p(35) & mul_p(30 downto 16));
                     else
                        sgn_v := cur_smp;
                     end if;
                  else
                     sgn_v := (others => '0');
                  end if;
                  sgn_r <= sgn_v;               -- 0 for idle voices: adds 0
                  st <= S_MLR;

               -- both channels in ONE cycle (mul1 = L, mul2 = R), phase
               -- inversion per FLG_PHASEFL/FR; then straight to the next
               -- voice (its RAM words were prefetched during S_MINT and the
               -- address held this cycle, so q is valid at its S_VSTART).
               when S_MLR =>
                  prod := resize(signed(mul_p(24 downto 0)), 32);
                  if flags(vidx)(FLG_PHASEFL) = '1' then prod := -prod; end if;
                  acc_l <= acc_l + prod(23 downto 8);
                  prod := resize(signed(mul2_p(24 downto 0)), 32);
                  if flags(vidx)(FLG_PHASEFR) = '1' then prod := -prod; end if;
                  acc_r <= acc_r + prod(23 downto 8);
                  if vidx = 31 then st <= S_DONE;
                  else vidx <= vidx + 1; st <= S_VSTART; end if;

               when S_DONE =>
                  -- final >>3 then truncate to s16 (identical to original)
                  audio_l <= std_logic_vector(resize(acc_l(23 downto 3), 16));
                  audio_r <= std_logic_vector(resize(acc_r(23 downto 3), 16));
                  st <= S_IDLE;
            end case;

            -- pending-init SET must win over this voice's S_VSTART clear when
            -- a keyon commit lands in the exact same cycle -> placed AFTER
            -- the FSM case (last assignment wins).
            if do_keyon then
               for i in 0 to 31 loop
                  if flags(i)(FLG_KEYON) = '1' then pend_kon(i)  <= '1'; end if;
                  if flags(i)(FLG_KEYOFF) = '1' then pend_koff(i) <= '1'; end if;
               end loop;
            end if;
         end if;
      end if;
   end process;


   ----------------------------------------------------------------------------
   -- wave-fetch adapter (fetch side): per-voice word cache + exact prefetch
   ----------------------------------------------------------------------------
   -- hit detect (combinational): the last-fill FF bypass is checked FIRST (it
   -- covers the settle window of a just-written wc_data entry); wc_q covers
   -- everything older. Wave ROM is immutable -> a tag match is always fresh.
   f_hit_fb <= '1' when fb_valid = '1' and fb_v = vidx
                    and fb_tag = unsigned(fs_addr(23 downto 2)) else '0';
   f_hit    <= '1' when f_hit_fb = '1' or
                   (wc_valid(vidx) = '1'
                    and wc_tag(vidx) = unsigned(fs_addr(23 downto 2))) else '0';

   -- line-data RAM: read address is ALWAYS the current voice (vidx is stable
   -- from one cycle before S_VSTART, so wc_q is settled when S_FETCH_W looks)
   wc_we <= '1' when est = E_WAIT and rom_ready = '1' else '0';
   wcram : process(clk)
   begin
      if rising_edge(clk) then
         if wc_we = '1' then wc_data(e_dst) <= rom_data; end if;
         wc_q <= wc_data(vidx);
      end if;
   end process;

   fetch_adapter : process(clk)
      variable pfv   : integer range 0 to 31;
      variable found : boolean;
      variable ntag  : unsigned(21 downto 0);
   begin
      if rising_edge(clk) then
         fs_ready <= '0';
         st_d     <= st;

         -- 1) serve cache hits (any time, even while a background fill runs)
         if fs_rd = '1' and f_hit = '1' then
            if f_hit_fb = '1' then fs_data <= bsel(fb_word, fs_addr(1 downto 0));
            else                   fs_data <= bsel(wc_q,    fs_addr(1 downto 0));
            end if;
            fs_ready <= '1';
         end if;

         -- 2) external fill engine: a demand miss preempts the prefetch queue
         case est is
            when E_IDLE =>
               if fs_rd = '1' and f_hit = '0' then
                  e_dst    <= vidx;
                  e_tag    <= unsigned(fs_addr(23 downto 2));
                  e_dem    <= '1';
                  rom_addr <= fs_addr(23 downto 2) & "00";
                  rom_rd   <= '1';
                  est      <= E_WAIT;
               else
                  found := false; pfv := 0;
                  for i in 0 to 31 loop
                     if not found and pf_want(i) = '1' then
                        pfv := i; found := true;
                     end if;
                  end loop;
                  if found then
                     if wc_valid(pfv) = '1' and wc_tag(pfv) = pf_addr(pfv) then
                        pf_want(pfv) <= '0';                 -- already cached
                     else
                        e_dst    <= pfv;
                        e_tag    <= pf_addr(pfv);
                        e_dem    <= '0';
                        rom_addr <= std_logic_vector(pf_addr(pfv)) & "00";
                        rom_rd   <= '1';
                        est      <= E_WAIT;
                     end if;
                  end if;
               end if;
            when E_WAIT =>
               if rom_ready = '1' then
                  rom_rd          <= '0';
                  wc_tag(e_dst)   <= e_tag;   -- wc_data written via wc_we
                  wc_valid(e_dst) <= '1';
                  fb_v            <= e_dst;
                  fb_tag          <= e_tag;
                  fb_word         <= rom_data;
                  fb_valid        <= '1';
                  if pf_addr(e_dst) = e_tag then pf_want(e_dst) <= '0'; end if;
                  if e_dem = '1' then
                     -- the FSM is blocked in S_FETCH_W on exactly this address
                     fs_data  <= bsel(rom_data, fs_addr(1 downto 0));
                     fs_ready <= '1';
                  end if;
                  est <= E_IDLE;
               end if;
         end case;

         -- 3) keyon commit: queue a pram walk for every keyon'd voice so its
         -- first wave word is (usually) cached before the voice's first slot
         if cs_wr = '1' and unsigned(cs_addr) = x"405" then
            for i in 0 to 31 loop
               if flags(i)(FLG_KEYON) = '1' then kon_pend(i) <= '1'; end if;
            end loop;
         end if;

         -- 4) keyon walker: read pram(kw_v) via the spare read-port slots;
         -- pos24 = pram(55:32) (bank & start) -> word tag = pram(55:34)
         case kwst is
            when K_IDLE =>
               found := false;
               for i in 0 to 31 loop
                  if not found and kon_pend(i) = '1' then
                     kw_v <= i; found := true;
                  end if;
               end loop;
               if found then kwst <= K_REQ; end if;
            when K_REQ =>
               if kw_grant = '1' then kwst <= K_WAITQ; end if;
            when K_WAITQ =>
               -- pram_q holds voice kw_v's word during this cycle
               pf_addr(kw_v)  <= unsigned(pram_q(55 downto 34));
               pf_want(kw_v)  <= '1';
               kon_pend(kw_v) <= '0';
               kwst <= K_IDLE;
         end case;

         -- 5) snoop (placed LAST: a fresh snoop wins any same-cycle pf_want
         -- bookkeeping above): a fetch was just served for voice vidx and the
         -- FSM has computed its EXACT next fetch position (cur_pos, incl.
         -- loop/reverse/ping-pong/LINK). Queue it if it isn't cached.
         if st = S_MINT and st_d = S_FETCH_W then
            if flags(vidx)(FLG_BUSY) = '1' then      -- not one-shot-ended
               ntag := cur_pos(23 downto 2);
               if not ((wc_valid(vidx) = '1' and wc_tag(vidx) = ntag) or
                       (est = E_WAIT and e_dst = vidx and e_tag = ntag)) then
                  pf_addr(vidx) <= ntag;
                  pf_want(vidx) <= '1';
               end if;
            end if;
         end if;

         if reset = '1' then
            -- cache entries deliberately SURVIVE reset (wave ROM immutable,
            -- tags exact); only the work queues are flushed
            pf_want  <= (others => '0');
            kon_pend <= (others => '0');
            kwst     <= K_IDLE;
            fs_ready <= '0';
         end if;
      end if;
   end process;

   -- combinational count of BUSY voices (silence triage) -- unchanged
   busycnt : process(flags)
      variable c : unsigned(5 downto 0);
   begin
      c := (others => '0');
      for i in 0 to 31 loop
         if flags(i)(FLG_BUSY) = '1' then c := c + 1; end if;
      end loop;
      dbg_busy_cnt <= std_logic_vector(c);
   end process;

end architecture;
