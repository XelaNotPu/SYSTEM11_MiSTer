//
// sdram
// Copyright (c) 2015-2019 Sorgelig
//
// Some parts of SDRAM code used from project:
// http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module sdram
(
	input              init,        // reset to initialize RAM
	input              clk,         // clock ~100MHz
	input              clk_sdramclk, // phase-shifted clock driving the SDRAM_CLK output pin (interface/write-timing test)
	input              clk_dqcap,   // phase-shifted clock that captures read DQ (dq_reg) — tune for late-DQ margin
	input              clk_base,    // clock ~33MHz
                      
	input              SDRAM_EN,    // Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0 
   
	inout  reg [15:0]  SDRAM_DQ,    // 16 bit bidirectional data bus
	output reg [12:0]  SDRAM_A,     // 13 bit multiplexed address bus
	output             SDRAM_DQML,  // two byte masks
	output             SDRAM_DQMH,  // 
	output reg  [1:0]  SDRAM_BA,    // two banks
	output             SDRAM_nCS,   // a single chip select
	output             SDRAM_nWE,   // write enable
	output             SDRAM_nRAS,  // row address select
	output             SDRAM_nCAS,  // columns address select
	output             SDRAM_CKE,   // clock enable
	output             SDRAM_CLK,   // clock for chip

	input              refreshForce,
	input              pagemode_en, // 1=enable ch1 page-mode (skip CMD_ACTIVE on same-row hits)
	output             ram_idle,    // used to tell the core a write command on ch2 will be accepted instantly

	input      [26:0]  ch1_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [127:0] ch1_dout,    // data output to cpu
	output reg [31:0]  ch1_dout32,  // data output to cpu
	input      [15:0]  ch1_din,     // data input from cpu
	input              ch1_req,     // request
	input              ch1_rnw,     // 1 - read, 0 - write
	input              ch1_dma,     // 1 - read 128bit for dma
	input      [ 1:0]  ch1_cntDMA,  // count of words-1 for dma read
	input              ch1_cache,   // 1 - read 128bit for cache
	output reg         ch1_ready,
	output reg [ 3:0]  cache_wr,    
	output reg [31:0]  cache_data,  
	output reg [ 7:0]  cache_addr,  
	output reg         dma_wr,  
	output reg         dma_reqprocessed,  
	output reg [31:0]  dma_data,  

	input      [26:0]  ch2_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [31:0]  ch2_dout,    // data output to cpu
	input      [31:0]  ch2_din,     // data input from cpu
	input              ch2_req,     // request
	input              ch2_rnw,     // 1 - read, 0 - write
   input      [3:0]   ch2_be,      
	output reg         ch2_ready,
                      
	input      [26:0]  ch3_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
	output reg [31:0]  ch3_dout,    // data output to cpu
	input      [31:0]  ch3_din,     // data input from cpu
	input              ch3_req,     // request
	input              ch3_rnw,     // 1 - read, 0 - write
	input      [3:0]   ch3_be,
	output reg         ch3_ready,

	input      [26:0]  dmafifo_adr,
	input      [31:0]  dmafifo_data,
	input              dmafifo_empty,
	output reg         dmafifo_read,

	// B-pm-probe: sticky latches for page-mode FSM events (debug-bar observability)
	output reg         dbg_pm_hit  = 1'b0,  // page-mode HIT (skip-ACTIVE) path ever taken
	output reg         dbg_pm_open = 1'b0,  // page-mode ACTIVE left a row open (pagemode_en path) ever
	output reg         dbg_pm_pre  = 1'b0,  // page-mode PRECHARGE (entered PRECHARGE_1) ever fired
	// B-jtag-probe: live FSM state for the ISSP/JTAG observability node
	output      [8:0]  dbg_sdram,            // {lastbank_ch1_valid, command[2:0], state[4:0]}
	output      [7:0]  dbg_drd1              // data_ready_delay1[7:0]: read-data capture window
);

assign dbg_sdram = {lastbank_ch1_valid, command, state[4:0]};
assign dbg_drd1  = data_ready_delay1[7:0];

assign SDRAM_nCS  = chip;
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE  = command[0];
assign SDRAM_CKE  = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];

localparam BURST_LENGTH        = 8;
//(BURST_LENGTH == 8) ? 3'b011 : (BURST_LENGTH == 4) ? 3'b010 : (BURST_LENGTH == 2) ? 3'b001 : 3'b000;  // 000=1, 001=2, 010=4, 011=8
// we do 4 bursts of 2 words(16bit) for every read. The reason is that a burst of 8 will wrap inside the page. e.g. reading address 6,7,8,.. is not possible, it will read 6,7,0,.. instead
// as bursts of 2 can be done back-to-back, this does not have any latency or bandwidth penalty compared to full 8 word burst
localparam BURST_CODE          = 3'b001;   
localparam ACCESS_TYPE         = 1'b0;     // 0=sequential, 1=interleaved
localparam CAS_LATENCY         = 3'd2;     // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE             = 2'b00;    // only 00 (standard operation) allowed
localparam NO_WRITE_BURST      = 1'b1;     // 0= write burst enabled, 1=only single access write
localparam MODE                = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_CODE};

localparam sdram_startup_cycles= 14'd12100;// 100us, plus a little more, @ 100MHz
localparam cycles_per_refresh  = 14'd780;  // (64000*100)/8192-1 Calc'd as (64ms @ 100MHz)/8192 rose
localparam startup_refresh_max = 14'b11111111111111;

// SDRAM commands
wire [2:0] CMD_NOP             = 3'b111;
wire [2:0] CMD_ACTIVE          = 3'b011;
wire [2:0] CMD_READ            = 3'b101;
wire [2:0] CMD_WRITE           = 3'b100;
wire [2:0] CMD_PRECHARGE       = 3'b010;
wire [2:0] CMD_AUTO_REFRESH    = 3'b001;
wire [2:0] CMD_LOAD_MODE       = 3'b000;

reg [13:0] refresh_count = startup_refresh_max - sdram_startup_cycles;
reg  [2:0] command;
reg        chip;

localparam STATE_STARTUP = 0;
localparam STATE_WAIT    = 1;
localparam STATE_RW1     = 2;
localparam STATE_RW2     = 3;
localparam STATE_IDLE    = 4;
localparam STATE_IDLE_1  = 5;
localparam STATE_IDLE_2  = 6;
localparam STATE_IDLE_3  = 7;
localparam STATE_IDLE_4  = 8;
localparam STATE_IDLE_5  = 9;
localparam STATE_IDLE_6  = 10;
localparam STATE_IDLE_7  = 11;
localparam STATE_IDLE_8  = 12;
localparam STATE_IDLE_9  = 13;
localparam STATE_RFSH    = 14;
// ch1 page-mode states (only reachable when pagemode_en=1). tRP = 2 cycles.
localparam STATE_PRECHARGE_1 = 15;
localparam STATE_PRECHARGE_2 = 16;

reg clk1xToggle     = 0;
reg clk1xToggle3X   = 0;
reg clk1xToggle3X_1 = 0;
reg clk3xIndex      = 0;

reg ram_idleNext    = 0;

assign ram_idle = ram_idleNext && !ch3_req;

reg [10:0] lastbank;
// ch1 page-mode tracker (only meaningful when pagemode_en=1).
// {chip, bank, row} of the currently-open ch1 row.
reg        lastbank_ch1_chip  = 1'b0;
reg  [1:0] lastbank_ch1_bank  = 2'b0;
reg [12:0] lastbank_ch1_row   = 13'b0;
reg        lastbank_ch1_valid = 1'b0;
// ch3 buffered for timing closure
reg [26:0]  ch3buf_addr;
reg [31:0]  ch3buf_din; 
reg         ch3buf_rnw; 
reg [3:0]   ch3buf_be;

always @(posedge clk_base) begin

   ch1_ready <= ch1_ready_ramclock;
	ch2_ready <= ch2_ready_ramclock;
	ch3_ready <= ch3_ready_ramclock;

	dma_reqprocessed <= dma_reqprocessed_ramclock;
   
   clk1xToggle <= !clk1xToggle;
      
   ram_idleNext <= 0;
   if (state == STATE_IDLE || state == STATE_IDLE_1 || state == STATE_IDLE_2 || (state == STATE_RW1 && saved_wr) || state == STATE_RW2) begin
      if (refresh_count < (cycles_per_refresh - 14'd16) && !ch1_rq && !ch2_rq && !ch3_rq) begin
         ram_idleNext <= 1;
      end
   end
   
   if (ch1_ready_ramclock) begin
      ch1_dout32 <= ch1_dout[31:0];
   end
   
   dma_wr  <= 0;
   dma_ack <= 0;

   // 2026-07-11 dma delivery-hazard fix: dma_done now asserts only when the FULL line is captured
   // (completion tap derived from the read's word count) and carries a snapshot {dma_line,
   // dma_line_cnt}. Delivery reads ONLY the dma_hold snapshot (never live ch1_dout capture state),
   // and a done arriving mid-burst is queued in a 1-deep skid instead of overriding the burst
   // (the old override truncated the in-flight line: word 3 was replaced by the next line's word 0
   // whenever two dones came closer than 4 clk1x, e.g. the 11-cycle page-HIT read cadence).
   if (dma_wr && (dma_counter < dma_count)) begin
      // burst in progress: deliver words 1..3 from the snapshot
      dma_wr      <= 1;
      dma_counter <= dma_counter + 1'b1;
      if (dma_counter == 0) dma_data <= dma_hold[ 63:32];
      if (dma_counter == 1) dma_data <= dma_hold[ 95:64];
      if (dma_counter == 2) dma_data <= dma_hold[127:96];
      if (dma_done) begin
         // a new line completed while this one is still delivering: queue it
         dma_ack        <= 1;
         dma_skid       <= dma_line;
         dma_skid_cnt   <= dma_line_cnt;
         dma_skid_valid <= 1;
         // synthesis translate_off
         if (dma_skid_valid) $display("sdram.sv ERROR: dma skid OVERFLOW - 3rd line done while delivering+queued (t=%0t)", $time);
         // synthesis translate_on
      end
   end else if (dma_skid_valid) begin
      // previous burst just ended (or idle): start the queued line
      dma_wr      <= 1;
      dma_data    <= dma_skid[31:0];
      dma_hold    <= dma_skid;
      dma_count   <= dma_skid_cnt;
      dma_counter <= 0;
      if (dma_done) begin  // simultaneous new completion: refill the skid slot (order preserved)
         dma_ack      <= 1;
         dma_skid     <= dma_line;
         dma_skid_cnt <= dma_line_cnt;
      end else begin
         dma_skid_valid <= 0;
      end
   end else if (dma_done) begin
      dma_ack     <= 1;
      dma_wr      <= 1;
      dma_data    <= dma_line[31:0];
      dma_hold    <= dma_line;
      dma_count   <= dma_line_cnt;
      dma_counter <= 0;
   end

end

reg ch1_ready_ramclock = 0;
reg ch2_ready_ramclock = 0;
reg ch3_ready_ramclock = 0;
reg refreshForce_1 = 0;

reg cache_buffer      = 0;
reg cache_buffer_next = 0;

reg cache_done_0  = 0;
reg cache_done_1  = 0;
reg cache_done_2  = 0;
reg cache_done_3  = 0;
reg [3:0] cache_wr_next = 0;

reg       dma_buffer    = 0;
reg       dma_done      = 0;
reg       dma_ack       = 0;
reg [1:0] dma_count_3x  = 0;
reg [1:0] dma_count     = 0;
reg [1:0] dma_counter   = 0;
reg       dma_reqprocessed_ramclock = 0;
// dma delivery-hazard fix: per-read metadata travels in a 2-entry ACCEPT-ORDER FIFO
// (dma_buffer/dma_count_3x are overwritten by the NEXT request's accept 1 cycle before this
// read's last tap, so completion-tap selection must not read them live). Push at ch1 READ
// accept (the same cycle dma_buffer/dma_count_3x are written; both ACTIVE and page-HIT paths),
// pop when the read's data_ready_delay1 bit exits at tap [0]. Accepts and completions are
// strictly in-order in this FSM and at most 2 reads are in flight, so 2 entries suffice.
reg  [2:0]  dma_meta0    = 0;      // FIFO entries: {is_dma, cntDMA[1:0]}
reg  [2:0]  dma_meta1    = 0;
reg         dma_meta_rd  = 0;      // 1-bit ring pointers
reg         dma_meta_wr  = 0;
wire [2:0]  dma_meta_head = dma_meta_rd ? dma_meta1 : dma_meta0;
// synthesis translate_off
integer     dma_meta_occ = 0;      // sim-only occupancy check
// synthesis translate_on
reg [127:0] dma_line        = 0;   // completed-line snapshot (clk domain, written at completion tap)
reg [1:0]   dma_line_cnt    = 0;   // its word count-1
reg [127:0] dma_hold        = 0;   // clk1x delivery snapshot (never live capture state)
reg [127:0] dma_skid        = 0;   // 1-deep queue for back-to-back dones
reg [1:0]   dma_skid_cnt    = 0;
reg         dma_skid_valid  = 0;

reg  [4:0] state = STATE_STARTUP;  // 5 bits: holds STATE_PRECHARGE_2 (16)

reg ch1_rq, ch2_rq, ch3_rq, refreshForce_req;
reg saved_wr;
reg saved_128read = 0;

reg [CAS_LATENCY+BURST_LENGTH:0] data_ready_delay1, data_ready_delay2, data_ready_delay3;

reg [12:0] cas_addr;
reg [31:0] saved_data;
reg  [3:0] saved_be;
reg [15:0] dq_reg;
// Read-DQ capture on a dedicated (phase-tunable) clock. clk_dqcap = clk gives the stock posedge
// capture; a phase-shifted clk_dqcap samples DQ later to tolerate late real-chip DQ arrival.
always @(posedge clk_dqcap) dq_reg <= SDRAM_DQ;

reg [1:0] ch;

always @(posedge clk) begin
  
   clk1xToggle3X   <= clk1xToggle;
   clk1xToggle3X_1 <= clk1xToggle3X;
   clk3xIndex      <= clk1xToggle3X_1 == clk1xToggle;
	
	ch1_rq <= ch1_rq | (ch1_req & clk3xIndex);
	ch2_rq <= ch2_rq | (ch2_req & clk3xIndex);
	ch3_rq <= ch3_rq | (ch3_req & clk3xIndex);
   
   ch3buf_addr <= ch3_addr;
   ch3buf_din  <= ch3_din;
   ch3buf_rnw  <= ch3_rnw;
   ch3buf_be   <= ch3_be;
	
	if (ch1_ready) ch1_ready_ramclock <= 0;
	if (ch2_ready) ch2_ready_ramclock <= 0;
	if (ch3_ready) ch3_ready_ramclock <= 0;
	
	if (dma_ack) dma_done <= 0;

	if (dma_reqprocessed) dma_reqprocessed_ramclock <= 0;

	dmafifo_read <= 0;

	refreshForce_1 <= refreshForce;
	refreshForce_req <= refreshForce_req | (refreshForce & ~refreshForce_1);

	refresh_count <= refresh_count+1'b1;

	data_ready_delay1 <= data_ready_delay1>>1;
	data_ready_delay2 <= data_ready_delay2>>1;
	data_ready_delay3 <= data_ready_delay3>>1;

   
   cache_wr     <= 0;
   cache_done_0 <= 0;
   cache_done_1 <= 0;
   cache_done_2 <= 0;
   cache_done_3 <= 0;
   if (cache_done_0) begin cache_data <= ch1_dout[ 31: 0]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_1) begin cache_data <= ch1_dout[ 63:32]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_2) begin cache_data <= ch1_dout[ 95:64]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
   if (cache_done_3) begin cache_data <= ch1_dout[127:96]; cache_wr <= cache_wr_next; cache_wr_next <= { cache_wr_next[2:0], 1'b0 }; end
      
   if(data_ready_delay1[7]) ch1_dout[ 15: 00]  <= dq_reg;
   if(data_ready_delay1[6]) ch1_dout[ 31: 16]  <= dq_reg;
   if(data_ready_delay1[5]) ch1_dout[ 47: 32]  <= dq_reg;
   if(data_ready_delay1[4]) ch1_dout[ 63: 48]  <= dq_reg;
   if(data_ready_delay1[3]) ch1_dout[ 79: 64]  <= dq_reg;
   if(data_ready_delay1[2]) ch1_dout[ 95: 80]  <= dq_reg;
   if(data_ready_delay1[1]) ch1_dout[111: 96]  <= dq_reg;
   if(data_ready_delay1[0]) ch1_dout[127:112]  <= dq_reg;
   if(data_ready_delay1[6] && ~dma_buffer && ~cache_buffer_next) ch1_ready_ramclock <= 1;
   if(data_ready_delay1[4] && cache_buffer_next)                 ch1_ready_ramclock <= 1;

   // dma delivery-hazard fix: dma_done fires at the tap where the LAST word of this read is being
   // captured (not at word 0 like before), together with a completed-line snapshot for the clk1x
   // consumer. dq_reg is merged in for the halfword arriving on the completion tap itself (the
   // ch1_dout <= dq_reg assignments above are nonblocking, so ch1_dout doesn't hold it yet).
   // {is_dma, cnt} come from the accept-order metadata FIFO head - NOT from live
   // dma_buffer/dma_count_3x, which the next request's accept may already have overwritten.
   if(data_ready_delay1[6] && dma_meta_head[2] && dma_meta_head[1:0] == 2'd0) begin dma_done <= 1; dma_line_cnt <= 2'd0; dma_line[ 31:0] <= {dq_reg, ch1_dout[15:0]}; end
   if(data_ready_delay1[4] && dma_meta_head[2] && dma_meta_head[1:0] == 2'd1) begin dma_done <= 1; dma_line_cnt <= 2'd1; dma_line[ 63:0] <= {dq_reg, ch1_dout[47:0]}; end
   if(data_ready_delay1[2] && dma_meta_head[2] && dma_meta_head[1:0] == 2'd2) begin dma_done <= 1; dma_line_cnt <= 2'd2; dma_line[ 95:0] <= {dq_reg, ch1_dout[79:0]}; end
   if(data_ready_delay1[0] && dma_meta_head[2] && dma_meta_head[1:0] == 2'd3) begin dma_done <= 1; dma_line_cnt <= 2'd3; dma_line        <= {dq_reg, ch1_dout[111:0]}; end
   if(data_ready_delay1[0]) begin
      // this ch1 read's delay1 bit exits the pipe: pop its metadata (every ch1 read - single,
      // cache or dma - sets the bit in STATE_RW1 and it always traverses down to tap [0])
      dma_meta_rd <= ~dma_meta_rd;
      // synthesis translate_off
      dma_meta_occ = dma_meta_occ - 1;
      if (dma_meta_occ < 0) $display("sdram.sv ERROR: dma meta FIFO UNDERFLOW (t=%0t)", $time);
      // synthesis translate_on
   end

   if(data_ready_delay1[7]) cache_buffer_next <= cache_buffer;
   if(data_ready_delay1[6] && cache_buffer_next) cache_done_0 <= 1;
   if(data_ready_delay1[4] && cache_buffer_next) cache_done_1 <= 1;
   if(data_ready_delay1[2] && cache_buffer_next) cache_done_2 <= 1;
   if(data_ready_delay1[0] && cache_buffer_next) cache_done_3 <= 1;

	if(data_ready_delay2[7]) ch2_dout[15:00]    <= dq_reg;
	if(data_ready_delay2[6]) ch2_dout[31:16]    <= dq_reg;
	if(data_ready_delay2[2]) ch2_ready_ramclock <= 1;

	if(data_ready_delay3[7]) ch3_dout[15:00]    <= dq_reg;
	if(data_ready_delay3[6]) ch3_dout[31:16]    <= dq_reg;
	if(data_ready_delay3[2]) ch3_ready_ramclock <= 1;

	SDRAM_DQ <= 16'bZ;
   
   if (SDRAM_EN) begin
   
      command <= CMD_NOP;
      if (state == STATE_PRECHARGE_1) dbg_pm_pre <= 1'b1;   // B-pm-probe: page-mode PRECHARGE fired
      case (state)
         STATE_STARTUP: begin
            SDRAM_A    <= 0;
            SDRAM_BA   <= 0;
   
            if (refresh_count == (startup_refresh_max-64)) chip <= 0;
            if (refresh_count == (startup_refresh_max-32)) chip <= 1;
   
            // All the commands during the startup are NOPS, except these
            if (refresh_count == startup_refresh_max-63 || refresh_count == startup_refresh_max-31) begin
               // ensure all rows are closed
               command     <= CMD_PRECHARGE;
               SDRAM_A[10] <= 1;  // all banks
               SDRAM_BA    <= 2'b00;
            end
            if (refresh_count == startup_refresh_max-55 || refresh_count == startup_refresh_max-23) begin
               // these refreshes need to be at least tREF (66ns) apart
               command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-47 || refresh_count == startup_refresh_max-15) begin
               command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-39 || refresh_count == startup_refresh_max-7) begin
               // Now load the mode register
               command     <= CMD_LOAD_MODE;
               SDRAM_A     <= MODE;
            end
   
            if (!refresh_count) begin
               state   <= STATE_IDLE;
               refresh_count <= 0;
            end
         end
   
         STATE_IDLE_9: begin
            state <= STATE_IDLE_8;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_8: begin
            state   <= STATE_IDLE_7;
            if (saved_128read) begin
               command <= CMD_READ;
               SDRAM_A <= cas_addr;
            end
         end
         
         STATE_IDLE_7: begin
            state <= STATE_IDLE_6;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_6: begin 
            state <= STATE_IDLE_5;
            if (saved_128read) begin
               command <= CMD_READ;
               SDRAM_A <= cas_addr;
            end
         end
         
         STATE_IDLE_5: begin 
            state <= STATE_IDLE_4;
            if (saved_128read) begin
               cas_addr[8:0] <= cas_addr[8:0] + 2'd2;
            end
         end
         
         STATE_IDLE_4: begin
            state <= STATE_IDLE_3;
            if (saved_128read) begin
               command       <= CMD_READ;
               SDRAM_A       <= cas_addr;
               saved_128read <= 0;
            end
         end
         
         STATE_IDLE_3: begin
            state <= STATE_IDLE_2;
         end
         
         STATE_IDLE_2: begin
            state <= STATE_IDLE_1;
         end
         
         STATE_IDLE_1: begin
            state      <= STATE_IDLE;
            // mask possible refresh to reduce colliding.
            if (refresh_count > cycles_per_refresh) begin
               // If a ch1 page-mode row is still open we must close it before
               // AUTO_REFRESH (which requires all banks idle). `chip` is left
               // alone so PRECHARGE targets the chip that owns the open row.
               if (lastbank_ch1_valid) begin
                  command            <= CMD_PRECHARGE;
                  SDRAM_A[10]        <= 1'b1;
                  state              <= STATE_PRECHARGE_1;
                  lastbank_ch1_valid <= 0;
               end else begin
                  state    <= STATE_RFSH;
                  command  <= CMD_AUTO_REFRESH;
                  chip     <= 0;
                  refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
               end
            end
         end
   
         STATE_RFSH: begin
            state    <= STATE_IDLE_5;
            command  <= CMD_AUTO_REFRESH;
            chip     <= 1;
         end
   
         STATE_IDLE: begin
            saved_128read <= 0;
            if (refreshForce_req || refresh_count > cycles_per_refresh) begin
               // PRECHARGE first if a page-mode row is open.
               if (lastbank_ch1_valid) begin
                  command            <= CMD_PRECHARGE;
                  SDRAM_A[10]        <= 1'b1;
                  state              <= STATE_PRECHARGE_1;
                  lastbank_ch1_valid <= 0;
               end else begin
                  state            <= STATE_RFSH;
                  command          <= CMD_AUTO_REFRESH;
                  chip             <= 0;
                  refreshForce_req <= 0;
                  if (refresh_count > cycles_per_refresh)
                     refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
                  else
                     refresh_count <= 14'd0;
               end

            end else if(~dmafifo_empty) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b0, dmafifo_adr[25:1]};
               chip         <= dmafifo_adr[26];
               saved_data   <= dmafifo_data;
               saved_wr     <= 1'b1;
               saved_be     <= 4'b1111;
               ch           <= 1;
               command      <= CMD_ACTIVE;
               state        <= STATE_WAIT;
               dmafifo_read <= 1'b1;
               lastbank     <= dmafifo_adr[20:10];
               // DMA touches the bus; invalidate ch1 tracker.
               lastbank_ch1_valid <= 0;
            end else if(ch1_req | ch1_rq) begin
               // HIT path — only reachable when pagemode_en=1 (because the tracker
               // is only set to 1 in the no-tracker branch when pagemode_en=1).
               if (pagemode_en && lastbank_ch1_valid &&
                   lastbank_ch1_chip == ch1_addr[26] &&
                   lastbank_ch1_bank == ch1_addr[24:23] &&
                   lastbank_ch1_row  == ch1_addr[22:10]) begin
                  cas_addr[8:0] <= ch1_addr[9:1];
                  SDRAM_BA      <= ch1_addr[24:23];
                  chip          <= ch1_addr[26];
                  saved_data    <= ch1_din;
                  saved_wr      <= ~ch1_rnw;
                  ch            <= 0;
                  ch1_rq        <= 0;
                  // dma reads take the 1-cycle-longer WAIT path even on a page HIT: the delivery
                  // bus (one 32-bit dma_data word per clk1x) sustains exactly one 4-word line per
                  // 12 clk_3x. The 11-cycle HIT-to-HIT cadence would outrun it, overflowing any
                  // fixed-depth queue (dones arrive faster than 4-beat bursts can drain).
                  state         <= ch1_dma ? STATE_WAIT : STATE_RW1;
                  dbg_pm_hit    <= 1'b1;   // B-pm-probe: HIT path taken

                  cache_buffer <= ch1_cache;
                  cache_addr   <= ch1_addr[11:4];
                  if (ch1_addr[3:2] == 2'b00) cache_wr_next <= 4'b0001;
                  if (ch1_addr[3:2] == 2'b01) cache_wr_next <= 4'b0010;
                  if (ch1_addr[3:2] == 2'b10) cache_wr_next <= 4'b0100;
                  if (ch1_addr[3:2] == 2'b11) cache_wr_next <= 4'b1000;

                  dma_buffer                <= ch1_dma;
                  dma_reqprocessed_ramclock <= ch1_dma;
                  dma_count_3x              <= ch1_cntDMA;

                  // accept-order metadata FIFO push (READS only: mirrors the RW1 delay1-bit set)
                  if (ch1_rnw) begin
                     if (dma_meta_wr) dma_meta1 <= {ch1_dma, ch1_cntDMA};
                     else             dma_meta0 <= {ch1_dma, ch1_cntDMA};
                     dma_meta_wr <= ~dma_meta_wr;
                     // synthesis translate_off
                     dma_meta_occ = dma_meta_occ + 1;
                     if (dma_meta_occ > 2) $display("sdram.sv ERROR: dma meta FIFO OVERFLOW (t=%0t)", $time);
                     // synthesis translate_on
                  end

                  saved_128read <= ch1_dma | ch1_cache;

               // Row-mismatch PRECHARGE — fires when a page-mode row is open but
               // doesn't match the request (or when user toggled pagemode_en off
               // mid-flight, leaving a residual open row). Closes the row, then
               // STATE_IDLE re-evaluates and falls into the ACTIVE branch.
               end else if (lastbank_ch1_valid) begin
                  command            <= CMD_PRECHARGE;
                  SDRAM_A[10]        <= 1'b1;
                  state              <= STATE_PRECHARGE_1;
                  lastbank_ch1_valid <= 0;
                  // ch1_rq preserved — the pending request still needs servicing.

               // Normal ACTIVE path. cas_addr[10] depends on pagemode_en:
               //   pagemode OFF → 1 = auto-precharge (baseline; row closes after burst)
               //   pagemode ON  → 0 = no auto-precharge (row stays open for HIT)
               end else begin
                  {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, ~pagemode_en, ch1_addr[25:1]};
                  chip         <= ch1_addr[26];
                  saved_data   <= ch1_din;
                  saved_wr     <= ~ch1_rnw;
                  ch           <= 0;
                  ch1_rq       <= 0;
                  command      <= CMD_ACTIVE;
                  state        <= STATE_WAIT;

                  cache_buffer <= ch1_cache;
                  cache_addr   <= ch1_addr[11:4];
                  if (ch1_addr[3:2] == 2'b00) cache_wr_next <= 4'b0001;
                  if (ch1_addr[3:2] == 2'b01) cache_wr_next <= 4'b0010;
                  if (ch1_addr[3:2] == 2'b10) cache_wr_next <= 4'b0100;
                  if (ch1_addr[3:2] == 2'b11) cache_wr_next <= 4'b1000;

                  dma_buffer                <= ch1_dma;
                  dma_reqprocessed_ramclock <= ch1_dma;
                  dma_count_3x              <= ch1_cntDMA;

                  // accept-order metadata FIFO push (READS only: mirrors the RW1 delay1-bit set)
                  if (ch1_rnw) begin
                     if (dma_meta_wr) dma_meta1 <= {ch1_dma, ch1_cntDMA};
                     else             dma_meta0 <= {ch1_dma, ch1_cntDMA};
                     dma_meta_wr <= ~dma_meta_wr;
                     // synthesis translate_off
                     dma_meta_occ = dma_meta_occ + 1;
                     if (dma_meta_occ > 2) $display("sdram.sv ERROR: dma meta FIFO OVERFLOW (t=%0t)", $time);
                     // synthesis translate_on
                  end

                  saved_128read <= ch1_dma | ch1_cache;

                  // Tracker valid only when page-mode opted in.
                  lastbank_ch1_chip  <= ch1_addr[26];
                  lastbank_ch1_bank  <= ch1_addr[24:23];
                  lastbank_ch1_row   <= ch1_addr[22:10];
                  lastbank_ch1_valid <= pagemode_en;
                  if (pagemode_en) dbg_pm_open <= 1'b1;   // B-pm-probe: row left open
               end

            end else if(ch2_req | ch2_rq) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch2_be[1:0], ch2_rnw, ch2_addr[25:1]};
               chip       <= ch2_addr[26];
               saved_data <= ch2_din;
               saved_wr   <= ~ch2_rnw;
               saved_be   <= ch2_be;
               ch         <= 1;
               ch2_rq     <= 0;
               command    <= CMD_ACTIVE;
               state      <= STATE_WAIT;
               ch2_ready_ramclock <= 1;
               lastbank_ch1_valid <= 0;
            end else if(ch3_rq) begin
               {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch3buf_be[1:0], ch3buf_rnw, ch3buf_addr[25:1]};
               chip       <= ch3buf_addr[26];
               saved_data <= ch3buf_din;
               saved_wr   <= ~ch3buf_rnw;
               saved_be   <= ch3buf_be;
               ch         <= 2;
               ch3_rq     <= 0;
               command    <= CMD_ACTIVE;
               state      <= STATE_WAIT;
               lastbank_ch1_valid <= 0;
            end
         end

         // 2-cycle tRP wait before STATE_IDLE re-evaluates request / refresh.
         STATE_PRECHARGE_1: state <= STATE_PRECHARGE_2;
         STATE_PRECHARGE_2: state <= STATE_IDLE;

         STATE_WAIT: state <= STATE_RW1;
         STATE_RW1: begin
            SDRAM_A <= cas_addr;
            if(saved_wr) begin
               command  <= CMD_WRITE;
               SDRAM_DQ <= saved_data[15:0];
               if(!ch) begin
                  ch1_ready_ramclock  <= 1;
                  // 2026-07-07: tDAL/tRC extra idles REVERTED to the movie-park-verified
                  // IDLE_2 exit — the +2 idle cycles per CPU write are a suspect in the
                  // whole-game slow-motion regression and were never A/B'd on hardware.
                  state <= STATE_IDLE_2;
               end
               else begin
                  state <= STATE_RW2;
               end
            end
            else begin
               command <= CMD_READ;
               state   <= STATE_IDLE_9;
                  if(ch == 0) data_ready_delay1[CAS_LATENCY+BURST_LENGTH] <= 1;
               else if(ch == 1) data_ready_delay2[CAS_LATENCY+BURST_LENGTH] <= 1;
               else             data_ready_delay3[CAS_LATENCY+BURST_LENGTH] <= 1;
            end
         end
   
         STATE_RW2: begin
            if(ch == 1) begin
               SDRAM_A[0]           <= 1;
               command              <= CMD_WRITE;
               SDRAM_DQ             <= saved_data[31:16];
               SDRAM_A[12:11]       <= ~saved_be[3:2];
               if(~dmafifo_empty && (lastbank == dmafifo_adr[20:10])) begin
                  cas_addr[8:0]     <= dmafifo_adr[9:1];
                  saved_data        <= dmafifo_data;
                  state             <= STATE_RW1;
                  dmafifo_read      <= 1'b1;
               end else begin
                  state             <= STATE_IDLE_2;  // 2026-07-07: tDAL +1 idle reverted (see RW1)
                  SDRAM_A[10]       <= 1;
               end
            end
            else begin
               state                <= STATE_IDLE_2;  // 2026-07-07: tDAL +1 idle reverted (see RW1)
               SDRAM_A[10]          <= 1;
               SDRAM_A[0]           <= 1;
               command              <= CMD_WRITE;
               SDRAM_DQ             <= saved_data[31:16];
               SDRAM_A[12:11]       <= ~saved_be[3:2];
               ch3_ready_ramclock   <= 1;
            end
         end
      endcase
   
      if (init) begin
         state <= STATE_STARTUP;
         refresh_count <= startup_refresh_max - sdram_startup_cycles;
      end
   end
	else begin
		SDRAM_A <= 'Z;
		SDRAM_BA <= 'Z;
		command <= 'Z;
		chip <= 'Z;
	end   
end

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_sdramclk),   // phase-shifted: shifts SDRAM_CLK vs the FPGA data/cmd outputs (write-timing test)
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(SDRAM_EN),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

endmodule
