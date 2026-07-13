library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

library mem;

use work.pexport.all;

entity cpu is
   port 
   (
      clk1x                 : in  std_logic;
      clk2x                 : in  std_logic;
      clk3x                 : in  std_logic;
      ce                    : in  std_logic;
      reset                 : in  std_logic;
      
      TURBO                 : in  std_logic;
      TURBO_CACHE           : in  std_logic;
      TURBO_CACHE50         : in  std_logic;
      
      irqRequest            : in  std_logic;
      dmaStallCPU           : in  std_logic;
      cpuPaused             : in  std_logic;
      
      error                 : out std_logic := '0';
      error2                : out std_logic := '0';
      
      mem_request           : out std_logic;
      mem_rnw               : out std_logic; 
      mem_isData            : out std_logic; 
      mem_isCache           : out std_logic; 
      mem_oldtagvalids      : out std_logic_vector(3 downto 0);
      mem_addressInstr      : out unsigned(31 downto 0); 
      mem_addressData       : out unsigned(31 downto 0); 
      mem_reqsize           : out unsigned(1 downto 0); 
      mem_writeMask         : out std_logic_vector(3 downto 0); 
      mem_dataWrite         : out std_logic_vector(31 downto 0); 
      mem_dataRead          : in  std_logic_vector(31 downto 0); 
      mem_done              : in  std_logic;
      mem_fifofull          : in  std_logic;
      mem_tagvalids         : in  std_logic_vector(3 downto 0);
      
      cache_wr              : in  std_logic_vector(3 downto 0);
      cache_data            : in  std_logic_vector(31 downto 0);
      cache_addr            : in  std_logic_vector(7 downto 0);
      
      stallNext             : out std_logic;
      
      dma_cache_Adr         : in  std_logic_vector(21 downto 0);
      dma_cache_data        : in  std_logic_vector(31 downto 0);
      dma_cache_write       : in  std_logic;
      
      ram_done              : in  std_logic;
      ram_rnw               : in  std_logic;
      ram_dataRead          : in  std_logic_vector(31 downto 0); 
      
      gte_busy              : in  std_logic;
      gte_readEna           : out std_logic := '0';
      gte_readAddr          : out unsigned(5 downto 0);
      gte_readData          : in  unsigned(31 downto 0);
      gte_writeAddr         : out unsigned(5 downto 0);
      gte_writeData         : out unsigned(31 downto 0);
      gte_writeEna          : out std_logic := '0'; 
      gte_cmdData           : out unsigned(31 downto 0);
      gte_cmdEna            : out std_logic := '0'; 
      
      SS_reset              : in  std_logic;
      SS_DataWrite          : in  std_logic_vector(31 downto 0);
      SS_Adr                : in  unsigned(7 downto 0);
      SS_wren_CPU           : in  std_logic;
      SS_wren_SCP           : in  std_logic;
      SS_rden_CPU           : in  std_logic;
      SS_rden_SCP           : in  std_logic;
      SS_DataRead_CPU       : out std_logic_vector(31 downto 0);
      SS_DataRead_SCP       : out std_logic_vector(31 downto 0);
      SS_idle               : out std_logic;
   
-- synthesis translate_off
      cpu_done              : out std_logic := '0'; 
      cpu_export            : out cpu_export_type := ((others => (others => '0')), (others => '0'), (others => '0'), (others => '0'));
-- synthesis translate_on
      
      debug_firstGTE        : in  std_logic;
      -- DIAGNOSTIC (System 11 boot triage): latch the FIRST real CPU fault (excl.
      -- interrupt code 0 / syscall code 8). EPC = faulting PC, code = ExcCode
      -- (4/5=AdEL/AdES address error, 6=PC out of bounds/wild jump, A=reserved instr).
      dbg_exc_epc           : out unsigned(31 downto 0) := (others => '0');
      dbg_exc_code          : out unsigned(3 downto 0) := (others => '0');
      -- architectural a1 (reg[5]) latched at the first fault: ODD => store used a wrong
      -- (even) operand = CPU forwarding bug; EVEN => odd path entered with even a1 =
      -- wild-jump / upstream pointer corruption.
      dbg_fault_a1          : out unsigned(31 downto 0) := (others => '0');
      -- return address (reg[31]) at the first fault = the caller/return context
      dbg_fault_ra          : out unsigned(31 downto 0) := (others => '0');
      -- faulting store/load ADDRESS (EXEMemAddr) latched at the first AdEL/AdES = the bad pointer
      dbg_fault_addr        : out unsigned(31 downto 0) := (others => '0');
      -- at the first fault: [31:16]=$s1(r17)[15:0] [15:0]=$s2(r18)[15:0] (the BEQ branch operands), and $sp(r29)
      dbg_fault_s1s2        : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_fault_sp          : out std_logic_vector(31 downto 0) := (others => '0');
      -- WRITE-CAPTURE: first SW of a garbage (<0x10000) value to the crash table entry 0x803FFE04:
      -- dbg_wrcap_pc = the storing instruction's PC, dbg_wrcap_data = the value stored (the garbage ptr)
      dbg_wrcap_pc          : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_wrcap_data        : out std_logic_vector(31 downto 0) := (others => '0');
      -- DIAGNOSTIC: latch the actual fetched instruction WORD at the decompressor branch
      -- andi @0xBFC20280 (expected 0x30A20001). If != expected => instruction-fetch/icache
      -- corruption on that ROM line (explains the off-by-one odd-path store -> AdES).
      dbg_instr_word        : out unsigned(31 downto 0) := (others => '0');
      -- In-core trace buffer (JTAG-free logic analyzer): 64 samples x 32 bits, free-running
      -- ring frozen ~20 cycles after the first genuine fault. trace_flat = flattened buffer;
      -- trace_meta[31]=frozen [30]=triggered [5:0]=head (ring index of oldest sample).
      trace_flat            : out std_logic_vector(2047 downto 0) := (others => '0');
      trace_meta            : out std_logic_vector(31 downto 0) := (others => '0');
      -- SIM-ONLY operand-forward observation ports (driven by concurrent assigns below; outside
      -- translate_off so the Verilator/yosys build can read them). For the andi->beqz forward-gap
      -- unit test: watch the regfile (ground truth) vs value1 (the operand read) vs the result-
      -- forward source (resultData/Target/WE) at each committed instruction (pcOld1, stall).
      dbg_value1            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_value2            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_resultData        : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_resultTarget      : out std_logic_vector(4 downto 0)  := (others => '0');
      dbg_resultWE          : out std_logic := '0';
      dbg_stall             : out std_logic_vector(4 downto 0)  := (others => '0');
      dbg_pcOld1            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_reg_v0            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_reg_a0            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_reg_s2            : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_mem1req           : out std_logic := '0';
      dbg_membusy           : out std_logic := '0';
      dbg_stall1            : out std_logic := '0';
      -- regfile WRITE-PORT tap (synthesis-visible, unlike the translate_off 'regs' shadow). The
      -- harness maintains its own 32-reg shadow from these to observe register state reliably.
      dbg_wr_wren           : out std_logic := '0';
      dbg_wr_addr           : out std_logic_vector(4 downto 0)  := (others => '0');
      dbg_wr_data           : out std_logic_vector(31 downto 0) := (others => '0')
   );
end entity;

architecture arch of cpu is
     
   -- register file
   signal regs_address_a               : std_logic_vector(4 downto 0);
   signal regs_data_a                  : std_logic_vector(31 downto 0);
   signal regs_wren_a                  : std_logic;
   signal regs1_address_b              : std_logic_vector(4 downto 0);
   signal regs1_q_b                    : std_logic_vector(31 downto 0);
   signal regs2_address_b              : std_logic_vector(4 downto 0);
   signal regs2_q_b                    : std_logic_vector(31 downto 0);
   -- register-file read-during-write bypass (System11 forwarding-gap fix)
   signal regs1_q_b_wt                 : std_logic_vector(31 downto 0);
   signal regs2_q_b_wt                 : std_logic_vector(31 downto 0);
   signal regs_wt_wren                 : std_logic := '0';
   signal regs_wt_addr                 : std_logic_vector(4 downto 0) := (others => '0');
   signal regs_wt_data                 : std_logic_vector(31 downto 0) := (others => '0');
   signal regs1_rdaddr_q               : std_logic_vector(4 downto 0) := (others => '0');
   signal regs2_rdaddr_q               : std_logic_vector(4 downto 0) := (others => '0');
   -- LIVE regfile reads of the EXECUTE-stage sources (decodeSource1/2): refreshed every cycle
   -- so an operand picks up a producer that commits while this instruction is stalled in decode.
   signal regs3_q_b                    : std_logic_vector(31 downto 0);
   signal regs4_q_b                    : std_logic_vector(31 downto 0);
   signal regs3_q_b_wt                 : std_logic_vector(31 downto 0);
   signal regs4_q_b_wt                 : std_logic_vector(31 downto 0);
   signal regs3_rdaddr_q               : std_logic_vector(4 downto 0) := (others => '0');
   signal regs4_rdaddr_q               : std_logic_vector(4 downto 0) := (others => '0');
   signal regsSS_address_b             : std_logic_vector(4 downto 0) := (others => '0');
   signal regsSS_q_b                   : std_logic_vector(31 downto 0);
   signal regsSS_rden                  : std_logic := '0';
   
   signal ss_regs_loading              : std_logic := '0';
   signal ss_regs_load                 : std_logic := '0';
   signal ss_regs_addr                 : unsigned(4 downto 0);
   signal ss_regs_data                 : std_logic_vector(31 downto 0);
   
   -- other register
   signal PC                           : unsigned(31 downto 0) := (others => '0');
   signal hi                           : unsigned(31 downto 0) := (others => '0');
   signal lo                           : unsigned(31 downto 0) := (others => '0');
               
   signal cop0_BPC                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_BDA                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_JUMPDEST                : unsigned(31 downto 0) := (others => '0');
   signal cop0_DCIC                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_BADVADDR                : unsigned(31 downto 0) := (others => '0');
   signal cop0_BDAM                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_BPCM                    : unsigned(31 downto 0) := (others => '0');
   signal cop0_SR                      : unsigned(31 downto 0) := (others => '0');
   signal cop0_CAUSE                   : unsigned(31 downto 0) := (others => '0');
   signal cop0_EPC                     : unsigned(31 downto 0) := (others => '0');
   signal cop0_PRID                    : unsigned(31 downto 0) := (others => '0');
     
   signal CACHECONTROL                 : unsigned(31 downto 0) := (others => '0');
               
   -- common   
   signal ce_1                         : std_logic := '0';
   
   signal stallNew1                    : std_logic := '0';
   signal stallNew2                    : std_logic := '0';
   signal stallNew3                    : std_logic := '0';
   signal stallNew4                    : std_logic := '0';
   signal stallNew5                    : std_logic := '0';
               
   signal stall1                       : std_logic := '0';
   signal stall2                       : std_logic := '0';
   signal stall3                       : std_logic := '0';
   signal stall4                       : std_logic := '0';
   signal stall                        : unsigned(4 downto 0) := (others => '0');
                     
   signal exception                    : unsigned(4 downto 0) := (others => '0');
   signal exceptionBreakpoint          : std_logic;
               
   signal exceptionNew1                : std_logic := '0';
   signal exceptionNew3                : std_logic := '0';
   signal exceptionNew5                : std_logic := '0';
   signal exceptionNew                 : unsigned(4 downto 0) := (others => '0');
   
   signal exception_SR                 : unsigned(31 downto 0) := (others => '0');
   signal exception_CAUSE              : unsigned(31 downto 0) := (others => '0');
   signal exception_EPC                : unsigned(31 downto 0) := (others => '0');
   signal exception_JMP                : unsigned(31 downto 0) := (others => '0');
   
   signal dbg_exc_seen                 : std_logic := '0';   -- sticky: first fault latched
   signal dbg_wrcap_seen               : std_logic := '0';   -- sticky: first garbage-ptr store to 0x803FFE04 latched
   signal dbg_instr_seen               : std_logic := '0';   -- sticky: decompressor andi word latched
   -- C76-BRINGUP DIAG 2026-06-24: capture the word the CPU DECODED at PC 0x10170 (the CpU-fault
   -- instruction). opcode0/PCold0 are a matched fetch pair; latch opcode0 when PCold0[19:0]=0x10170.
   -- MAME-correct = 0xA420FB00 (sh zero). A different value here = the icache/SDRAM read is corrupt.
   signal cap_fetch_word               : unsigned(31 downto 0) := (others => '0');
   signal cap_fetch_seen               : std_logic := '0';
   -- DECISIVE DIAG 2026-06-24: the RAW word delivered (mem_dataRead) on a cache-MISS FILL of 0x10170.
   -- 0xA420FB00 => SDRAM delivered correct (decode/icache bug); 0x48000000 => delivery delivered
   -- wrong; 0x00000000 (never set) => 0x10170 was always a HIT = stale icache (never re-filled).
   signal cap_raw                      : unsigned(31 downto 0) := (others => '0');
   signal cap_raw_seen                 : std_logic := '0';
   -- DECOMPRESSOR PIPELINE CAPTURE (2026-06-24): at the byte-extraction "sra v1,v1,8" (pcOld1 low
   -- 28 bits = 0xFC20264) capture the rs operand (value1 = v1, the source halfword the lhu loaded)
   -- and the shift result (EXEresultData = v1>>8), sticky-last; FREEZE on the decompressor's store
   -- to output 0x10170. dbg_dcap_op[15:8]=0xA4 => operand correct (bug downstream); =0x48 => operand
   -- STALE (load-use forward hazard at the sra). dbg_dcap_res[7:0]: 0xA4 => sra OK, 0x48 => ALU wrong.
   signal dbg_dcap_op                  : unsigned(31 downto 0) := (others => '0');
   signal dbg_dcap_res                 : unsigned(31 downto 0) := (others => '0');
   signal dbg_dcap_frozen              : std_logic := '0';
   signal dbg_cmp_arm                  : std_logic := '0';   -- CAPTURE #6 arm: source lhu hit 0x28002
   signal dbg_arm2                     : std_logic := '0';            -- CAPTURE #9 arm: control-byte read
   signal dbg_cnt2                     : unsigned(1 downto 0) := "00"; -- CAPTURE #9 helper-call counter
   -- CAPTURE #4 (2026-06-24): MAME ground-truth output halfwords for RAM 0x10000-0x101FF
   -- (index = addr[8:1]); used by the first-mismatch detector to find the first divergent
   -- decompressed output byte vs MAME. Generated from mame_out.bin.
   type t_mametab is array(0 to 255) of unsigned(15 downto 0);
   constant mame_tab : t_mametab := (
      x"FFE0", x"27BD", x"001C", x"AFBF", x"0018", x"AFB2", x"0014", x"AFB1",
      x"41B7", x"0C00", x"0010", x"AFB0", x"1F80", x"3C01", x"0000", x"AC3D",
      x"1F80", x"3C05", x"8005", x"3C04", x"0000", x"8CA5", x"33B0", x"2484",
      x"4227", x"0C00", x"0001", x"2410", x"8005", x"3C04", x"4227", x"0C00",
      x"33BC", x"2484", x"419C", x"0C00", x"0000", x"0000", x"8010", x"3C04",
      x"F528", x"0C00", x"0130", x"2484", x"8026", x"3C03", x"4846", x"9463",
      x"8020", x"3C02", x"6BE0", x"2442", x"9025", x"0040", x"8010", x"3C01",
      x"1880", x"0003", x"0821", x"0023", x"8026", x"3C02", x"4868", x"9442",
      x"0140", x"8C23", x"8026", x"3C01", x"8026", x"3C05", x"484C", x"94A5",
      x"486A", x"A422", x"8026", x"3C01", x"8026", x"3C06", x"484E", x"94C6",
      x"486C", x"A425", x"8026", x"3C01", x"8026", x"3C07", x"4844", x"94E7",
      x"486E", x"A426", x"8026", x"3C01", x"8026", x"3C08", x"4848", x"9508",
      x"4870", x"A427", x"8026", x"3C01", x"8026", x"3C09", x"484A", x"9529",
      x"4872", x"A428", x"8026", x"3C01", x"8026", x"3C0A", x"4850", x"954A",
      x"4874", x"A429", x"8026", x"3C01", x"8026", x"3C0B", x"4852", x"956B",
      x"4876", x"A42A", x"8026", x"3C01", x"8026", x"3C0C", x"4854", x"958C",
      x"4878", x"A42B", x"8026", x"3C01", x"487A", x"A42C", x"8026", x"3C01",
      x"487C", x"AC23", x"49DC", x"0C01", x"2025", x"0000", x"7A3C", x"0C00",
      x"0000", x"0000", x"B695", x"0C00", x"0000", x"0000", x"521C", x"0C00",
      x"0000", x"0000", x"B582", x"0C00", x"0000", x"0000", x"B4D6", x"0C00",
      x"0000", x"0000", x"B8D1", x"0C00", x"0000", x"0000", x"A9D4", x"0C00",
      x"0000", x"0000", x"8026", x"3C01", x"4880", x"A420", x"8026", x"3C01",
      x"4882", x"A420", x"8026", x"3C01", x"4884", x"A420", x"8014", x"3C01",
      x"FB00", x"A420", x"8026", x"3C01", x"488A", x"A420", x"8026", x"3C01",
      x"4888", x"A420", x"8026", x"3C01", x"488E", x"A420", x"8026", x"3C01",
      x"488C", x"A420", x"8026", x"3C01", x"4890", x"A430", x"BDA7", x"0C00",
      x"0001", x"2404", x"8026", x"3C01", x"41BC", x"0C00", x"4894", x"AC32",
      x"0B3C", x"0C01", x"0000", x"0000", x"0B4C", x"0C01", x"0000", x"0000",
      x"2040", x"0002", x"2021", x"0082", x"2100", x"0004", x"2023", x"0082",
      x"20C0", x"0004", x"2023", x"0082", x"20C0", x"0004", x"2021", x"0082",
      x"2080", x"0004", x"2021", x"0082", x"8021", x"3C03", x"8026", x"3C01",
      x"4898", x"AC22", x"FBF4", x"2463", x"2100", x"0004", x"0B74", x"0C01"
   );
   signal dbg_arm                      : std_logic := '0';   -- armed once helper entry 0xBFC20280 fetched
   -- In-core trace buffer (JTAG-free): 64-sample free-running ring, frozen post-fault.
   type t_trace is array(0 to 63) of std_logic_vector(31 downto 0);
   signal trace_mem                    : t_trace := (others => (others => '0'));
   signal trace_wptr                   : unsigned(5 downto 0) := (others => '0');
   signal trace_frozen                 : std_logic := '0';
   signal trace_trig                   : std_logic := '0';
   signal trace_postcnt                : unsigned(4 downto 0) := (others => '0');
   signal trace_head                   : unsigned(5 downto 0) := (others => '0');
   signal trace_sample                 : std_logic_vector(31 downto 0);
   signal trace_f_result, trace_f_late, trace_f_wb, trace_f_wd : std_logic;
   signal trace_ds1_a1, trace_ds1_v0, trace_rt_eq_ds1          : std_logic;
   signal trace_stall_nz                                        : std_logic;
   signal trace_is_beqz                                         : std_logic;
   signal trace_wr_v0                                           : std_logic;
   signal exceptionCode                : unsigned(3 downto 0);
   signal exceptionCode_3              : unsigned(3 downto 0);   
   signal exceptionInstr               : unsigned(1 downto 0);
   signal exception_PC                 : unsigned(31 downto 0);
   signal exception_branch             : std_logic;
   signal exception_brslot             : std_logic;
   signal exception_JMPnext            : unsigned(31 downto 0);
               
   signal memoryMuxStage4              : std_logic := '0';
   signal memoryMuxBusy                : std_logic := '0';
   signal mem1_request_latched         : std_logic := '0';
               
   signal opcode0                      : unsigned(31 downto 0) := (others => '0');
   signal opcode1                      : unsigned(31 downto 0) := (others => '0');
   signal opcode2                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_off
   signal opcode3                      : unsigned(31 downto 0) := (others => '0');
   signal opcode4                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_on  
  
   signal PCold0                       : unsigned(31 downto 0) := (others => '0');
   signal PCold1                       : unsigned(31 downto 0) := (others => '0');
   
-- synthesis translate_off
   signal PCold2                       : unsigned(31 downto 0) := (others => '0');
   signal PCold3                       : unsigned(31 downto 0) := (others => '0');
   signal PCold4                       : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_on
   
   signal value1                       : unsigned(31 downto 0) := (others => '0');
   signal value2                       : unsigned(31 downto 0) := (others => '0');
               
   -- stage 1          
   -- cache
   signal tag_address_a                : std_logic_vector(7 downto 0);
   signal tag_data_a                   : std_logic_vector(23 downto 0);
   signal tag_wren_a                   : std_logic;
   signal tag_address_b                : std_logic_vector(7 downto 0);
   signal tag_q_b                      : std_logic_vector(23 downto 0);
   
   signal cache_address_b              : std_logic_vector(7 downto 0);
   signal cache_q_b                    : std_logic_vector(127 downto 0);
   
   signal FetchAddr                    : unsigned(31 downto 0) := (others => '0'); 
   signal FetchLastAddr                : unsigned(31 downto 0) := (others => '0'); 
   signal FetchLastCache               : std_logic := '0';
   signal FetchLastTagvalids           : std_logic_vector(3 downto 0);
   
   signal cacheValueLast               : unsigned(31 downto 0) := (others => '0'); 
   signal cacheHitLast                 : std_logic := '0';
   
   -- regs           
   signal blockIRQ                     : std_logic := '0';
   signal blockIRQCnt                  : integer range 0 to 10;
   signal fetchReady                   : std_logic := '0';
   signal cacheHit                     : std_logic := '0';
               
   -- wires          
   signal mem1_request                 : std_logic := '0';
   signal mem1_cacherequest            : std_logic := '0';
   signal mem1_tagvalids               : std_logic_vector(3 downto 0);
   signal mem1_address                 : unsigned(31 downto 0) := (others => '0'); 
               
   signal PCnext                       : unsigned(31 downto 0) := (others => '0');
   signal opcodeNext                   : unsigned(31 downto 0) := (others => '0');
   signal fetchReadyNext               : std_logic := '0';
   signal fetchReadyNow                : std_logic := '0';
   signal cacheHitTest                 : std_logic;
   signal cacheHitNext                 : std_logic := '0';
   signal blockIRQNext                 : std_logic := '0';
   signal blockIRQCntNext              : integer range 0 to 10;
            
   -- stage 2           
   --regs            
   signal decodeException              : std_logic := '0';
   signal decodeImmData                : unsigned(15 downto 0) := (others => '0');
   signal decodeSource1                : unsigned(4 downto 0) := (others => '0');
   signal decodeSource2                : unsigned(4 downto 0) := (others => '0');
   signal decodeValue1                 : unsigned(31 downto 0) := (others => '0');
   signal decodeValue2                 : unsigned(31 downto 0) := (others => '0');
   signal decodeOP                     : unsigned(5 downto 0) := (others => '0');
   signal decodeFunct                  : unsigned(5 downto 0) := (others => '0');
   signal decodeShamt                  : unsigned(4 downto 0) := (others => '0');
   signal decodeRD                     : unsigned(4 downto 0) := (others => '0');
   signal decodeTarget                 : unsigned(4 downto 0) := (others => '0');
   signal decodeJumpTarget             : unsigned(25 downto 0) := (others => '0');
   signal decode_gte_readAddr          : unsigned(5 downto 0) := (others => '0');
   
   signal decodeReqSource1             : std_logic := '0';
   signal decodeReqSource2             : std_logic := '0';
   signal decodeLateStall              : std_logic := '0';
   
   -- wires
   signal opcodeCacheMuxed             : unsigned(31 downto 0) := (others => '0');
   
   signal decImmData                   : unsigned(15 downto 0);
   signal decSource1                   : unsigned(4 downto 0);
   signal decSource2                   : unsigned(4 downto 0);
   signal decOP                        : unsigned(5 downto 0);
   signal decFunct                     : unsigned(5 downto 0);
   signal decShamt                     : unsigned(4 downto 0);
   signal decRD                        : unsigned(4 downto 0);
   signal decTarget                    : unsigned(4 downto 0);
   signal decJumpTarget                : unsigned(25 downto 0);
   
   signal decReqSource1                : std_logic;
   signal decReqSource2                : std_logic;
            
   -- stage 3    
   type CPU_LOADTYPE is
   (
      LOADTYPE_SBYTE,
      LOADTYPE_SWORD,
      LOADTYPE_LEFT,
      LOADTYPE_DWORD,
      LOADTYPE_BYTE,
      LOADTYPE_WORD,
      LOADTYPE_RIGHT
   );
   
   type CPU_EXESTALLTYPE is
   (
      EXESTALLTYPE_NONE,
      EXESTALLTYPE_READLO,
      EXESTALLTYPE_READHI,
      EXESTALLTYPE_GTE,
      EXESTALLTYPE_GTECMD
   );
   
   --regs         
   signal blockLoadforward             : std_logic := '0';
   signal executeException             : std_logic := '0';
   signal resultWriteEnable            : std_logic := '0';
   signal executeGTEReadEnable         : std_logic := '0';
   signal executeBranchdelaySlot       : std_logic := '0';
   signal executeBranchTaken           : std_logic := '0';
   signal resultTarget                 : unsigned(4 downto 0) := (others => '0');
   signal resultData                   : unsigned(31 downto 0) := (others => '0');
   signal executeMemWriteEnable        : std_logic;
   signal executeMemWriteData          : unsigned(31 downto 0) := (others => '0');
   signal executeMemWriteMask          : std_logic_vector(3 downto 0) := (others => '0');
   signal executeMemWriteAddr          : unsigned(31 downto 0) := (others => '0');
   signal executeCOP0WriteEnable       : std_logic := '0';
   signal executeCOP0WriteDestination  : unsigned(4 downto 0) := (others => '0');
   signal executeCOP0WriteValue        : unsigned(31 downto 0) := (others => '0');
   signal executeLoadType              : CPU_LOADTYPE;
   signal executeReadAddress           : unsigned(31 downto 0) := (others => '0');
   signal executeReadEnable            : std_logic := '0';
   signal executeGTETarget             : unsigned(4 downto 0) := (others => '0');
   signal hiloWait                     : integer range 0 to 38;
   signal executeStalltype             : CPU_EXESTALLTYPE;
   signal execute_gte_writeAddr        : unsigned(5 downto 0) := (others => '0');
   signal execute_gte_writeData        : unsigned(31 downto 0) := (others => '0');
   signal execute_gte_writeEna         : std_logic := '0'; 
   signal execute_gte_cmdData          : unsigned(31 downto 0);
   signal execute_gte_cmdEna           : std_logic := '0'; 
   signal execute_gte_readAddr         : unsigned(5 downto 0) := (others => '0');
   signal execute_lastreadCOP          : std_logic := '0'; 

   --wires
   signal branch                       : std_logic := '0';
   signal PCbranch                     : unsigned(31 downto 0) := (others => '0');
   signal EXEresultWriteEnable         : std_logic;
   signal EXEresultData                : unsigned(31 downto 0) := (others => '0');
   signal EXEresultTarget              : unsigned(4 downto 0) := (others => '0');
   signal EXEBranchdelaySlot           : std_logic := '0';
   signal EXEBranchTaken               : std_logic := '0';
   signal EXEMemWriteEnable            : std_logic := '0';
   signal EXEMemWriteData              : unsigned(31 downto 0) := (others => '0');
   signal EXEMemWriteMask              : std_logic_vector(3 downto 0) := (others => '0');
   signal EXEMemAddr                   : unsigned(31 downto 0) := (others => '0');
   signal EXEMemWriteException         : std_logic := '0';
   signal EXECOP0WriteEnable           : std_logic := '0';
   signal EXECOP0WriteDestination      : unsigned(4 downto 0) := (others => '0');
   signal EXECOP0WriteValue            : unsigned(31 downto 0) := (others => '0');
   signal EXELoadType                  : CPU_LOADTYPE;
   signal EXEReadEnable                : std_logic := '0';
   signal EXEReadException             : std_logic := '0';
   signal EXEGTeReadEnable             : std_logic := '0';
   signal EXEcalcMULT                  : std_logic := '0';
   signal EXEcalcMULTU                 : std_logic := '0';
   signal EXEcalcDIV                   : std_logic := '0';
   signal EXEcalcDIVU                  : std_logic := '0';
   signal EXEhiUpdate                  : std_logic := '0';
   signal EXEloUpdate                  : std_logic := '0';
   signal EXEstalltype                 : CPU_EXESTALLTYPE;
   signal EXEgte_writeAddr             : unsigned(5 downto 0);
   signal EXEgte_writeData             : unsigned(31 downto 0);
   signal EXEgte_writeEna              : std_logic := '0';    
   signal EXEgte_cmdData               : unsigned(31 downto 0);
   signal EXEgte_cmdEna                : std_logic := '0'; 
   signal EXElastreadCOP               : std_logic := '0'; 
   signal EXEBreakpoint                : std_logic := '0';
   
   --MULT/DIV
   type CPU_HILOCALC is
   (
      HILOCALC_MULT, 
      HILOCALC_MULTU,
      HILOCALC_DIV,  
      HILOCALC_DIVU,
      HILOCALC_DIV0
   );
   signal hilocalc                     : CPU_HILOCALC;
   
   signal mul1                         : unsigned(31 downto 0);
   signal mul2                         : unsigned(31 downto 0);
   signal mulResultS                   : signed(63 downto 0);
   signal mulResultU                   : unsigned(63 downto 0);
   
   signal DIVstart                     : std_logic;
   signal DIVdividend                  : signed(32 downto 0);
   signal DIVdivisor                   : signed(32 downto 0);
   signal DIVquotient                  : signed(32 downto 0);
   signal DIVremainder                 : signed(32 downto 0);    
   signal DIV0quotient                 : unsigned(31 downto 0);
   signal DIV0remainder                : unsigned(31 downto 0);    
         
   -- stage 4 
   -- scratchpad
   signal scratchpad_address_a         : std_logic_vector(7 downto 0);
   signal scratchpad_data_a            : std_logic_vector(31 downto 0);
   signal scratchpad_wren_a            : std_logic_vector(3 downto 0);
   signal scratchpad_q_a               : std_logic_vector(31 downto 0);
   signal scratchpad_address_b         : std_logic_vector(7 downto 0);
   signal scratchpad_q_b               : std_logic_vector(31 downto 0);
   signal scratchpad_dataread          : unsigned(31 downto 0);
   
   -- data cache  
   signal dcache_read_enable           : std_logic := '0';
   -- 2026-06-26: 20-bit (addr[21:2]) so the dcache tags the full 4MB ZN-1/System11 RAM.
   -- Was 19-bit (addr[20:2], 2MB): the upper 2MB (e.g. 0x2B1CE0) ALIASED onto the low 2MB
   -- (0x0B1CE0), so the CPU read a stale low-2MB cache line while SDRAM held the right value.
   signal dcache_read_addr             : std_logic_vector(19 downto 0) := (others => '0');
   signal dcache_read_hit              : std_logic;
   signal dcache_read_data             : std_logic_vector(31 downto 0);
         
   signal dcache_hit_next              : std_logic := '0';
         
   signal dcache_write_enable          : std_logic := '0';
   signal dcache_write_clear           : std_logic := '0';
   signal dcache_write_addr            : std_logic_vector(19 downto 0) := (others => '0');
   signal dcache_write_data            : std_logic_vector(31 downto 0) := (others => '0');
   
   signal spad_cache_dataread          : unsigned(31 downto 0);
   
   -- reg      
   signal writebackException           : std_logic := '0';
   signal writebackTarget              : unsigned(4 downto 0) := (others => '0');
   signal writebackData                : unsigned(31 downto 0) := (others => '0');
   signal writebackWriteEnable         : std_logic := '0';
   signal writebackGTEReadEnable       : std_logic := '0';
   signal writebackLoadType            : CPU_LOADTYPE;
   signal writebackReadAddress         : unsigned(31 downto 0) := (others => '0');
   signal writebackInvalidateCacheEna  : std_logic := '0';
   signal writebackInvalidateCacheLine : unsigned(7 downto 0) := (others => '0');
   signal WBgte_writeAddr              : unsigned(5 downto 0);
   
   signal lateReadTarget               : unsigned(4 downto 0) := (others => '0');
   signal lateReadOldData              : unsigned(31 downto 0) := (others => '0');
   signal lateReadData                 : unsigned(31 downto 0) := (others => '0');
   signal lateReadWrite                : std_logic := '0';
   signal lateReadBypass               : std_logic := '0';
   signal lateReadReqDone              : std_logic := '0';
   signal lateReadWriteAfterWrite      : std_logic := '0';
   signal lateReadStall                : std_logic := '0';
   signal lateReadRam                  : std_logic := '0';
         
   -- wire     
   signal mem4_request                 : std_logic := '0';
   signal mem4_address                 : unsigned(31 downto 0) := (others => '0');
   signal mem4_reqsize                 : unsigned(1 downto 0) := (others => '0');
   signal mem4_rnw                     : std_logic := '0';
   signal mem4_pending                 : std_logic := '0';
   signal mem4_dataWrite               : std_logic_vector(31 downto 0) := (others => '0');
   signal WBCACHECONTROL               : unsigned(31 downto 0) := (others => '0');
   signal WBinvalidateCacheEna         : std_logic := '0';
   signal WBinvalidateCacheLine        : unsigned(7 downto 0) := (others => '0');
         
         
   -- stage 5     
   -- reg      
   signal writeDoneTarget              : unsigned(4 downto 0) := (others => '0');
   signal writeDoneData                : unsigned(31 downto 0) := (others => '0');
   signal writeDoneWriteEnable         : std_logic := '0';
   
   -- savestates
   type t_ssarray is array(0 to 95) of std_logic_vector(31 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0')); 

   signal ss_scp_rden_1                : std_logic;              
   
   -- debug
-- synthesis translate_off
   signal debugCnt                     : unsigned(31 downto 0);
   signal debugSum                     : unsigned(31 downto 0);
   signal debugTmr                     : unsigned(31 downto 0);
   
   signal stallcountNo                 : integer;
   signal stallcount1                  : integer;
   signal stallcount3                  : integer;
   signal stallcount4                  : integer;
   signal stallcountDMA                : integer;
-- synthesis translate_on
   
   signal debugStallcounter            : unsigned(9 downto 0);
   signal debug300exception            : std_logic := '0';
   
   -- export
-- synthesis translate_off
   type tRegs is array(0 to 31) of unsigned(31 downto 0);
   signal regs                         : tRegs := (others => (others => '0'));
-- synthesis translate_on

   -- SYSTEM11 RELIABLE OPERAND REGFILE (2026-06-25): the RamMLAB regfile reads back 0 for a
   -- register that holds a correct COMMITTED value. Confirmed on HW via the packed capture:
   -- at the BIOS decompressor "or a0,s2,zero" @0x1FC20320, decodeSource1=0x12($18) decoded
   -- correctly but all 3 MLAB read ports (decodeValue1, regs3_q_b_wt, value1) returned 0, while
   -- the write-port tap proved $18 = 0x1FC2800x was committed. Same write-OK / read-wrong pattern
   -- as the SDRAM phantom, here in the on-chip regfile. FIX: a flip-flop shadow register file with
   -- a combinational (bulletproof) read feeds value1/value2; the MLAB instances stay only for the
   -- savestate/unaffected paths. reg0 is never written so it always reads 0.
   type tRegsFF is array(0 to 31) of unsigned(31 downto 0);
   signal regsFF                       : tRegsFF := (others => (others => '0'));
   signal regFF1                       : unsigned(31 downto 0);
   signal regFF2                       : unsigned(31 downto 0);

   -- BOOT-PROGRESS DIAG: sticky highest KSEG0-RAM (0x8xxxxxxx) committed PC offset. Game entry is
   -- ~0x80050000 (offset>=0x50000) => decompressor finished + BIOS jumped to game code. Combined
   -- with the exception latch this is a POSITIVE progress signal (vs the exception-only overlay).
   signal maxRAMPC                     : unsigned(20 downto 0) := (others => '0');
   signal irqVecCount                  : unsigned(7 downto 0) := (others => '0'); -- entries to the exception vector
   signal prevAtVec                    : std_logic := '0';

begin

   -- In-core trace buffer: value1-forwarding source flags (mirror the value1 mux conditions),
   -- the packed 32-bit sample, the meta word, and the flattened buffer for the renderer.
   trace_f_result  <= '1' when (decodeSource1 > 0 and resultTarget    = decodeSource1 and resultWriteEnable    = '1' and execute_lastreadCOP = '0') else '0';
   trace_f_late    <= '1' when (decodeSource1 = lateReadTarget and lateReadBypass = '1' and blockLoadforward = '0') else '0';
   trace_f_wb      <= '1' when (decodeSource1 > 0 and writebackTarget = decodeSource1 and writebackWriteEnable = '1' and blockLoadforward = '0') else '0';
   trace_f_wd      <= '1' when (decodeSource1 > 0 and writeDoneTarget = decodeSource1 and writeDoneWriteEnable = '1') else '0';
   trace_ds1_a1    <= '1' when (decodeSource1 = 5) else '0';   -- decode reads a1
   trace_ds1_v0    <= '1' when (decodeSource1 = 2) else '0';   -- decode reads v0 (the beqz)
   trace_rt_eq_ds1 <= '1' when (resultTarget = decodeSource1) else '0';
   trace_stall_nz  <= '1' when (stall /= 0) else '0';
   -- TARGETED beqz capture: a sample is taken only while the helper beqz (PC 0x?284) is the
   -- execute-stage instruction (pcOld0(11:2)=0x0A1), so value1/value2/branch/forwards are all
   -- coherent for THAT instruction. [31:16]=value1[15:0] (the v0 it compares), [15:8]=value2[7:0]
   -- (=zero reg, should be 0), [7]=branch (taken?), [6:3]=fwd r/l/wb/wd, [2]=ds1_v0, [1]=ds1_a1,
   -- [0]=stall/=0. value1==0 & branch==0 => comparator bug; value1/=0 => andi's v0 didn't forward.
   -- gate on the helper ANDI being the DECODE-stage instruction (andi v0,a1,1 = 0x30A20001:
   -- decodeOP=0xC, rs=a1=5, imm=1). Capture whether it PRODUCES its result (EXEresultWriteEnable
   -- / EXEresultData=v0) and REGISTERS it (resultWriteEnable/resultTarget). If at no stall=0
   -- cycle does it produce v0=0, the andi's result is dropped => beqz reads stale v0.
   -- gate on the WRITEBACK stage targeting v0 (reg2) -> trace every cycle a result for v0 is at
   -- writeback. Shows whether the andi's v0=0 reaches writeback and the regfile write fires.
   -- LIVE-PC tracer: capture the EXECUTE-stage PC (pcOld1) every committed instruction (stall=0).
   -- No fault now, so the ring free-runs; the newest 64 samples = where the game is currently
   -- looping (FPS=0, no render -> find the wait/stall loop).
   trace_is_beqz   <= '1' when (stall = 0) else '0';
   trace_wr_v0     <= '0';
   trace_sample    <= std_logic_vector(pcOld1);
   dbg_instr_word  <= pcOld1;   -- LIVE committed PC (full 32-bit, unsigned) -> overlay to pin the render loop
   trace_meta      <= trace_frozen & trace_trig & std_logic_vector(to_unsigned(0, 24)) & std_logic_vector(trace_head);
   gen_trace_flat: for i in 0 to 63 generate
      trace_flat((i+1)*32-1 downto i*32) <= trace_mem(i);
   end generate;

   -- SIM-ONLY operand-forward observation (concurrent, synthesis-visible).
   dbg_value1       <= std_logic_vector(value1);
   dbg_value2       <= std_logic_vector(value2);
   dbg_resultData   <= std_logic_vector(resultData);
   dbg_resultTarget <= std_logic_vector(resultTarget);
   dbg_resultWE     <= resultWriteEnable;
   dbg_stall        <= std_logic_vector(stall);
   dbg_pcOld1       <= std_logic_vector(pcOld1);
   dbg_reg_v0       <= std_logic_vector(regsFF(4));   -- a0 (synthesis-active FF regfile, not sim-only regs)
   dbg_reg_a0       <= std_logic_vector(regsFF(5));   -- a1
   dbg_reg_s2       <= std_logic_vector(regsFF(2));   -- v0 (loaded [a0]&0xFF in the poll)
   dbg_mem1req      <= mem1_request;
   dbg_membusy      <= memoryMuxBusy;
   dbg_stall1       <= stall1;
   dbg_wr_wren      <= regs_wt_wren;
   dbg_wr_addr      <= regs_wt_addr;
   dbg_wr_data      <= regs_wt_data;

   -- IO
   mem_request       <= mem1_request or mem1_request_latched or mem4_request when (memoryMuxBusy = '0' or mem_done = '1') else '0';
   mem_isCache       <= FetchLastCache     when (mem1_request_latched = '1') else mem1_cacherequest;
   mem_oldtagvalids  <= FetchLastTagvalids when (mem1_request_latched = '1') else mem1_tagvalids;
   mem_addressInstr  <= FetchLastAddr      when (mem1_request_latched = '1') else mem1_address;
   mem_isData        <= mem4_request;
   mem_rnw           <= mem4_rnw     when mem4_request = '1' else '1';
   mem_addressData   <= mem4_address;
   mem_reqsize       <= mem4_reqsize when mem4_request = '1' else "10";
   mem_dataWrite     <= mem4_dataWrite;
   mem_writeMask     <= executeMemWriteMask;

   -- KUSEG/KSEG0 cached, plus ONLY the System11 decompressor region [0x1FC20000,0x1FC30000) so
   -- it runs from the ICACHE (like PSX's cached BIOS) instead of per-instruction uncached READROM
   -- fetches -> avoids the stall pattern that opens the andi->beqz forward gap. Early BIOS init
   -- (0x1FC00xxx) stays uncached (proven path); I/O / banked ROM stay below 0x1FC20000.
   -- TEST 2026-06-25: decompressor region clause REMOVED -> [0x1FC20000,0x1FC30000) now runs UNCACHED
   -- again, to test whether the branch divergence is stall-cadence dependent (cached vs uncached).
   mem1_cacherequest <= '1' when (to_integer(FetchAddr(31 downto 29)) = 0 or to_integer(FetchAddr(31 downto 29)) = 4) else '0';

   stallNext         <= mem_request or stallNew3;

   -- common
   stall        <= dmaStallCPU & stall4 & stall3 & stall2 & stall1;

   exceptionNew <= exceptionNew5 & '0' & exceptionNew3 & '0' & exceptionNew1;
   
   mem4_pending <= memoryMuxBusy and memoryMuxStage4;
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then
         
            -- no ss when stalled -> not relevant for savestate
            memoryMuxStage4       <= '0'; 
            memoryMuxBusy         <= '0';
            mem1_request_latched  <= '0';
         
         elsif (ce = '1') then
            
            if (mem1_request = '1') then
               FetchLastAddr      <= mem1_address;
               FetchLastCache     <= mem1_cacherequest;
               FetchLastTagvalids <= mem1_tagvalids;
               if (mem4_request = '1' or memoryMuxBusy = '1') then
                  mem1_request_latched <= '1';
               end if;
            end if;
            
            if (mem_done = '1') then
               memoryMuxBusy <= '0';
            end if;
            
            if (mem_request = '1' and (memoryMuxBusy = '0' or mem_done = '1')) then
               memoryMuxStage4  <= mem_isData;
               memoryMuxBusy    <= mem_rnw;
               if (mem_isData = '0') then
                  mem1_request_latched <= '0';
               end if;
            end if;

         end if;
      end if;
   end process;
   
--##############################################################
--############################### register file
--##############################################################
   iregisterfile1 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs1_address_b,
      q          => regs1_q_b
	);
   
   regs_wren_a    <= '1' when (ss_regs_load = '1') else
                     '1' when (lateReadWrite = '1') else
                     '1' when (ce = '1' and stall = 0 and writebackWriteEnable = '1' and writebackException = '0' and writebackTarget > 0) else 
                     '0';
   
   regs_data_a    <= ss_regs_data when (ss_regs_load = '1') else 
                     std_logic_vector(lateReadData) when (lateReadWrite = '1') else 
                     std_logic_vector(writebackData);
                     
   regs_address_a <= std_logic_vector(ss_regs_addr) when (ss_regs_load = '1') else 
                     std_logic_vector(lateReadTarget) when (lateReadWrite = '1') else 
                     std_logic_vector(writebackTarget);
   
   
   regs1_address_b <= std_logic_vector(decSource1);
   regs2_address_b <= std_logic_vector(decSource2);

   -- CPU forwarding-gap fix (System11; no PSX-compat constraint): the RamMLAB regfile reads
   -- old data when a write collides with the operand read, and the value1/value2 forward net
   -- checks the REGISTERED decodeSource (1 cycle behind the combinational read addr decSource),
   -- so it misses this collision -> consumer reads a stale operand. This is the andi->beqz v0
   -- gap that drives the decompressor AdES. Bypass it: align the write + read-addr to the
   -- 1-cycle synchronous read latency and substitute the write data on a same-cell hit.
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         regs_wt_wren   <= regs_wren_a;
         regs_wt_addr   <= regs_address_a;
         regs_wt_data   <= regs_data_a;
         regs1_rdaddr_q <= regs1_address_b;
         regs2_rdaddr_q <= regs2_address_b;
      end if;
   end process;
   regs1_q_b_wt <= regs_wt_data when (regs_wt_wren = '1' and regs_wt_addr = regs1_rdaddr_q) else regs1_q_b;
   regs2_q_b_wt <= regs_wt_data when (regs_wt_wren = '1' and regs_wt_addr = regs2_rdaddr_q) else regs2_q_b;

   -- FF shadow regfile: mirror the regfile write port (incl. savestate loads, which drive the same
   -- regs_wren_a/regs_address_a/regs_data_a). Never write reg0 so it stays 0. Combinational reads.
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (regs_wren_a = '1' and unsigned(regs_address_a) /= 0) then
            regsFF(to_integer(unsigned(regs_address_a))) <= unsigned(regs_data_a);
         end if;
      end if;
   end process;
   regFF1 <= regsFF(to_integer(decodeSource1));
   regFF2 <= regsFF(to_integer(decodeSource2));

   -- BOOT-PROGRESS latch: highest RAM PC committed + count of entries to the MIPS exception vector
   -- (0x80000080 BEV=0 / 0xBFC00180 BEV=1). The game's early loop waits on an IRQ; if irqVecCount
   -- stays 0 the FPGA takes NO interrupts -> spins forever (root = IRQ delivery / C76).
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset = '1') then
            maxRAMPC    <= (others => '0');
            irqVecCount <= (others => '0');
            prevAtVec   <= '0';
         else
            if (pcOld1(31 downto 28) = x"8" and pcOld1(20 downto 0) > maxRAMPC) then
               maxRAMPC <= pcOld1(20 downto 0);
            end if;
            if (pcOld1 = x"80000080" or pcOld1 = x"BFC00180") then
               if (prevAtVec = '0' and irqVecCount /= x"FF") then irqVecCount <= irqVecCount + 1; end if;
               prevAtVec <= '1';
            else
               prevAtVec <= '0';
            end if;
         end if;
      end if;
   end process;

   -- WRITE-CAPTURE (2026-07-04): sticky-latch the FIRST store of a garbage (<0x10000) value to the
   -- crash pointer-table entry 0x803FFE04, with its PC (PCold1). EXEMemAddr/EXEMemWriteData/PCold1 are
   -- aligned at the execute stage (same as the fault path). Finds the routine writing the bad ptr (0x4A05).
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset = '1') then
            dbg_wrcap_seen <= '0';
         elsif (ce = '1') then
            if (dbg_wrcap_seen = '0' and EXEMemWriteEnable = '1'
                and EXEMemAddr(23 downto 0) = x"3FFE04"
                and EXEMemWriteData(31 downto 16) = x"0000") then
               dbg_wrcap_seen <= '1';
               dbg_wrcap_pc   <= std_logic_vector(PCold1);
               dbg_wrcap_data <= std_logic_vector(EXEMemWriteData);
            end if;
         end if;
      end if;
   end process;
   -- zn_debug_val (via dbg_fault_a1): [31:24]=irqVecCount, [23:21]=0, [20:0]=maxRAMPC offset.
   -- maxRAMPC = highest KSEG0-RAM PC the MIPS ever committed: offset>=0x50000 => past the C76 verify
   -- loop @0x8003E690 into game boot. Tells whether the C76 fixes are unblocking Tekken at all.
   dbg_fault_a1(31 downto 24) <= irqVecCount;
   dbg_fault_a1(23 downto 21) <= "000";
   dbg_fault_a1(20 downto 0)  <= maxRAMPC;
   
   iregisterfile2 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs2_address_b,
      q          => regs2_q_b
	);

   -- LIVE execute-stage operand reads (decodeSource1/2) + their read-during-write bypass.
   iregisterfile3 : entity mem.RamMLAB
      GENERIC MAP ( width => 32, widthad => 5 )
      PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => std_logic_vector(decodeSource1),
      q          => regs3_q_b
      );
   iregisterfile4 : entity mem.RamMLAB
      GENERIC MAP ( width => 32, widthad => 5 )
      PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => std_logic_vector(decodeSource2),
      q          => regs4_q_b
      );
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         regs3_rdaddr_q <= std_logic_vector(decodeSource1);
         regs4_rdaddr_q <= std_logic_vector(decodeSource2);
      end if;
   end process;
   regs3_q_b_wt <= regs_wt_data when (regs_wt_wren = '1' and regs_wt_addr = regs3_rdaddr_q) else regs3_q_b;
   regs4_q_b_wt <= regs_wt_data when (regs_wt_wren = '1' and regs_wt_addr = regs4_rdaddr_q) else regs4_q_b;

   iregisterfileSS : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regsSS_address_b,
      q          => regsSS_q_b
	);

--##############################################################
--############################### stage 1
--##############################################################

   itagram : entity mem.RamMLAB
   generic map
   (
      width      => 24,
      widthad    => 8
   )
   port map
   (
      inclock    => clk1x,
      wren       => tag_wren_a,
      data       => tag_data_a,
      wraddress  => tag_address_a,
      rdaddress  => tag_address_b,
      q          => tag_q_b
   );

   tag_address_a <= std_logic_vector(writebackInvalidateCacheLine) when (writebackInvalidateCacheEna = '1') else std_logic_vector(FetchLastAddr(11 downto 4));
   
   tag_data_a    <= "0000"        & std_logic_vector(FetchLastAddr(31 downto 12)) when (writebackInvalidateCacheEna = '1') else
                    mem_tagvalids & std_logic_vector(FetchLastAddr(31 downto 12));
   
   tag_address_b <= std_logic_vector(FetchAddr(11 downto 4));

   gcache: for i in 0 to 3 generate
   begin
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 32)
      port map
      (
         clock_a     => clk3x,   -- icache fill clock matches sdram.sv .clk(clk_3x) [ZN1-stock]
         address_a   => cache_addr,
         data_a      => cache_data,
         wren_a      => cache_wr(i),
         
         clock_b     => clk1x,
         address_b   => cache_address_b,
         data_b      => x"00000000",
         wren_b      => '0',
         q_b         => cache_q_b((32*i) + 31 downto (32*i))
      );
   end generate; 
   
   FetchAddr       <= x"80000040" when (exceptionBreakpoint = '1') else
                      x"BFC00180" when (exception > 0 and cop0_SR(22) = '1') else
                      x"80000080" when (exception > 0 and cop0_SR(22) = '0') else
                      PCbranch when branch = '1' else
                      PC;
                      
   cache_address_b <= std_logic_vector(FetchAddr(11 downto 4));
   
   cacheHitTest    <= '1' when (unsigned(tag_q_b(19 downto 0)) = FetchAddr(31 downto 12) and tag_q_b(20 + to_integer(unsigned(FetchAddr(3 downto 2)))) = '1') else '0';
            

   mem1_address    <= FetchAddr;

   process (blockirq, cop0_SR, cop0_CAUSE, exception, stall, mem_done, mem_dataRead, memoryMuxStage4, fetchReady, stall1, opcode0, reset, FetchAddr, 
            tag_q_b, blockirqCnt, FetchLastAddr, writebackInvalidateCacheEna, cacheHitTest)
   begin
      PCnext          <= FetchAddr;
      fetchReadyNext  <= fetchReady;
      fetchReadyNow   <= '0';
      stallNew1       <= stall1;
      opcodeNext      <= opcode0;
      blockirqNext    <= blockirq;
      blockirqCntNext <= blockirqCnt;
      
      exceptionNew1   <= '0';
      exceptionNew5   <= '0';

      tag_wren_a      <= '0';
      
      mem1_request    <= '0';
      cacheHitNext    <= '0';
      mem1_tagvalids  <= "0000";
      
      if (mem_done = '1' and memoryMuxStage4 = '0') then
         -- validate the icache line for any CACHEABLE fill (KUSEG/KSEG0 or boot-program ROM);
         -- FetchLastCache = mem1_cacherequest captured at request time.
         if (FetchLastCache = '1') then
            tag_wren_a   <= '1';
         end if;
      end if;
      
      if (writebackInvalidateCacheEna = '1') then
         tag_wren_a   <= '1';
      end if;

      if (exception = 0 and blockirq = '0' and cop0_SR(0) = '1' and (cop0_SR(10 downto 8) and cop0_CAUSE(10 downto 8)) /= "000") then
      
         if (stall = 0) then
            blockirqNext    <= '1';
            blockirqCntNext <= 10;     
            exceptionNew5   <= '1';
         elsif (stall1 = '1') then
            if (mem_done = '1' and memoryMuxStage4 = '0') then
               stallNew1 <= '0';
            end if;
         end if;
         
      elsif (stall = 0) then
      
         if (reset = '0') then
         
            if (mem1_cacherequest = '1') then -- cacheable (KUSEG/KSEG0 or boot-program ROM)
               if (cacheHitTest = '1') then
                  cacheHitNext      <= '1';
                  PCnext            <= FetchAddr + 4;
               else
                  mem1_request      <= '1';
                  stallNew1         <= '1';
                  if (unsigned(tag_q_b(19 downto 0)) = FetchAddr(31 downto 12)) then
                     mem1_tagvalids <= tag_q_b(23 downto 20);
                  end if;
               end if;
            else -- uncached (I/O, banked ROM)
               mem1_request      <= '1';
               stallNew1         <= '1';
            end if;
         
         end if;
      
         if (exception > 0) then
      
            blockirqNext    <= '1';
            blockirqCntNext <= 10;    
            
         else 
         
            fetchReadyNext <= '0';

            if (blockirqCnt > 0) then
               blockirqCntNext <= blockirqCnt - 1;
               if (blockirqCnt = 1) then
                  blockirqNext <= '0';
               end if;
            end if;
      
         end if;
      
      elsif (stall1 = '1') then
      
         if (mem_done = '1' and memoryMuxStage4 = '0') then
            
            stallNew1      <= '0';
            PCnext         <= FetchAddr + 4;
            fetchReadyNext <= '1';
            fetchReadyNow  <= '1';
            opcodeNext     <= unsigned(mem_dataRead);

         end if;
      
      end if;
      
   end process;
   
   ss_out( 0) <= std_logic_vector(PC);
   ss_out(25)(0) <= fetchReady;
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         
         ce_1 <= ce;
      
         if (reset = '1') then
                     
            stall1         <= '0';
            PC             <= unsigned(ss_in(0)); -- x"BFC00000";
                           
            blockIRQ       <= '0'; -- todo: busy for savestate?
            blockirqCnt    <= 0;
            fetchReady     <= ss_in(25)(0);
            opcode0        <= unsigned(ss_in(14));
            PCold0         <= unsigned(ss_in(19));
            
            cacheHit       <= '0';
            cacheHitLast   <= '0';
         
         elsif (ce = '1') then
            
            fetchReady     <= fetchReadyNext;
            PC             <= PCnext;
            stall1         <= stallNew1;
            
            blockirq       <= blockirqNext;   
            blockirqCnt    <= blockirqCntNext;
            
            cacheHit       <= cacheHitNext;
            if (cacheHit = '1' and stall > 0) then
               cacheHitLast   <= '1';
               case (PCold0(3 downto 2)) is
                  when "00" => cacheValueLast <= unsigned(cache_q_b( 31 downto  0));
                  when "01" => cacheValueLast <= unsigned(cache_q_b( 63 downto 32));
                  when "10" => cacheValueLast <= unsigned(cache_q_b( 95 downto 64));
                  when "11" => cacheValueLast <= unsigned(cache_q_b(127 downto 96));
                  when others => null;
               end case;
            elsif (stall = 0) then
               cacheHitLast <= '0';
            end if;
            
            if (fetchReadyNow = '1') then
               opcode0        <= opcodeNext;
               PCold0         <= PC;
            end if;

            if (cacheHitNext = '1') then
               PCold0 <= FetchAddr;
            end if;

            -- DIAG: latch the decoded word at PC 0x10170 (matched opcode0/PCold0 pair, sticky first).
            if (cap_fetch_seen = '0' and PCold0(19 downto 0) = x"10170") then
               cap_fetch_word <= opcode0;
               cap_fetch_seen <= '1';
            end if;
            -- DECISIVE: latch the RAW delivered word (mem_dataRead) on the cache-MISS FILL of 0x10170.
            if (cap_raw_seen = '0' and fetchReadyNow = '1' and FetchAddr(19 downto 0) = x"10170") then
               cap_raw      <= unsigned(mem_dataRead);
               cap_raw_seen <= '1';
            end if;

            -- DECOMPRESSOR PIPELINE CAPTURE: sticky-last operand/result at the byte-extraction sra
            -- (pcOld1 low 28 bits = 0xFC20264), frozen on the decompressor's store to output 0x10170
            -- (EXEMemWriteEnable + EA low20=0x10170 + nonzero high half, to skip the boot zero-clear).
            -- CAPTURE #8: the control word s5 at iteration-2's literal-vs-copy decision. At the
            -- 2nd-iteration "andi v0,s5,0x0001" (pcOld1 low28=0xFC203FC, FIRST occurrence = output
            -- 0x10001's decision): value1 = s5 ($21, the control word), EXEresultData = s5 & 1 (the
            -- branch selector: 1=>literal, 0=>copy). FIRED SENTINEL in top byte (0xFA) so never-fired
            -- is distinguishable. zn_debug_val = {0xFA, s5[7:0], 0x00, (s5&1)[7:0]}.
            -- res(s5&1)=1 => s5 OK & should go LITERAL; if FPGA still copies => BRANCH mis-resolved
            -- (branch-resolution race). res=0 => s5 is WRONG (control-byte read or sra s5,1 corrupted).
            -- CAPTURE #9: the source pointer a0(=s2) at iteration-2's helper call. Counter-gated to
            -- the 0x80010000 decompression: ARM on the control-byte helper read (a0=0x1FC28000), then
            -- count helper calls (0xFC20210); the 2nd subsequent call (dbg_cnt2=1) = out[0x10001].
            -- value1=a0, EXEresultData=a0&1. op=a0[15:0], res={0xFA sentinel, a0&1}. MAME a0=0x1FC28002
            -- => zn_debug_val=0x8002FA00. a0[15:0]/=0x8002 => s2 WRONG; a0=0x8002 & a0&1=0 but read odd
            -- => HELPER BRANCH RACE. res[15:8]/=0xFA => never fired.
            -- MEASUREMENT RULER (first-mismatch detector): at the byte-writer combiner "sh v0,-1(a1)"
            -- (pcOld1 low28=0xFC2029C, output 0x10000-0x101FF), compare value2(=output halfword) vs the
            -- MAME ground-truth mame_tab; latch the FIRST mismatch. zn_debug_val = {0xFA sentinel,
            -- halfword index(0..255), fpga halfword}. top byte 0xFA => a mismatch (idx=0 -> out 0x10000;
            -- larger idx => the fix pushed the failure later). top byte 0x00 => NO mismatch (boot output
            -- matches MAME = the fix WORKED for this region).
            -- DECISIVE SOURCE-DATA CAPTURE (via the reliable write-port tap): the FIRST source lhu
            -- (pcOld1 low28=0xFC20258) address + the halfword the CPU actually LOADED (next write to
            -- v1=$3=reg3). zn_debug_val={src_addr[15:0], loaded_v1[15:0]}. MAME first source read =
            -- lhu(0x1FC28000)=0xE0FF (s11_prog.bin[0x28000]). If loaded=0xE0FF => source reads FAITHFUL
            -- => bug is CONTROL FLOW (not SDRAM/read-path). If loaded wrong => SDRAM/READROM corruption.
            -- 2ND SOURCE-READ CAPTURE (the read feeding out[0x10001]): the 2nd even-path source lhu
            -- @0xFC20258: its address (EXEMemAddr) + the loaded halfword (next write to v1=$3 via the
            -- reliable write-port tap). MAME: addr=0x8002 (0x28002), v1=0xBDFF. zn_debug_val={addr16,v1
            -- 16}. addr!=0x8002 => source POINTER wrong; addr=0x8002 & v1 low byte!=0xFF => addr-specific
            -- READ CORRUPTION; addr=0x8002 & v1=0xBDFF => read faithful => byte-extraction/control bug.
            if (dbg_dcap_frozen = '0') then
               -- S2-EVOLUTION CAPTURE: trace writes to s2($18) via the write-port tap. Arm on the write
               -- that sets s2=0x1FC28000 (source base), then capture the NEXT TWO writes to $18.
               -- MAME: s2 advances 0x...8000 -> 0x8001 -> 0x8002. zn_debug_val={s2_next1[15:0],
               -- s2_next2[15:0]}. A 0x0000 reveals the write that clobbers s2 (and roughly when).
               -- OPERAND-READ SPLIT: at the failing "or a0,s2,zero" @0xFC20320 (armed on the 0x80010000
               -- decompression via the s2=0x...8000 write; gated to the one whose result a0 is NOT a
               -- valid source ptr, EXEresultData high /= 0x1FC2). Capture value1 (operand the or used)
               -- vs decodeValue1 (regfile value latched at decode). zn_debug_val={value1[15:0],
               -- decodeValue1[15:0]}. value1=0 & decodeValue1=0x8002 => FORWARD-MUX overrode good regfile
               -- value with 0; both 0 => REGFILE READ itself returned 0.
               -- UNAMBIGUOUS PACK: zn_debug_val = {op[15:0],res[15:0]} =
               --   [31]    fired (1=capture happened; 0=never fired, ignore the rest)
               --   [30:26] decodeSource1  (expect 0x12=$18; other => delay-slot mis-DECODE)
               --   [25:16] value1[17:8]   (operand USED; expect 0x280 for s2=0x1FC2800x; 0 => read 0)
               --   [12:3]  decodeValue1[17:8] (regfile latch; expect 0x280; 0 => regfile read 0)
               --   [2:0]   regs3_q_b_wt[10:8] (live re-read low slice, tie-breaker)
               if (dbg_arm2 = '0' and dbg_wr_wren = '1' and dbg_wr_addr = "10010" and dbg_wr_data(27 downto 0) = x"FC28000") then
                  dbg_arm2 <= '1';
               end if;
               -- FIX VALIDATION: capture value1 (=regFF1 now) + the or-result at the FIRST 0x20320
               -- after arming (no failing-case gate). zn_debug_val: [31]=fired, [30:16]=value1[14:0],
               -- [15:0]=EXEresultData[15:0] (the a0 produced). FIXED => value1[14:0]=0x0002 region and
               -- EXEresultData=0x8002 (a0=0x1FC28002, low16=0x8002). STILL BROKEN => value1=0 / result=0.
               if (dbg_arm2 = '1' and pcOld1(27 downto 0) = x"FC20320") then
                  dbg_dcap_op     <= x"0000" & ("1" & value1(14 downto 0));
                  dbg_dcap_res    <= x"0000" & EXEresultData(15 downto 0);
                  dbg_dcap_frozen <= '1';
               end if;
            end if;

         elsif (ce_1 = '1') then
            
            if (cacheHit = '1') then
               cacheHitLast   <= '1';
               case (PCold0(3 downto 2)) is
                  when "00" => cacheValueLast <= unsigned(cache_q_b( 31 downto  0));
                  when "01" => cacheValueLast <= unsigned(cache_q_b( 63 downto 32));
                  when "10" => cacheValueLast <= unsigned(cache_q_b( 95 downto 64));
                  when "11" => cacheValueLast <= unsigned(cache_q_b(127 downto 96));
                  when others => null;
               end case;
            end if;
               
         end if;
      end if;
     
   end process;
   
   
--##############################################################
--############################### stage 2
--##############################################################
   
   opcodeCacheMuxed <= cacheValueLast when cacheHitLast = '1' else
                       unsigned(cache_q_b( 31 downto  0)) when (cacheHit = '1' and PCold0(3 downto 2) = "00") else
                       unsigned(cache_q_b( 63 downto 32)) when (cacheHit = '1' and PCold0(3 downto 2) = "01") else
                       unsigned(cache_q_b( 95 downto 64)) when (cacheHit = '1' and PCold0(3 downto 2) = "10") else
                       unsigned(cache_q_b(127 downto 96)) when (cacheHit = '1' and PCold0(3 downto 2) = "11") else
                       opcode0;
                       
                       
                       
   decImmData    <= opcodeCacheMuxed(15 downto 0);
   decJumpTarget <= opcodeCacheMuxed(25 downto 0);
   decSource1    <= opcodeCacheMuxed(25 downto 21);
   decSource2    <= opcodeCacheMuxed(20 downto 16);
   decOP         <= opcodeCacheMuxed(31 downto 26);
   decFunct      <= opcodeCacheMuxed(5 downto 0);
   decShamt      <= opcodeCacheMuxed(10 downto 6);
   decRD         <= opcodeCacheMuxed(15 downto 11);
   decTarget     <= opcodeCacheMuxed(20 downto 16) when (opcodeCacheMuxed(31 downto 26) > 0) else opcodeCacheMuxed(15 downto 11);                 
               
   -- find which value is required by which opcode for blocking
   process (decSource1, decSource2, decOP, decFunct, decShamt, decRD)
   begin
   
      decReqSource1 <= '0';
      decReqSource2 <= '0';

      case (to_integer(decOP)) is
      
         when 16#00# =>
            case (to_integer(decFunct)) is
      
               when 16#08# | -- JR 
                    16#09# | -- JALR
                    16#11# | -- MTHI
                    16#13#   -- MTLO
               => decReqSource1 <= '1'; 
               
               when 16#00# | -- SLL
                    16#02# | -- SRL
                    16#03#   -- SRA
               => decReqSource2 <= '1'; 
                        
               when 16#04# | -- SLLV
                    16#06# | -- SRLV
                    16#07# | -- SRAV
                    16#18# | -- MULT
                    16#19# | -- MULTU
                    16#1A# | -- DIV
                    16#1B# | -- DIVU
                    16#20# | -- ADD
                    16#21# | -- ADDU
                    16#22# | -- SUB
                    16#23# | -- SUBU
                    16#24# | -- AND
                    16#25# | -- OR
                    16#26# | -- XOR
                    16#27# | -- NOR
                    16#2A# | -- SLT
                    16#2B#   -- SLTI
               => decReqSource1 <= '1';
                  decReqSource2 <= '1';                   
                  
               when others => null;
                  
            end case;
            
         when 16#01# | -- B: BLTZ, BGEZ, BLTZAL, BGEZAL
              16#06# | -- BLEZ
              16#07# | -- BGTZ
              16#08# | -- ADDI
              16#09# | -- ADDIU
              16#0A# | -- SLTI
              16#0B# | -- SLTIU
              16#0C# | -- ANDI
              16#0D# | -- ORI
              16#0E# | -- XORI
              16#20# | -- LB
              16#21# | -- LH
              16#23# | -- LW
              16#24# | -- LBU
              16#25# | -- LHU
              16#32# | -- LWC2
              16#3A#   -- SWC2
            => decReqSource1 <= '1';

         when 16#04# | -- BEQ
              16#05# | -- BNE
              16#28# | -- SB
              16#29# | -- SH
              16#2A# | -- SWL
              16#2B# | -- SW
              16#2E# | -- SWR
              16#22# | -- LWL
              16#26#   -- LWR
            => decReqSource1 <= '1';
               decReqSource2 <= '1';  
         
         
         when 16#10# => -- COP0
            if (to_integer(decSource1) = 4) then
               decReqSource2 <= '1';   
            end if;
            
         when 16#12# => -- COP2
            if (to_integer(decSource1) = 4 or to_integer(decSource1) = 6) then
               decReqSource2 <= '1';   
            end if;   

         when others => 
            null;
      
      end case;
      
   end process;
                
   ss_out(14) <= std_logic_vector(opcodeCacheMuxed);
   ss_out(19) <= std_logic_vector(PCold0);

   ss_out(15) <= std_logic_vector(opcode1);
   ss_out(20) <= std_logic_vector(pcOld1);

   ss_out(32)(25) <= decodeException;
   
   ss_out(26)(15 downto 0)   <= std_logic_vector(decodeImmData);
   ss_out(31)( 4 downto 0)   <= std_logic_vector(decodeSource1);
   ss_out(31)(12 downto 8)   <= std_logic_vector(decodeSource2);
   ss_out(27)                <= std_logic_vector(decodeValue1);
   ss_out(28)                <= std_logic_vector(decodeValue2);
   ss_out(31)(29 downto 24)  <= std_logic_vector(decodeOP);
   ss_out(32)(13 downto  8)  <= std_logic_vector(decodeFunct);
   ss_out(32)(20 downto 16)  <= std_logic_vector(decodeShamt);
   ss_out(32)( 4 downto  0)  <= std_logic_vector(decodeRD);
   ss_out(31)(20 downto 16)  <= std_logic_vector(decodeTarget);
   ss_out(29)(25 downto  0)  <= std_logic_vector(decodeJumpTarget);

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then
         
            stall2     <= '0';

            trace_wptr    <= (others => '0');   -- in-core trace ring reset
            trace_frozen  <= '0';
            trace_trig    <= '0';
            trace_postcnt <= (others => '0');
            trace_head    <= (others => '0');

            pcOld1  <= unsigned(ss_in(20));
            opcode1 <= unsigned(ss_in(15));
            
            decodeException  <= ss_in(32)(25);
            decodeImmData    <= unsigned(ss_in(26)(15 downto 0));
            decodeSource1    <= unsigned(ss_in(31)(4 downto 0));
            decodeSource2    <= unsigned(ss_in(31)(12 downto 8));
            decodeValue1     <= unsigned(ss_in(27));
            decodeValue2     <= unsigned(ss_in(28));
            decodeOP         <= unsigned(ss_in(31)(29 downto 24));
            decodeFunct      <= unsigned(ss_in(32)(13 downto 8));
            decodeShamt      <= unsigned(ss_in(32)(20 downto 16));
            decodeRD         <= unsigned(ss_in(32)(4 downto 0));
            decodeTarget     <= unsigned(ss_in(31)(20 downto 16));
            decodeJumpTarget <= unsigned(ss_in(29)(25 downto 0));
            
            if (unsigned(ss_in(31)(29 downto 24)) = 16#12#) then
               decode_gte_readAddr <= ss_in(31)(1) & unsigned(ss_in(32)(4 downto 0)); -- decodeSource1(1) & decodeRD 
            else
               decode_gte_readAddr <= '0' & unsigned(ss_in(31)(12 downto 8)); -- decodeSource2
            end if;
            
            decodeReqSource1 <= '0'; -- no savestate required, cannot save while load is pending
            decodeReqSource2 <= '0';
         
         elsif (ce = '1') then

            -- IN-CORE TRACE: free-running 64-deep ring at INSTRUCTION granularity (one sample per
            -- stall=0 commit cycle). This spans many more instructions than per-cycle capture
            -- (stalls reach 11+ cycles), so 64 samples cover the andi->beqz->sh window across
            -- iterations. On the first genuine fault (dbg_exc_seen) capture 4 more commits then
            -- FREEZE. head = ring index of oldest sample.
            if (trace_frozen = '0') then
               -- capture ONLY while the helper beqz (0x?284) is in execute => each entry is one
               -- beqz evaluation with coherent value1/value2/branch. newest = the fault beqz.
               if (trace_is_beqz = '1') then
                  trace_mem(to_integer(trace_wptr)) <= trace_sample;
                  trace_wptr <= trace_wptr + 1;
               end if;
               -- freeze a couple cycles after the fault (the fault beqz is already captured).
               if (trace_trig = '1') then
                  if (trace_postcnt = 0) then
                     trace_frozen <= '1';
                     trace_head   <= trace_wptr;   -- next-write pos; newest valid = head-1
                  else
                     trace_postcnt <= trace_postcnt - 1;
                  end if;
               elsif (dbg_exc_seen = '1') then
                  trace_trig <= '1';
                  trace_postcnt <= to_unsigned(2, 5);
               end if;
            end if;

            -- DIAGNOSTIC (runs EVERY ce cycle, incl. stalls): capture the OPERAND a1 the
            -- decompressor andi uses. NOTE: `regs` is synthesis-off (sim only), so the real
            -- operand is value1 (forwarded from regs1_q_b). pcOld1<=pcOld0 is stall-gated so
            -- PCold1 SKIPS the andi (it executes during the helper's first jal icache-miss
            -- stall). Instead key on opcode1 = the andi word 0x30A20001 (HELD during the
            -- stall), armed once the helper entry 0xBFC20280 is fetched (so we don't catch an
            -- earlier andi v0,a1,1). value1 then = a1. ODD (0x80010001) => a1 stale-by-one at
            -- the sh = operand-forward bug; EVEN (0x80010000) => branch/andi mis-execution.
            -- (dbg_instr_word is captured at the exception latch instead — single driver.)

            if (stall = 0) then

               if (exception(4 downto 1) > 0) then
               
                  if (exception(4) = '1') then decodeException <= '1'; end if;
                  
                  decodeImmData    <= (others => '0');
                  decodeSource1    <= (others => '0');
                  decodeSource2    <= (others => '0');
                  decodeValue1     <= (others => '0');
                  decodeValue2     <= (others => '0');
                  decodeOP         <= (others => '0');
                  decodeFunct      <= (others => '0');
                  decodeShamt      <= (others => '0');
                  decodeRD         <= (others => '0');
                  decodeTarget     <= (others => '0');
                  decodeJumpTarget <= (others => '0');
               
               else
               
                  decodeException <= '0';
                  if (exception(0) = '1') then decodeException <= '1'; end if;
   
                  pcOld1  <= pcOld0;
                  opcode1 <= opcodeCacheMuxed;

                  decodeValue1     <= unsigned(regs1_q_b_wt);   -- regfile read-during-write bypass
                  decodeValue2     <= unsigned(regs2_q_b_wt);
   
                  decodeImmData    <= decImmData;   
                  decodeJumpTarget <= decJumpTarget;
                  decodeSource1    <= decSource1;
                  decodeSource2    <= decSource2;
                  decodeOP         <= decOP;
                  decodeFunct      <= decFunct;     
                  decodeShamt      <= decShamt;     
                  decodeRD         <= decRD;        
                  decodeTarget     <= decTarget;    
                                     
                  if (opcodeCacheMuxed(31 downto 26) = 16#12#) then
                     decode_gte_readAddr <= opcodeCacheMuxed(22) & opcodeCacheMuxed(15 downto 11); -- decodeSource1(1) & decodeRD 
                  else
                     decode_gte_readAddr <= '0' & opcodeCacheMuxed(20 downto 16); -- decodeSource2
                  end if;
                  
                  decodeReqSource1 <= decReqSource1;
                  decodeReqSource2 <= decReqSource2;
                  
               end if;
      
            end if;
            
            if (mem4_pending = '1') then
               if ((decReqSource1    = '1' and decSource1    = lateReadTarget) or (decodeReqSource1 = '1' and decodeSource1 = lateReadTarget) or
                   (decReqSource2    = '1' and decSource2    = lateReadTarget) or (decodeReqSource2 = '1' and decodeSource2 = lateReadTarget)) then
                  stall2          <= '1'; 
                  -- for some reason the original cpu stalls 1 cycle longer than needed if the value is required by next op...need to compensate
                  if (stall2 = '0') then
                     decodeLateStall <= not stall4;
                  end if;
               end if;
            elsif (TURBO = '1' or stall4 = '0' or decodeLateStall = '0') then
               stall2 <= '0';
            end if;
            
         end if;
      end if;
   end process;
   
   
--##############################################################
--############################### stage 3
--##############################################################

   process (decodeValue1, decodeValue2, decodeSource1, decodeSource2, resultTarget, writebackTarget, writeDoneTarget, resultWriteEnable, writebackWriteEnable, writeDoneWriteEnable,
            resultData, writebackData, writeDoneData, blockLoadforward, execute_lastreadCOP, lateReadBypass, lateReadTarget, lateReadData,
            regs3_q_b_wt, regs4_q_b_wt, regs3_rdaddr_q, regs4_rdaddr_q, regs_wt_wren, regs_wt_addr, regs_wt_data, regFF1, regFF2)
   begin

      -- DEFAULT operand: the FF shadow regfile (regFF1) = the reliable COMMITTED value of this
      -- instruction's source register. Replaces the unreliable MLAB read (decodeValue1 / the held
      -- live re-read regs3_q_b_wt), which returned 0 for a correctly-committed register. The staged
      -- forwards below still override for in-flight producers (EX/MEM/WB not yet in the FF shadow).
      value1 <= regFF1;
      -- SYSTEM11 SAFETY NET (2026-06-25): forward the ACTUAL regfile write (regs_wt_*, the committed
      -- writeback) when it targets this operand source. Closes the read-during-write / stalled-consumer
      -- gap where decodeValue1 was latched stale and the producer has aged past the staged forward
      -- window below. Lower priority than the staged forwards (which are newer), higher than the default.
      if (regs_wt_wren = '1' and decodeSource1 > 0 and unsigned(regs_wt_addr) = decodeSource1) then value1 <= unsigned(regs_wt_data); end if;
      if    (decodeSource1 > 0 and resultTarget    = decodeSource1 and resultWriteEnable    = '1' and execute_lastreadCOP = '0') then value1 <= resultData;
      elsif (decodeSource1 = lateReadTarget and lateReadBypass = '1' and blockLoadforward = '0' )                                then value1 <= lateReadData;
      elsif (decodeSource1 > 0 and writebackTarget = decodeSource1 and writebackWriteEnable = '1' and blockLoadforward = '0')    then value1 <= writebackData;
      elsif (decodeSource1 > 0 and writeDoneTarget = decodeSource1 and writeDoneWriteEnable = '1')                               then value1 <= writeDoneData;
      end if;

      value2 <= regFF2;
      if (regs_wt_wren = '1' and decodeSource2 > 0 and unsigned(regs_wt_addr) = decodeSource2) then value2 <= unsigned(regs_wt_data); end if;
      if    (decodeSource2 > 0 and resultTarget    = decodeSource2 and resultWriteEnable    = '1' and execute_lastreadCOP = '0') then value2 <= resultData;
      elsif (decodeSource2 = lateReadTarget and lateReadBypass = '1' and blockLoadforward = '0' )                                then value2 <= lateReadData;
      elsif (decodeSource2 > 0 and writebackTarget = decodeSource2 and writebackWriteEnable = '1' and blockLoadforward = '0'   ) then value2 <= writebackData;
      elsif (decodeSource2 > 0 and writeDoneTarget = decodeSource2 and writeDoneWriteEnable = '1')                               then value2 <= writeDoneData;
      end if;
      
   end process;
   
   EXEBreakpoint <= '1' when ((cop0_DCIC(31 downto 29) = "111" and cop0_DCIC(24 downto 23) = "11") and (((pcOld1 xor cop0_BPC) and cop0_BPCM) = x"00000000")) else '0';

   process (decodeImmData, decodeTarget, decodeJumpTarget, decodeSource1, decodeSource2, decodeValue1, decodeValue2, decodeOP, decodeFunct, decodeShamt, decodeRD, exception, stall3, stall, value1, value2, pcOld0, resultData, executeStalltype,
            cop0_BPC, cop0_BDA, cop0_JUMPDEST, cop0_DCIC, cop0_BADVADDR, cop0_BDAM, cop0_BPCM, cop0_SR, cop0_CAUSE, cop0_EPC, cop0_PRID, PC, hi, lo, hiloWait, 
            opcode1, gte_readAddr, decode_gte_readAddr, gte_readData, gte_busy, execute_gte_cmdEna, ce, execute_gte_readAddr, EXEBreakpoint)
      variable calcResult   : unsigned(31 downto 0);
      variable calcMemAddr  : unsigned(31 downto 0);
      variable executeShamt : unsigned(4 downto 0) := (others => '0');
      variable shiftValue   : signed(32 downto 0) := (others => '0');
   begin
   
      branch                  <= '0';
      exceptionNew3           <= '0';
      stallNew3               <= stall3;
      EXEresultData           <= resultData;
      PCbranch                <= pcOld0;
      EXEresultTarget         <= decodeTarget;
      EXEresultWriteEnable    <= '0';          
            
      calcMemAddr             := value1 + unsigned(resize(signed(decodeImmData), 32));
      EXEMemAddr              <= calcMemAddr;
      
      EXEMemWriteEnable       <= '0';
      EXEMemWriteData         <= value2;
      EXEMemWriteMask         <= "1111";
      EXEMemWriteException    <= '0';
      
      EXELoadType             <= LOADTYPE_DWORD;
      EXEReadEnable           <= '0';
      EXEReadException        <= '0';
      EXEGTeReadEnable        <= '0';
      
      EXECOP0WriteEnable      <= '0';
      EXECOP0WriteDestination <= decodeRD;
      EXECOP0WriteValue       <= value2;
      
      EXEBranchdelaySlot      <= '0';
      EXEBranchTaken          <= '0';
      
      EXEcalcMULT             <= '0';
      EXEcalcMULTU            <= '0';
      EXEcalcDIV              <= '0';
      EXEcalcDIVU             <= '0';
      
      EXEhiUpdate             <= '0';
      EXEloUpdate             <= '0';
      
      EXElastreadCOP          <= '0';
      
      EXEgte_cmdEna           <= '0';
      EXEgte_cmdData          <= opcode1;
      
      EXEgte_writeAddr        <= gte_readAddr;
      EXEgte_writeData        <= value2;
      EXEgte_writeEna         <= '0';
      
      exceptionCode_3         <= x"0";
      
      EXEstalltype            <= EXESTALLTYPE_NONE;
      
      gte_readAddr            <= decode_gte_readAddr;
      gte_readEna             <= '0';
      
      if (executeStalltype = EXESTALLTYPE_GTE and gte_busy = '0' and gte_cmdEna = '0' and ce = '1') then
         gte_readEna         <= '1';
         gte_readAddr        <= execute_gte_readAddr;
      end if;
      
      -- multiplex immidiate and register based shift amount, so both types can use the same shifters
      executeShamt := decodeShamt;
      if (decodeFunct(2) = '1') then
         executeShamt := value1(4 downto 0);
      end if;
      -- multiplex high bit of rightshift so arithmetic shift can be reused for logical shift
      shiftValue := '0' & signed(value2);
      if (decodeFunct(0) = '1') then
         shiftValue(32) := value2(31); 
      end if;
      
      if (EXEBreakpoint = '1') then

         exceptionNew3   <= '1';
         exceptionCode_3 <= x"9";

      elsif (exception(4 downto 2) = 0 and stall = 0) then
             
         case (to_integer(decodeOP)) is
         
            when 16#00# =>
               case (to_integer(decodeFunct)) is
         
                  when 16#00# | 16#04# => -- SLL | SLLV
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value2 sll to_integer(executeShamt);

                  when 16#02# | 16#03# | 16#06# | 16#07# => -- SRL | SRA | SRLV | SRAV
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= resize(unsigned(shift_right(shiftValue,to_integer(executeShamt))), 32);                        
                    
                  when 16#08# => -- JR 
                     EXEBranchdelaySlot <= '1';
                     EXEBranchTaken     <= '1';               
                     PCbranch           <= value1;
                     if (value1(1 downto 0) > 0) then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"4";
                     else
                        branch <= '1';
                     end if;
                    
                  when 16#09# => -- JALR
                     EXEBranchdelaySlot   <= '1';
                     EXEBranchTaken       <= '1';               
                     PCbranch             <= value1;
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= PC;
                     EXEresultTarget      <= decodeRD;
                     if (value1(1 downto 0) > 0) then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"4";
                     else
                        branch <= '1';
                     end if;

                  when 16#0C# => -- SYSCALL
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"8";
                     
                  when 16#0D# => -- BREAK
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"9";

                  when 16#10# => -- MFHI
                     EXEresultWriteEnable <= '1';
                     if (hiloWait > 1) then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_READHI;
                     else
                        EXEresultData <= hi;
                     end if;
                     
                  when 16#11# => -- MTHI
                     EXEhiUpdate <= '1';
                     
                  when 16#12# => -- MFLO
                     EXEresultWriteEnable <= '1';
                     if (hiloWait > 1) then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_READLO;
                     else
                        EXEresultData <= lo;
                     end if;
                     
                  when 16#13# => -- MTLO
                     EXEloUpdate <= '1';

                  when 16#18# => -- MULT
                     EXEcalcMULT <= '1';
                     
                  when 16#19# => -- MULTU
                     EXEcalcMULTU <= '1';
                     
                  when 16#1A# => -- DIV
                     EXEcalcDIV <= '1';
                     
                  when 16#1B# => -- DIVU
                     EXEcalcDIVU <= '1';
                  
                  when 16#20# => -- ADD
                     calcResult    := value1 + value2; 
                     EXEresultData <= calcResult;               
                     if (((calcResult(31) xor value1(31)) and (calcResult(31) xor value2(31))) = '1') then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"C";
                     else
                        EXEresultWriteEnable <= '1';
                     end if;

                  when 16#21# => -- ADDU
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 + value2;  
                    
                  when 16#22# => -- SUB
                     calcResult    := value1 - value2; 
                     EXEresultData <= calcResult;               
                     if (((calcResult(31) xor value1(31)) and (value1(31) xor value2(31))) = '1') then
                        exceptionNew3   <= '1';
                        exceptionCode_3 <= x"C";
                     else
                        EXEresultWriteEnable <= '1';
                     end if;

                  when 16#23# => -- SUBU
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 - value2;

                  when 16#24# => -- AND
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 and value2;
                    
                  when 16#25# => -- OR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 or value2;
                     
                  when 16#26# => -- XOR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 xor value2;
                     
                  when 16#27# => -- NOR
                     EXEresultWriteEnable <= '1';
                     EXEresultData        <= value1 nor value2;
                 
                  when 16#2A# => -- SLT
                     EXEresultWriteEnable <= '1';
                     if (signed(value1) < signed(value2)) then 
                        EXEresultData <= x"00000001";
                     else
                        EXEresultData <= x"00000000";
                     end if;  
                   
                  when 16#2B# => -- SLTI
                     EXEresultWriteEnable <= '1';
                     if (value1 < value2) then 
                        EXEresultData <= x"00000001";
                     else
                        EXEresultData <= x"00000000";
                     end if;   
                     
                  when others => 
                     exceptionNew3   <= '1';
                     exceptionCode_3 <= x"A";
                     
               end case;
               
            when 16#01# => -- B: BLTZ, BGEZ, BLTZAL, BGEZAL
               EXEBranchdelaySlot <= '1';
               if (decodeSource2(0) = '1') then
                  if (signed(value1) >= 0) then
                     EXEBranchTaken <= '1';               
                     branch         <= '1';
                  end if;
               else
                  if (signed(value1) < 0) then
                     EXEBranchTaken <= '1';               
                     branch         <= '1';
                  end if;
               end if;
               if (decodeSource2(4 downto 1) = "1000") then
                    EXEresultWriteEnable <= '1';
                    EXEresultData        <= PC;
                    EXEresultTarget      <= to_unsigned(31, 5);
               end if;
               PCbranch <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               
            when 16#02# => -- J
               EXEBranchdelaySlot <= '1';
               EXEBranchTaken     <= '1';               
               branch             <= '1';
               PCbranch           <= pcOld0(31 downto 28) & decodeJumpTarget & "00";
               
            when 16#03# => -- JAL
               EXEBranchdelaySlot   <= '1';
               EXEBranchTaken       <= '1';               
               branch               <= '1';
               EXEresultWriteEnable <= '1';
               EXEresultData        <= PC;
               EXEresultTarget      <= to_unsigned(31, 5);
               PCbranch             <= pcOld0(31 downto 28) & decodeJumpTarget & "00";
               
            when 16#04# => -- BEQ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (value1 = value2) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#05# => -- BNE
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (value1 /= value2) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#06# => -- BLEZ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (signed(value1) <= 0) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
               
            when 16#07# => -- BGTZ
               EXEBranchdelaySlot   <= '1';
               PCbranch             <= pcOld0 + unsigned((resize(signed(decodeImmData), 30) & "00"));
               if (signed(value1) > 0) then
                  EXEBranchTaken    <= '1';               
                  branch            <= '1';
               end if;
            
            when 16#08# => -- ADDI
               calcResult    := value1 + unsigned(resize(signed(decodeImmData), 32)); 
               EXEresultData <= calcResult;               
               if (((calcResult(31) xor value1(31)) and (calcResult(31) xor decodeImmData(15))) = '1') then
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"C";
               else
                  EXEresultWriteEnable <= '1';
               end if;
            
            when 16#09# => -- ADDIU
               EXEresultData        <= value1 + unsigned(resize(signed(decodeImmData), 32));            
               EXEresultWriteEnable <= '1';
               
            when 16#0A# => -- SLTI
               EXEresultWriteEnable <= '1';
               if (signed(value1) < resize(signed(decodeImmData), 32)) then 
                  EXEresultData <= x"00000001";
               else
                  EXEresultData <= x"00000000";
               end if;
               
            when 16#0B# => -- SLTIU
               EXEresultWriteEnable <= '1';
               if (value1 < unsigned(resize(signed(decodeImmData), 32))) then 
                  EXEresultData <= x"00000001";
               else
                  EXEresultData <= x"00000000";
               end if;
               
            when 16#0C# => -- ANDI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= x"0000" & (value1(15 downto 0) and decodeImmData);
               
            when 16#0D# => -- ORI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= value1(31 downto 16) & (value1(15 downto 0) or decodeImmData);
               
            when 16#0E# => -- XORI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= value1(31 downto 16) & (value1(15 downto 0) xor decodeImmData);
               
            when 16#0F# => -- LUI
               EXEresultWriteEnable <= '1';
               EXEresultData        <= decodeImmData & x"0000";
               
            when 16#10# => -- COP0
               if (cop0_SR(1) = '1' and cop0_SR(28) = '0') then
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  if (decodeSource1(4) = '1') then
                     case (to_integer(decodeImmData(6 downto 0))) is
                        when 1 | 2 | 4 | 8 =>
                           exceptionNew3   <= '1';
                           exceptionCode_3 <= x"A";

                        when 16 => -- Cop0Op - rfe
                           EXECOP0WriteEnable      <= '1';
                           EXECOP0WriteDestination <= to_unsigned(12, 5);
                           EXECOP0WriteValue       <= cop0_SR(31 downto 4) & cop0_SR(5 downto 2);

                        when others => report "should not happen" severity failure; 
                     end case;
                  else
                     case (to_integer(decodeSource1)) is
                     
                        when 0 => -- mfcn
                           EXEresultWriteEnable <= '1';
                           EXElastreadCOP       <= '1';
                           case (to_integer(decodeRD)) is
                              when 16#3# => EXEresultData <= cop0_BPC;
                              when 16#5# => EXEresultData <= cop0_BDA;
                              when 16#6# => EXEresultData <= cop0_JUMPDEST;
                              when 16#7# => EXEresultData <= cop0_DCIC;
                              when 16#8# => EXEresultData <= cop0_BADVADDR;
                              when 16#9# => EXEresultData <= cop0_BDAM;
                              when 16#B# => EXEresultData <= cop0_BPCM;
                              when 16#C# => EXEresultData <= cop0_SR;
                              when 16#D# => EXEresultData <= cop0_CAUSE;
                              when 16#E# => EXEresultData <= cop0_EPC;
                              when 16#F# => EXEresultData <= cop0_PRID;
                              when others => EXEresultData <= (others => '0');
                           end case;

                        when 4 => -- mtcn
                           exeCOP0WriteEnable      <= '1';
                           exeCOP0WriteDestination <= decodeRD;
                           exeCOP0WriteValue       <= value2;
                         
                        when others => report "should not happen" severity failure; 
                     end case;
                  end if;
               end if;
               
            when 16#11# => -- COP1 -> NOP 
               null; 
               
            when 16#12# => -- COP2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  if (decodeSource1(4) = '1') then
                     EXEgte_cmdEna <= '1';
                     if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                        stallNew3    <= '1';
                        EXEstalltype <= EXESTALLTYPE_GTECMD;
                     end if;
                  else
                     case (decodeSource1(3 downto 0)) is
                        when x"0" => --mfcn
                           EXEresultWriteEnable <= '1';
                           EXEresultData        <= gte_readData;
                           EXElastreadCOP       <= '1';
                           if (gte_busy = '1' or gte_cmdEna = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then --gte_cmdEna not needed as will be busy on new request anyway?
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTE;
                           else
                              gte_readEna          <= ce;
                           end if;
                        
                        when x"2" => --cfcn
                           EXEresultWriteEnable <= '1';
                           EXEresultData        <= gte_readData;
                           EXElastreadCOP       <= '1';
                           if (gte_busy = '1' or gte_cmdEna = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then --gte_cmdEna not needed as will be busy on new request anyway?
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTE;
                           else
                              gte_readEna          <= ce;
                           end if;
                        
                        when x"4" => --mtcn
                           EXEgte_writeEna      <= '1';
                           if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTECMD;
                           end if;
                        
                        when x"6" => --cfcn
                           EXEgte_writeEna      <= '1';
                           if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                              stallNew3    <= '1';
                              EXEstalltype <= EXESTALLTYPE_GTECMD;
                           end if;
                        
                        when others => null;
                     end case;
                  end if;
               end if;
               
            when 16#13# => -- COP3 -> NOP 
               null; 

            when 16#20# => -- LB
               EXELoadType   <= LOADTYPE_SBYTE;
               EXEReadEnable <= '1';
               
             when 16#21# => -- LH
               EXELoadType <= LOADTYPE_SWORD;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if;  

            when 16#22# => -- LWL
               EXELoadType   <= LOADTYPE_LEFT;
               EXEReadEnable <= '1';
               EXEresultData <= value2;
               
            when 16#23# => -- LW
               EXELoadType <= LOADTYPE_DWORD;
               if (calcMemAddr(1 downto 0) /= "00") then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if;  

            when 16#24# => -- LBU
               EXELoadType <= LOADTYPE_BYTE;
               EXEReadEnable <= '1';

            when 16#25# => -- LHU
               EXELoadType <= LOADTYPE_WORD;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3    <= '1';
                  exceptionCode_3  <= x"4";
                  EXEReadException <= '1';
               else
                  EXEReadEnable <= '1';
               end if; 
               
            when 16#26# => -- LWR
               EXELoadType   <= LOADTYPE_RIGHT;
               EXEReadEnable <= '1';
               EXEresultData <= value2;    

            when 16#28# => -- SB
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "0001"; EXEMemWriteData <= value2; 
                  when 1 => EXEMemWriteMask <= "0010"; EXEMemWriteData <= value2(23 downto 0) & x"00";   
                  when 2 => EXEMemWriteMask <= "0100"; EXEMemWriteData <= value2(15 downto 0) & x"0000";   
                  when 3 => EXEMemWriteMask <= "1000"; EXEMemWriteData <= value2(7 downto 0) & x"000000";   
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';

            when 16#29# => -- SH
               if (calcMemAddr(1) = '1') then
                  EXEMemWriteData <= value2(15 downto 0) & x"0000";
                  EXEMemWriteMask <= "1100";
               else
                  EXEMemWriteData <= value2;
                  EXEMemWriteMask <= "0011";
               end if;
               if (calcMemAddr(0) = '1') then
                  exceptionNew3        <= '1';
                  exceptionCode_3      <= x"5";
                  EXEMemWriteException <= '1';
               else
                  EXEMemWriteEnable <= '1';
               end if;
               
            when 16#2A# => -- SWL
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "0001"; EXEMemWriteData <= x"000000" & value2(31 downto 24);
                  when 1 => EXEMemWriteMask <= "0011"; EXEMemWriteData <= x"0000" & value2(31 downto 16);
                  when 2 => EXEMemWriteMask <= "0111"; EXEMemWriteData <= x"00" & value2(31 downto 8);
                  when 3 => EXEMemWriteMask <= "1111"; EXEMemWriteData <= value2;
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';   

            when 16#2B# => -- SW
               if (calcMemAddr(1 downto 0) /= "00") then
                  exceptionNew3        <= '1';
                  exceptionCode_3      <= x"5";
                  EXEMemWriteException <= '1';
               else
                  EXEMemWriteEnable <= '1';
               end if;
               
            when 16#2E# => -- SWR
               case (to_integer(calcMemAddr(1 downto 0))) is 
                  when 0 => EXEMemWriteMask <= "1111"; EXEMemWriteData <= value2;
                  when 1 => EXEMemWriteMask <= "1110"; EXEMemWriteData <= value2(23 downto 0) & x"00";
                  when 2 => EXEMemWriteMask <= "1100"; EXEMemWriteData <= value2(15 downto 0) & x"0000";
                  when 3 => EXEMemWriteMask <= "1000"; EXEMemWriteData <= value2( 7 downto 0) & x"000000";
                  when others => null;
               end case;
               EXEMemWriteEnable <= '1';    
            
            when 16#30# => -- LWC0 -> NOP 
               null;            

            when 16#31# => -- LWC1 -> NOP 
               null;    

            when 16#32# => -- LWC2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  EXEGTeReadEnable <= '1';
                  EXELoadType      <= LOADTYPE_DWORD;
                  EXEReadEnable    <= '1';
                  if (gte_busy = '1' or execute_gte_cmdEna = '1') then
                     stallNew3    <= '1';
                     EXEstalltype <= EXESTALLTYPE_GTECMD;
                  end if;
               end if;                        
               
            when 16#33# => -- LWC3 -> NOP 
               null;    
               
            when 16#38# => -- SWC0 -> NOP 
               null;    
               
            when 16#39# => -- SWC1 -> NOP 
               null; 
               
            when 16#3A# => -- SWC2
               if (cop0_SR(30) = '0') then -- COP2 disabled
                  exceptionNew3   <= '1';
                  exceptionCode_3 <= x"B";
               else
                  EXEMemWriteEnable <= '1';
                  EXEMemWriteData   <= gte_readData;
                  if (gte_busy = '1' or execute_gte_cmdEna = '1' or gte_writeEna = '1') then
                     stallNew3    <= '1';
                     EXEstalltype <= EXESTALLTYPE_GTE;
                  else
                     gte_readEna  <= ce;
                  end if;
               end if; 
               
            when 16#3B# => -- SWC3 -> NOP 
               null; 
               
            when others => 
               exceptionNew3   <= '1';
               exceptionCode_3 <= x"A";
         
         end case;
             
      end if;
      
   end process;
   
   ss_out( 3)               <= std_logic_vector(cop0_BPC);                   
   ss_out( 4)               <= std_logic_vector(cop0_BDA);                   
   ss_out( 5)               <= std_logic_vector(cop0_JUMPDEST);              
   ss_out( 6)               <= std_logic_vector(cop0_DCIC);                  
   ss_out( 8)               <= std_logic_vector(cop0_BDAM);                  
   ss_out( 9)               <= std_logic_vector(cop0_BPCM);                  
   ss_out(10)               <= std_logic_vector(cop0_SR);                    
   ss_out(11)               <= std_logic_vector(cop0_CAUSE);                 
   ss_out(12)               <= std_logic_vector(cop0_EPC);                   
   ss_out(13)               <= std_logic_vector(cop0_PRID);  
   
   ss_out(16) <= std_logic_vector(opcode2);
   --ss_out(21) <= std_logic_vector(pcOld2);
   
   ss_out(24)(13)           <= blockLoadforward;           
    
   ss_out(41)(24)           <= executeException;          
   ss_out(41)(20)           <= resultWriteEnable;          
   ss_out(33)               <= std_logic_vector(resultData);                 
   ss_out(40)(4 downto 0)   <= std_logic_vector(resultTarget);               
   ss_out(41)(27)           <= executeBranchdelaySlot;     
   ss_out(41)(26)           <= executeBranchTaken;         
   ss_out(35)               <= std_logic_vector(executeMemWriteData);        
   ss_out(40)(19 downto 16) <= executeMemWriteMask;        
   ss_out(36)               <= std_logic_vector(executeMemWriteAddr);        
   ss_out(41)(23)           <= executeMemWriteEnable;      
   ss_out(41)(18 downto 16) <= std_logic_vector(to_unsigned(CPU_LOADTYPE'POS(executeLoadType), 3));       
   ss_out(34)               <= std_logic_vector(executeReadAddress);        
   ss_out(41)(21)           <= executeReadEnable;          
   ss_out(41)(25)           <= executeCOP0WriteEnable;     
   ss_out(40)(28 downto 24) <= std_logic_vector(executeCOP0WriteDestination);
   ss_out(37)               <= std_logic_vector(executeCOP0WriteValue);      
                
   ss_out(1)                <= std_logic_vector(hi);                         
   ss_out(2)                <= std_logic_vector(lo);                         

   ss_out(41)(22)           <= executeGTEReadEnable;       
   ss_out(40)(12 downto 8)  <= std_logic_vector(executeGTETarget);           

   ss_out(59)(5 downto 0)   <= std_logic_vector(execute_gte_writeAddr);      
   ss_out(57)               <= std_logic_vector(execute_gte_writeData);      
   ss_out(59)(8)            <= execute_gte_writeEna;       
                     
   ss_out(58)               <= std_logic_vector(execute_gte_cmdData);        
   ss_out(59)(9)            <= execute_gte_cmdEna;   
   
   ss_out(59)(10)           <= execute_lastreadCOP;         
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         if (reset = '1') then

            stall3                        <= '0';
            dbg_exc_seen                  <= '0';
            dbg_exc_epc                   <= (others => '0');
            dbg_exc_code                  <= (others => '0');
            dbg_fault_ra                  <= (others => '0');

            cop0_BPC                      <= unsigned(ss_in(3));
            cop0_BDA                      <= unsigned(ss_in(4));
            cop0_JUMPDEST                 <= unsigned(ss_in(5));
            cop0_DCIC                     <= unsigned(ss_in(6));
            cop0_BDAM                     <= unsigned(ss_in(8));
            cop0_BPCM                     <= unsigned(ss_in(9));
            cop0_SR                       <= unsigned(ss_in(10));
            cop0_CAUSE                    <= unsigned(ss_in(11));
            cop0_EPC                      <= unsigned(ss_in(12));
            cop0_PRID                     <= unsigned(ss_in(13)); -- x"00000002";
                       
            --pcOld2                        <= unsigned(ss_in(21));
            opcode2                       <= unsigned(ss_in(16));
                        
            blockLoadforward              <= ss_in(24)(13);
                  
            executeException              <= ss_in(41)(24);
            resultWriteEnable             <= ss_in(41)(20);
            resultData                    <= unsigned(ss_in(33));
            resultTarget                  <= unsigned(ss_in(40)(4 downto 0));
            executeBranchdelaySlot        <= ss_in(41)(27);
            executeBranchTaken            <= ss_in(41)(26);
            executeMemWriteData           <= unsigned(ss_in(35));
            executeMemWriteMask           <= ss_in(40)(19 downto 16);
            executeMemWriteAddr           <= unsigned(ss_in(36));
            executeMemWriteEnable         <= ss_in(41)(23);
            executeLoadType               <= CPU_LOADTYPE'VAL(to_integer(unsigned(ss_in(41)(18 downto 16))));
            executeReadAddress            <= unsigned(ss_in(34));
            executeReadEnable             <= ss_in(41)(21);
            executeCOP0WriteEnable        <= ss_in(41)(25);
            executeCOP0WriteDestination   <= unsigned(ss_in(40)(28 downto 24));
            executeCOP0WriteValue         <= unsigned(ss_in(37));
            hiloWait                      <= 0;
            
            hi                            <= unsigned(ss_in(1));
            lo                            <= unsigned(ss_in(2));
            
            executeStalltype              <= EXESTALLTYPE_NONE;
            
            executeGTEReadEnable          <= ss_in(41)(22);
            executeGTETarget              <= unsigned(ss_in(40)(12 downto 8));
            
            execute_gte_writeAddr         <= unsigned(ss_in(59)(5 downto 0));
            execute_gte_writeData         <= unsigned(ss_in(57));
            execute_gte_writeEna          <= ss_in(59)(8);
                                   
            execute_gte_cmdData           <= unsigned(ss_in(58));
            execute_gte_cmdEna            <= ss_in(59)(9);
            
            execute_lastreadCOP           <= ss_in(59)(10);
            
         elsif (ce = '1') then
            
            -- mul/div calc/wait
            if (hiloWait > 0) then
               hiloWait <= hiloWait - 1;
               if (hiloWait = 1) then
                  case (executeStalltype) is
                     when EXESTALLTYPE_READHI => resultData <= hi; stall3 <= '0'; executeStalltype <= EXESTALLTYPE_NONE;
                     when EXESTALLTYPE_READLO => resultData <= lo; stall3 <= '0'; executeStalltype <= EXESTALLTYPE_NONE;
                     when others => null;
                  end case;
               end if;
            end if;
            
            mulResultS <= signed(mul1) * signed(mul2);
            mulResultU <= mul1 * mul2;
            
            if (hiloWait = 2) then
               case (hilocalc) is
                  when HILOCALC_MULT  => hi <=   unsigned(mulResultS(63 downto 32));  lo <=    unsigned(mulResultS(31 downto 0));
                  when HILOCALC_MULTU => hi <=            mulResultU(63 downto 32);   lo <=             mulResultU(31 downto 0);
                  when HILOCALC_DIV   => hi <=  unsigned(DIVremainder(31 downto  0)); lo <=   unsigned(DIVquotient(31 downto 0));
                  when HILOCALC_DIVU  => hi <=  unsigned(DIVremainder(31 downto  0)); lo <=   unsigned(DIVquotient(31 downto 0));
                  when HILOCALC_DIV0  => hi <=           DIV0remainder;               lo <=            DIV0quotient;
               end case;
            end if;
            
            -- GTE
            if (executeStalltype = EXESTALLTYPE_GTE and gte_readEna = '1') then
               resultData          <= gte_readData;
               executeMemWriteData <= gte_readData;
               stall3              <= '0';
               executeStalltype    <= EXESTALLTYPE_NONE;
            end if;
            
            if (executeStalltype = EXESTALLTYPE_GTECMD and gte_busy = '0') then
               stall3              <= '0';
               executeStalltype    <= EXESTALLTYPE_NONE;
            end if;
               
            if (stall = 0) then
            
               if (exception(4 downto 2) > 0) then
               
                  executeException              <= '1';
                                                
                  stall3                        <= '0';
                     
                  resultWriteEnable             <= '0';
                  executeReadEnable             <= '0';
                  executeMemWriteEnable         <= '0';
                  executeGTEReadEnable          <= '0';
                  executeCOP0WriteEnable        <= '0';
                  
                  executeStalltype              <= EXESTALLTYPE_NONE;
                        
               else     
               
-- synthesis translate_off
                  pcOld2                        <= pcOld1;
-- synthesis translate_on
                     
                  executeException              <= decodeException;
                  opcode2                       <= opcode1;
                        
                  stall3                        <= stallNew3;
                        
                  -- from calculation     
                  resultWriteEnable             <= EXEresultWriteEnable;
                        
                  resultData                    <= EXEresultData;    
                  resultTarget                  <= EXEresultTarget;
                        
                  executeBranchdelaySlot        <= EXEBranchdelaySlot;
                  executeBranchTaken            <= EXEBranchTaken;       
      
                  executeMemWriteData           <= EXEMemWriteData;             
                  executeMemWriteMask           <= EXEMemWriteMask;             
                  executeMemWriteAddr           <= EXEMemAddr(31 downto 2) & "00";             
                  executeMemWriteEnable         <= EXEMemWriteEnable;  

                  executeLoadType               <= EXELoadType;   
                  executeReadAddress            <= EXEMemAddr;
                  executeReadEnable             <= EXEReadEnable; 
                  
                  executeGTEReadEnable          <= EXEGTeReadEnable;
                  executeGTETarget              <= decodeSource2;

                  executeCOP0WriteEnable        <= EXECOP0WriteEnable;     
                  executeCOP0WriteDestination   <= EXECOP0WriteDestination;
                  executeCOP0WriteValue         <= EXECOP0WriteValue; 

                  executeStalltype              <= EXEstalltype; 

                  execute_gte_writeAddr         <= EXEgte_writeAddr;
                  execute_gte_writeData         <= EXEgte_writeData;
                  execute_gte_writeEna          <= EXEgte_writeEna;

                  execute_gte_cmdData           <= EXEgte_cmdData;
                  execute_gte_cmdEna            <= EXEgte_cmdEna;  

                  execute_gte_readAddr          <= decode_gte_readAddr;  
                  execute_lastreadCOP           <= EXElastreadCOP;              

                  if (EXECOP0WriteEnable = '1') then
                     case (to_integer(EXECOP0WriteDestination)) is
                        when 16#3# => cop0_BPC   <= EXECOP0WriteValue;
                        when 16#5# => cop0_BDA   <= EXECOP0WriteValue;
                        when 16#7# => cop0_DCIC  <= EXECOP0WriteValue and x"FF80F03F";
                        when 16#9# => cop0_BDAM  <= EXECOP0WriteValue;
                        when 16#B# => cop0_BPCM  <= EXECOP0WriteValue;
                        when 16#C# => cop0_SR    <= EXECOP0WriteValue and x"F27FFF3F";
                        when 16#D# => cop0_CAUSE <= EXECOP0WriteValue and x"00000300";
                        when others => null;
                     end case;
                  end if;
                  
                  if (executeException = '1') then
                     cop0_SR        <= exception_SR;
                     cop0_CAUSE     <= exception_CAUSE;
                     cop0_EPC       <= exception_EPC;
                     cop0_JUMPDEST  <= exception_JMP;
                     -- DIAGNOSTIC (2026-06-14): latch the FIRST GENUINE FAULT exception.
                     -- Boot legitimately takes interrupts (ExcCode 0) and syscalls (ExcCode 8),
                     -- so those are EXCLUDED. What we want is the fault that vectors to the BIOS
                     -- abort handler (AdEL/AdES=4/5, PC-OOB=6, DBE=7, RI=A). exception_CAUSE(5:2)=ExcCode.
                     if (dbg_exc_seen = '0' and exception_CAUSE(5 downto 2) /= x"0"
                                            and exception_CAUSE(5 downto 2) /= x"8") then
                        dbg_exc_seen <= '1';
                        dbg_exc_epc  <= exception_EPC;
                        dbg_exc_code <= exception_CAUSE(5 downto 2);
                        -- regs() read was synchronous/stale (returned 0). cop0_BADVADDR is the
                        -- architectural faulting address (the store/load target that raised AdES).
                        -- DECISIVE DIAG 2026-06-24: report the RAW delivered word (cap_raw) on the
                        -- cache-MISS FILL of 0x10170 (vs MAME 0xA420FB00). 0xA420FB00=delivery OK
                        -- (decode/icache bug); 0x48000000=delivery wrong; 0x0=always-hit stale icache.
                        -- dbg_fault_a1 is now driven CONCURRENTLY = boot-progress word (max RAM-PC +
                        -- exc); the dcap readout path is retired in favour of positive progress tracking.
                        dbg_fault_ra <= regs(31);   -- ra at the FIRST exception
                        -- dbg_instr_word repurposed to the LIVE committed PC (concurrent assign below) —
                        -- SDRAM is fixed so there's no fault to capture; we need to pin the cached render loop.
                     end if;
                  end if;
                  
                  cop0_CAUSE(10) <= irqRequest;

                  blockLoadforward <= '0';
                  if (executeReadEnable = '1' and EXEReadEnable = '1' and EXEGTeReadEnable = '0' and resultTarget = EXEresultTarget) then
                     blockLoadforward <= '1';
                  end if;                 
                  
                  -- new mul/div
                  if (EXEcalcMULT = '1') then
                     hilocalc <= HILOCALC_MULT;
                     mul1     <= value1;
                     mul2     <= value2;
                     if    (value1(31 downto 11) = 0 or value1(31 downto 11) = 16#1FFFFF#) then hiloWait <= 7;
                     elsif (value1(31 downto 20) = 0 or value1(31 downto 20) = 16#FFF#)    then hiloWait <= 10;
                     else  hiloWait <= 14;
                     end if;
                  end if;
                  
                  if (EXEcalcMULTU = '1') then
                     hilocalc <= HILOCALC_MULTU;
                     mul1     <= value1;
                     mul2     <= value2;
                     if    (value1(31 downto 11) = 0) then hiloWait <= 7;
                     elsif (value1(31 downto 20) = 0) then hiloWait <= 10;
                     else  hiloWait <= 14;
                     end if;
                  end if;
                  
                  if (EXEcalcDIV = '1') then
                     hiloWait    <= 37;
                     if (value2 = 0) then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0remainder <= value1;
                        if (signed(value1) >= 0) then
                           DIV0quotient <= (others => '1');
                        else
                           DIV0quotient <= x"00000001";
                        end if;
                     elsif (value1 = x"80000000" and value2 = x"FFFFFFFF") then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0quotient  <= x"80000000";
                        DIV0remainder <= (others => '0');
                     else
                        hilocalc    <= HILOCALC_DIV;
                        --DIVstart    <= '1';
                        --DIVdividend <= resize(signed(value1), 33);
                        --DIVdivisor  <= resize(signed(value2), 33);
                     end if;
                  end if;
                  
                  if (EXEcalcDIVU = '1') then
                     hiloWait    <= 37;
                     if (value2 = 0) then
                        hilocalc      <= HILOCALC_DIV0;
                        DIV0remainder <= value1;
                        DIV0quotient  <= (others => '1');
                     else
                        hilocalc    <= HILOCALC_DIVU;
                        --DIVstart    <= '1';
                        --DIVdividend <= '0' & signed(value1);
                        --DIVdivisor  <= '0' & signed(value2);
                     end if;
                  end if;
                  
                  if (EXEhiUpdate = '1') then hi <= value1; end if;
                  if (EXEloUpdate = '1') then lo <= value1; end if;
                  
               end if;
               
               
            end if;

         end if;
         
      end if;
   end process;
   
   DIVstart    <= '1' when (reset = '0' and ce = '1' and stall = 0 and exception(4 downto 2) = 0 and (EXEcalcDIV = '1' or EXEcalcDIVU = '1')) else '0';
   DIVdividend <= resize(signed(value1), 33) when (EXEcalcDIV = '1') else '0' & signed(value1);
   DIVdivisor  <= resize(signed(value2), 33) when (EXEcalcDIV = '1') else '0' & signed(value2);
   
   
--##############################################################
--############################### stage 4
--##############################################################
   
   
   -- scratchpad ###############################################
   scratchpad_address_a <= std_logic_vector(SS_Adr(7 downto 0)) when (SS_wren_SCP = '1' or SS_rden_SCP = '1') else std_logic_vector(executeMemWriteAddr(9 downto 2));
   scratchpad_data_a    <= SS_DataWrite                         when (SS_wren_SCP = '1') else std_logic_vector(executeMemWriteData);
   
   scratchpad_address_b <= std_logic_vector(executeReadAddress(9 downto 2));
   
   gscratchpad: for i in 0 to 3 generate
   begin
      icache: entity work.dpram
      generic map ( addr_width => 8, data_width => 8)
      port map
      (
         clock_a     => clk1x,
         clken_a     => ce or SS_wren_SCP or SS_rden_SCP,
         address_a   => scratchpad_address_a,
         data_a      => scratchpad_data_a((8*i) + 7 downto (8*i)),
         wren_a      => scratchpad_wren_a(i),
         q_a         => scratchpad_q_a((8*i) + 7 downto (8*i)),
         
         clock_b     => clk2x,
         address_b   => scratchpad_address_b,
         data_b      => x"00",
         wren_b      => '0',
         q_b         => scratchpad_q_b((8*i) + 7 downto (8*i))
      );
   end generate; 
   
   scratchpad_dataread <= unsigned(scratchpad_q_b);
   
   
   -- datacache ###############################################
   dcache_write_enable <= '1' when (ram_done = '1' and ram_rnw = '1' and mem4_pending = '1' and writebackReadAddress(28 downto 0) < 16#800000#) else 
                          '1' when (mem4_request = '1' and mem4_rnw = '0') else 
                          '1' when (dma_cache_write = '1') else
                          '0';
                          
   dcache_write_clear  <=  '1' when (mem4_request = '1' and mem4_rnw = '0' and executeMemWriteMask /= "1111") else '0';
                          
   -- bit 21 (= dcache addr bit 19) carries the 4MB upper/lower half. 2026-06-28: dma_cache_Adr is now
   -- 22-bit and carries D_MADR[21], so DMA writes ABOVE 2MB (e.g. the GPU ordering tables / scene data
   -- at 0x2xxxxx) invalidate the CORRECT dcache half. The old code padded bit 21 to 0 ("DMA targets the
   -- low 2MB") which is a PSX-2MB assumption — false for System 11's 4MB RAM -> CPU read stale OT -> ring.
   dcache_write_addr   <= dma_cache_Adr(21 downto 2)                         when (dma_cache_write = '1') else
                          std_logic_vector(executeMemWriteAddr(21 downto 2)) when (mem4_request = '1' and mem4_rnw = '0') else
                          std_logic_vector(writebackReadAddress(21 downto 2));

   dcache_write_data   <= dma_cache_data  when (dma_cache_write = '1') else
                          ram_dataRead    when (ram_done = '1' and mem4_pending = '1') else
                          mem4_dataWrite;

   dcache_read_enable  <= ce when (stall = 0 and executeReadEnable = '1' and executeReadAddress(28 downto 0) < 16#800000#) else '0';

   dcache_read_addr    <= std_logic_vector(executeReadAddress(21 downto 2));

   idatacache : entity work.datacache
   generic map
   (
      SIZE              => 16384,
      SIZEBASEBITS      => 20,  -- 4MB tag (addr[21:2]) for ZN-1/System11; was 19 (2MB) -> upper-2MB alias bug
      BITWIDTH          => 32
   )
   port map
   (
      clk1x             => clk1x,
      clk2x             => clk2x,
      reset             => reset,
      halfrate          => TURBO_CACHE50,
                        
      read_enable       => dcache_read_enable,  -- only used for calculating cache hit ratio
      read_addr         => dcache_read_addr,   
      read_hit          => dcache_read_hit,   
      read_data         => dcache_read_data,   

      write_enable      => dcache_write_enable,
      write_clear       => dcache_write_clear,
      write_addr        => dcache_write_addr,  
      write_data        => dcache_write_data 
   );
   
   -- stage 4 processes ########################################
   
   spad_cache_dataread <= scratchpad_dataread when ((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) else
                          unsigned(dcache_read_data);
   
   process (stall, exception, executeMemWriteEnable, executeMemWriteAddr, executeMemWriteData, cop0_SR, CACHECONTROL, stall4, executeReadEnable, executeReadAddress, executeLoadType, executeMemWriteMask, 
            SS_wren_SCP, SS_rden_SCP, mem_fifofull, executeCOP0WriteEnable, executeCOP0WriteDestination, executeCOP0WriteValue, dcache_read_hit, TURBO_CACHE, writebackGTEReadEnable,
            mem_done, memoryMuxStage4, mem4_pending, lateReadReqDone, exceptionNew, EXEReadEnable, EXEMemWriteEnable)
      variable skipmem : std_logic;
   begin
   
      mem4_request   <= '0';
      stallNew4      <= stall4;
      
      WBCACHECONTROL <= CACHECONTROL;
      
      mem4_address   <= executeMemWriteAddr;
      mem4_rnw       <= '1';
      mem4_dataWrite <= std_logic_vector(executeMemWriteData);
      mem4_reqsize   <= "10";
      
      WBinvalidateCacheEna  <= '0';
      WBinvalidateCacheLine <= executeMemWriteAddr(11 downto 4);
      
      scratchpad_wren_a    <= "0000";
      
      -- ############
      -- stall handling for data load pipeline
      -- ############
      if (mem4_pending = '1') then
         -- unstalling possible after read request has been sent, but only if next command is no read/write and data is not going to GTE
         if (lateReadReqDone = '1' and executeReadEnable = '0' and writebackGTEReadEnable = '0' and executeMemWriteEnable = '0') then 
            stallNew4 <= '0';
         end if;
         
         -- stall when exception happens next
         if (exceptionNew /= 0) then
            stallNew4 <= '1';
         end if;
         
         -- stall when next action would be a read/write request
         if (EXEReadEnable = '1' or EXEMemWriteEnable = '1') then
            stallNew4 <= '1';
         end if;
         
         -- stall when GTE would be accessed ?
         --if (EXEgte_writeEna = '1' or EXEgte_cmdEna = '1') then
         --   stallNew4 <= '1';
         --end if;
         
         -- must stall for 1 cycle when data is received to have a spot in register write
         if (mem_done = '1' and memoryMuxStage4 = '1' and writebackGTEReadEnable = '0') then 
            stallNew4   <= '1';
         end if;
      end if;
      
      -- ############
      -- Load/Store
      -- ############
      
      if (exception(4 downto 3) = 0 and stall = 0) then
      
         if (executeMemWriteEnable = '1') then
            skipmem := '0';
         
            case (to_integer(unsigned(executeMemWriteAddr(31 downto 29)))) is
            
               when 0 | 4 => -- cached
                  if (cop0_SR(16) = '1') then -- cache isolation
                     skipmem               := '1';
                     WBinvalidateCacheEna  <= '1';
                  end if;
                  
                  if (executeMemWriteAddr(28 downto 10) = 16#7E000#) then -- scratchpad
                     skipmem := '1';
                     scratchpad_wren_a <= executeMemWriteMask;
                  end if;
                  
               when 6 | 7 => -- KSEG2
                  skipmem := '1';
                  if (executeMemWriteAddr = x"FFFE0130") then
                     WBCACHECONTROL <= executeMemWriteData;
                  end if;
               
               when others => null;
               
            end case;
            
            if (skipmem = '0') then
               mem4_request   <= '1';
               mem4_address   <= executeMemWriteAddr;
               mem4_rnw       <= '0';
               mem4_dataWrite <= std_logic_vector(executeMemWriteData);
               stallNew4      <= mem_fifofull;
            end if;
         
         end if;
         
         if (executeReadEnable = '1') then

            case (executeLoadType) is
               when LOADTYPE_SBYTE => mem4_reqsize <= "00";
               when LOADTYPE_SWORD => mem4_reqsize <= "01";
               when LOADTYPE_LEFT  => mem4_reqsize <= "10"; 
               when LOADTYPE_DWORD => mem4_reqsize <= "10";
               when LOADTYPE_BYTE  => mem4_reqsize <= "00"; 
               when LOADTYPE_WORD  => mem4_reqsize <= "01"; 
               when LOADTYPE_RIGHT => mem4_reqsize <= "10";
            end case;

            if ((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) then
               --report "scratchpad access" severity failure;
            elsif (TURBO_CACHE = '1' and executeReadAddress(28 downto 0) < 16#800000# and dcache_read_hit = '1') then
               -- cache hit
            elsif (executeReadAddress = x"FFFE0130") then
               -- cachecontrol
            else 
               mem4_request   <= '1';
               mem4_address   <= executeReadAddress;
               if (executeLoadType = LOADTYPE_LEFT or executeLoadType = LOADTYPE_RIGHT) then 
                  mem4_address(1 downto 0) <= "00";
               end if;
               mem4_rnw       <= '1';
               stallNew4      <= '1';
            end if;
         
         end if;
         
      end if;
      
      -- savestate scratchpad handling
      if (SS_wren_SCP = '1') then
         scratchpad_wren_a     <= "1111";
      end if;
      
      if (SS_rden_SCP = '1') then
         scratchpad_wren_a <= "0000";
      end if;
      
   end process;
   
   --ss_out(22)               <= std_logic_vector(pcOld3);                     
   --ss_out(17)               <= std_logic_vector(opcode3);                                     
                                                 
   ss_out(56)               <= std_logic_vector(CACHECONTROL);               
                                             
   ss_out(47)(4 downto 0)   <= std_logic_vector(writebackTarget);            
   ss_out(42)               <= std_logic_vector(writebackData);              
   ss_out(47)(24)           <= writebackWriteEnable;       

   ss_out(47)(26)           <= writebackException;         
                    
   ss_out(47)(30)           <= writebackGTEReadEnable;     
   ss_out(48)(5 downto 0)   <= std_logic_vector(WBgte_writeAddr);          
   
   process (clk1x)
      variable dataReadData : unsigned(31 downto 0);
      variable oldData      : unsigned(31 downto 0);
   begin
      if (rising_edge(clk1x)) then
      
         if (ce = '1') then
            gte_writeEna  <= '0';
            gte_cmdEna    <= '0';
         end if;
      
         if (reset = '1') then
         
            stall4                           <= '0';
                              
            --pcOld3                           <= unsigned(ss_in(22));
            --opcode3                          <= unsigned(ss_in(17));
                              
            CACHECONTROL                     <= unsigned(ss_in(56));
                        
            writebackTarget                  <= unsigned(ss_in(47)(4 downto 0));
            writebackData                    <= unsigned(ss_in(42));
            writebackWriteEnable             <= ss_in(47)(24);
         
            writebackInvalidateCacheEna      <= '0'; -- todo: only used in BIOS?
            
            writebackException               <= ss_in(47)(26);
            
            writebackGTEReadEnable           <= ss_in(47)(30);
            WBgte_writeAddr                  <= unsigned(ss_in(48)(5 downto 0));
            
            gte_writeEna                     <= '0';
            gte_cmdEna                       <= '0';
            
            lateReadWrite                    <= '0';
            lateReadBypass                   <= '0';
            lateReadReqDone                  <= '0';
            
         elsif (ce = '1') then
         
            stall4         <= stallNew4;
            dataReadData   := unsigned(mem_dataRead);
            oldData        := writebackData;
            
            writebackInvalidateCacheEna  <= WBinvalidateCacheEna; 
            writebackInvalidateCacheLine <= WBinvalidateCacheLine;   
            
            if (lateReadBypass = '1' and stall4 = '0') then
               lateReadRam <= '0';
            end if;
            
            lateReadReqDone <= '0';
            if (mem4_request = '1' and mem4_rnw = '1') then
               lateReadReqDone <= '1';

               -- need to compensate for timing in original design on back to back reads:
               -- this is due to unclear reason why the original design is slower here than it could be
               if (lateReadBypass = '1') then
                  -- one additional wait cycle if target of first read is to be used after second read
                  if ((decodeReqSource1 = '1' and decodeSource1 = lateReadTarget) or (decodeReqSource2 = '1' and decodeSource2 = lateReadTarget)) then
                     lateReadStall <= not TURBO;
                  end if;
                  -- one additional wait cycle if target of both reads is the same and goes to ram
                  if (resultTarget = lateReadTarget and executeReadAddress(28 downto 0) < 16#800000# and lateReadRam = '1') then
                     lateReadStall <= not TURBO;
                  end if;
               end if;
               if (executeReadAddress(28 downto 0) < 16#800000#) then
                  lateReadRam <= '1';
               end if;
            end if;
            
            if (resultWriteEnable = '1' and mem4_pending = '1' and resultTarget = lateReadTarget) then
               lateReadWriteAfterWrite <= '1';
            end if;
            
            
            if (stall = 0) then
            
               lateReadBypass <= '0';

               if (exception(4 downto 3) > 0) then
               
                  writebackException           <= '1'; 
                  
               else
-- synthesis translate_off
                  pcOld3                       <= pcOld2;
                  opcode3                      <= opcode2;
-- synthesis translate_on
               
                  writebackTarget              <= resultTarget;
                  writebackData                <= resultData;
                  
                  writebackException           <= executeException;
                           
                  CACHECONTROL                 <= WBCACHECONTROL;
                  
                  writebackGTEReadEnable       <= executeGTEReadEnable;
                  WBgte_writeAddr              <= '0' & executeGTETarget;
                  
                  oldData := resultData;
                  if (lateReadTarget = resultTarget and lateReadBypass = '1') then
                     oldData := lateReadData;
                  elsif (writebackTarget = resultTarget and writebackWriteEnable = '1') then
                     oldData := writebackData;
                  end if;
                  
                  writebackWriteEnable <= '0';
                  if (executeReadEnable = '1') then
                     if (((executeReadAddress(31 downto 29) = 0 or executeReadAddress(31 downto 29) = 4) and executeReadAddress(28 downto 10) = 16#7E000#) or -- scratchpad read
                        (TURBO_CACHE = '1' and executeReadAddress(28 downto 0) < 16#800000# and dcache_read_hit = '1')) then -- data cache read
                        if (executeGTEReadEnable = '1') then
                           gte_writeAddr <= '0' & executeGTETarget;
                           gte_writeData <= spad_cache_dataread;
                           gte_writeEna  <= '1';
                        else
                           writebackWriteEnable <= '1';

                           case (executeLoadType) is
                              when LOADTYPE_SBYTE => 
                                 case (executeReadAddress(1 downto 0)) is 
                                    when "00" => writebackData <= unsigned(resize(signed(spad_cache_dataread( 7 downto  0)), 32));
                                    when "01" => writebackData <= unsigned(resize(signed(spad_cache_dataread(15 downto  8)), 32));
                                    when "10" => writebackData <= unsigned(resize(signed(spad_cache_dataread(23 downto 16)), 32));
                                    when "11" => writebackData <= unsigned(resize(signed(spad_cache_dataread(31 downto 24)), 32));
                                    when others => null;
                                 end case;  
                                    
                              when LOADTYPE_SWORD => 
                                 if (executeReadAddress(1) = '0') then
                                    writebackData <= unsigned(resize(signed(spad_cache_dataread(15 downto 0)), 32));
                                 else
                                    writebackData <= unsigned(resize(signed(spad_cache_dataread(31 downto 16)), 32));
                                 end if;
                                    
                              when LOADTYPE_LEFT =>
                                 case (to_integer(executeReadAddress(1 downto 0))) is
                                    when 0 => writebackData <= spad_cache_dataread( 7 downto 0) & oldData(23 downto 0);
                                    when 1 => writebackData <= spad_cache_dataread(15 downto 0) & oldData(15 downto 0);
                                    when 2 => writebackData <= spad_cache_dataread(23 downto 0) & oldData( 7 downto 0); 
                                    when 3 => writebackData <= spad_cache_dataread;
                                    when others => null;
                                 end case;
                                    
                              when LOADTYPE_DWORD => writebackData <= spad_cache_dataread;
                              
                              when LOADTYPE_BYTE  =>
                                 case (executeReadAddress(1 downto 0)) is 
                                    when "00" => writebackData <= x"000000" & spad_cache_dataread( 7 downto  0);
                                    when "01" => writebackData <= x"000000" & spad_cache_dataread(15 downto  8);
                                    when "10" => writebackData <= x"000000" & spad_cache_dataread(23 downto 16);
                                    when "11" => writebackData <= x"000000" & spad_cache_dataread(31 downto 24);
                                    when others => null;
                                 end case;  
                              
                              when LOADTYPE_WORD  => 
                                 if (executeReadAddress(1) = '0') then
                                    writebackData <= x"0000" & spad_cache_dataread(15 downto 0);
                                 else
                                    writebackData <= x"0000" & spad_cache_dataread(31 downto 16);
                                 end if;
                              
                              when LOADTYPE_RIGHT =>
                                 case (to_integer(executeReadAddress(1 downto 0))) is
                                    when 0 => writebackData <= spad_cache_dataread;
                                    when 1 => writebackData <= oldData(31 downto 24) & spad_cache_dataread(31 downto  8);
                                    when 2 => writebackData <= oldData(31 downto 16) & spad_cache_dataread(31 downto 16);
                                    when 3 => writebackData <= oldData(31 downto  8) & spad_cache_dataread(31 downto 24);
                                    when others => null;
                                 end case;
                           end case;
                        end if;
                     elsif (executeReadAddress = x"FFFE0130") then
                        writebackWriteEnable <= '1';
                        writebackData        <= CACHECONTROL;
                     else
                        writebackLoadType       <= executeLoadType;
                        writebackReadAddress    <= executeReadAddress;
                        lateReadTarget          <= resultTarget;
                        lateReadOldData         <= oldData;
                        lateReadWriteAfterWrite <= '0';
                     end if;
                  else
                     writebackWriteEnable <= resultWriteEnable;
                  end if;
                  
                  if (execute_gte_writeEna = '1') then
                     gte_writeAddr <= execute_gte_writeAddr;
                     gte_writeData <= execute_gte_writeData;
                     gte_writeEna  <= '1';
                  end if;
                  
                  if (execute_gte_cmdEna = '1') then
                     gte_cmdData <= execute_gte_cmdData;
                     gte_cmdEna  <= '1';
                  end if;
                  
                  
               end if;
               
            else

               if (mem_fifofull = '0' and mem4_pending = '0') then
                  lateReadStall <= '0';
                  if (lateReadStall = '0') then
                     stall4 <= '0';
                  end if;
               end if;
               
               lateReadWrite <= '0';
               
               if (lateReadWrite = '1') then
                  lateReadBypass <= '1';
               end if;
               
            end if;
            
            if (mem_done = '1' and memoryMuxStage4 = '1') then
               if (writebackGTEReadEnable = '1') then
                  gte_writeAddr <= WBgte_writeAddr;
                  gte_writeData <= dataReadData;
                  gte_writeEna  <= '1';
               else
                  if (lateReadTarget > 0 and lateReadWriteAfterWrite = '0') then
                     if (resultWriteEnable = '0' or resultTarget /= lateReadTarget) then -- write after write in same cycle -> ignore
                        lateReadWrite <= '1';
                     else
                        lateReadRam   <= '0';
                     end if;
                  end if;

                  case (writebackLoadType) is
                     
                     when LOADTYPE_SBYTE => lateReadData <= unsigned(resize(signed(dataReadData(7 downto 0)), 32));
                     when LOADTYPE_SWORD => lateReadData <= unsigned(resize(signed(dataReadData(15 downto 0)), 32));
                     when LOADTYPE_LEFT =>
                        case (to_integer(writebackReadAddress(1 downto 0))) is
                           when 0 => lateReadData <= dataReadData( 7 downto 0) & lateReadOldData(23 downto 0);
                           when 1 => lateReadData <= dataReadData(15 downto 0) & lateReadOldData(15 downto 0);
                           when 2 => lateReadData <= dataReadData(23 downto 0) & lateReadOldData( 7 downto 0); 
                           when 3 => lateReadData <= dataReadData;
                           when others => null;
                        end case;
                           
                     when LOADTYPE_DWORD => lateReadData <= dataReadData;
                     when LOADTYPE_BYTE  => lateReadData <= x"000000" & dataReadData(7 downto 0);
                     when LOADTYPE_WORD  => lateReadData <= x"0000" & dataReadData(15 downto 0);
                     when LOADTYPE_RIGHT =>
                        case (to_integer(writebackReadAddress(1 downto 0))) is
                           when 0 => lateReadData <= dataReadData;
                           when 1 => lateReadData <= lateReadOldData(31 downto 24) & dataReadData(31 downto  8);
                           when 2 => lateReadData <= lateReadOldData(31 downto 16) & dataReadData(31 downto 16);
                           when 3 => lateReadData <= lateReadOldData(31 downto  8) & dataReadData(31 downto 24);
                           when others => null;
                        end case;
                        
                  end case;
               end if;   
            end if;
            
            
   
         end if;
         
         if (SS_wren_SCP = '1') then
            writebackInvalidateCacheEna  <= '1';
            writebackInvalidateCacheLine <= SS_Adr(7 downto 0);
         end if;
         
      end if;
   end process;
   
   --ss_out(23)              <= std_logic_vector(pcOld4);
   --ss_out(18)              <= std_logic_vector(opcode4);
   
   ss_out(50)(12 downto 8) <= std_logic_vector(writeDoneTarget);
   ss_out(49)              <= std_logic_vector(writeDoneData);
   ss_out(50)(16)          <= writeDoneWriteEnable;
   
--##############################################################
--############################### stage 5
--##############################################################
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
-- synthesis translate_off
         cpu_done <= '0';
         
         debugTmr <= debugTmr + 1;
-- synthesis translate_on
      
         if (reset = '1') then
            
            --pcOld4               <= unsigned(ss_in(23));
            --opcode4              <= unsigned(ss_in(18));
            
            writeDoneTarget      <= unsigned(ss_in(50)(12 downto 8));
            writeDoneData        <= unsigned(ss_in(49));
            writeDoneWriteEnable <= ss_in(50)(16);
            
-- synthesis translate_off
            debugCnt             <= (others => '0');
            debugSum             <= (others => '0');
            debugTmr             <= (others => '0');
-- synthesis translate_on
         
         elsif (ce = '1') then
            
            if (stall = 0) then
            
-- synthesis translate_off
               pcOld4               <= pcOld3;
               opcode4              <= opcode3;
-- synthesis translate_on
            
               writeDoneTarget      <= writebackTarget;     
               writeDoneData        <= writebackData;       
               writeDoneWriteEnable <= writebackWriteEnable;
               
               -- export
               if (writebackWriteEnable = '1' and writebackException = '0') then 
                  if (writebackTarget > 0) then
-- synthesis translate_off
                     regs(to_integer(writebackTarget)) <= writebackData;
                     debugSum <= debugSum + writebackData;
-- synthesis translate_on
                  end if;
               end if;
               
-- synthesis translate_off
               debugCnt          <= debugCnt+ 1;

               cpu_done          <= '1';
               cpu_export.pc     <= pcOld4;
               cpu_export.opcode <= opcode4;
               cpu_export.cause  <= cop0_CAUSE;
               for i in 0 to 31 loop
                  cpu_export.regs(i) <= regs(i);
               end loop;
               
               if (debugCnt(31) = '1' and debugSum(31) = '1' and debugTmr(31) = '1' and writebackTarget = 0) then
                  writeDoneWriteEnable <= '0';
               end if;
-- synthesis translate_on
               
            end if;
            
-- synthesis translate_off
            if (lateReadBypass = '1') then
               regs(to_integer(lateReadTarget)) <= lateReadData;
            end if;
-- synthesis translate_on
   
         end if;
         
         -- export
-- synthesis translate_off
         if (ss_regs_load = '1') then
            regs(to_integer(ss_regs_addr)) <= unsigned(ss_regs_data);
         end if; 
-- synthesis translate_on
         
      end if;
   end process;
   
--##############################################################
--############################### exception handling
--##############################################################

   ss_out(24)(9 downto 5)  <= std_logic_vector(exception);      

   ss_out(7)               <= std_logic_vector(cop0_BADVADDR);  

   ss_out(51)              <= std_logic_vector(exception_SR);   
   ss_out(52)              <= std_logic_vector(exception_CAUSE);
   ss_out(53)              <= std_logic_vector(exception_EPC);  
   ss_out(54)              <= std_logic_vector(exception_JMP);  

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (reset = '1') then
         
            exception            <= unsigned(ss_in(24)(9 downto 5));
         
            cop0_BADVADDR        <= unsigned(ss_in(7));
            
            exception_SR         <= unsigned(ss_in(51));
            exception_CAUSE      <= unsigned(ss_in(52));
            exception_EPC        <= unsigned(ss_in(53));
            exception_JMP        <= unsigned(ss_in(54));

         elsif (ce = '1') then
            
            if (stall = 0) then
         
               exception           <= exceptionNew;
               exceptionBreakpoint <= EXEBreakpoint;
               if (exceptionNew1 = '1') then    -- PC out of bounds
                  exceptionCode     <= x"6";
                  exceptionInstr    <= opcode2(27 downto 26);
                  exception_PC      <= PCnext;
                  exception_branch  <= executeBranchTaken;
                  exception_brslot  <= executeBranchdelaySlot;
               elsif (exceptionNew5 = '1') then -- interrupt
                  exceptionCode     <= x"0";
                  exceptionInstr    <= opcode1(27 downto 26);
                  exception_PC      <= pcOld1;
                  exception_branch  <= executeBranchTaken;
                  exception_brslot  <= executeBranchdelaySlot;
               else                             -- execute stage
                  exceptionCode     <= exceptionCode_3;
                  exceptionInstr    <= opcode1(27 downto 26);
                  if (EXEBranchTaken = '1') then
                     exception_PC      <= PCbranch;
                     exception_branch  <= '0';
                     exception_brslot  <= '0';
                     if (exceptionNew3 = '1') then
                        cop0_BADVADDR     <= PCbranch;
                     end if;
                  else
                     exception_PC      <= PCold1;
                     exception_branch  <= executeBranchTaken;
                     exception_brslot  <= executeBranchdelaySlot;
                     if (EXEMemWriteException = '1' or EXEReadException = '1') then
                        cop0_BADVADDR  <= EXEMemAddr;
                        -- DIAG 2026-07-04: latch the faulting store/load ADDRESS (the bad pointer that
                        -- raised AdEL/AdES) at the FIRST fault. EPC=0x8002E78C is SH $s3,0($v0); this
                        -- captures $v0 = the odd/corrupt pointer. Compare vs MAME's value at that slot.
                        if (dbg_exc_seen = '0') then
                           dbg_fault_addr <= EXEMemAddr;
                           -- DIAG 2026-07-04b: also latch the branch operands $s1(r17)/$s2(r18) and $sp(r29)
                           -- from the RELIABLE combinational FF regfile, to see WHY the FPGA reaches this SH
                           -- (wrong branch: (s2|s1)&FFFF!=0) and to compute the source addr 0x20000+r29+0x4C.
                           dbg_fault_s1s2 <= std_logic_vector(regsFF(17)(15 downto 0)) & std_logic_vector(regsFF(18)(15 downto 0));
                           dbg_fault_sp   <= std_logic_vector(regsFF(29));
                        end if;
                     end if;
                  end if;
               end if;
               exception_JMPnext <= PCold0;
               
               if (exception > 0) then
                  exception_SR    <= cop0_SR(31 downto 6) & cop0_SR(3 downto 0) & "00";
                  exception_CAUSE <= cop0_CAUSE;
                  exception_CAUSE(5 downto 2)   <= exceptionCode;
                  exception_CAUSE(29 downto 28) <= exceptionInstr; 
                  exception_CAUSE(30) <= exception_branch;
                  exception_CAUSE(31) <= exception_brslot;
                  if (exception_brslot = '1') then
                     exception_EPC <= exception_PC - 4;
                     exception_JMP <= exception_JMPnext;
                  else
                     exception_EPC <= exception_PC;
                  end if;
               end if;
               
            end if;
   
         end if;
      end if;
   end process;
   
--##############################################################
--############################### submodules
--##############################################################
   
   idivider : entity work.divider
   port map
   (
      clk       => clk1x,      
      start     => DIVstart,
      done      => open,      
      busy      => open,
      dividend  => DIVdividend, 
      divisor   => DIVdivisor,  
      quotient  => DIVquotient, 
      remainder => DIVremainder
   );
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         ss_regs_load <= '0';
      
         if (SS_reset = '1') then
         
            for i in 0 to 56 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(0)  <= x"BFC00000"; -- PC
            ss_in(13) <= x"00000002"; -- cop0_PRID
            
            ss_regs_loading <= '1';
            ss_regs_addr    <= (others => '0');
            ss_regs_data    <= (others => '0');
            
         elsif (SS_wren_CPU = '1' and SS_Adr < 96) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
            
         elsif (SS_wren_CPU = '1' and SS_Adr >= 96 and SS_Adr < 128) then
            ss_regs_load <= '1';
            ss_regs_addr <= resize(SS_Adr - 96, 5);
            ss_regs_data <= SS_DataWrite;
         end if;
         
         if (ss_regs_loading = '1') then
            ss_regs_load <= '1';
            ss_regs_addr <= ss_regs_addr + 1;
            if (ss_regs_addr = 31) then
               ss_regs_loading <= '0';
            end if;
         end if;
      
         -- also check this?
         -- cop0_SR(10 downto 8) and cop0_CAUSE(10 downto 8)) /= "000"
         SS_idle <= '0';
         if (hiloWait = 0 and blockIRQ = '0' and (irqRequest = '0' or cop0_SR(0) = '0') and mem_done = '0' and lateReadWrite = '0' and lateReadBypass = '0') then
            SS_idle <= '1';
         end if;
      
         regsSS_rden <= '0';
         if (SS_rden_CPU = '1' and SS_Adr >= 96 and SS_Adr < 128) then
            regsSS_address_b <= std_logic_vector(resize(SS_Adr - 96, 5));
            regsSS_rden      <= '1';
         end if;
         
         if (regsSS_rden = '1') then
            SS_DataRead_CPU <= regsSS_q_b;
         elsif (SS_rden_CPU = '1' and SS_Adr < 96) then
            SS_DataRead_CPU <= ss_out(to_integer(SS_Adr));
         end if;
      
         ss_scp_rden_1 <= SS_rden_SCP;
         if (ss_scp_rden_1 = '1') then
            SS_DataRead_SCP <= scratchpad_q_a;
         end if;
      
      end if;
   end process;
   
--##############################################################
--############################### debug
--##############################################################

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         error  <= '0';
         error2 <= '0';
      
         if (reset = '1') then
         
            debugStallcounter <= (others => '0');
            debug300exception <= '0';
            
-- synthesis translate_off
            stallcountNo      <= 0;
            stallcount1       <= 0;
            stallcount3       <= 0;
            stallcount4       <= 0;
            stallcountDMA     <= 0;
-- synthesis translate_on
      
         elsif (ce = '1') then
         
            if (stall = 0) then
               debugStallcounter <= (others => '0');
            elsif (cpuPaused = '0') then  
               debugStallcounter <= debugStallcounter + 1;
            end if;
            
            debug300exception <= '0';
            if (mem_request = '1' and mem_isData = '1' and mem_rnw = '1' and mem_addressData = x"00000300") then
               debug300exception <= '1';
            end if;
            
            if (debug300exception = '1') then
               error        <= '1';
            end if;            
            
            if (debugStallcounter(9) = '1') then
               error2       <= '1';
            end if;
            
-- synthesis translate_off
            
            if (stallcountNo = 0 and stallcount4 = 0 and stallcount3 = 0 and stallcount1 = 0 and stallcountDMA = 0) then
               stallcountNo <= 0;
            end if;
            
            -- performance counters
            if (stall = 0) then
               stallcountNo <= stallcountNo + 1;
            elsif (stall4 = '1') then
               stallcount4 <= stallcount4 + 1;
            elsif (stall3 = '1') then
               stallcount3 <= stallcount3 + 1;
            elsif (stall1 = '1') then
               stallcount1 <= stallcount1 + 1;
            end if;
            
         else
            
            stallcountDMA <= stallcountDMA + 1;
            
-- synthesis translate_on
            
         end if;
         
      end if;
   end process;
   
   

end architecture;





