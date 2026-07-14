-- ============================================================================
-- M37702 CPU core (Namco C76) -- microcoded sequential core
-- ----------------------------------------------------------------------------
-- 65816-derived 16-bit MCU. Shared effective-address FSM + shared 8/16-bit
-- memory read/write micro-sequences + a per-class execute step. Operand width
-- follows the M flag (accumulator/memory) or X flag (index) at runtime.
-- See docs/system11-m37702-core-plan.md. Reset: PC=read16(0x00FFFE), M0X0, I=1.
--
-- Implemented (boot-path tier): LDA/LDX/LDY/STA/STX/STY/STZ and ALU
-- (ORA/AND/EOR/ADC/SBC/CMP/CPX/CPY/BIT) over imm/dp/abs/dp,X/dp,Y/abs,X/abs,Y;
-- RMW (INC/DEC/ASL/LSR/ROL/ROR) acc+memory; transfers; INX/DEX/INY/DEY; stack
-- push/pull; conditional branches + BRA; JMP/JSR/RTS; flag ops. ADC/SBC are
-- BINARY only (decimal TODO). Indirect modes + 0x42/0x89 prefixes + interrupts
-- are later phases; any unimplemented opcode -> ST_HALT for the trace-diff loop.
-- ============================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity m37702 is
   port (
      clk        : in  std_logic;
      ce         : in  std_logic;
      reset      : in  std_logic;

      bus_addr   : out std_logic_vector(23 downto 0) := (others => '0');
      bus_dout   : out std_logic_vector(7 downto 0) := (others => '0');
      bus_din    : in  std_logic_vector(7 downto 0);
      bus_rd     : out std_logic := '0';
      bus_wr     : out std_logic := '0';
      bus_ready  : in  std_logic;

      irq0       : in  std_logic;
      irq1       : in  std_logic;
      irq2       : in  std_logic;
      irq_tb0    : in  std_logic := '0';   -- Timer B0 interrupt tick (1-cycle pulse); vector 0xFFE4
      irq_tb1    : in  std_logic := '0';   -- Timer B1 interrupt tick (1-cycle pulse); vector 0xFFE2
      irq_ad     : in  std_logic := '0';   -- A-D conversion-complete tick (1-cycle pulse); vector 0xFFD6
      irq_ta2    : in  std_logic := '0';   -- Timer A2 tick (1-cycle pulse); vector 0xFFF0 (music tempo)
      irq_ta3    : in  std_logic := '0';   -- Timer A3 tick (1-cycle pulse); vector 0xFFEE
      -- per-source interrupt PRIORITY (IC register bits[2:0], 0=disabled). The CPU only takes an
      -- interrupt whose priority is > the current IPL (and I-flag clear), and raises IPL to it on
      -- entry. Without this, a low-priority source (e.g. TB1=2) wrongly nests inside a higher ISR.
      prio_int0  : in  unsigned(2 downto 0) := (others=>'0');
      prio_int1  : in  unsigned(2 downto 0) := (others=>'0');
      prio_int2  : in  unsigned(2 downto 0) := (others=>'0');
      prio_tb0   : in  unsigned(2 downto 0) := (others=>'0');
      prio_tb1   : in  unsigned(2 downto 0) := (others=>'0');
      prio_ta2   : in  unsigned(2 downto 0) := (others=>'0');
      prio_ta3   : in  unsigned(2 downto 0) := (others=>'0');
      prio_ad    : in  unsigned(2 downto 0) := (others=>'0');

      dbg_pc     : out std_logic_vector(23 downto 0);
      dbg_opcode : out std_logic_vector(7 downto 0);
      dbg_valid  : out std_logic;
      dbg_halted : out std_logic;
      dbg_x      : out std_logic_vector(15 downto 0)
   );
end entity;

architecture arch of m37702 is

   signal regA   : unsigned(15 downto 0) := (others => '0');
   signal regB   : unsigned(15 downto 0) := (others => '0');  -- 2nd accumulator (0x42 page)
   signal regX   : unsigned(15 downto 0) := (others => '0');
   signal regY   : unsigned(15 downto 0) := (others => '0');
   signal regS   : unsigned(15 downto 0) := (others => '0');
   signal regPC  : unsigned(15 downto 0) := (others => '0');
   signal regPG  : unsigned(7 downto 0)  := (others => '0');
   signal regDT  : unsigned(7 downto 0)  := (others => '0');
   signal regDPR : unsigned(15 downto 0) := (others => '0');

   signal fl_n, fl_v, fl_m, fl_x, fl_d, fl_i, fl_z, fl_c : std_logic := '0';
   signal ipl : unsigned(2 downto 0) := (others => '0');

   signal ir       : std_logic_vector(7 downto 0) := (others => '0');
   signal ea       : unsigned(23 downto 0) := (others => '0');
   signal operand  : unsigned(15 downto 0) := (others => '0');
   signal wval     : unsigned(15 downto 0) := (others => '0');
   signal mask16   : unsigned(15 downto 0) := (others => '0');  -- LDM/SEB/CLB immediate
   signal w8       : std_logic := '0';     -- '1' = 8-bit operand

   signal irq0_l, irq1_l, irq2_l : std_logic := '0';
   signal irq_tb0_pend : std_logic := '0';   -- Timer B0 interrupt pending (set on pulse, cleared when taken)
   signal irq_tb1_pend : std_logic := '0';   -- Timer B1 interrupt pending (the C76's 357x/run service tick @0xC31F)
   signal irq_ad_pend  : std_logic := '0';   -- A-D conversion-complete pending; vector 0xFFD6 -> ISR 0xC30D
   signal irq_ta2_pend : std_logic := '0';   -- Timer A2 pending; vector 0xFFF0
   signal irq_ta3_pend : std_logic := '0';   -- Timer A3 pending; vector 0xFFEE

   type am_t  is (AM_IMP, AM_IMM, AM_DP, AM_DPX, AM_DPY, AM_ABS, AM_ABX, AM_ABY,
                  AM_AL, AM_ALX,    -- absolute long (24-bit) + indexed
                  AM_DXI, AM_DIY, AM_DI,   -- (dp,X) / (dp),Y / (dp) indirect
                  AM_S);                   -- stack-relative: ea = bank0:(regS + 1-byte offset)
   type cls_t is (C_NONE, C_LOAD, C_STORE, C_STZ, C_CMP,
                  C_ORA, C_AND, C_EOR, C_ADC, C_SBC, C_BIT,
                  C_INC, C_DEC, C_ASL, C_LSR, C_ROL, C_ROR,
                  C_JMP, C_JSR, C_JMPI, C_JSRIX,   -- C_JSRIX: 0xFC JSR (abs,X) indirect
                  C_JMPIX,                        -- 0x7C JMP (abs,X) indirect (no push)
                  C_JSL,                          -- 0x22 JSL al (24-bit subroutine)
                  C_JML,                          -- 0x5C JML al (24-bit jump, no push)
                  C_LDM, C_SEB, C_CLB,    -- M37702: store-imm-to-mem, set/clear bits
                  C_BBS, C_BBC,           -- M37702: bit-test-and-branch (0x24/2C/34/3C)
                  C_MPY,                  -- M37702: 0x89-page multiply (A*SRC -> B:A)
                  C_DIV,                  -- M37702: 0x89-page unsigned divide (B:A / SRC -> A=quot, B=rem)
                  C_RLA);                 -- M37702: 0x89 0x49 RLA #imm = rotate acc left by imm bits
   type reg_t is (R_A, R_X, R_Y, R_NONE);
   signal am  : am_t  := AM_IMP;
   signal cls : cls_t := C_NONE;
   signal tgt : reg_t := R_NONE;

   -- M37702 instruction prefixes: 0x42 (B-accumulator page), 0x89 (MUL/DIV page)
   type pfx_t is (PFX_NONE, PFX_42, PFX_89);
   signal pfx   : pfx_t := PFX_NONE;
   signal use_b : std_logic := '0';   -- '1' = accumulator ops target B (0x42 page)

   type state_t is (
      ST_RST_LO, ST_RST_LO_W, ST_RST_HI_W,
      ST_FETCH, ST_FETCH_W, ST_DECODE,
      ST_EA_B0, ST_EA_B0_W, ST_EA_B1_W, ST_EA_B2_W, ST_EA_DONE,
      ST_EA_PTR_LO, ST_EA_PTR_LO_W, ST_EA_PTR_HI_W,
      ST_RD_LO, ST_RD_LO_W, ST_RD_HI_W, ST_EXEC,
      ST_WR_LO, ST_WR_LO_W, ST_WR_HI, ST_WR_HI_W,
      ST_PUSH_HI, ST_PUSH_HI_W, ST_PUSH_LO, ST_PUSH_LO_W,
      ST_PULL_LO, ST_PULL_LO_W, ST_PULL_HI, ST_PULL_HI_W,
      ST_JMP_FIN, ST_BR_W, ST_BR_W2, ST_REPSEP, ST_REPSEP_W,
      ST_JSRIX_LO, ST_JSRIX_LO_W, ST_JSRIX_HI_W,   -- 0xFC JSR (abs,X) indirect target read
      ST_JSL_PC, ST_JSL_FIN,                        -- 0x22 JSL: push PG then PC, then 24-bit jump
      ST_RTL_PG, ST_RTL_PG_W,                       -- 0x6B RTL: after pulling PC, pull PG byte
      ST_BRL_LO, ST_BRL_LO_W, ST_BRL_HI_W,          -- 0x82 BRL: 16-bit relative branch
      ST_PSHPUL_RD, ST_PSHPUL_RD_W,                 -- 0xEB/FB: read the register mask
      ST_PSH_STEP, ST_PUL_STEP, ST_PUL_WB,          -- PSH/PUL bit-iteration
      ST_PFETCH, ST_PFETCH_W, ST_LDT, ST_LDT_W, ST_DIV,
      ST_LDMI_LO, ST_LDMI_LO_W, ST_LDM_RMW, ST_LDMI_HI_W,
      ST_PEA, ST_PEA_W, ST_PEA_HI_W,
      ST_INT_PUSH, ST_INT_PUSH_W, ST_INT_VL, ST_INT_VL_W, ST_INT_VH_W,
      ST_RTI_PULL, ST_RTI_PULL_W,
      ST_RETIRE, ST_HALT
   );
   signal state : state_t := ST_RST_LO;
   signal ret   : state_t := ST_RETIRE;

   signal br_take : std_logic := '0';

   -- 0x89-page DIV: 1-bit-per-cycle restoring divider (16 iters when m=1, 32 when m=0).
   -- Dividend B:A is left-aligned in div_num and shifted into the partial remainder;
   -- div_quot accumulates the FULL 2w-bit quotient (needed for MAME's overflow test).
   signal div_num  : unsigned(31 downto 0) := (others => '0');  -- dividend, shifts left
   signal div_quot : unsigned(31 downto 0) := (others => '0');  -- quotient, shifts in
   signal div_rem  : unsigned(15 downto 0) := (others => '0');  -- partial remainder (< divisor)
   signal div_dsr  : unsigned(15 downto 0) := (others => '0');  -- divisor
   signal div_cnt  : integer range 0 to 32 := 0;

   -- 0xEB PSH / 0xFB PUL: push/pull multiple registers per an 8-bit mask.
   signal psh_mask : std_logic_vector(7 downto 0) := (others => '0');
   signal psh_bit  : integer range 0 to 8 := 0;   -- PSH: forward bit 0..7
   signal pul_ph   : integer range 0 to 7 := 0;   -- PUL: phase over the ordered pull list
   signal pul_cur  : integer range 0 to 7 := 0;   -- PUL: which register the current pull targets
   signal is_pul   : std_logic := '0';
   signal pushval : unsigned(15 downto 0) := (others => '0');
   signal push_w8 : std_logic := '0';

   -- interrupt entry / RTI
   signal int_vec    : unsigned(15 downto 0) := (others => '0');  -- vector address
   signal int_pushpc : unsigned(15 downto 0) := (others => '0');  -- return PC to push
   signal int_step   : unsigned(2 downto 0)  := (others => '0');  -- push/pull sequencer
   signal int_newipl : unsigned(2 downto 0)  := (others => '0');  -- IPL to set AFTER pushing the old one

   -- synthesis translate_off
   signal dbg_lastpc   : std_logic_vector(23 downto 0) := (others => '0'); -- sim: last fetched PC
   signal dbg_lowfired : std_logic := '0';
   -- synthesis translate_on

begin

   process (clk)
      -- flag helpers (assign architecture flag signals directly)
      procedure set_nz(v : unsigned(15 downto 0); eb : std_logic) is
      begin
         if eb = '1' then
            fl_n <= v(7);
            if v(7 downto 0) = x"00" then fl_z <= '1'; else fl_z <= '0'; end if;
         else
            fl_n <= v(15);
            if v = x"0000" then fl_z <= '1'; else fl_z <= '0'; end if;
         end if;
      end procedure;

      procedure set_ps(b : std_logic_vector(7 downto 0)) is
      begin
         fl_c<=b(0); fl_z<=b(1); fl_i<=b(2); fl_d<=b(3);
         fl_x<=b(4); fl_m<=b(5); fl_v<=b(6); fl_n<=b(7);
      end procedure;

      -- In 8-bit index mode (X flag set) the index registers are 8-bit: their high byte
      -- reads as 0 for ALL indexed addressing. Our regX/regY retain a stale high byte
      -- (LDX #imm in 8-bit mode only loads the low byte), so mask it here at every use --
      -- else e.g. JSR (abs,X) @0xC2B2 indexes 0xBEFA by a garbage XH -> wrong jump-table
      -- entry -> jump to 0x0000 -> the C76 BRK-handler derail.
      function mask_idx(v : unsigned(15 downto 0); x8 : std_logic) return unsigned is
      begin
         if x8 = '1' then return x"00" & v(7 downto 0); else return v; end if;
      end function;

      -- write a register from a loaded value, honouring 8/16 width
      procedure load_reg(v : unsigned(15 downto 0); eb : std_logic) is
      begin
         set_nz(v, eb);
      end procedure;

      variable s9    : unsigned(8 downto 0);
      variable s17   : unsigned(16 downto 0);
      variable a16   : unsigned(15 downto 0);
      variable ps    : std_logic_vector(7 downto 0);
      variable r     : unsigned(15 downto 0);
      variable av    : unsigned(15 downto 0);   -- accumulator source (A or B per use_b)
      variable prod  : unsigned(31 downto 0);   -- MPY product
      variable cin   : std_logic;
      variable pw8   : std_logic;                -- PSH/PUL: current reg push/pull width (1=8-bit)
      variable pb    : integer range 0 to 7;     -- PSH/PUL: current bit index
      variable int_take : boolean;               -- interrupt-acceptance: a source was selected
      variable best_prio: unsigned(2 downto 0);  -- highest pending priority found (> ipl)
      variable int_sel  : integer range 0 to 8;  -- 1=TB1 2=TB0 3=INT2 4=INT1 5=INT0 6=AD 7=TA2 8=TA3
      -- write the active accumulator (B if use_b else A), honouring 8/16 width
      procedure wr_acc(v : unsigned(15 downto 0)) is
      begin
         if use_b='1' then
            if w8='1' then regB <= regB(15 downto 8) & v(7 downto 0); else regB <= v; end if;
         else
            if w8='1' then regA <= regA(15 downto 8) & v(7 downto 0); else regA <= v; end if;
         end if;
      end procedure;
      -- same, but width from fl_m (for implied accumulator inc/dec/shift ops)
      procedure wr_acc_m(v : unsigned(15 downto 0)) is
      begin
         if use_b='1' then
            if fl_m='1' then regB <= regB(15 downto 8) & v(7 downto 0); else regB <= v; end if;
         else
            if fl_m='1' then regA <= regA(15 downto 8) & v(7 downto 0); else regA <= v; end if;
         end if;
      end procedure;
   begin
      if rising_edge(clk) then
         if reset = '1' then
            state <= ST_RST_LO;
            bus_rd <= '0'; bus_wr <= '0';
            dbg_valid <= '0'; dbg_halted <= '0';
            fl_m<='0'; fl_x<='0'; fl_d<='0'; fl_i<='1';
            fl_n<='0'; fl_v<='0'; fl_z<='0'; fl_c<='0';
            ipl<=(others=>'0'); regPG<=(others=>'0');
            regDT<=(others=>'0'); regDPR<=(others=>'0');
            pfx<=PFX_NONE; use_b<='0';
            irq0_l<='0'; irq1_l<='0'; irq2_l<='0';
            irq_tb0_pend<='0'; irq_tb1_pend<='0'; irq_ad_pend<='0';
            irq_ta2_pend<='0'; irq_ta3_pend<='0';

         elsif ce = '1' then
            dbg_valid <= '0';
            irq0_l<=irq0; irq1_l<=irq1; irq2_l<=irq2;
            if irq_tb0='1' then irq_tb0_pend<='1'; end if;  -- latch the Timer B0 tick pulse
            if irq_ta2='1' then irq_ta2_pend<='1'; end if;  -- latch the Timer A2 tick pulse
            if irq_ta3='1' then irq_ta3_pend<='1'; end if;  -- latch the Timer A3 tick pulse
            if irq_tb1='1' then irq_tb1_pend<='1'; end if;  -- latch the Timer B1 tick pulse
            if irq_ad ='1' then irq_ad_pend <='1'; end if;  -- latch the A-D completion pulse

            case state is

               -- reset vector ------------------------------------------------
               when ST_RST_LO =>
                  bus_addr <= x"00FFFE"; bus_rd <= '1'; state <= ST_RST_LO_W;
               when ST_RST_LO_W =>
                  if bus_ready='1' then
                     regPC(7 downto 0) <= unsigned(bus_din);
                     bus_addr <= x"00FFFF"; state <= ST_RST_HI_W;
                  end if;
               when ST_RST_HI_W =>
                  if bus_ready='1' then
                     regPC(15 downto 8) <= unsigned(bus_din);
                     bus_rd<='0'; state<=ST_FETCH;
                  end if;

               -- fetch -------------------------------------------------------
               when ST_FETCH =>
                  -- IPL-masked priority interrupt acceptance (matches MAME m37710i_update_irqs):
                  -- take the highest-priority PENDING source whose IC priority STRICTLY exceeds the
                  -- current IPL (I-flag clear), and raise IPL to it on entry (RTI restores IPL).
                  -- Tie order (first wins): TB1>TB0>INT2>INT1>INT0 (lower vector = higher hw prio).
                  -- This stops a low-priority source (TB1=2) from wrongly nesting inside a higher
                  -- ISR (INT0/INT2/TB0=3/4), which corrupted the firmware's stack (S drift -> derail).
                  int_take := false; best_prio := ipl; int_sel := 0;
                  if fl_i='0' then
                     if irq_tb1_pend='1' and prio_tb1  > best_prio then best_prio:=prio_tb1;  int_sel:=1; int_take:=true; end if;
                     if irq_ad_pend ='1' and prio_ad   > best_prio then best_prio:=prio_ad;   int_sel:=6; int_take:=true; end if;
                     if irq_tb0_pend='1' and prio_tb0  > best_prio then best_prio:=prio_tb0;  int_sel:=2; int_take:=true; end if;
                     if irq_ta2_pend='1' and prio_ta2  > best_prio then best_prio:=prio_ta2;  int_sel:=7; int_take:=true; end if;
                     if irq_ta3_pend='1' and prio_ta3  > best_prio then best_prio:=prio_ta3;  int_sel:=8; int_take:=true; end if;
                     if irq2_l='1'       and prio_int2 > best_prio then best_prio:=prio_int2; int_sel:=3; int_take:=true; end if;
                     if irq1_l='1'       and prio_int1 > best_prio then best_prio:=prio_int1; int_sel:=4; int_take:=true; end if;
                     if irq0_l='1'       and prio_int0 > best_prio then best_prio:=prio_int0; int_sel:=5; int_take:=true; end if;
                  end if;
                  if int_take then
                     -- synthesis translate_off
                     report "DBG INT taken sel=" & integer'image(int_sel) &
                            " (1=TB1 2=TB0 3=INT2 4=INT1 5=INT0) at regPC=" & to_hstring(regPC) &
                            " ipl=" & integer'image(to_integer(ipl));
                     -- synthesis translate_on
                     int_newipl <= best_prio;   -- raised at entry completion (after the OLD ipl is pushed)
                     case int_sel is
                        when 1      => int_vec<=x"FFE2"; irq_tb1_pend<='0';
                        when 7      => int_vec<=x"FFEA"; irq_ta2_pend<='0';  -- Timer A2 (MAME m37710_irq_vectors)
                        when 8      => int_vec<=x"FFE8"; irq_ta3_pend<='0';  -- Timer A3
                        when 6      => int_vec<=x"FFD6"; irq_ad_pend <='0';
                        when 2      => int_vec<=x"FFE4"; irq_tb0_pend<='0';
                        when 3      => int_vec<=x"FFF0";
                        when 4      => int_vec<=x"FFF2";
                        when others => int_vec<=x"FFF4";
                     end case;
                     int_pushpc<=regPC; int_step<=(others=>'0'); state<=ST_INT_PUSH;
                  else
                     -- synthesis translate_off
                     if dbg_lowfired = '0' and regPG = x"00" and regPC < x"0080" then
                        report "DBG FIRST-LOW fetch PC=" & to_hstring(std_logic_vector(regPG) & std_logic_vector(regPC)) &
                               " from prevPC=" & to_hstring(dbg_lastpc) & " regS=" & to_hstring(regS) &
                               " ipl=" & integer'image(to_integer(ipl));
                        dbg_lowfired <= '1';
                     end if;
                     dbg_lastpc <= std_logic_vector(regPG) & std_logic_vector(regPC);
                     -- 2026-07-06 music triage: windowed full instruction-fetch trace around
                     -- the observed B94x dispatcher pass (~16.03 ms)
                     if now >= 103000 us and now <= 118000 us then   -- SFX window
                        report "IT " & to_hstring(std_logic_vector(regPG) & std_logic_vector(regPC));
                     end if;
                     -- synthesis translate_on
                     bus_addr <= std_logic_vector(regPG) & std_logic_vector(regPC);
                     dbg_pc   <= std_logic_vector(regPG) & std_logic_vector(regPC);
                     bus_rd<='1'; state<=ST_FETCH_W;
                  end if;
               when ST_FETCH_W =>
                  if bus_ready='1' then
                     -- synthesis translate_off
                     if dbg_pc = x"00DCCB" then
                        report "DISPATCH @DCCB(ANDB) regB(index)=" & to_hstring(regB) & " regDPR=" & to_hstring(regDPR) & " regDT=" & to_hstring(regDT);
                     end if;
                     if dbg_pc = x"00DCCF" then report "DISPATCH @DCCF (after ANDB#000f) regB=" & to_hstring(regB); end if;
                     if dbg_pc = x"00DCD3" then report "DISPATCH @DCD3 (after ASL B)     regB=" & to_hstring(regB); end if;
                     if dbg_pc = x"00DCD7" then report "DISPATCH @DCD7 (after ADCB#dceb) regB=" & to_hstring(regB) & " carry=" & std_logic'image(fl_c); end if;
                     if dbg_pc = x"00DCDA" then
                        report "DISPATCH @DCDA(LDB$00,X) regX=" & to_hstring(regX) & " fl_x=" & std_logic'image(fl_x) & " fl_m=" & std_logic'image(fl_m) & " regDPR=" & to_hstring(regDPR);
                     end if;
                     if dbg_pc = x"00DCDE" then
                        report "DISPATCH @DCDE(PHB) regB(target)=" & to_hstring(regB);
                     end if;
                     -- synthesis translate_on
                     ir<=bus_din; dbg_opcode<=bus_din;
                     regPC<=regPC+1; bus_rd<='0'; state<=ST_DECODE;
                  end if;

               -- decode ------------------------------------------------------
               when ST_DECODE =>
                  am<=AM_IMP; cls<=C_NONE; tgt<=R_NONE;
                  if use_b='1' then av:=regB; else av:=regA; end if;  -- active acc (stable here)
                  if pfx=PFX_NONE and ir=x"42" then
                     pfx<=PFX_42; state<=ST_PFETCH;                           -- B-acc prefix
                  elsif pfx=PFX_NONE and ir=x"89" then
                     pfx<=PFX_89; state<=ST_PFETCH;                           -- MUL/DIV prefix
                  elsif pfx=PFX_89 and ir=x"C2" then
                     state<=ST_LDT;                                           -- LDT #imm8 -> DT
                  elsif pfx=PFX_89 and (ir=x"05" or ir=x"09" or ir=x"0D"
                       or ir=x"15" or ir=x"19" or ir=x"0F" or ir=x"1D" or ir=x"1F"
                       or ir=x"01" or ir=x"11" or ir=x"12" or ir=x"03") then
                     -- MPY (A * SRC -> B:A). Full MAME 89-page dispatch (m37710op.h
                     -- OP(201..21f)): dxi,s,d,dli,imm,a,al,diy,di,siy,dx,dliy,ay,ax,alx.
                     -- All modes with EA plumbing wired; dli(07)/siy(13)/dliy(17) halt
                     -- below (no long-indirect EA yet). MPY sr,S (89 03) is the C76 BIOS
                     -- helper @0xEA6B: PHB / MPY $01,S / PLB / RTS (A*B -> A, B kept).
                     cls<=C_MPY; w8<=fl_m; state<=ST_EA_B0;
                     case ir is
                        when x"09"=>am<=AM_IMM; when x"05"=>am<=AM_DP;
                        when x"0D"=>am<=AM_ABS; when x"15"=>am<=AM_DPX;
                        when x"19"=>am<=AM_ABY; when x"0F"=>am<=AM_AL;
                        when x"1D"=>am<=AM_ABX; when x"1F"=>am<=AM_ALX;
                        when x"01"=>am<=AM_DXI; when x"11"=>am<=AM_DIY;
                        when x"12"=>am<=AM_DI;  when x"03"=>am<=AM_S;
                        when others=>null;
                     end case;
                  elsif pfx=PFX_89 and (ir=x"29" or ir=x"25" or ir=x"2D"
                       or ir=x"35" or ir=x"3D" or ir=x"39" or ir=x"2F" or ir=x"3F"
                       or ir=x"21" or ir=x"31" or ir=x"32" or ir=x"23") then
                     -- DIV (unsigned): B:A / SRC -> quotient A, remainder B.
                     -- MAME 89-page dispatch (m37710op.h OP(22x/23x)): dxi,s,d,dli,imm,a,al,
                     -- diy,di,siy,dx,dliy,ay,ax,alx. All modes with EA plumbing are wired
                     -- here; dli(27)/siy(33)/dliy(37) halt below (no long-indirect EA yet).
                     -- NOTE: MAME's 89 page has NO signed DIVS — MPYS/DIVS are 7750-block
                     -- opcodes (28x-2bx) that MAME leaves unimplemented; unsigned only.
                     cls<=C_DIV; w8<=fl_m; state<=ST_EA_B0;
                     case ir is
                        when x"29"=>am<=AM_IMM; when x"25"=>am<=AM_DP;
                        when x"2D"=>am<=AM_ABS; when x"35"=>am<=AM_DPX;
                        when x"3D"=>am<=AM_ABX; when x"39"=>am<=AM_ABY;
                        when x"2F"=>am<=AM_AL;  when x"3F"=>am<=AM_ALX;
                        when x"21"=>am<=AM_DXI; when x"31"=>am<=AM_DIY;
                        when x"32"=>am<=AM_DI;  when x"23"=>am<=AM_S;
                        when others=>null;
                     end case;
                  elsif pfx=PFX_89 and ir=x"49" then
                     -- RLA #imm : rotate the active accumulator LEFT by imm bit positions
                     -- (imm width follows fl_m). Read the immediate, then rotate in ST_EXEC.
                     cls<=C_RLA; w8<=fl_m; am<=AM_IMM; state<=ST_EA_B0;
                  elsif pfx=PFX_89 and ir=x"28" then
                     -- XAB : exchange the A and B accumulators (16-bit swap), set N/Z from new A.
                     regA<=regB; regB<=regA; set_nz(regB, fl_m); state<=ST_RETIRE;
                  elsif pfx=PFX_89 and (ir=x"07" or ir=x"13" or ir=x"17"
                       or ir=x"27" or ir=x"33" or ir=x"37") then
                     state<=ST_HALT;   -- MPY/DIV dli/siy/dliy TODO (no long-indirect EA plumbing)
                  else
                  -- (use_b already set in ST_PFETCH_W for the 0x42 page; the acc
                  --  inc/dec/shift opcodes below honour it for A vs B)
                  case ir is
                     when x"EA" => state<=ST_RETIRE;                          -- NOP
                     when x"00" =>                                            -- BRK -> vector 0xFFFA
                        -- synthesis translate_off
                        if regPG = x"00" and regPC(15 downto 8) /= x"00" then
                           report "DBG BRK at regPC=" & to_hstring(regPC) & " push_pc=" & to_hstring(regPC+1) & " regS=" & to_hstring(regS);
                        end if;
                        -- synthesis translate_on
                        int_pushpc<=regPC+1;  -- skip signature byte
                        int_vec<=x"FFFA"; int_step<=(others=>'0'); state<=ST_INT_PUSH;
                     when x"40" =>                                            -- RTI
                        -- synthesis translate_off
                        report "DBG RTI start regS=" & to_hstring(regS) & " at regPC=" & to_hstring(regPC);
                        -- synthesis translate_on
                        int_step<=(others=>'0'); state<=ST_RTI_PULL;
                     when x"18" => fl_c<='0'; state<=ST_RETIRE;               -- CLC
                     when x"38" => fl_c<='1'; state<=ST_RETIRE;               -- SEC
                     when x"58" => fl_i<='0'; state<=ST_RETIRE;               -- CLI
                     when x"78" => fl_i<='1'; state<=ST_RETIRE;               -- SEI
                     when x"D8" => fl_m<='0'; state<=ST_RETIRE;               -- CLM (clear M -> 16-bit)
                     when x"F8" => fl_m<='1'; state<=ST_RETIRE;               -- SEM (set M -> 8-bit)
                     when x"B8" => fl_v<='0'; state<=ST_RETIRE;               -- CLV
                     -- transfers
                     -- A<->X/Y transfers honour the 0x42 B-accumulator prefix (av = regB when use_b):
                     -- TBX (0x42 0xAA) must transfer B, not A. A 1-byte bug here read the wrong reg,
                     -- corrupting the C76's RTS jump-table dispatch @0xDCE0 (X=0 -> target 0 -> derail).
                     when x"AA" => regX<=av; set_nz(av,fl_x); state<=ST_RETIRE; -- TAX / TBX
                     when x"A8" => regY<=av; set_nz(av,fl_x); state<=ST_RETIRE; -- TAY / TBY
                     when x"8A" => if use_b='1' then regB<=regX; else regA<=regX; end if; set_nz(regX,fl_m); state<=ST_RETIRE; -- TXA / TXB
                     when x"98" => if use_b='1' then regB<=regY; else regA<=regY; end if; set_nz(regY,fl_m); state<=ST_RETIRE; -- TYA / TYB
                     when x"9B" => regY<=regX; set_nz(regX,fl_x); state<=ST_RETIRE; -- TXY
                     when x"BB" => regX<=regY; set_nz(regY,fl_x); state<=ST_RETIRE; -- TYX
                     when x"1B" => regS<=regA; state<=ST_RETIRE;              -- TCS
                     when x"3B" => regA<=regS; set_nz(regS,'0'); state<=ST_RETIRE; -- TSC
                     when x"5B" => regDPR<=regA; set_nz(regA,'0'); state<=ST_RETIRE; -- TCD
                     when x"7B" => regA<=regDPR; set_nz(regDPR,'0'); state<=ST_RETIRE; -- TDC
                     when x"9A" => regS<=regX; state<=ST_RETIRE;              -- TXS
                     when x"BA" => regX<=regS; set_nz(regS,fl_x); state<=ST_RETIRE; -- TSX
                     -- inc/dec reg
                     when x"E8" => a16:=regX+1; if fl_x='1' then regX<=regX(15 downto 8)&a16(7 downto 0); else regX<=a16; end if; set_nz(a16,fl_x); state<=ST_RETIRE; -- INX
                     when x"C8" => a16:=regY+1; if fl_x='1' then regY<=regY(15 downto 8)&a16(7 downto 0); else regY<=a16; end if; set_nz(a16,fl_x); state<=ST_RETIRE; -- INY
                     when x"CA" => a16:=regX-1; if fl_x='1' then regX<=regX(15 downto 8)&a16(7 downto 0); else regX<=a16; end if; set_nz(a16,fl_x); state<=ST_RETIRE; -- DEX
                     when x"88" => a16:=regY-1; if fl_x='1' then regY<=regY(15 downto 8)&a16(7 downto 0); else regY<=a16; end if; set_nz(a16,fl_x); state<=ST_RETIRE; -- DEY
                     -- accumulator inc/dec (M37702: 1A=DEA, 3A=INA; +B via use_b)
                     when x"1A" => a16:=av-1; wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE; -- DEA/DEB
                     when x"3A" => a16:=av+1; wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE; -- INA/INB
                     -- accumulator shifts (A, or B via use_b / 0x42 page)
                     when x"0A" =>  -- ASL
                        if fl_m='1' then fl_c<=av(7); a16:=av(15 downto 8)&(av(6 downto 0)&'0');
                        else fl_c<=av(15); a16:=av(14 downto 0)&'0'; end if;
                        wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE;
                     when x"4A" =>  -- LSR
                        if fl_m='1' then fl_c<=av(0); a16:=av(15 downto 8)&('0'&av(7 downto 1));
                        else fl_c<=av(0); a16:='0'&av(15 downto 1); end if;
                        wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE;
                     when x"2A" =>  -- ROL
                        if fl_m='1' then a16:=av(15 downto 8)&(av(6 downto 0)&fl_c); fl_c<=av(7);
                        else a16:=av(14 downto 0)&fl_c; fl_c<=av(15); end if;
                        wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE;
                     when x"6A" =>  -- ROR
                        if fl_m='1' then a16:=av(15 downto 8)&(fl_c&av(7 downto 1)); fl_c<=av(0);
                        else a16:=fl_c&av(15 downto 1); fl_c<=av(0); end if;
                        wr_acc_m(a16); set_nz(a16,fl_m); state<=ST_RETIRE;
                     -- stack push
                     when x"48" => pushval<=av; push_w8<=fl_m; ret<=ST_RETIRE; if fl_m='1' then state<=ST_PUSH_LO; else state<=ST_PUSH_HI; end if; -- PHA / PHB (av=regB when 0x42)
                     when x"DA" => pushval<=regX; push_w8<=fl_x; ret<=ST_RETIRE; if fl_x='1' then state<=ST_PUSH_LO; else state<=ST_PUSH_HI; end if; -- PHX
                     when x"5A" => pushval<=regY; push_w8<=fl_x; ret<=ST_RETIRE; if fl_x='1' then state<=ST_PUSH_LO; else state<=ST_PUSH_HI; end if; -- PHY
                     -- PHP/PLP are 16-bit on the M37710: push IPL(hi) + PS(lo), pull PS(lo) + IPL(hi).
                     -- (MAME OP_PHP/OP_PLP push/pull two bytes unconditionally.) A 1-byte PLP left the
                     -- C76's TB1-ISR stack off by one (LDA #imm16/PHA/PLP idiom) -> RTI derailed -> the
                     -- mailbox was never serviced. push high=IPL, low=PS so PS ends on top of stack.
                     when x"08" => ps:=fl_n&fl_v&fl_m&fl_x&fl_d&fl_i&fl_z&fl_c; pushval<=resize(ipl,8)&unsigned(ps); push_w8<='0'; ret<=ST_RETIRE; state<=ST_PUSH_HI; -- PHP (16-bit: IPL+PS)
                     when x"8B" => pushval<=x"00"&regDT; push_w8<='1'; ret<=ST_RETIRE; state<=ST_PUSH_LO; -- PHB
                     when x"4B" => pushval<=x"00"&regPG; push_w8<='1'; ret<=ST_RETIRE; state<=ST_PUSH_LO; -- PHK
                     when x"0B" => pushval<=regDPR; push_w8<='0'; ret<=ST_RETIRE; state<=ST_PUSH_HI; -- PHD
                     -- stack pull (writeback in ST_EXEC)
                     when x"68" => push_w8<=fl_m; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLA
                     when x"FA" => push_w8<=fl_x; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLX
                     when x"7A" => push_w8<=fl_x; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLY
                     when x"28" => push_w8<='0'; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLP (16-bit: PS+IPL)
                     when x"AB" => push_w8<='1'; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLB
                     when x"2B" => push_w8<='0'; ret<=ST_EXEC; state<=ST_PULL_LO; -- PLD
                     when x"60" => push_w8<='0'; ret<=ST_EXEC; cls<=C_JMP; state<=ST_PULL_LO; -- RTS
                     when x"6B" => push_w8<='0'; ret<=ST_RTL_PG; state<=ST_PULL_LO; -- RTL: pull PC(16) then PG(8)
                     when x"EB" => is_pul<='0'; state<=ST_PSHPUL_RD; -- PSH: push multiple regs per mask
                     when x"FB" => is_pul<='1'; state<=ST_PSHPUL_RD; -- PUL: pull multiple regs per mask
                     -- branches
                     when x"10" => br_take<=not fl_n; state<=ST_BR_W;         -- BPL
                     when x"30" => br_take<=fl_n;     state<=ST_BR_W;         -- BMI
                     when x"50" => br_take<=not fl_v; state<=ST_BR_W;         -- BVC
                     when x"70" => br_take<=fl_v;     state<=ST_BR_W;         -- BVS
                     when x"90" => br_take<=not fl_c; state<=ST_BR_W;         -- BCC
                     when x"B0" => br_take<=fl_c;     state<=ST_BR_W;         -- BCS
                     when x"D0" => br_take<=not fl_z; state<=ST_BR_W;         -- BNE
                     when x"F0" => br_take<=fl_z;     state<=ST_BR_W;         -- BEQ
                     when x"80" => br_take<='1';      state<=ST_BR_W;         -- BRA
                     when x"82" => state<=ST_BRL_LO;                          -- BRL (16-bit rel, always)
                     when x"C2" => state<=ST_REPSEP;                          -- REP #imm
                     when x"E2" => state<=ST_REPSEP;                          -- SEP #imm
                     -- memory-operand opcodes: set am/cls/tgt/w8, go to EA
                     when others =>
                        -- defaults overwritten below; HALT if unrecognised
                        state<=ST_EA_B0;
                        case ir is
                           -- LDA
                           when x"A9"=>cls<=C_LOAD;tgt<=R_A;am<=AM_IMM;w8<=fl_m;
                           when x"A3"=>cls<=C_LOAD;tgt<=R_A;am<=AM_S;  w8<=fl_m;  -- LDA sr,S
                           when x"A5"=>cls<=C_LOAD;tgt<=R_A;am<=AM_DP; w8<=fl_m;
                           when x"AD"=>cls<=C_LOAD;tgt<=R_A;am<=AM_ABS;w8<=fl_m;
                           when x"B5"=>cls<=C_LOAD;tgt<=R_A;am<=AM_DPX;w8<=fl_m;
                           when x"BD"=>cls<=C_LOAD;tgt<=R_A;am<=AM_ABX;w8<=fl_m;
                           when x"B9"=>cls<=C_LOAD;tgt<=R_A;am<=AM_ABY;w8<=fl_m;
                           -- LDX
                           when x"A2"=>cls<=C_LOAD;tgt<=R_X;am<=AM_IMM;w8<=fl_x;
                           when x"A6"=>cls<=C_LOAD;tgt<=R_X;am<=AM_DP; w8<=fl_x;
                           when x"AE"=>cls<=C_LOAD;tgt<=R_X;am<=AM_ABS;w8<=fl_x;
                           when x"B6"=>cls<=C_LOAD;tgt<=R_X;am<=AM_DPY;w8<=fl_x;
                           when x"BE"=>cls<=C_LOAD;tgt<=R_X;am<=AM_ABY;w8<=fl_x;
                           -- LDY
                           when x"A0"=>cls<=C_LOAD;tgt<=R_Y;am<=AM_IMM;w8<=fl_x;
                           when x"A4"=>cls<=C_LOAD;tgt<=R_Y;am<=AM_DP; w8<=fl_x;
                           when x"AC"=>cls<=C_LOAD;tgt<=R_Y;am<=AM_ABS;w8<=fl_x;
                           when x"B4"=>cls<=C_LOAD;tgt<=R_Y;am<=AM_DPX;w8<=fl_x;
                           when x"BC"=>cls<=C_LOAD;tgt<=R_Y;am<=AM_ABX;w8<=fl_x;
                           -- STA
                           when x"85"=>cls<=C_STORE;tgt<=R_A;am<=AM_DP; w8<=fl_m;
                           when x"8D"=>cls<=C_STORE;tgt<=R_A;am<=AM_ABS;w8<=fl_m;
                           when x"95"=>cls<=C_STORE;tgt<=R_A;am<=AM_DPX;w8<=fl_m;
                           when x"9D"=>cls<=C_STORE;tgt<=R_A;am<=AM_ABX;w8<=fl_m;
                           when x"99"=>cls<=C_STORE;tgt<=R_A;am<=AM_ABY;w8<=fl_m;
                           -- STX / STY
                           when x"86"=>cls<=C_STORE;tgt<=R_X;am<=AM_DP; w8<=fl_x;
                           when x"8E"=>cls<=C_STORE;tgt<=R_X;am<=AM_ABS;w8<=fl_x;
                           when x"96"=>cls<=C_STORE;tgt<=R_X;am<=AM_DPY;w8<=fl_x;
                           when x"84"=>cls<=C_STORE;tgt<=R_Y;am<=AM_DP; w8<=fl_x;
                           when x"8C"=>cls<=C_STORE;tgt<=R_Y;am<=AM_ABS;w8<=fl_x;
                           when x"94"=>cls<=C_STORE;tgt<=R_Y;am<=AM_DPX;w8<=fl_x;
                           -- LDM (store immediate to memory; M37702 reuses STZ slots)
                           when x"64"=>cls<=C_LDM;am<=AM_DP; w8<=fl_m;
                           when x"9C"=>cls<=C_LDM;am<=AM_ABS;w8<=fl_m;
                           when x"74"=>cls<=C_LDM;am<=AM_DPX;w8<=fl_m;
                           when x"9E"=>cls<=C_LDM;am<=AM_ABX;w8<=fl_m;
                           -- SEB / CLB (set / clear memory bits by immediate mask)
                           when x"04"=>cls<=C_SEB;am<=AM_DP; w8<=fl_m;
                           when x"0C"=>cls<=C_SEB;am<=AM_ABS;w8<=fl_m;
                           when x"14"=>cls<=C_CLB;am<=AM_DP; w8<=fl_m;
                           when x"1C"=>cls<=C_CLB;am<=AM_ABS;w8<=fl_m;
                           -- ORA
                           when x"09"=>cls<=C_ORA;am<=AM_IMM;w8<=fl_m;
                           when x"05"=>cls<=C_ORA;am<=AM_DP; w8<=fl_m;
                           when x"0D"=>cls<=C_ORA;am<=AM_ABS;w8<=fl_m;
                           when x"15"=>cls<=C_ORA;am<=AM_DPX;w8<=fl_m;
                           when x"1D"=>cls<=C_ORA;am<=AM_ABX;w8<=fl_m;
                           when x"19"=>cls<=C_ORA;am<=AM_ABY;w8<=fl_m;
                           -- AND
                           when x"29"=>cls<=C_AND;am<=AM_IMM;w8<=fl_m;
                           when x"25"=>cls<=C_AND;am<=AM_DP; w8<=fl_m;
                           when x"2D"=>cls<=C_AND;am<=AM_ABS;w8<=fl_m;
                           when x"35"=>cls<=C_AND;am<=AM_DPX;w8<=fl_m;
                           when x"3D"=>cls<=C_AND;am<=AM_ABX;w8<=fl_m;
                           when x"39"=>cls<=C_AND;am<=AM_ABY;w8<=fl_m;
                           -- EOR
                           when x"49"=>cls<=C_EOR;am<=AM_IMM;w8<=fl_m;
                           when x"45"=>cls<=C_EOR;am<=AM_DP; w8<=fl_m;
                           when x"4D"=>cls<=C_EOR;am<=AM_ABS;w8<=fl_m;
                           when x"55"=>cls<=C_EOR;am<=AM_DPX;w8<=fl_m;
                           when x"5D"=>cls<=C_EOR;am<=AM_ABX;w8<=fl_m;
                           when x"59"=>cls<=C_EOR;am<=AM_ABY;w8<=fl_m;
                           -- ADC
                           when x"69"=>cls<=C_ADC;am<=AM_IMM;w8<=fl_m;
                           when x"65"=>cls<=C_ADC;am<=AM_DP; w8<=fl_m;
                           when x"6D"=>cls<=C_ADC;am<=AM_ABS;w8<=fl_m;
                           when x"75"=>cls<=C_ADC;am<=AM_DPX;w8<=fl_m;
                           when x"7D"=>cls<=C_ADC;am<=AM_ABX;w8<=fl_m;
                           when x"79"=>cls<=C_ADC;am<=AM_ABY;w8<=fl_m;
                           -- stack-relative (sr,S) ALU/load/store family (LDA/CMP sr already exist).
                           -- ADC $1,S @0xDA0F (and siblings) appear in the C76 mailbox-service code.
                           when x"63"=>cls<=C_ADC;am<=AM_S;w8<=fl_m;             -- ADC sr,S
                           when x"E3"=>cls<=C_SBC;am<=AM_S;w8<=fl_m;             -- SBC sr,S
                           when x"03"=>cls<=C_ORA;am<=AM_S;w8<=fl_m;             -- ORA sr,S
                           when x"23"=>cls<=C_AND;am<=AM_S;w8<=fl_m;             -- AND sr,S
                           when x"43"=>cls<=C_EOR;am<=AM_S;w8<=fl_m;             -- EOR sr,S
                           when x"83"=>cls<=C_STORE;tgt<=R_A;am<=AM_S;w8<=fl_m;  -- STA sr,S
                           -- SBC
                           when x"E9"=>cls<=C_SBC;am<=AM_IMM;w8<=fl_m;
                           when x"E5"=>cls<=C_SBC;am<=AM_DP; w8<=fl_m;
                           when x"ED"=>cls<=C_SBC;am<=AM_ABS;w8<=fl_m;
                           when x"F5"=>cls<=C_SBC;am<=AM_DPX;w8<=fl_m;
                           when x"FD"=>cls<=C_SBC;am<=AM_ABX;w8<=fl_m;
                           when x"F9"=>cls<=C_SBC;am<=AM_ABY;w8<=fl_m;
                           -- CMP
                           when x"C9"=>cls<=C_CMP;tgt<=R_A;am<=AM_IMM;w8<=fl_m;
                           when x"C3"=>cls<=C_CMP;tgt<=R_A;am<=AM_S;  w8<=fl_m;
                           when x"C5"=>cls<=C_CMP;tgt<=R_A;am<=AM_DP; w8<=fl_m;
                           when x"CD"=>cls<=C_CMP;tgt<=R_A;am<=AM_ABS;w8<=fl_m;
                           when x"D5"=>cls<=C_CMP;tgt<=R_A;am<=AM_DPX;w8<=fl_m;
                           when x"DD"=>cls<=C_CMP;tgt<=R_A;am<=AM_ABX;w8<=fl_m;
                           when x"D9"=>cls<=C_CMP;tgt<=R_A;am<=AM_ABY;w8<=fl_m;
                           -- CPX / CPY
                           when x"E0"=>cls<=C_CMP;tgt<=R_X;am<=AM_IMM;w8<=fl_x;
                           when x"E4"=>cls<=C_CMP;tgt<=R_X;am<=AM_DP; w8<=fl_x;
                           when x"EC"=>cls<=C_CMP;tgt<=R_X;am<=AM_ABS;w8<=fl_x;
                           when x"C0"=>cls<=C_CMP;tgt<=R_Y;am<=AM_IMM;w8<=fl_x;
                           when x"C4"=>cls<=C_CMP;tgt<=R_Y;am<=AM_DP; w8<=fl_x;
                           when x"CC"=>cls<=C_CMP;tgt<=R_Y;am<=AM_ABS;w8<=fl_x;
                           -- BBS/BBC: bit-test-and-branch (M37702: 0x24/2C=BBS, 0x34/3C=BBC).
                           -- These are NOT 65816 BIT (M37702 has no BIT; 0x89 is the MUL prefix).
                           -- Stream: opcode, EA(dp=1/abs=2), mask(1 if M=1 / 2 if M=0), rel(1).
                           when x"24"=>cls<=C_BBS;am<=AM_DP; w8<=fl_m;
                           when x"2C"=>cls<=C_BBS;am<=AM_ABS;w8<=fl_m;
                           when x"34"=>cls<=C_BBC;am<=AM_DP; w8<=fl_m;
                           when x"3C"=>cls<=C_BBC;am<=AM_ABS;w8<=fl_m;
                           -- RMW INC/DEC/ASL/LSR/ROL/ROR (memory)
                           when x"E6"=>cls<=C_INC;am<=AM_DP; w8<=fl_m;
                           when x"EE"=>cls<=C_INC;am<=AM_ABS;w8<=fl_m;
                           when x"F6"=>cls<=C_INC;am<=AM_DPX;w8<=fl_m;
                           when x"FE"=>cls<=C_INC;am<=AM_ABX;w8<=fl_m;
                           when x"C6"=>cls<=C_DEC;am<=AM_DP; w8<=fl_m;
                           when x"CE"=>cls<=C_DEC;am<=AM_ABS;w8<=fl_m;
                           when x"D6"=>cls<=C_DEC;am<=AM_DPX;w8<=fl_m;
                           when x"DE"=>cls<=C_DEC;am<=AM_ABX;w8<=fl_m;
                           when x"06"=>cls<=C_ASL;am<=AM_DP; w8<=fl_m;
                           when x"0E"=>cls<=C_ASL;am<=AM_ABS;w8<=fl_m;
                           when x"16"=>cls<=C_ASL;am<=AM_DPX;w8<=fl_m;
                           when x"1E"=>cls<=C_ASL;am<=AM_ABX;w8<=fl_m;
                           when x"46"=>cls<=C_LSR;am<=AM_DP; w8<=fl_m;
                           when x"4E"=>cls<=C_LSR;am<=AM_ABS;w8<=fl_m;
                           when x"56"=>cls<=C_LSR;am<=AM_DPX;w8<=fl_m;
                           when x"5E"=>cls<=C_LSR;am<=AM_ABX;w8<=fl_m;
                           when x"26"=>cls<=C_ROL;am<=AM_DP; w8<=fl_m;
                           when x"2E"=>cls<=C_ROL;am<=AM_ABS;w8<=fl_m;
                           when x"36"=>cls<=C_ROL;am<=AM_DPX;w8<=fl_m;
                           when x"3E"=>cls<=C_ROL;am<=AM_ABX;w8<=fl_m;
                           when x"66"=>cls<=C_ROR;am<=AM_DP; w8<=fl_m;
                           when x"6E"=>cls<=C_ROR;am<=AM_ABS;w8<=fl_m;
                           when x"76"=>cls<=C_ROR;am<=AM_DPX;w8<=fl_m;
                           when x"7E"=>cls<=C_ROR;am<=AM_ABX;w8<=fl_m;
                           -- absolute-long accumulator ops (AL = 0xnF, ALX = 0xnF|0x10)
                           when x"0F"=>cls<=C_ORA;am<=AM_AL; w8<=fl_m;
                           when x"1F"=>cls<=C_ORA;am<=AM_ALX;w8<=fl_m;
                           when x"2F"=>cls<=C_AND;am<=AM_AL; w8<=fl_m;
                           when x"3F"=>cls<=C_AND;am<=AM_ALX;w8<=fl_m;
                           when x"4F"=>cls<=C_EOR;am<=AM_AL; w8<=fl_m;
                           when x"5F"=>cls<=C_EOR;am<=AM_ALX;w8<=fl_m;
                           when x"6F"=>cls<=C_ADC;am<=AM_AL; w8<=fl_m;
                           when x"7F"=>cls<=C_ADC;am<=AM_ALX;w8<=fl_m;
                           when x"8F"=>cls<=C_STORE;tgt<=R_A;am<=AM_AL; w8<=fl_m;
                           when x"9F"=>cls<=C_STORE;tgt<=R_A;am<=AM_ALX;w8<=fl_m;
                           when x"AF"=>cls<=C_LOAD;tgt<=R_A;am<=AM_AL; w8<=fl_m;
                           when x"BF"=>cls<=C_LOAD;tgt<=R_A;am<=AM_ALX;w8<=fl_m;
                           when x"CF"=>cls<=C_CMP;tgt<=R_A;am<=AM_AL; w8<=fl_m;
                           when x"DF"=>cls<=C_CMP;tgt<=R_A;am<=AM_ALX;w8<=fl_m;
                           when x"EF"=>cls<=C_SBC;am<=AM_AL; w8<=fl_m;
                           when x"FF"=>cls<=C_SBC;am<=AM_ALX;w8<=fl_m;
                           -- indirect modes: (dp,X)=col 01, (dp),Y=col 11, (dp)=col 12
                           when x"01"=>cls<=C_ORA;am<=AM_DXI;w8<=fl_m;
                           when x"11"=>cls<=C_ORA;am<=AM_DIY;w8<=fl_m;
                           when x"12"=>cls<=C_ORA;am<=AM_DI; w8<=fl_m;
                           when x"21"=>cls<=C_AND;am<=AM_DXI;w8<=fl_m;
                           when x"31"=>cls<=C_AND;am<=AM_DIY;w8<=fl_m;
                           when x"32"=>cls<=C_AND;am<=AM_DI; w8<=fl_m;
                           when x"41"=>cls<=C_EOR;am<=AM_DXI;w8<=fl_m;
                           when x"51"=>cls<=C_EOR;am<=AM_DIY;w8<=fl_m;
                           when x"52"=>cls<=C_EOR;am<=AM_DI; w8<=fl_m;
                           when x"61"=>cls<=C_ADC;am<=AM_DXI;w8<=fl_m;
                           when x"71"=>cls<=C_ADC;am<=AM_DIY;w8<=fl_m;
                           when x"72"=>cls<=C_ADC;am<=AM_DI; w8<=fl_m;
                           when x"81"=>cls<=C_STORE;tgt<=R_A;am<=AM_DXI;w8<=fl_m;
                           when x"91"=>cls<=C_STORE;tgt<=R_A;am<=AM_DIY;w8<=fl_m;
                           when x"92"=>cls<=C_STORE;tgt<=R_A;am<=AM_DI; w8<=fl_m;
                           when x"A1"=>cls<=C_LOAD;tgt<=R_A;am<=AM_DXI;w8<=fl_m;
                           when x"B1"=>cls<=C_LOAD;tgt<=R_A;am<=AM_DIY;w8<=fl_m;
                           when x"B2"=>cls<=C_LOAD;tgt<=R_A;am<=AM_DI; w8<=fl_m;
                           when x"C1"=>cls<=C_CMP;tgt<=R_A;am<=AM_DXI;w8<=fl_m;
                           when x"D1"=>cls<=C_CMP;tgt<=R_A;am<=AM_DIY;w8<=fl_m;
                           when x"D2"=>cls<=C_CMP;tgt<=R_A;am<=AM_DI; w8<=fl_m;
                           when x"E1"=>cls<=C_SBC;am<=AM_DXI;w8<=fl_m;
                           when x"F1"=>cls<=C_SBC;am<=AM_DIY;w8<=fl_m;
                           when x"F2"=>cls<=C_SBC;am<=AM_DI; w8<=fl_m;
                           -- jumps
                           when x"4C"=>cls<=C_JMP;am<=AM_ABS;
                           when x"20"=>cls<=C_JSR;am<=AM_ABS;
                           when x"22"=>cls<=C_JSL;am<=AM_AL;            -- JSL al (24-bit)
                           when x"5C"=>cls<=C_JML;am<=AM_AL;            -- JML al (24-bit jump, no push)
                           when x"6C"=>cls<=C_JMPI;am<=AM_ABS;w8<='0';  -- JMP (abs) indirect
                           when x"FC"=>cls<=C_JSRIX;am<=AM_ABS;w8<='0'; -- JSR (abs,X) indirect
                           when x"7C"=>cls<=C_JMPIX;am<=AM_ABS;w8<='0'; -- JMP (abs,X) indirect
                           when x"F4"=>state<=ST_PEA;                   -- PEA #imm16 -> push
                           when others => state<=ST_HALT;
                        end case;
                  end case;
                  end if;

               -- prefix: fetch the real opcode byte then re-decode -----------
               when ST_PFETCH =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_PFETCH_W;
               when ST_PFETCH_W =>
                  if bus_ready='1' then
                     ir<=bus_din; dbg_opcode<=bus_din;
                     regPC<=regPC+1; bus_rd<='0'; state<=ST_DECODE;
                     if pfx=PFX_42 then use_b<='1'; end if;  -- set before decode runs
                  end if;

               -- LDT #imm8 : load Data Bank register (DT) from immediate -----
               when ST_LDT =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_LDT_W;
               when ST_LDT_W =>
                  if bus_ready='1' then
                     regDT<=unsigned(bus_din); regPC<=regPC+1; bus_rd<='0';
                     state<=ST_RETIRE;
                  end if;

               -- LDM/SEB/CLB: read the immediate value/mask (after the address) --
               when ST_LDMI_LO =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_LDMI_LO_W;
               when ST_LDMI_LO_W =>
                  if bus_ready='1' then
                     mask16(7 downto 0)<=unsigned(bus_din); regPC<=regPC+1; bus_rd<='0';
                     if w8='1' then
                        mask16(15 downto 8)<=(others=>'0'); state<=ST_LDM_RMW;
                     else
                        bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC+1);
                        bus_rd<='1'; state<=ST_LDMI_HI_W;
                     end if;
                  end if;
               when ST_LDMI_HI_W =>
                  if bus_ready='1' then
                     mask16(15 downto 8)<=unsigned(bus_din); regPC<=regPC+1; bus_rd<='0';
                     state<=ST_LDM_RMW;
                  end if;
               when ST_LDM_RMW =>
                  if cls=C_LDM then
                     wval<=mask16; ret<=ST_RETIRE; state<=ST_WR_LO;   -- store imm
                  else
                     state<=ST_RD_LO;   -- SEB/CLB: read mem[ea], modify in EXEC
                  end if;

               -- effective address -----------------------------------------
               when ST_EA_B0 =>
                  if am=AM_IMM then
                     ea <= regPG & regPC;
                     state <= ST_RD_LO;
                  else
                     bus_addr <= std_logic_vector(regPG) & std_logic_vector(regPC);
                     bus_rd<='1'; state<=ST_EA_B0_W;
                  end if;
               when ST_EA_B0_W =>
                  if bus_ready='1' then
                     regPC<=regPC+1; bus_rd<='0';
                     if am=AM_S then
                        -- stack-relative: ea = bank0:(regS + unsigned 1-byte offset)
                        a16 := regS + resize(unsigned(bus_din),16);
                        ea <= resize(a16, 24);
                        state<=ST_EA_DONE;
                     elsif am=AM_DP or am=AM_DPX or am=AM_DPY then
                        a16 := regDPR + resize(unsigned(bus_din),16);
                        if am=AM_DPX then a16:=a16+mask_idx(regX,fl_x); end if;
                        if am=AM_DPY then a16:=a16+mask_idx(regY,fl_x); end if;
                        ea <= resize(a16, 24);
                        state<=ST_EA_DONE;
                     elsif am=AM_DXI or am=AM_DIY or am=AM_DI then
                        -- direct-page pointer address (bank 0); (dp,X) adds X here
                        a16 := regDPR + resize(unsigned(bus_din),16);
                        if am=AM_DXI then a16:=a16+mask_idx(regX,fl_x); end if;
                        ea <= resize(a16, 24);
                        state<=ST_EA_PTR_LO;
                     else
                        operand(7 downto 0) <= unsigned(bus_din);
                        bus_addr <= std_logic_vector(regPG) & std_logic_vector(regPC+1);
                        bus_rd<='1'; state<=ST_EA_B1_W;
                     end if;
                  end if;
               when ST_EA_B1_W =>
                  if bus_ready='1' then
                     regPC<=regPC+1; bus_rd<='0';
                     if am=AM_AL or am=AM_ALX then
                        operand(15 downto 8) <= unsigned(bus_din);   -- mid byte
                        bus_addr <= std_logic_vector(regPG) & std_logic_vector(regPC+1);
                        bus_rd<='1'; state<=ST_EA_B2_W;              -- read bank byte
                     else
                        a16 := unsigned(bus_din) & operand(7 downto 0);
                        if cls=C_JMP or cls=C_JSR or cls=C_JMPI then
                           ea <= regPG & a16;
                        elsif cls=C_JSRIX then
                           ea <= regPG & (a16 + mask_idx(regX,fl_x));   -- pointer = PG:(abs+X), X masked to 8b when fl_x
                        elsif am=AM_ABX then
                           ea <= (regDT & a16) + resize(mask_idx(regX,fl_x), 24);
                        elsif am=AM_ABY then
                           ea <= (regDT & a16) + resize(mask_idx(regY,fl_x), 24);
                        else
                           ea <= regDT & a16;
                        end if;
                        state<=ST_EA_DONE;
                     end if;
                  end if;
               when ST_EA_B2_W =>
                  if bus_ready='1' then
                     regPC<=regPC+1; bus_rd<='0';
                     -- bank:mid:lo = full 24-bit address (long addressing)
                     if am=AM_ALX then
                        ea <= (unsigned(bus_din) & operand) + resize(mask_idx(regX,fl_x), 24);
                     else
                        ea <= unsigned(bus_din) & operand;
                     end if;
                     state<=ST_EA_DONE;
                  end if;

               -- indirect: read the 16-bit pointer from the dp address in ea ---
               when ST_EA_PTR_LO =>
                  bus_addr<=std_logic_vector(ea); bus_rd<='1'; state<=ST_EA_PTR_LO_W;
               when ST_EA_PTR_LO_W =>
                  if bus_ready='1' then
                     operand(7 downto 0)<=unsigned(bus_din); bus_rd<='0';
                     bus_addr<=std_logic_vector(unsigned(ea)+1);
                     bus_rd<='1'; state<=ST_EA_PTR_HI_W;
                  end if;
               when ST_EA_PTR_HI_W =>
                  if bus_ready='1' then
                     bus_rd<='0';
                     a16 := unsigned(bus_din) & operand(7 downto 0);   -- pointer
                     if am=AM_DIY then
                        ea <= (regDT & a16) + resize(mask_idx(regY,fl_x), 24);         -- (dp),Y
                     else
                        ea <= regDT & a16;                              -- (dp,X) / (dp)
                     end if;
                     state<=ST_EA_DONE;
                  end if;

               -- route after EA --------------------------------------------
               when ST_EA_DONE =>
                  case cls is
                     when C_STORE =>
                        case tgt is
                           when R_A => if use_b='1' then wval<=regB; else wval<=regA; end if;
                           when R_X => wval<=regX;
                           when R_Y => wval<=regY;
                           when others => wval<=(others=>'0');
                        end case;
                        ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_STZ =>
                        wval<=(others=>'0'); ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_JMP =>
                        regPC<=unsigned(ea(15 downto 0)); state<=ST_RETIRE;   -- JMP abs
                     when C_JSR =>
                        pushval<=regPC; push_w8<='0'; ret<=ST_JMP_FIN; state<=ST_PUSH_HI;  -- M37710: push actual return addr (RTS has no +1)
                     when C_JSL =>
                        -- ea = 24-bit target. Push PG (8-bit), then PC-1 (16-bit), then jump24.
                        pushval<=x"00"&regPG; push_w8<='1'; ret<=ST_JSL_PC; state<=ST_PUSH_LO;
                     when C_JML =>
                        -- 0x5C JML al: same 24-bit target as JSL, but NO return address is
                        -- pushed. Load PC and the program bank straight from ea and retire.
                        -- Namco's shared System 11 sound library uses this to cross banks
                        -- (Dunk Mania / Prime Goal EX halted the C76 here at PC 0xB9A0).
                        regPC <= ea(15 downto 0);
                        regPG <= ea(23 downto 16);
                        state <= ST_RETIRE;
                     when C_JSRIX | C_JMPIX =>
                        -- M37710 JMP/JSR (abs,X): pointer table lives at PG:(abs+X) — MAME
                        -- read_16_AXI(REG_PG | u16(abs + REG_X)). The missing +X (and PG
                        -- bank) sent the SFX refresh dispatch (EC77: JMP ($005C,X)) into
                        -- garbage -> BRK storm -> sound-engine restart. Fixed 2026-07-07.
                        ea <= regPG & (ea(15 downto 0) + regX);
                        state<=ST_JSRIX_LO;   -- ea = pointer; read 16-bit target then (push)+jump
                     when C_LDM | C_SEB | C_CLB | C_BBS | C_BBC =>
                        state<=ST_LDMI_LO;  -- address done; read the immediate (mask) value
                     when others =>
                        state<=ST_RD_LO;   -- read classes + RMW
                  end case;

               -- read operand ----------------------------------------------
               when ST_RD_LO =>
                  bus_addr<=std_logic_vector(ea); bus_rd<='1'; state<=ST_RD_LO_W;
               when ST_RD_LO_W =>
                  if bus_ready='1' then
                     operand(7 downto 0)<=unsigned(bus_din); bus_rd<='0';
                     if am=AM_IMM then regPC<=regPC+1; end if;
                     if w8='1' then
                        operand(15 downto 8)<=(others=>'0'); state<=ST_EXEC;
                     else
                        -- 16-bit value is at ea and ea+1 (for IMM, ea = the
                        -- immediate's address captured at decode). Using ea+1
                        -- avoids the regPC-not-yet-incremented hazard.
                        bus_addr<=std_logic_vector(unsigned(ea)+1);
                        bus_rd<='1'; state<=ST_RD_HI_W;
                     end if;
                  end if;
               when ST_RD_HI_W =>
                  if bus_ready='1' then
                     operand(15 downto 8)<=unsigned(bus_din); bus_rd<='0';
                     if am=AM_IMM then regPC<=regPC+1; end if;
                     state<=ST_EXEC;
                  end if;

               -- execute ----------------------------------------------------
               when ST_EXEC =>
                  state<=ST_RETIRE;
                  if use_b='1' then av:=regB; else av:=regA; end if;  -- active accumulator
                  case cls is
                     when C_LOAD =>
                        case tgt is
                           when R_A => wr_acc(operand);
                           -- 8-bit index mode (X flag set): the index register is 8-bit and
                           -- its high byte is 0 (NOT preserved) — else indexed addressing like
                           -- JSR (abs,X) uses a stale high byte and reads the wrong pointer.
                           when R_X => if w8='1' then regX<=x"00"&operand(7 downto 0); else regX<=operand; end if;
                           when R_Y => if w8='1' then regY<=x"00"&operand(7 downto 0); else regY<=operand; end if;
                           when others => null;
                        end case;
                        set_nz(operand,w8);
                     when C_ORA => r:=av or operand;  wr_acc(r); set_nz(r,w8);
                     when C_AND => r:=av and operand; wr_acc(r); set_nz(r,w8);
                     when C_EOR => r:=av xor operand; wr_acc(r); set_nz(r,w8);
                     when C_RLA =>   -- rotate active accumulator LEFT by operand bit positions.
                        -- MAME m37710 OP_RLA rotates REG_A only and does NOT touch any flags
                        -- (N/Z/C unchanged) — so NO set_nz here (corrupting flags caused a
                        -- mis-branch -> derail to the 0xC000 BIOS string).
                        if w8='1' then
                           r:=av(15 downto 8) & rotate_left(av(7 downto 0), to_integer(operand(2 downto 0)));
                        else
                           r:=rotate_left(av, to_integer(operand(3 downto 0)));
                        end if;
                        wr_acc(r);
                     when C_BIT =>
                        r:=av and operand;
                        if w8='1' then
                           if r(7 downto 0)=x"00" then fl_z<='1'; else fl_z<='0'; end if;
                           fl_n<=operand(7); fl_v<=operand(6);
                        else
                           if r=x"0000" then fl_z<='1'; else fl_z<='0'; end if;
                           fl_n<=operand(15); fl_v<=operand(14);
                        end if;
                     -- BBS/BBC: operand=mem[ea], mask16=immediate mask. Set the branch
                     -- predicate, then ST_BR_W reads the rel byte and branches. BBS takes
                     -- when ALL masked bits are set; BBC when ALL masked bits are clear.
                     when C_BBS =>
                        if (operand and mask16) = mask16 then br_take<='1'; else br_take<='0'; end if;
                        state<=ST_BR_W;
                     when C_BBC =>
                        if (operand and mask16) = x"0000" then br_take<='1'; else br_take<='0'; end if;
                        state<=ST_BR_W;
                     when C_ADC =>
                        if w8='1' then
                           s9:=('0'&av(7 downto 0))+('0'&operand(7 downto 0))+("00000000"&fl_c);
                           fl_c<=s9(8); fl_v<=(not(av(7) xor operand(7))) and (av(7) xor s9(7));
                           wr_acc(resize(s9(7 downto 0),16)); set_nz(resize(s9(7 downto 0),16),'1');
                        else
                           s17:=('0'&av)+('0'&operand)+(x"0000"&fl_c);
                           fl_c<=s17(16); fl_v<=(not(av(15) xor operand(15))) and (av(15) xor s17(15));
                           wr_acc(s17(15 downto 0)); set_nz(s17(15 downto 0),'0');
                        end if;
                     when C_SBC =>
                        if w8='1' then
                           s9:=('0'&av(7 downto 0))+('0'&(not operand(7 downto 0)))+("00000000"&fl_c);
                           fl_c<=s9(8); fl_v<=(av(7) xor operand(7)) and (av(7) xor s9(7));
                           wr_acc(resize(s9(7 downto 0),16)); set_nz(resize(s9(7 downto 0),16),'1');
                        else
                           s17:=('0'&av)+('0'&(not operand))+(x"0000"&fl_c);
                           fl_c<=s17(16); fl_v<=(av(15) xor operand(15)) and (av(15) xor s17(15));
                           wr_acc(s17(15 downto 0)); set_nz(s17(15 downto 0),'0');
                        end if;
                     when C_CMP =>
                        case tgt is when R_X => a16:=regX; when R_Y => a16:=regY; when others => a16:=av; end case;
                        if w8='1' then
                           s9:=('0'&a16(7 downto 0))+('0'&(not operand(7 downto 0)))+"000000001";
                           fl_c<=s9(8); set_nz(resize(s9(7 downto 0),16),'1');
                        else
                           s17:=('0'&a16)+('0'&(not operand))+('0'&x"0001");
                           fl_c<=s17(16); set_nz(s17(15 downto 0),'0');
                        end if;
                     when C_INC => if w8='1' then wval<=operand(15 downto 8)&(operand(7 downto 0)+1); set_nz(operand(15 downto 8)&(operand(7 downto 0)+1),'1'); else wval<=operand+1; set_nz(operand+1,'0'); end if; ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_DEC => if w8='1' then wval<=operand(15 downto 8)&(operand(7 downto 0)-1); set_nz(operand(15 downto 8)&(operand(7 downto 0)-1),'1'); else wval<=operand-1; set_nz(operand-1,'0'); end if; ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_ASL =>
                        if w8='1' then fl_c<=operand(7); r:=operand(15 downto 8)&(operand(6 downto 0)&'0'); else fl_c<=operand(15); r:=operand(14 downto 0)&'0'; end if;
                        wval<=r; set_nz(r,w8); ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_LSR =>
                        fl_c<=operand(0);
                        if w8='1' then r:=operand(15 downto 8)&('0'&operand(7 downto 1)); else r:='0'&operand(15 downto 1); end if;
                        wval<=r; set_nz(r,w8); ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_ROL =>
                        if w8='1' then r:=operand(15 downto 8)&(operand(6 downto 0)&fl_c); fl_c<=operand(7); else r:=operand(14 downto 0)&fl_c; fl_c<=operand(15); end if;
                        wval<=r; set_nz(r,w8); ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_ROR =>
                        if w8='1' then r:=operand(15 downto 8)&(fl_c&operand(7 downto 1)); fl_c<=operand(0); else r:=fl_c&operand(15 downto 1); fl_c<=operand(0); end if;
                        wval<=r; set_nz(r,w8); ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_SEB => wval<=operand or mask16;        ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_CLB => wval<=operand and (not mask16);  ret<=ST_RETIRE; state<=ST_WR_LO;
                     when C_JMP =>
                        regPC<=operand;   -- RTS: jump to pulled PC (M37710: no +1; JSR pushed actual addr)
                     when C_JMPI =>
                        regPC<=operand;     -- JMP (abs): operand = [pointer]
                     when C_MPY =>
                        -- A * SRC -> low to A, high to B (BA); C=0, Z/N on full product
                        if w8='1' then
                           prod(15 downto 0) := resize(av(7 downto 0) * operand(7 downto 0), 16);
                           regA <= regA(15 downto 8) & prod(7 downto 0);
                           regB <= regB(15 downto 8) & prod(15 downto 8);
                           fl_c <= '0'; fl_n <= prod(15);
                           if prod(15 downto 0) = x"0000" then fl_z<='1'; else fl_z<='0'; end if;
                        else
                           prod := av * operand;
                           regA <= prod(15 downto 0);
                           regB <= prod(31 downto 16);
                           fl_c <= '0'; fl_n <= prod(31);
                           if prod = x"00000000" then fl_z<='1'; else fl_z<='0'; end if;
                        end if;
                     when C_DIV =>
                        -- (89-page) unsigned divide, per MAME OP_DIV (m37710op.h):
                        --   m=0: (B<<16|A) / SRC16 ; m=1: ((B&FF)<<8|(A&FF)) / SRC8
                        --   quotient -> A (truncated to w), remainder -> B; V=C=1 on
                        --   quotient overflow (N then unchanged), Z from truncated quot.
                        --   Divisor 0 -> software interrupt via vector 0xFFFC.
                        if (operand = x"0000") then
                           -- zero divide: MAME m37710i_interrupt_software(0xfffc) pushes
                           -- PG, PC (past the operand), IPL, PS, sets I, PG=0, PC=[FFFC].
                           -- (Shared entry path also clears D and re-loads IPL; MAME's
                           -- software trap leaves both alone, so pass the current IPL.)
                           int_pushpc<=regPC; int_vec<=x"FFFC"; int_newipl<=ipl;
                           int_step<=(others=>'0'); state<=ST_INT_PUSH;
                        else
                           div_dsr <= operand;   -- read path zeroed bits 15:8 when w8
                           if w8='1' then
                              div_num <= regB(7 downto 0) & regA(7 downto 0) & x"0000";
                              div_cnt <= 16;
                           else
                              div_num <= regB & regA;
                              div_cnt <= 32;
                           end if;
                           div_quot <= (others=>'0'); div_rem <= (others=>'0');
                           state<=ST_DIV;
                        end if;
                     when others =>
                        -- stack pull writebacks
                        case ir is
                           when x"68" =>  -- PLA / PLB (write regB when 0x42-prefixed)
                              if use_b='1' then
                                 if fl_m='1' then regB<=regB(15 downto 8)&operand(7 downto 0); else regB<=operand; end if;
                              else
                                 if fl_m='1' then regA<=regA(15 downto 8)&operand(7 downto 0); else regA<=operand; end if;
                              end if; set_nz(operand,fl_m);
                           when x"FA" => if fl_x='1' then regX<=regX(15 downto 8)&operand(7 downto 0); else regX<=operand; end if; set_nz(operand,fl_x);
                           when x"7A" => if fl_x='1' then regY<=regY(15 downto 8)&operand(7 downto 0); else regY<=operand; end if; set_nz(operand,fl_x);
                           when x"AB" => regDT<=operand(7 downto 0); set_nz(operand,fl_m);
                           when x"2B" => regDPR<=operand; set_nz(operand,'0');
                           when x"28" => set_ps(std_logic_vector(operand(7 downto 0))); ipl<=operand(10 downto 8); -- PLP: PS(lo)+IPL(hi)
                           when others => null;
                        end case;
                  end case;

               -- DIV: restoring divide, 1 quotient bit per ce cycle ----------
               when ST_DIV =>
                  if div_cnt = 0 then
                     -- synthesis translate_off
                     report "DBG DIV done pc=" & to_hstring(dbg_pc) & " op2=" & to_hstring(ir) &
                            " dsr=" & to_hstring(div_dsr) & " quot=" & to_hstring(div_quot) &
                            " rem=" & to_hstring(div_rem) & " w8=" & std_logic'image(w8);
                     -- synthesis translate_on
                     -- writeback per MAME OP_DIV; remainder is exact (< divisor),
                     -- quotient is the full 2w-bit value truncated to w for A.
                     if w8='1' then
                        regA <= regA(15 downto 8) & div_quot(7 downto 0);
                        regB <= regB(15 downto 8) & div_rem(7 downto 0);
                        if div_quot(15 downto 8) /= x"00" then
                           fl_v<='1'; fl_c<='1';           -- overflow: N unchanged
                        else
                           fl_v<='0'; fl_c<='0'; fl_n<=div_quot(7);
                        end if;
                        if div_quot(7 downto 0) = x"00" then fl_z<='1'; else fl_z<='0'; end if;
                     else
                        regA <= div_quot(15 downto 0);
                        regB <= div_rem;
                        if div_quot(31 downto 16) /= x"0000" then
                           fl_v<='1'; fl_c<='1';           -- overflow: N unchanged
                        else
                           fl_v<='0'; fl_c<='0'; fl_n<=div_quot(15);
                        end if;
                        if div_quot(15 downto 0) = x"0000" then fl_z<='1'; else fl_z<='0'; end if;
                     end if;
                     state<=ST_RETIRE;
                  else
                     -- shift the next dividend MSB into the partial remainder,
                     -- compare/subtract the divisor, shift the quotient bit in.
                     s17 := div_rem & div_num(31);
                     div_num <= div_num(30 downto 0) & '0';
                     if s17 >= ('0' & div_dsr) then
                        s17 := s17 - ('0' & div_dsr);
                        div_quot <= div_quot(30 downto 0) & '1';
                     else
                        div_quot <= div_quot(30 downto 0) & '0';
                     end if;
                     div_rem <= s17(15 downto 0);
                     div_cnt <= div_cnt - 1;
                  end if;

               -- write operand ---------------------------------------------
               when ST_WR_LO =>
                  bus_addr<=std_logic_vector(ea); bus_dout<=std_logic_vector(wval(7 downto 0));
                  bus_wr<='1'; state<=ST_WR_LO_W;
               when ST_WR_LO_W =>
                  if bus_ready='1' then
                     bus_wr<='0';
                     if w8='1' then state<=ret; else state<=ST_WR_HI; end if;
                  end if;
               when ST_WR_HI =>
                  bus_addr<=std_logic_vector(unsigned(ea)+1); bus_dout<=std_logic_vector(wval(15 downto 8));
                  bus_wr<='1'; state<=ST_WR_HI_W;
               when ST_WR_HI_W =>
                  if bus_ready='1' then bus_wr<='0'; state<=ret; end if;

               -- stack push (hi then lo) -----------------------------------
               when ST_PUSH_HI =>
                  bus_addr<=x"00"&std_logic_vector(regS); bus_dout<=std_logic_vector(pushval(15 downto 8));
                  bus_wr<='1'; state<=ST_PUSH_HI_W;
               when ST_PUSH_HI_W =>
                  if bus_ready='1' then bus_wr<='0'; regS<=regS-1; state<=ST_PUSH_LO; end if;
               when ST_PUSH_LO =>
                  bus_addr<=x"00"&std_logic_vector(regS); bus_dout<=std_logic_vector(pushval(7 downto 0));
                  bus_wr<='1'; state<=ST_PUSH_LO_W;
               when ST_PUSH_LO_W =>
                  if bus_ready='1' then bus_wr<='0'; regS<=regS-1; state<=ret; end if;

               -- stack pull (lo then hi) -----------------------------------
               when ST_PULL_LO =>
                  bus_addr<=x"00"&std_logic_vector(regS+1); bus_rd<='1'; state<=ST_PULL_LO_W;
               when ST_PULL_LO_W =>
                  if bus_ready='1' then
                     operand(7 downto 0)<=unsigned(bus_din); bus_rd<='0'; regS<=regS+1;
                     if push_w8='1' then operand(15 downto 8)<=(others=>'0'); state<=ret;
                     else state<=ST_PULL_HI; end if;
                  end if;
               when ST_PULL_HI =>
                  bus_addr<=x"00"&std_logic_vector(regS+1); bus_rd<='1'; state<=ST_PULL_HI_W;
               when ST_PULL_HI_W =>
                  if bus_ready='1' then
                     operand(15 downto 8)<=unsigned(bus_din); bus_rd<='0'; regS<=regS+1; state<=ret;
                  end if;

               -- REP/SEP #imm (clear/set PS bits per mask) -----------------
               when ST_REPSEP =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_REPSEP_W;
               when ST_REPSEP_W =>
                  if bus_ready='1' then
                     regPC<=regPC+1; bus_rd<='0';
                     -- ir = C2 (REP, clear) or E2 (SEP, set); bit n -> flag
                     if ir=x"C2" then    -- REP: clear selected
                        if bus_din(0)='1' then fl_c<='0'; end if;
                        if bus_din(1)='1' then fl_z<='0'; end if;
                        if bus_din(2)='1' then fl_i<='0'; end if;
                        if bus_din(3)='1' then fl_d<='0'; end if;
                        if bus_din(4)='1' then fl_x<='0'; end if;
                        if bus_din(5)='1' then fl_m<='0'; end if;
                        if bus_din(6)='1' then fl_v<='0'; end if;
                        if bus_din(7)='1' then fl_n<='0'; end if;
                     else                 -- SEP: set selected
                        if bus_din(0)='1' then fl_c<='1'; end if;
                        if bus_din(1)='1' then fl_z<='1'; end if;
                        if bus_din(2)='1' then fl_i<='1'; end if;
                        if bus_din(3)='1' then fl_d<='1'; end if;
                        if bus_din(4)='1' then fl_x<='1'; end if;
                        if bus_din(5)='1' then fl_m<='1'; end if;
                        if bus_din(6)='1' then fl_v<='1'; end if;
                        if bus_din(7)='1' then fl_n<='1'; end if;
                     end if;
                     state<=ST_RETIRE;
                  end if;

               -- PEA #imm16 : push a 16-bit immediate onto the stack -------
               when ST_PEA =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_PEA_W;
               when ST_PEA_W =>
                  if bus_ready='1' then
                     pushval(7 downto 0)<=unsigned(bus_din); regPC<=regPC+1; bus_rd<='0';
                     bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC+1);
                     bus_rd<='1'; state<=ST_PEA_HI_W;
                  end if;
               when ST_PEA_HI_W =>
                  if bus_ready='1' then
                     pushval(15 downto 8)<=unsigned(bus_din); regPC<=regPC+1; bus_rd<='0';
                     push_w8<='0'; ret<=ST_RETIRE; state<=ST_PUSH_HI;
                  end if;

               -- JSR finalize ----------------------------------------------
               when ST_JMP_FIN =>
                  regPC<=unsigned(ea(15 downto 0)); state<=ST_RETIRE;

               -- 0x22 JSL: PG already pushed; now push PC-1 (16-bit) then jump to ea[23:0]
               when ST_JSL_PC =>
                  pushval<=regPC; push_w8<='0'; ret<=ST_JSL_FIN; state<=ST_PUSH_HI;  -- push actual return addr (RTL has no +1)
               when ST_JSL_FIN =>
                  regPG<=unsigned(ea(23 downto 16)); regPC<=unsigned(ea(15 downto 0));
                  state<=ST_RETIRE;

               -- 0x6B RTL: operand holds the pulled 16-bit PC; pull the PG byte, then
               -- jump to (PG : PC+1) (matches JSL pushing PC-1).
               when ST_RTL_PG =>
                  bus_addr<=x"00"&std_logic_vector(regS+1); bus_rd<='1'; state<=ST_RTL_PG_W;
               when ST_RTL_PG_W =>
                  if bus_ready='1' then
                     regPG<=unsigned(bus_din); regS<=regS+1; bus_rd<='0';
                     regPC<=operand; state<=ST_RETIRE;   -- RTL: pulled PC (no +1)
                  end if;

               -- 0x82 BRL: read 16-bit signed relative, always branch.
               when ST_BRL_LO =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_BRL_LO_W;
               when ST_BRL_LO_W =>
                  if bus_ready='1' then
                     operand(7 downto 0)<=unsigned(bus_din); bus_rd<='0';
                     bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC+1);
                     bus_rd<='1'; regPC<=regPC+1; state<=ST_BRL_HI_W;
                  end if;
               when ST_BRL_HI_W =>
                  if bus_ready='1' then
                     bus_rd<='0';
                     -- regPC is now the 2nd rel byte addr; +1 = next-instr base
                     regPC<=(regPC+1)+(unsigned(bus_din) & operand(7 downto 0));
                     state<=ST_RETIRE;
                  end if;

               -- 0xEB PSH / 0xFB PUL: read the 8-bit register mask -----------
               when ST_PSHPUL_RD =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_PSHPUL_RD_W;
               when ST_PSHPUL_RD_W =>
                  if bus_ready='1' then
                     psh_mask<=bus_din; regPC<=regPC+1; bus_rd<='0';
                     psh_bit<=0; pul_ph<=0;
                     if is_pul='1' then state<=ST_PUL_STEP; else state<=ST_PSH_STEP; end if;
                  end if;

               -- PSH: push regs for set mask bits, order A,B,X,Y,DPR,DT,PG,PS.
               when ST_PSH_STEP =>
                  if psh_bit > 7 then
                     state<=ST_RETIRE;
                  elsif psh_mask(psh_bit)='0' then
                     psh_bit<=psh_bit+1;
                  else
                     pw8 := '0';
                     case psh_bit is
                        when 0 => pushval<=regA;             pw8:=fl_m;   -- A  (M width)
                        when 1 => pushval<=regB;             pw8:=fl_m;   -- B  (M width)
                        when 2 => pushval<=regX;             pw8:=fl_x;   -- X  (X width)
                        when 3 => pushval<=regY;             pw8:=fl_x;   -- Y  (X width)
                        when 4 => pushval<=regDPR;           pw8:='0';    -- DPR (16)
                        when 5 => pushval<=x"00"&regDT;      pw8:='1';    -- DT  (8)
                        when 6 => pushval<=x"00"&regPG;      pw8:='1';    -- PG  (8)
                        when others =>                                     -- PS: ipl(hi) then ps(lo)
                           ps := fl_n&fl_v&fl_m&fl_x&fl_d&fl_i&fl_z&fl_c;
                           pushval<=resize(ipl, 8) & unsigned(ps);
                           pw8:='0';
                     end case;
                     psh_bit<=psh_bit+1; ret<=ST_PSH_STEP;
                     if pw8='1' then state<=ST_PUSH_LO; else state<=ST_PUSH_HI; end if;
                  end if;

               -- PUL: pull regs in reverse order PS,DT,DPR,Y,X,BA,A (PG is NOT pulled).
               when ST_PUL_STEP =>
                  if pul_ph > 6 then
                     state<=ST_RETIRE;
                  else
                     case pul_ph is
                        when 0 => pb:=7;  when 1 => pb:=5;  when 2 => pb:=4;
                        when 3 => pb:=3;  when 4 => pb:=2;  when 5 => pb:=1;
                        when others => pb:=0;
                     end case;
                     if psh_mask(pb)='0' then
                        pul_ph<=pul_ph+1;
                     else
                        case pb is
                           when 0|1    => pw8:=fl_m;   -- A/B (M width)
                           when 2|3    => pw8:=fl_x;   -- X/Y (X width)
                           when 5      => pw8:='1';    -- DT (8)
                           when others => pw8:='0';    -- DPR(16), PS(16: ps+ipl)
                        end case;
                        push_w8<=pw8; pul_cur<=pb; pul_ph<=pul_ph+1;
                        ret<=ST_PUL_WB; state<=ST_PULL_LO;
                     end if;
                  end if;
               when ST_PUL_WB =>
                  case pul_cur is
                     when 0 => regA<=operand;
                     when 1 => regB<=operand;
                     when 2 => regX<=operand;
                     when 3 => regY<=operand;
                     when 4 => regDPR<=operand;
                     when 5 => regDT<=operand(7 downto 0);
                     when others => set_ps(std_logic_vector(operand(7 downto 0)));  -- PS lo
                                    ipl<=operand(10 downto 8);                       -- IPL hi
                  end case;
                  state<=ST_PUL_STEP;

               -- 0xFC JSR (abs,X): read 16-bit target from the pointer in ea, then
               -- push return PC and jump (reuse C_JSR's push + ST_JMP_FIN).
               when ST_JSRIX_LO =>
                  bus_addr<=std_logic_vector(ea); bus_rd<='1'; state<=ST_JSRIX_LO_W;
               when ST_JSRIX_LO_W =>
                  if bus_ready='1' then
                     operand(7 downto 0)<=unsigned(bus_din); bus_rd<='0';
                     bus_addr<=std_logic_vector(unsigned(ea)+1); bus_rd<='1';
                     state<=ST_JSRIX_HI_W;
                  end if;
               when ST_JSRIX_HI_W =>
                  if bus_ready='1' then
                     bus_rd<='0';
                     a16 := unsigned(bus_din) & operand(7 downto 0);   -- 16-bit target
                     ea <= regPG & a16;
                     if cls=C_JMPIX then
                        regPC<=a16; state<=ST_RETIRE;                  -- JMP (abs,X): jump, no push
                     else
                        pushval<=regPC; push_w8<='0'; ret<=ST_JMP_FIN; state<=ST_PUSH_HI;  -- JSR: push actual ret addr
                     end if;
                  end if;

               -- branch (two-phase: issue offset read, then wait+compute) ---
               when ST_BR_W =>
                  bus_addr<=std_logic_vector(regPG) & std_logic_vector(regPC);
                  bus_rd<='1'; state<=ST_BR_W2;
               when ST_BR_W2 =>
                  if bus_ready='1' then
                     bus_rd<='0';
                     if br_take='1' then
                        regPC<=(regPC+1)+unsigned(resize(signed(bus_din),16));
                     else
                        regPC<=regPC+1;
                     end if;
                     state<=ST_RETIRE;
                  end if;

               -- interrupt entry: push PG, PC(hi,lo), IPL, PS; load vector -----
               when ST_INT_PUSH =>
                  bus_addr<=x"00"&std_logic_vector(regS);
                  case int_step is
                     when "000" => bus_dout<=std_logic_vector(regPG);
                     when "001" => bus_dout<=std_logic_vector(int_pushpc(15 downto 8));
                     when "010" => bus_dout<=std_logic_vector(int_pushpc(7 downto 0));
                     when "011" => bus_dout<="00000"&std_logic_vector(ipl);
                     when others=> bus_dout<=fl_n&fl_v&fl_m&fl_x&fl_d&fl_i&fl_z&fl_c;
                  end case;
                  bus_wr<='1'; state<=ST_INT_PUSH_W;
               when ST_INT_PUSH_W =>
                  if bus_ready='1' then
                     bus_wr<='0'; regS<=regS-1;
                     if int_step="100" then state<=ST_INT_VL;
                     else int_step<=int_step+1; state<=ST_INT_PUSH; end if;
                  end if;
               when ST_INT_VL =>
                  bus_addr<=x"00"&std_logic_vector(int_vec); bus_rd<='1'; state<=ST_INT_VL_W;
               when ST_INT_VL_W =>
                  if bus_ready='1' then
                     regPC(7 downto 0)<=unsigned(bus_din);
                     bus_addr<=x"00"&std_logic_vector(int_vec+1); state<=ST_INT_VH_W;
                  end if;
               when ST_INT_VH_W =>
                  if bus_ready='1' then
                     regPC(15 downto 8)<=unsigned(bus_din); bus_rd<='0';
                     regPG<=(others=>'0'); fl_i<='1'; fl_d<='0';
                     ipl<=int_newipl;   -- raise IPL to the taken interrupt's priority (old ipl was pushed)
                     state<=ST_FETCH;
                  end if;

               -- RTI: pull PS, IPL, PC(lo,hi), PG -------------------------
               when ST_RTI_PULL =>
                  regS<=regS+1;
                  bus_addr<=x"00"&std_logic_vector(regS+1); bus_rd<='1'; state<=ST_RTI_PULL_W;
               when ST_RTI_PULL_W =>
                  if bus_ready='1' then
                     bus_rd<='0';
                     case int_step is
                        when "000" => set_ps(bus_din);                       -- PS flags
                        when "001" => ipl<=unsigned(bus_din(2 downto 0));    -- IPL
                        when "010" => regPC(7 downto 0)<=unsigned(bus_din);  -- PC lo
                        when "011" => regPC(15 downto 8)<=unsigned(bus_din); -- PC hi
                        when others=> regPG<=unsigned(bus_din);              -- PG
                     end case;
                     if int_step="100" then state<=ST_FETCH;
                     else int_step<=int_step+1; state<=ST_RTI_PULL; end if;
                  end if;

               when ST_RETIRE =>
                  dbg_valid<='1'; pfx<=PFX_NONE; use_b<='0'; state<=ST_FETCH;
               when ST_HALT =>
                  dbg_halted<='1'; state<=ST_HALT;
               when others => state<=ST_HALT;
            end case;
         end if;
      end if;
   end process;

   dbg_x <= std_logic_vector(regX);

end architecture;
