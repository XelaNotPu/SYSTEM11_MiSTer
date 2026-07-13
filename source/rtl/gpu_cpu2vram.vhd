library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity gpu_cpu2vram is
   port 
   (
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      drawer_reset         : in  std_logic;
      
      DrawPixelsMask       : in  std_logic;
      SetMask              : in  std_logic;
      gpuType1             : in  std_logic := '0';  -- System 11 CXD8538Q: MAME image-load uses RAW W/H (no 0->1024/512 expand)
      errorMASK            : out std_logic;
      
      proc_idle            : in  std_logic;
      fifo_Valid           : in  std_logic;
      fifo_data            : in  std_logic_vector(31 downto 0);
      requestFifo          : out std_logic := '0';
      done                 : out std_logic := '0';
      CmdDone              : out std_logic := '0';
      
      pixelStall           : in  std_logic;
      pixelColor           : out std_logic_vector(15 downto 0);
      pixelAddr            : out unsigned(20 downto 0);
      pixelWrite           : out std_logic;
      -- build #21: parser-side dst-X bit 9 capture detect.
      -- Fires on the cycle when REQUESTWORD2 consumes a dst word whose X bit 9 is set
      -- (i.e., destination X >= 512). Independent of whether pixelWrite ever fires.
      dbg_parsed_dstX_hi   : out std_logic;
      -- build #45: classify the cpu2vram INPUT (FIFO source word) for the pixel being
      -- written THIS cycle, gated to the cube-CLUT dest (row=488, col<256). This is the
      -- value upstream of pixelColor; cpu2vram is a pure copy so input should == output.
      -- Splits read-path (DMA/RAM delivers red to FIFO) vs cpu2vram (corrupts green->red).
      dbg_cube_in_green    : out std_logic;  -- INPUT pure-green at cube gate
      dbg_cube_in_red      : out std_logic;  -- INPUT pure-red   at cube gate
      dbg_cube_in_any      : out std_logic;  -- INPUT any pixel  at cube gate (anchor)
      -- build #133: expose latched upper halfword (= pixel 2 source for cpu2vram emission).
      -- Used by gpu.vhd to compare against cpu2vram_pixelColor at cube CLUT lane-3 writes.
      dbg_fifo_data_1      : out std_logic_vector(15 downto 0);
      -- build #137: sticky-once-set probes of the upper-halfword R-bit latch chain.
      -- The 3 signals form a causal chain (A→B→C):
      --   A dbg_h37_input_r31_ever   = '1' once: fifo_Valid='1' AND fifo_data(20:16)="11111"
      --     (R=31 ever appears at cpu2vram's fifo INPUT upper halfword)
      --   B dbg_h37_writing_r31_ever = '1' once: state=WRITING AND fifo_Valid='1' AND
      --                                          fifo_data(20:16)="11111"
      --     (R=31 input arrives while state machine is in WRITING — the only state in
      --      which fifo_data_1 latches the upper halfword)
      --   C dbg_h37_latch_r31_ever   = '1' once: fifo_data_1(4:0)="11111"
      --     (the latched register itself ever holds R=31)
      -- Outcome map: A LIT & B LIT & C DARK → latch wire broken
      --              A LIT & B DARK         → FSM never enters WRITING when R=31 present
      --              A DARK                  → fifo_data upstream of cpu2vram has no R=31
      dbg_h37_input_r31_ever   : out std_logic := '0';
      dbg_h37_writing_r31_ever : out std_logic := '0';
      dbg_h37_latch_r31_ever   : out std_logic := '0';
      -- build #138: cube-CLUT-specific lane-2/lane-3 sticky probes.
      -- Cube CLUT is uploaded at copyDstX=256, copyDstY=482 (verified via MAME GP0 stream).
      -- Filter scope: state=WRITING, copyDstY=482, copyDstX(9:8)="01" (col in 256..511 page).
      -- A dbg_h38_lane2_input_r31_ever : ever at lane-2 INPUT cycle (x(1:0)="10",
      --   fifo_Valid='1') we saw fifo_data(20:16)="11111". This is the cycle when
      --   word 1 of cube CLUT (0x3FFF_023F) is consumed; upper halfword should have R=31.
      -- B dbg_h38_lane3_latch_r31_ever : ever at lane-3 EMIT cycle (x(1:0)="11",
      --   fifo_Valid_1='1') we saw fifo_data_1(4:0)="11111". Latched upper halfword
      --   should be 0x3FFF here.
      -- C dbg_h38_lane3_anchor_ever    : the lane-3 EMIT condition ever fired (no R check).
      --   Anchor proves the trigger samples a real cycle (must be LIT or A/B are moot).
      dbg_h38_lane2_input_r31_ever : out std_logic := '0';
      dbg_h38_lane3_latch_r31_ever : out std_logic := '0';
      dbg_h38_lane3_anchor_ever    : out std_logic := '0';
      -- build #139: where does the cube CLUT upload actually land in FPGA?
      -- B138 anchor at (X=256, Y=482) was DARK; existing in_cube comment uses Y=488.
      -- B139 narrows trigger to a cube-CLUT-shaped upload: size 16×1 AND fifo_data
      -- upper halfword has R=31 (a cube-like CLUT entry). Three stickys distinguish
      -- where it goes:
      --   A any_ever — any such upload ever (sanity)
      --   B y482_ever — and copyDstY=482 (MAME ground truth)
      --   C y488_ever — and copyDstY=488 (FPGA's existing in_cube guess)
      dbg_h39_cubeshape_any_ever  : out std_logic := '0';
      dbg_h39_cubeshape_y482_ever : out std_logic := '0';
      dbg_h39_cubeshape_y488_ever : out std_logic := '0';
      -- build #145: Y=482 vs Y=480 pixelWrite probes — answer "does FSM emit the write?"
      -- (Per [[zn1-pio-path-audit]]: cube CLUT at Y=482 should go through same code path
      -- as Y=480 CLUTs that work. This isolates whether the bug is in the FSM emit step
      -- or downstream of cpu2vram.)
      --   RED   = h45_y482_anchor      : state=WRITING AND copyDstY=482 ever (sanity, must fire)
      --   GREEN = h45_y482_pixwrite    : pixelWrite='1' with row=482 ever (does FSM emit?)
      --   BLUE  = h45_y480_pixwrite    : pixelWrite='1' with row=480 ever (positive control)
      dbg_h45_y482_anchor   : out std_logic := '0';
      dbg_h45_y482_pixwrite : out std_logic := '0';
      dbg_h45_y480_pixwrite : out std_logic := '0';
      -- build #146/147/148: copyDstY value capture probes (now repurposed for B149).
      -- B149 captures fifo_data at copyDstY ∈ [472..476] (the narrow band around B147's
      -- measured Y≈474). Bars:
      --   dbg_h46_y_minus_240 = h49_fifo_data(8:0)    — entry 0 (low halfword) bits 8:0
      --   dbg_h46_y_high_bit  = '0' (unused in B149)
      --   dbg_h46_anchor      = sticky: ever fired
      dbg_h46_y_minus_240 : out std_logic_vector(8 downto 0) := (others => '0');
      dbg_h46_y_high_bit  : out std_logic := '0';
      dbg_h46_anchor      : out std_logic := '0';
      -- build #149: entry 1 (upper halfword) bits 8:0 — includes R[4:0]
      dbg_h49_entry1_low  : out std_logic_vector(8 downto 0) := (others => '0');
      -- 2026-06-28: expose parsed upload params to diagnose endless-0xA0 hang.
      -- dbg_copysize = state[31:23 pad / 22:21] & copySizeY[20:11] & copySizeX[10:0]
      -- dbg_copydst  = copyDstY[21:10] & copyDstX[9:0]
      dbg_copysize        : out std_logic_vector(31 downto 0) := (others => '0');
      dbg_copydst         : out std_logic_vector(31 downto 0) := (others => '0')
   );
end entity;

architecture arch of gpu_cpu2vram is
   
   type tState is
   (
      IDLE,
      REQUESTWORD2,
      REQUESTWORD3,
      WRITING
   );
   signal state : tState := IDLE;
   
   signal copyDstX     : unsigned(9 downto 0);
   signal copyDstY     : unsigned(9 downto 0);
   signal copySizeX    : unsigned(10 downto 0);
   signal copySizeY    : unsigned(9 downto 0);
                       
   signal x            : unsigned(10 downto 0);
   signal y            : unsigned(9 downto 0);
   
   signal fifo_Valid_1 : std_logic;
   signal fifo_data_1  : std_logic_vector(15 downto 0);

-- synthesis translate_off
   signal simWordCount : integer := 0;   -- fifo words consumed in WRITING (this upload)
   signal simPxCount   : integer := 0;   -- pixels emitted in WRITING (this upload)
-- synthesis translate_on

   -- build #137: sticky-once-set probes (see entity-port comment)
   signal h37_input_r31_ever   : std_logic := '0';
   signal h37_writing_r31_ever : std_logic := '0';
   signal h37_latch_r31_ever   : std_logic := '0';

   -- build #138: cube-CLUT-specific lane sticky probes (see entity-port comment)
   signal h38_lane2_input_r31_ever : std_logic := '0';
   signal h38_lane3_latch_r31_ever : std_logic := '0';
   signal h38_lane3_anchor_ever    : std_logic := '0';

   -- build #139: cube-shape-upload Y probes (size 16x1 + R=31 entry)
   signal h39_cubeshape_any_ever  : std_logic := '0';
   signal h39_cubeshape_y482_ever : std_logic := '0';
   signal h39_cubeshape_y488_ever : std_logic := '0';

   -- build #145: Y=482 / Y=480 pixelWrite probes
   signal h45_y482_anchor   : std_logic := '0';
   signal h45_y482_pixwrite : std_logic := '0';
   signal h45_y480_pixwrite : std_logic := '0';

   -- build #146: latch copyDstY at first cube-shape upload (size 16x1 + R=31)
   signal h46_y_latched    : unsigned(9 downto 0) := (others => '0');
   signal h46_anchor       : std_logic := '0';
   signal h49_fifo_data    : std_logic_vector(31 downto 0) := (others => '0');

   -- build #45: combinational view of the pixel being written THIS cycle.
   signal in_row    : unsigned(9 downto 0);
   signal in_col    : unsigned(9 downto 0);
   signal in_src    : std_logic_vector(15 downto 0);
   signal in_write  : std_logic;
   signal in_cube   : std_logic;  -- write lands at cube gate (row=488, col<256)

   signal raw_dst   : std_logic_vector(31 downto 0) := (others => '0');
   signal raw_size  : std_logic_vector(31 downto 0) := (others => '0');

begin

   requestFifo <= '1' when (state = REQUESTWORD2 or state = REQUESTWORD3 ) else
                  '1' when (state = WRITING and pixelStall = '0' and fifo_Valid = '0' and ((x + 1 < copySizeX) or (y + 1 < copySizeY) or fifo_Valid_1 = '0')) else 
                  '0';

   process (clk2x)
      variable row : unsigned(9 downto 0);
      variable col : unsigned(9 downto 0);
   begin
      if rising_edge(clk2x) then
         
         errorMASK <= '0';
         if (state /= IDLE and DrawPixelsMask = '1') then
            errorMASK <= '1';
         end if;
         
         if (reset = '1') then

            state <= IDLE;
            -- build #137: clear sticky probes on reset
            h37_input_r31_ever   <= '0';
            h37_writing_r31_ever <= '0';
            h37_latch_r31_ever   <= '0';
            -- build #138: clear cube-CLUT lane stickys
            h38_lane2_input_r31_ever <= '0';
            h38_lane3_latch_r31_ever <= '0';
            h38_lane3_anchor_ever    <= '0';
            -- build #139: clear cube-shape Y stickys
            h39_cubeshape_any_ever  <= '0';
            h39_cubeshape_y482_ever <= '0';
            h39_cubeshape_y488_ever <= '0';
            -- build #145: clear Y=482/480 pixelWrite stickys
            h45_y482_anchor   <= '0';
            h45_y482_pixwrite <= '0';
            h45_y480_pixwrite <= '0';
            -- build #146: clear copyDstY latch
            h46_y_latched <= (others => '0');
            h46_anchor    <= '0';
            h49_fifo_data <= (others => '0');

         elsif (ce = '1') then
            -- build #137: sticky-on probes (set-only; only reset path clears)
            if (fifo_Valid = '1' and fifo_data(20 downto 16) = "11111") then
               h37_input_r31_ever <= '1';
               if (state = WRITING) then
                  h37_writing_r31_ever <= '1';
               end if;
            end if;
            if (fifo_data_1(4 downto 0) = "11111") then
               h37_latch_r31_ever <= '1';
            end if;

            -- build #138: cube-CLUT-specific filter (state=WRITING, copyDstY=482,
            -- copyDstX=256). Probe lane-2 INPUT cycle (x[1:0]="10", fifo_Valid='1')
            -- and lane-3 EMIT cycle (x[1:0]="11", fifo_Valid_1='1'). Set-only.
            if (state = WRITING
                and copyDstY = to_unsigned(482, 10)
                and copyDstX = to_unsigned(256, 10)) then
               -- lane-2 INPUT cycle: word 1 of cube CLUT consumed
               if (x(1 downto 0) = "10" and fifo_Valid = '1'
                   and fifo_data(20 downto 16) = "11111") then
                  h38_lane2_input_r31_ever <= '1';
               end if;
               -- lane-3 EMIT cycle: anchor + latch R=31 check
               if (x(1 downto 0) = "11" and fifo_Valid_1 = '1') then
                  h38_lane3_anchor_ever <= '1';
                  if (fifo_data_1(4 downto 0) = "11111") then
                     h38_lane3_latch_r31_ever <= '1';
                  end if;
               end if;
            end if;

            -- build #139: cube-SHAPE upload detector (size 16x1 + R=31 in upper hw).
            -- Doesn't constrain copyDstX/Y so we can OBSERVE where it lands.
            if (state = WRITING
                and copySizeX = to_unsigned(16, 11)
                and copySizeY = to_unsigned(1, 10)
                and fifo_Valid = '1'
                and fifo_data(20 downto 16) = "11111") then
               h39_cubeshape_any_ever <= '1';
               if (copyDstY = to_unsigned(482, 10)) then
                  h39_cubeshape_y482_ever <= '1';
               end if;
               if (copyDstY = to_unsigned(488, 10)) then
                  h39_cubeshape_y488_ever <= '1';
               end if;
            end if;

            -- build #149: capture fifo_data VALUE on the first 16x1 upload at
            -- copyDstY ∈ [472..476] — the narrow band around B147's measured Y≈474.
            -- This tells us what data accompanies the suspect upload: if it's MAME's
            -- cube CLUT (entry0=0x0000, entry1=0x7FFF), only the position is wrong.
            -- If data is different, both position and data are corrupted.
            if (h46_anchor = '0'
                and state = WRITING
                and copySizeX = to_unsigned(16, 11)
                and copySizeY = to_unsigned(1, 10)
                and fifo_Valid = '1'
                and copyDstY >= to_unsigned(472, 10)
                and copyDstY <= to_unsigned(476, 10)) then
               h49_fifo_data <= fifo_data;
               h46_anchor    <= '1';
            end if;

            -- build #145: Y=482 vs Y=480 pixelWrite probes — answers "does FSM emit the
            -- write for cube CLUT row?" (Y=482) vs "does FSM emit writes for the row that
            -- DOES land correctly?" (Y=480 positive control).
            -- ANCHOR: simply observe whether WRITING ever runs with copyDstY=482
            if (state = WRITING and copyDstY = to_unsigned(482, 10)) then
               h45_y482_anchor <= '1';
            end if;
            -- pixelWrite condition (same as the actual emit gate in WRITING state below):
            -- state=WRITING AND (fifo_Valid='1' OR fifo_Valid_1='1'), with row=copyDstY+y.
            if (state = WRITING
                and (fifo_Valid = '1' or fifo_Valid_1 = '1')) then
               if (copyDstY + y(9 downto 0) = to_unsigned(482, 10)) then
                  h45_y482_pixwrite <= '1';
               end if;
               if (copyDstY + y(9 downto 0) = to_unsigned(480, 10)) then
                  h45_y480_pixwrite <= '1';
               end if;
            end if;
         
            pixelColor   <= (others => '0');
            pixelAddr    <= (others => '0');
            pixelWrite   <= '0';
            
            done         <= '0';
            CmdDone      <= '0';
            
            fifo_Valid_1 <= '0';
         
            case (state) is
            
               when IDLE =>
                  
                  if (proc_idle = '1' and fifo_Valid = '1' and fifo_data(31 downto 29) = "101") then
                     state <= REQUESTWORD2;
                  end if;
            
               when REQUESTWORD2 =>
                  if (fifo_Valid = '1') then
                     state    <= REQUESTWORD3;
                     copyDstX <= unsigned(fifo_data( 9 downto  0));
                     copyDstY <= unsigned(fifo_data(25 downto 16));
                     raw_dst  <= fifo_data;   -- 2026-06-28: capture full dest word
                  end if;

               when REQUESTWORD3 =>
                  if (fifo_Valid = '1') then
-- synthesis translate_off
                     report "CPU2VRAM parse dstX=" & integer'image(to_integer(copyDstX)) &
                            " dstY=" & integer'image(to_integer(copyDstY)) &
                            " w=" & integer'image(to_integer(unsigned(fifo_data(9 downto 0)))) &
                            " h=" & integer'image(to_integer(unsigned(fifo_data(24 downto 16))));
-- synthesis translate_on
                     raw_size   <= fifo_data;  -- 2026-06-28: capture full size word
-- synthesis translate_off
                     simWordCount <= 0;
                     simPxCount   <= 0;
-- synthesis translate_on
                     CmdDone    <= '1';
                     state      <= WRITING;
                     copySizeX  <= '0' & unsigned(fifo_data( 9 downto  0));
                     copySizeY  <= '0' & unsigned(fifo_data(24 downto 16));
                     x          <= (others => '0');
                     y          <= (others => '0');
                     -- 0->1024/512 size expand is RETAIL-PSX behavior; MAME's CXD8538Q (System 11) uses RAW
                     -- W/H (a 0-width/height IMGLOAD writes a 1px sliver, not a 1024/512 runaway that would
                     -- consume the following GP0 command stream as texels). Gate the expand off for gputype1.
                     if (gpuType1 = '0' and unsigned(fifo_data( 9 downto  0)) = 0) then copySizeX <= to_unsigned(16#400#, 11); end if;
                     if (gpuType1 = '0' and unsigned(fifo_data(24 downto 16)) = 0) then copySizeY <= to_unsigned(16#200#, 10); end if;
                     -- 2026-06-30 DEFENSIVE GUARD (System 11): a ch1 DMA-read DQ-margin fault in sdram.sv
                     -- occasionally returns an all-1s (0xFFFFFFFF) word (see project_tekken_dma_read_margin).
                     -- If that word lands as the IMGLOAD size it yields copySizeX=1023/copySizeY=511 -> a
                     -- runaway upload that smears the whole GP0 command stream across VRAM (title = noise).
                     -- A legitimate size word never has the reserved bits 31:25 or 15:10 set, so an all-1s
                     -- word is unambiguously corrupt: write a 1px sliver instead of the catastrophic runaway.
                     if (gpuType1 = '1' and fifo_data = x"FFFFFFFF") then
                        copySizeX <= (others => '0');
                        copySizeY <= (others => '0');
                     end if;
                  end if;
                  
               when WRITING =>
-- synthesis translate_off
                  if (fifo_Valid = '1') then simWordCount <= simWordCount + 1; end if;
                  if (fifo_Valid = '1' or fifo_Valid_1 = '1') then
                     simPxCount <= simPxCount + 1;
                     if (fifo_Valid = '1' and fifo_Valid_1 = '1') then
                        report "CPU2VRAM COLLISION both-valid at px " & integer'image(simPxCount);
                     end if;
                  end if;
                  -- cycle-exact trace of the first upload's head (16x8=128px upload)
                  if (simPxCount <= 8 and copySizeX = 16 and copySizeY = 8) then
                     report "TAIL px=" & integer'image(simPxCount) & " V=" & std_logic'image(fifo_Valid) &
                            " V1=" & std_logic'image(fifo_Valid_1) & " x=" & integer'image(to_integer(x)) &
                            " y=" & integer'image(to_integer(y)) & " stall=" & std_logic'image(pixelStall) &
                            " data=" & to_hstring(fifo_data);
                  end if;
-- synthesis translate_on
                  if (fifo_Valid = '1') then
                     fifo_Valid_1 <= fifo_Valid;
                     fifo_data_1  <= fifo_data(31 downto 16);
                  end if;

                  -- todo: AND/OR masking

                  if (fifo_Valid = '1' or fifo_Valid_1 = '1') then
                     -- ZN-1 arcade boards have 2MB VRAM (1024x1024). Y is 10-bit native (0-1023).
                     -- DO NOT mask Y to 9 bits; CLUT pointer is also 10-bit (see gpu_poly.vhd).
                     row := copyDstY + y(9 downto 0);
                     col := copyDstX + x(9 downto 0);
      
                     pixelWrite <= '1';
                     pixelAddr  <= row & col & '0';
                     if (fifo_Valid = '1') then
                        pixelColor <= fifo_data(15 downto 0);
                     else
                        pixelColor <= fifo_data_1;
                     end if;
                     
                     if (SetMask = '1') then
                        pixelColor(15) <= '1';
                     end if;
                     
                     if (x + 1 < copySizeX) then
                        x <= x + 1;
                     else
                        x <= (others => '0');
                        if (y + 1 < copySizeY) then
                           y <= y + 1;
                        else
                           state <= IDLE;
                           done  <= '1';
-- synthesis translate_off
                           report "CPU2VRAM done: words=" & integer'image(simWordCount+1) &
                                  " px=" & integer'image(simPxCount+1) &
                                  " (expect words=(w*h+1)/2)";
-- synthesis translate_on
                        end if;
                     end if;
                  end if;
            
            end case;
            
            if (drawer_reset = '1') then
               state <= IDLE;
               if (state /= IDLE) then
                  done  <= '1'; 
               end if;
            end if;
         
         end if;
         
      end if;
   end process;

   -- build #21: parser-side dst-X high-bit detector.
   -- Combinationally exposes "we are in REQUESTWORD2 and the incoming fifo word
   -- has bit 9 of X set" so the upper level can latch "parser saw a high-X dst".
   dbg_parsed_dstX_hi <= '1' when (state = REQUESTWORD2 and fifo_Valid = '1' and fifo_data(9) = '1') else '0';

   -- build #45: mirror the WRITING-state pixel selection combinationally, then classify
   -- the source word at the cube-CLUT dest gate (row=488, col<256). Matches the clocked
   -- write logic: source = fifo_data(15:0) when fifo_Valid else fifo_data_1; address uses
   -- the CURRENT x,y (before the end-of-cycle increment).
   in_row   <= copyDstY + y(9 downto 0);
   in_col   <= copyDstX + x(9 downto 0);
   in_write <= '1' when (state = WRITING and (fifo_Valid = '1' or fifo_Valid_1 = '1')) else '0';
   in_src   <= fifo_data(15 downto 0) when (fifo_Valid = '1') else fifo_data_1;
   in_cube  <= '1' when (in_write = '1' and in_row = to_unsigned(488, 10) and in_col(9 downto 8) = "00") else '0';

   dbg_cube_in_any   <= in_cube;

   -- 2026-06-28: RAW 32-bit command words as latched from the fifo (settle data-in-fifo vs parse)
   dbg_copysize <= raw_size;   -- full size word (word2): upper16=height, lower16=width
   dbg_copydst  <= raw_dst;    -- full dest word (word1): upper16=Y, lower16=X

   -- build #133: expose latched upper halfword
   dbg_fifo_data_1   <= fifo_data_1;

   -- build #137: drive the three sticky-probe outputs
   dbg_h37_input_r31_ever   <= h37_input_r31_ever;
   dbg_h37_writing_r31_ever <= h37_writing_r31_ever;
   dbg_h37_latch_r31_ever   <= h37_latch_r31_ever;

   -- build #138: drive cube-CLUT lane probes
   dbg_h38_lane2_input_r31_ever <= h38_lane2_input_r31_ever;
   dbg_h38_lane3_latch_r31_ever <= h38_lane3_latch_r31_ever;
   dbg_h38_lane3_anchor_ever    <= h38_lane3_anchor_ever;

   -- build #139: drive cube-shape Y probes
   dbg_h39_cubeshape_any_ever  <= h39_cubeshape_any_ever;
   dbg_h39_cubeshape_y482_ever <= h39_cubeshape_y482_ever;
   dbg_h39_cubeshape_y488_ever <= h39_cubeshape_y488_ever;

   -- build #145: drive Y=482/480 pixelWrite probes
   dbg_h45_y482_anchor   <= h45_y482_anchor;
   dbg_h45_y482_pixwrite <= h45_y482_pixwrite;
   dbg_h45_y480_pixwrite <= h45_y480_pixwrite;

   -- build #149: drive fifo_data capture bars.
   --   RED   = h49_fifo_data(8:0)   — entry 0 (low halfword) bits 8:0
   --   GREEN = h49_fifo_data(24:16) — entry 1 (upper halfword) bits 8:0 (includes R[4:0] in 4:0)
   --   BLUE  = anchor sticky — fired at first WRITING+copySizeX=16+copySizeY=1+copyDstY∈[472..476]
   -- MAME-expected values (cube CLUT first FIFO word = 0x7FFF0000):
   --   entry 0 = 0x0000 → bits 8:0 = 0           → RED dark
   --   entry 1 = 0x7FFF → bits 8:0 = 0x1FF (511) → GREEN full bright (≥352)
   -- If RED nonzero: entry 0 (transparent) corrupted.
   -- If GREEN < 511: entry 1's G[3:0] or B[0] bits corrupted (R[4:0] still 31 because we caught it).
   dbg_h46_y_minus_240 <= h49_fifo_data(8 downto 0);
   dbg_h46_y_high_bit  <= '0';
   dbg_h46_anchor      <= h46_anchor;
   dbg_h49_entry1_low  <= h49_fifo_data(24 downto 16);
   dbg_cube_in_green <= '1' when (in_cube = '1'
                                  and in_src(4 downto 0)   = "00000"
                                  and in_src(14 downto 10) = "00000"
                                  and in_src(9 downto 5)  /= "00000") else '0';
   dbg_cube_in_red   <= '1' when (in_cube = '1'
                                  and in_src(9 downto 5)   = "00000"
                                  and in_src(14 downto 10) = "00000"
                                  and in_src(4 downto 0)  /= "00000") else '0';

end architecture;





