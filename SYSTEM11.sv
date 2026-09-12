//============================================================================
//  PSX
//  Copyright (C) 2019 Robert Peip
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign HDMI_FREEZE = 1'b0;
assign HDMI_BOB_DEINT = status[41];

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = bios_download | fixedrom_download | bankedrom_download | sprog_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [ 3:0] frameindex;
wire [11:0] DisplayWidth;
wire [11:0] DisplayHeight;
wire [ 9:0] DisplayOffsetX;
wire [ 8:0] DisplayOffsetY;

assign FB_BASE    = status[11] ? 32'h30000000 : {8'h30, frameindex, DisplayOffsetY, DisplayOffsetX, 1'b0};
assign FB_EN      = (status[14] || video_fbmode);
assign FB_FORMAT  = (status[10] || video_fb24) ? 5'b00101 : 5'b01100;
assign FB_WIDTH   = status[11] ? 12'd1024 : DisplayWidth;
assign FB_HEIGHT  = status[11] ? 12'd512  : DisplayHeight;
assign FB_STRIDE  = 14'd2048;
assign FB_FORCE_BLANK = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_1x;
wire clk_2x;
wire clk_3x;
wire clk_3x_ps;   // clk_3x (101.6MHz) phase-shifted +2460ps (+90deg): drives main SDRAM_CLK to test write/interface timing
wire clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_2x),
	.outclk_2(clk_3x),
	.outclk_3(clk_3x_ps),
	.locked(pll_locked)
);

pll2 pll2
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
   .reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);


wire FFrequest = joy[17] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoOut = 0; //status[57] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoClock = 0; //status[56] && ~FB_LL && ~DIRECT_VIDEO;

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg pdbg = 0, pdbg2 = 0;
	reg pffw = 0, pffw2 = 0;
	reg [3:0] state = 0;

	pald  <= isPal;
	pald2 <= pald;

	pdbg  <= syncVideoClock;
	pdbg2 <= pdbg;

	pffw  <= fast_forward;
	pffw2 <= pffw;

	cfg_write <= 0;
	if(pald2 != pald || pdbg2 != pdbg || pffw2 != pffw) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
         3: begin
					cfg_address <= 5;
					cfg_data <= pffw2 ? 131842 : pdbg2 ? 771 : 1028;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pffw2 ? 2147483648 : pdbg2 ? 551954751 : pald2 ? 2201376898 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg fast_forward;
reg ff_latch;

always @(posedge clk_1x) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= FFrequest;

	if (FFrequest)
		ff_count <= ff_count + 1;

	if (~last_ffw & FFrequest) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~FFrequest)) begin
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (FFrequest | ff_latch);
end

wire reset_or = RESET | buttons[1] | status[0] | ioctl_download | ~ram_cleared;  // hold reset until main RAM zero-filled

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6          7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//  XXXX XXXXXX XXXXXX XXXXX  XX XX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"SYSTEM11;;",
	// Manual "Load ... ROM" OSD entries removed (2026-08-15): every title loads
	// through its MRA, which drives the same ioctl path directly — the menu
	// items only invited broken half-loads. (Same cleanup S12 shipped in its
	// 20260813 release.)
	"-;",
	// "Video & Audio" (P1) hidden 2026-07-06 per request — status bits keep their
	// functions/defaults; re-add these lines to unhide.
	// "P1,Video & Audio;",
	// "P1O[33:32],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	// "P1O[35:34],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	// "DEP1O[62],Fixed HBlank,On,Off;",
	// "DEP1O[55],Fixed VBlank,Off,On;",
	// "d5P1O[4:3],Vertical Crop,Off,On(224/270),On(216/256);",
	// "P1O[67],Horizontal Crop,Off,On;",
	// "P1O[61],Black Transitions,On,Off;",
	// "P1O[41],Deinterlacing,Weave,Bob;",
	// "P1O[89],Render 480i as 480p,Off,On;",
	// "P1O[60],Sync 480i for HDMI,Off,On;",
	// "P1O[24],Rotate,Off,On;",
	// "P1O[22],Dithering,On,Off;",
	// "P1O[8:7],Stereo Mix,None,25%,50%,100%;",
	// The two physical DIP switches (MAME namcos11 "DIP SW2"), named exactly as
	// MAME names them. DIP1 (Test) enters each game's service menu.
	"P2,DIP Switches;",
	"P2O[96],DIP1 (Test),Off,On;",
	"P2O[97],DIP2 (Freeze),Off,On;",
	// Light-gun page (Point Blank 2 / Gunbarl, KEYCUS C443). Sensitivity is exposed rather than
	// guessed: the gun counters span only 688 x 239 units, so a high-DPI mouse saturates them at
	// 1:1. Crosshair defaults OFF — the real cabinet draws none (you aim a physical gun), and
	// keycus 0x09 is shared with My Angel 3, which is not a gun game.
	// H0: the whole page is hidden unless the loaded MRA declares a gun game.
	"H0P4,Light Gun;",
	"H0P4O[100],Crosshair,Off,On;",
	"H0P4O[99:98],Gun Sensitivity,1/4,1/8,1/2,1/1;",
	// GITHUB output template (2026-09-01): the Debug OSD page (FPS counter, boot
	// debug overlay, test/service toggles) is excluded from this edition.
	"-;",
	// Policy rev 4 (2026-09-02): opening the OSD no longer pauses the core by
	// default; this option opts back in. status[64] polarity is chosen so the
	// power-on/unset value (0) is Off — the pause gate below tests status[64]
	// directly (it was ~status[64] when pausing was the unconditional default).
	"O[64],Pause when OSD is open,Off,On;",
	"-;",
	"R0,Reset;",
	// Service (joy[13]) is the cabinet SERVICE1 button (service credit / service-menu
	// navigation), a game input like Coin — per-game labels come from each MRA's
	// <buttons> tag.
	"J1,Button1,Button2,Button3,Button4,Button5,Button6,Start,Coin,Pause,Service;",
	"jn,A,B,X,Y,L,R,Start,Select,L3,R3;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [127:0] status;
// Bit 0 hides the Light Gun OSD page (H0 prefix) for every game whose MRA does
// not declare itself a gun game — light-gun support must not be offered to
// games that don't natively have it.
wire [15:0] status_menumask = {15'd0, ~zn_gun_game};
wire        forced_scandoubler;
reg  [31:0] sd_lba0 = 0;
reg  [31:0] sd_lba1;
reg  [ 6:0] sd_lba2;
reg  [ 6:0] sd_lba3;
reg   [3:0] sd_rd;
reg   [3:0] sd_wr;
wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din2;
wire [15:0] sd_buff_din3;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
// nvram (AT28C16 EEPROM / settings) save path
wire        ioctl_upload;
wire [15:0] ioctl_din;
reg         ioctl_upload_req = 0;
wire  [7:0] ioctl_upload_index = 8'd9;   // nvram is MRA index 9
wire [31:0] ee_up_q;                     // EEPROM BRAM word read-back (from zn1_io) for the save
wire        ee_wr_pulse;                 // MIPS wrote the EEPROM (debounced below to request a save)
reg         ioctl_wait = 0;

wire [19:0] joy;
wire [19:0] joy_unmod;
wire [19:0] joy2;
wire [19:0] joy3;
wire [19:0] joy4;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_r0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_r1;
wire [15:0] joystick_analog_l2;
wire [15:0] joystick_analog_r2;
wire [15:0] joystick_analog_l3;
wire [15:0] joystick_analog_r3;

wire [7:0] paddle_0;

wire [24:0] mouse;

wire [15:0] joystick1_rumble;
wire [15:0] joystick2_rumble;
wire [15:0] joystick3_rumble;
wire [15:0] joystick4_rumble;
wire [32:0] RTC_time;

wire filter_on = (status[82:81] == 2'b00) ? 1'b0 : 1'b1;

assign HDMI_BLACKOUT = ~status[61];

wire [127:0] status_in = {status[127:39],ss_slot,status[36:19], 2'b00, status[16:0]};

wire bk_pending = 1'b0;
wire saving_memcard = 1'b0;
wire DIRECT_VIDEO;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(4), .BLKSZ(3)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(EXT_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(statusUpdate),
	.status_menumask(status_menumask),
	.info_req(psx_info_req),
	.info(psx_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	// nvram (EEPROM/settings) save path
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_upload_index(ioctl_upload_index),
	.ioctl_din(ioctl_din),

	.sd_lba('{sd_lba0, sd_lba1, sd_lba2, sd_lba3}),
	.sd_blk_cnt('{0,0, 0, 0}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{0, 0, sd_buff_din2, sd_buff_din3}),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_l_analog_0(joystick_analog_l0),
   .joystick_r_analog_0(joystick_analog_r0),
   .joystick_l_analog_1(joystick_analog_l1),
   .joystick_r_analog_1(joystick_analog_r1),
   .joystick_l_analog_2(joystick_analog_l2),
   .joystick_r_analog_2(joystick_analog_r2),
   .joystick_l_analog_3(joystick_analog_l3),
   .joystick_r_analog_3(joystick_analog_r3),
   .ps2_mouse(mouse),
   .joystick_0_rumble(paused ? 16'h0000 : joystick1_rumble),
   .joystick_1_rumble(paused ? 16'h0000 : joystick2_rumble),

   .paddle_0(paddle_0),

   .direct_video(DIRECT_VIDEO)
);

assign joy = joy_unmod[16] ? 20'b0 : joy_unmod;

assign sd_rd[0] = 0;
assign sd_wr[0] = 0;

assign sd_wr[1] = 0;

wire [35:0] EXT_BUS;
wire        heartbeat;

hps_ext hps_ext
(
	.clk_sys(clk_1x),
	.EXT_BUS(EXT_BUS),
	.heartbeat(heartbeat)
);


//////////////////////////  ROM DETECT  /////////////////////////////////

// SDRAM layout (25-bit byte address, flat):
//   0x0000000-0x03FFFFF: Main RAM   (4MB)
//   0x0400000-0x047FFFF: BIOS       (512KB) — ioctl_index 0, CPU 0x1FC00000
//   0x0480000-0x06FFFFF: Fixed ROM  (2.5MB) — ioctl_index 2, CPU 0x1F000000
//   0x0800000-0x3FFFFFF: Banked ROM (up to 56MB, 7 banks×8MB) — ioctl_index 3, CPU 0x1F000000
localparam BIOS_START      = 27'h0400000;
localparam FIXEDROM_START  = 27'h0480000;
localparam BANKEDROM_START = 27'h0800000;
// SPROG/WAVE sit above the largest System 11 banked ROM (rom8_64 = 32MB ends at
// 0x2800000 exactly). Old bases 0x1800000/0x1840000 collided with banked ROMs
// >16MB (My Angel 3). Wave ends at 0x2C40000 -> needs a >=64MB SDRAM module.
localparam SPROG_START     = 27'h2800000;  // System 11 C76 SPROG (256KB), after banked ROM
localparam WAVE_START      = 27'h2840000;  // System 11 C352 wave ROM (up to 4MB), after SPROG

reg bios_download, fixedrom_download, bankedrom_download, code_download, sprog_download;
reg c76bios_download;
// C76 internal BIOS byte writer: 16-bit ioctl words -> two byte writes into the c76 BIOS BRAM
reg        c76bios_pend = 0;
reg [13:0] c76bios_addr;
reg [15:0] c76bios_word;
reg        c76bios_wr = 0;
always @(posedge clk_1x) begin
   c76bios_wr <= 0;
   if (c76bios_download & ioctl_wr) begin
      c76bios_addr <= ioctl_addr[13:0];
      c76bios_word <= ioctl_dout;
      c76bios_wr   <= 1;
      c76bios_pend <= 1;
   end else if (c76bios_pend) begin
      c76bios_addr <= c76bios_addr | 14'd1;
      c76bios_word <= {8'h00, c76bios_word[15:8]};
      c76bios_wr   <= 1;
      c76bios_pend <= 0;
   end
end
reg        wave_download       = 0;
// ---------------------------------------------------------------------------
// EEPROM / nvram (AT28C16 settings) LOAD + SAVE.
// MRA index 9 is now an <nvram size="4096"> (was an all-FF <rom>). On a fresh
// board no .nvram exists so nothing is downloaded and the BRAM keeps its all-FF
// init (eeprom_ff.mif). If a saved .nvram exists the framework downloads it here.
// WIDE(1): each ioctl_wr carries a 16-bit halfword; ioctl_addr[1] picks lo/hi of
// the 32-bit BRAM word, so accumulate the low half then write the full word.
reg        eeprom_download     = 0;
reg        ee_dl_wr   = 0;
reg [9:0]  ee_dl_addr;
reg [31:0] ee_dl_data;
reg [15:0] ee_dl_lo;
always @(posedge clk_1x) begin
	ee_dl_wr <= 0;
	if (eeprom_download & ioctl_wr) begin
		if (~ioctl_addr[1]) begin
			ee_dl_lo <= ioctl_dout;                 // low halfword of the word
		end else begin
			ee_dl_addr <= ioctl_addr[11:2];
			ee_dl_data <= {ioctl_dout, ee_dl_lo};   // {hi, lo} -> full 32-bit word
			ee_dl_wr   <= 1;
		end
	end
end

// nvram SAVE read-back: during an index-9 upload, mux the EEPROM BRAM read address
// to ioctl_addr and return the selected halfword. SPI byte cadence >> the M10K read
// latency, so the word is settled by the time hps_io samples ioctl_din.
wire       ee_up_rd   = ioctl_upload & (ioctl_index == 8'd9);
wire [9:0] ee_up_addr = ioctl_addr[11:2];
assign     ioctl_din  = ee_up_rd ? (ioctl_addr[1] ? ee_up_q[31:16] : ee_up_q[15:0]) : 16'h0000;

// Auto-save trigger: ~1.5 s after the LAST EEPROM write settles, pulse ioctl_upload_req
// so a batch of setting changes results in a single .nvram write-back. clk_1x ~ 33 MHz.
localparam [26:0] EE_SAVE_DELAY = 27'd50_000_000;   // ~1.5 s
reg [26:0] ee_save_timer = 0;
always @(posedge clk_1x) begin
	ioctl_upload_req <= 0;
	if (ee_wr_pulse) begin
		ee_save_timer <= EE_SAVE_DELAY;             // (re)arm on each write
	end else if (ee_save_timer != 0) begin
		ee_save_timer <= ee_save_timer - 1'd1;
		if (ee_save_timer == 27'd1) ioctl_upload_req <= 1;   // fire once when it expires
	end
end
always @(posedge clk_1x) begin
	bios_download       <= ioctl_download & (ioctl_index[5:0] == 0);
	fixedrom_download   <= ioctl_download & (ioctl_index == 2);
	bankedrom_download  <= ioctl_download & (ioctl_index == 3);
	sprog_download      <= ioctl_download & (ioctl_index == 6);  // System 11 C76 SPROG
	wave_download       <= ioctl_download & (ioctl_index == 7);  // System 11 C352 wave ROM
	c76bios_download    <= ioctl_download & (ioctl_index == 8);  // C76 internal BIOS (namcoc76.zip c76.bin) -> c76 BRAM
	eeprom_download     <= ioctl_download & (ioctl_index == 9);  // EEPROM all-FF blank -> zn1_io EEPROM BRAM
	code_download       <= ioctl_download & (ioctl_index == 255);
end

// Dynamic platform config and CAT702 key loading (from MRA rom index 1/4/5)
reg [7:0]  zn_platform_r  = 8'h00;              // ioctl_index 1: platform id (0=Visco, 1=Raizing, 2=Taito, 3=Atlus, 4=Tecmo)
reg [7:0]  zn_keycus_id   = 8'h00;              // ioctl_index 1 byte[1]: KEYCUS type (0=none/Tekken1, 1=C406/Tekken2)
reg        zn_gun_game    = 1'b0;               // ioctl_index 1 byte[2] bit0: this MRA is a light-gun game (Point Blank 2 / Gunbarl)
// CAT702 security keys — NO baked-in key data (blank default, all zero).
// System 11 (Tekken/Soul Edge/etc.) does NOT use CAT702 at all — its protection
// is the KEYCUS C-chip (C406/C409), handled via zn_keycus_id. CAT702 is a ZN-1
// feature inherited from the ZN-1 base; ZN-1 game MRAs load the real 8-byte keys
// at runtime from their own ROM zips (index 4 = motherboard/KN01, index 5 =
// game/KN02, e.g. coh1002e.zip:et01.ic652). Nothing manufacturer-derived ships
// in the bitstream; keys come only from the game/BIOS zip the user provides.
reg [63:0] zn_cat702_key_a  = 64'h0;
reg [63:0] zn_cat702_key_b_r = 64'h0;

always @(posedge clk_1x) begin
	if (ioctl_wr) begin
		if (ioctl_index[5:0] == 1) begin
			// Word 0: byte0 = platform id, byte1 = KEYCUS type. Word 1 (optional,
			// 4-byte MRAs): byte2 bit0 = light-gun game. The gun flag exists because
			// KEYCUS C443 (0x09) is shared between Point Blank 2/Gunbarl (gun games)
			// and My Angel 3 (a quiz game) — the keycus alone cannot gate gun support.
			if (ioctl_addr[2:1] == 2'd0) begin
				zn_platform_r <= ioctl_dout[7:0];
				zn_keycus_id  <= ioctl_dout[15:8];   // 0 for old single-byte MRAs
			end else if (ioctl_addr[2:1] == 2'd1) begin
				zn_gun_game   <= ioctl_dout[0];
			end
		end else if (ioctl_index[5:0] == 4) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_a[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_a[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_a[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_a[63:48] <= ioctl_dout;
			endcase
		end else if (ioctl_index[5:0] == 5) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_b_r[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_b_r[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_b_r[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_b_r[63:48] <= ioctl_dout;
			endcase
		end
	end
end

// exe_download stub (unused in ZN, retained for save-state UI compatibility)
wire exe_download = 1'b0;

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (fixedrom_download || bankedrom_download) cart_loaded <= 1;
end

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

// ZN uses no CD
wire hasCD = 1'b0;

// loadExe and EXE header fields unused in ZN (no .EXE loading)
wire loadExe = 1'b0;
wire [31:0] exe_initial_pc    = 32'h0;
wire [31:0] exe_initial_gp    = 32'h0;
wire [31:0] exe_load_address  = 32'h0;
wire [31:0] exe_file_size     = 32'h0;
wire [31:0] exe_stackpointer  = 32'h0;

reg  [1:0] biosregion;
wire [1:0] region_out;
reg        isPal;

// ZN-1 Visco: NTSC-J (region JP)
always @(posedge clk_1x) begin
   isPal     <= 1'b0;
   biosregion <= 2'b01;  // JP BIOS
end

always @(posedge clk_1x) begin
   ramdownload_wr <= 0;
   if (bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) begin
      if (ioctl_wr) begin
         if (~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)
               // BIOS/program: SDRAM 0x400000 base (bit22, no overlap -> OR). ALWAYS
               // 22-bit (4MB) offset: the <=512KB ZN-1 BIOS fits, and System 11's 4MB
               // program needs it. CRITICAL: must NOT gate on zn_platform_r[4] here --
               // that flag is loaded from MRA index 1, which downloads AFTER the index-0
               // program, so it's still 0 during this download; gating truncated the
               // System 11 program to 512KB and wrapped/corrupted it onto itself.
               ramdownload_wraddr <= BIOS_START[26:0] | {5'b0, ioctl_addr[21:0]};
            else if (fixedrom_download)
               // Fixed ROM: SDRAM 0x480000 base (addition to handle overlapping bits)
               ramdownload_wraddr <= FIXEDROM_START[26:0] + {4'b0000, ioctl_addr[22:0]};
            else if (sprog_download)
               // System 11 C76 SPROG: SDRAM 0x2800000 base, 256KB (bits 25/23, no overlap -> OR)
               ramdownload_wraddr <= SPROG_START[26:0] | {9'b0, ioctl_addr[17:0]};
            else if (wave_download)
               // System 11 C352 wave ROM: SDRAM 0x2840000 base, up to 4MB (base bit18 set -> ADD)
               ramdownload_wraddr <= WAVE_START[26:0] + {5'b0, ioctl_addr[21:0]};
            else
               // Banked ROM: SDRAM 0x800000 base, 24 banks × 1MB = 24MB
               ramdownload_wraddr <= BANKEDROM_START[26:0] + ioctl_addr[26:0];
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait                <= 1;
         end
      end
      if (sdramCh3_done) ioctl_wait <= 0;
   end else begin
      ioctl_wait <= 0;
   end
end

// GITHUB output template (2026-09-02): the SDRAM write/read diagnostic capture
// latches that lived here (download-word, ch1-readback, OT-tail write monitors)
// were debug instrumentation and are excluded from this edition.

///////////////////////////  SAVESTATE  /////////////////////////////////

wire [1:0] ss_slot;
wire [7:0] ss_info;
wire [3:0] validSStates;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_1x        ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_loaded   ),
	.joySS          (joy_unmod[16] ),
	.joyRight       (joy_unmod[0]  ),
	.joyLeft        (joy_unmod[1]  ),
	.joyDown        (joy_unmod[2]  ),
	.joyUp          (joy_unmod[3]  ),
	.joyRewind      (0             ),
	.rewindEnable   (0             ),
	.status_slot    (status[38:37] ),
	.autoincslot    (status[68]    ),
	.OSD_saveload   (status[18:17] ),
   .validSStates   (validSStates  ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

////////////////////////////  PAD  ///////////////////////////////////

// 0000 -> DualShock
// 0001 -> off
// 0010 -> digital
// 0011 -> analog
// 0100 -> Namco GunCon lightgun
// 0101 -> Namco NeGcon
// 0110 -> Wheel Negcon
// 0111 -> Wheel Analog
// 1000 -> mouse
// 1001 -> Konami Justifier lightgun
// 1010 -> SNAC
// 1011 -> Analog Joystick
// 1100..1111 -> reserved

wire PadPortDS1      = (status[48:45] == 4'b0000);
wire PadPortEnable1  = (status[48:45] != 4'b0001);
wire PadPortDigital1 = (status[48:45] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog1  = (status[48:45] == 4'b0011) || (status[48:45] == 4'b0111);
wire PadPortGunCon1  = (status[48:45] == 4'b0100);
wire PadPortNeGcon1  = (status[48:45] == 4'b0101) || (status[48:45] == 4'b0110);
wire PadPortWheel1   = (status[48:45] == 4'b0110) || (status[48:45] == 4'b0111);
wire PadPortMouse1   = (status[48:45] == 4'b1000);
wire PadPortJustif1  = (status[48:45] == 4'b1001);
wire snacPort1       = (status[48:45] == 4'b1010) && ~multitap;
wire PadPortStick1   = (status[48:45] == 4'b1011);
wire PadPortPopn1    = (status[48:45] == 4'b1100);

wire PadPortDS2      = (status[52:49] == 4'b0000);
wire PadPortEnable2  = (status[52:49] != 4'b0001) && ~multitap;
wire PadPortDigital2 = (status[52:49] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog2  = (status[52:49] == 4'b0011) || (status[52:49] == 4'b0111);
wire PadPortGunCon2  = (status[52:49] == 4'b0100);
wire PadPortNeGcon2  = (status[52:49] == 4'b0101) || (status[52:49] == 4'b0110);
wire PadPortWheel2   = (status[52:49] == 4'b0110) || (status[52:49] == 4'b0111);
wire PadPortMouse2   = (status[52:49] == 4'b1000);
wire PadPortJustif2  = (status[52:49] == 4'b1001);
wire snacPort2       = (status[52:49] == 4'b1010) && ~multitap;
wire PadPortStick2   = (status[52:49] == 4'b1011);
wire PadPortPopn2    = (status[52:49] == 4'b1100);

reg paddleMode = 0;
reg paddleMin = 0;
reg paddleMax = 0;
wire [7:0] joy0_xmuxed = (paddleMode) ? (paddle_0 - 8'd128) : joystick_analog_l0[7:0];

// to activate paddleMode negcon mode must be active and paddle must best moved
always @(posedge clk_1x) begin
   if (PadPortNeGcon1) begin
      if (paddle_0 < 112) paddleMin <= 1'b1;
      if (paddle_0 > 144) paddleMax <= 1'b1;
      if (paddleMin && paddleMax) paddleMode <= 1'b1;
   end else begin
      paddleMode <= 0;
      paddleMin <= 0;
      paddleMax <= 0;
   end
end

// 00 -> multitap off
// 01 -> port1, 4 x digital
// 10 -> port1, 4 x analog
wire multitap        = (status[57:56] != 2'b00);
wire multitapDigital = (status[57:56] == 2'b01);
wire multitapAnalog  = (status[57:56] == 2'b10);

wire [1:0] padMode;
reg  [1:0] padMode_1;

reg [7:0] psx_info;
reg psx_info_req;

wire resetFromCD = 1'b0;

reg [3:0] ToggleDS = 0;
reg [3:0] joy19_1 = 0;

always @(posedge clk_1x) begin

   psx_info_req <= 0;
   padMode_1    <= padMode;

   if (ss_info_req) begin
      psx_info_req <= 1;
      psx_info     <= ss_info;
   end


   // DS toggle (unused in arcade but kept for joypad struct compatibility)
   joy19_1 <= {joy4[19] ,joy3[19] ,joy2[19] ,joy[19] };
   ToggleDS[0] <=  joy[19] & ~joy19_1[0];
   ToggleDS[1] <= joy2[19] & ~joy19_1[1];
   ToggleDS[2] <= joy3[19] & ~joy19_1[2];
   ToggleDS[3] <= joy4[19] & ~joy19_1[3];

end

////////////////////////////  PAUSE and RESET  ///////////////////////////
reg paused = 0;
reg [9:0] unpause = 0;
reg status1_1;
wire isPaused;

reg [20:0] aliveCnt = 0;
reg heartbeat_1 = 0;
reg hps_busy = 0;

reg reset = 0;

reg buttonpause_1 = 0;
reg button_paused = 0;

reg TURBO_MEM;
reg TURBO_COMP;
reg TURBO_CACHE;
reg TURBO_CACHE50;

always @(posedge clk_1x) begin

   paused <= 0;

   // pause from OSD open — only when the "Pause when OSD is open" option is On
   // (status[64]; default Off per policy rev 4, so the game keeps running under
   // an open OSD unless the user opts in)
   if (status[64] & OSD_STATUS & (unpause == 0)) begin
      paused <= 1;
   end

   // pause from button — joy[12] = Pause button (J1 list index 8 = 9th entry)
   // J1 mapping: Button1..6 at joy[4..9], Start at joy[10], Coin at joy[11], Pause at joy[12]
   buttonpause_1 <= joy[12];
   if (joy[12] & ~buttonpause_1) begin
      button_paused <= ~button_paused;
   end
   if (button_paused) begin
      paused <= 1;
   end

   // Advance Pause OSD trigger
   status1_1 <= status[1];
   if (status[1] & ~status1_1) begin
      unpause <= 1023;
   end else if (unpause > 0) begin
      unpause <= unpause - 1'd1;
   end

   // pause from heartbeat -> only used for savestate
   hps_busy    <= 0;
   heartbeat_1 <= heartbeat;
   if (heartbeat == heartbeat_1) begin
      if (aliveCnt[20] == 0) begin
         aliveCnt <= aliveCnt + 1'b1;
      end else begin
         hps_busy <= 1;
      end
   end else begin
      aliveCnt <= 0;
   end

   // reset
   reset <= 0;
   if (reset_or) begin
      reset    <= 1;
      aliveCnt <= 0;
   end

   // 1 => low    -> only MEM
   // 2 => medium -> MEM + 50% cache
   // 3 => high   -> everything
   TURBO_MEM      <= status[80:79] > 0;
   TURBO_COMP     <= status[80:79] == 2'b11;
   // 2026-06-28: FORCE data cache OFF. The R3000A in System 11 has NO main-RAM data cache (the D-cache
   // silicon is the 1KB scratchpad); TURBO_CACHE is a non-architectural emulator speedup whose 128-bit
   // fills / coherency are the source of the residual read corruption (corrupt OT-head ptr, cpu2vram
   // size words). Real hardware reads uncached -> reliable single reads. Slower but accurate.
   TURBO_CACHE    <= 1'b0;
   TURBO_CACHE50  <= 1'b0;

end

////////////////////////////  SYSTEM  ///////////////////////////////////

// ===== Namco System 11 sound subsystem (C76 M37702 + C352 PCM) =====
// First integration: the C76 runs its internal BIOS (idles, no mailbox yet);
// the C352 output is mixed into the PSX audio. Mailbox/ROM wiring + the
// System 11 MIPS memory map come next.
wire signed [15:0] psx_aud_l, psx_aud_r;
wire        [15:0] c352_aud_l, c352_aud_r;

reg c76_ce = 1'b0;
always @(posedge clk_1x) c76_ce <= ~c76_ce;          // C76 ~ clk_1x/2

reg [8:0] snd_div = 9'd0;
reg       snd_sample_ce = 1'b0;
always @(posedge clk_1x) begin                        // C352 sample tick (~88 kHz)
   snd_sample_ce <= 1'b0;
   if (snd_div == 9'd383) begin snd_div <= 9'd0; snd_sample_ce <= 1'b1; end
   else snd_div <= snd_div + 1'b1;
end

// System 11 C76 shared-RAM mailbox (16-bit MIPS word side), from psx_mister
wire [13:0] mb_mips_addr;
wire [15:0] mb_mips_wdata;
wire        mb_mips_we;
wire [15:0] mb_mips_rdata;

// System 11 C76 SPROG (program ROM) reader: c76_sound <-> SDRAM via ch3 (cheats are
// disabled in S11 so ch3 is free after download). C76 byte reads, latency-tolerant.
// (SPROG_START localparam is declared with the other SDRAM region constants above.)
wire [19:0] c76_sprog_addr;                    // C76 byte address (from c76_sound)
wire        c76_sprog_rd;                      // C76 read strobe (level, held until ready)
reg  [7:0]  c76_sprog_data  = 8'h00;           // byte returned to c76_sound
reg  [31:0] dbg_sprog_hdr   = 32'h00000000;    // DIAG: SPROG header word @byte 0x100 (low16 should=0x5500)
reg  [19:0] sprog_fetched   = 20'h00000;       // byte address the held c76_sprog_data is valid for
// ready is COMBINATIONAL + gated on the requested address matching the fetched byte. The M37702
// does 16-bit reads as back-to-back byte reads (ea, ea+1) holding rd asserted, so a level/rd-toggle
// handshake returns the STALE low byte for ea+1 (broke the SPROG 0x200100 signature read). Gating
// ready on the address forces a re-fetch when the M37702 advances to the next byte.
wire        c76_sprog_ready = (sprog_st == 2'd2) && (c76_sprog_addr[19:0] == sprog_fetched);
reg  [26:0] c76_sprog_sdaddr;                  // ch3 word-aligned byte address
reg         c76_sprog_req   = 1'b0;            // ch3 request (pulse)
reg  [1:0]  sprog_st        = 2'd0;            // reader FSM state
reg  [1:0]  sprog_bsel      = 2'd0;            // which byte of the 32-bit ch3 word
// C352 wave-ROM reader (2026-07-06): same ch3 mechanism as SPROG, mutually exclusive
// with it (only one ch3 request in flight; SPROG has priority — it gates C76 execution).
// ★ 2026-07-11 WORD SERVICE: the c352 fetch adapter now requests word-aligned 32-bit
// words (per-voice line cache inside c352.vhd) — hand back the whole ch3 word instead
// of byte-selecting it. wave_fetched init 24'hFFFFFF can never match a word-aligned
// address, so the first request always fetches.
wire [23:0] c76_wave_addr;                     // word-aligned ([1:0]==00) from c352
wire        c76_wave_rd;
reg  [31:0] c76_wave_data   = 32'h0;
reg  [23:0] wave_fetched    = 24'hFFFFFF;
wire        c76_wave_ready  = (wave_st == 2'd2) && (c76_wave_addr == wave_fetched);
reg  [26:0] c76_wave_sdaddr = 27'd0;
reg         c76_wave_req    = 1'b0;
reg  [1:0]  wave_st         = 2'd0;
// ★ 2026-07-11 CH3 ADDRESS-HOLD FIX (root cause of the gameplay audio static):
// sdram.sv re-registers ch3buf_addr from ch3_addr EVERY ram clock until the arbiter
// GRANTS the request (fixed priority ch1>ch2>ch3, so under CPU/GPU load the grant can
// be hundreds of clk_base late). The ch3 address mux used the 1-cycle c76_wave_req
// PULSE as its select, so any grant later than ~1 clk_1x re-pointed the pending wave
// read at c76_sprog_sdaddr — the C352 then decoded C76 PROGRAM bytes as PCM samples.
// That is exactly "static that scales with SDRAM traffic and lessens when the OSD
// pause gates the MIPS/GPU". Own the mux for the WHOLE transaction (wave_st==1).
wire        wave_ch3_own    = c76_wave_req | (wave_st == 2'd1);
reg         c76_ever_sprog      = 1'b0;        // diag: C76 ever requested a SPROG read (=C76 running)
reg         c76_sprog_done_ever = 1'b0;        // diag: a ch3 SPROG read ever completed

// ===== System 11 GUN I/F aiming (Point Blank 2 / Gunbarl, KEYCUS C443) =====
// The System 11 gun is NOT a scanline-sensing lightgun: the GUN I/F PCB just presents absolute
// X/Y counters at 0x1F780000 (MAME namcos11.cpp lightgun_r). So aiming reduces to maintaining an
// absolute position in the hardware's own counter units and clamping to MAME's legal spans:
//   GUN1X 0x0D8..0x387 (centre 0x22F)      GUN1Y 0x02C..0x11B (centre 0x0A8)
// PS/2 mice report RELATIVE deltas, so accumulate one step per mouse packet (mouse[24] toggles).
// Note PS/2 +Y is UP while screen Y grows DOWN, hence the subtraction.
// SENSITIVITY (2026-07-26): accumulating raw PS/2 deltas 1:1 pinned the pointer at the range
// extremes on a high-DPI mouse (measured: gun_x stuck at 0x387 = MAX, gun_y at 0x02C = MIN).
// Scale the deltas down, but keep 4 FRACTIONAL bits in the accumulator so slow, fine movements
// still register instead of being truncated to zero. Divisor is OSD-selectable because it depends
// on the user's mouse DPI, which we cannot know.
// REDESIGN 2026-07-26 (crosshair was offset from the shots): the pointer is now canonical in a
// RESOLUTION-INDEPENDENT virtual screen (1024 x 256), and BOTH the gun counters and the crosshair
// are derived from it. Previously the pointer lived in gun-counter units and the crosshair assumed
// those mapped 1:1 onto the active area — true only if the display were exactly 688x240, which it
// is not, so the crosshair drifted away from the actual aim point.
// Virtual width/height are powers of two, so every divide below is a constant SHIFT:
//   gun_x = 216 + (px*687 >> 10)   gun_y = 44 + (py*239 >> 8)     (constant multiplies)
//   screen  = (px*h_act >> 10),  (py*v_act >> 8)                  (one mult each, once per frame)
// The crosshair therefore lands exactly where the gun points, by construction, at any resolution.
localparam [13:0] PXMAX_F = 14'd1023 << 4;        // 10.4 fixed point
localparam [11:0] PYMAX_F = 12'd255  << 4;        // 8.4 fixed point
reg         [13:0] px_f       = 14'd512 << 4;     // centre
reg         [11:0] py_f       = 12'd128 << 4;
reg                mouse_ev_d = 1'b0;
wire signed  [8:0] ms_dx      = {mouse[4], mouse[15:8]};
wire signed  [8:0] ms_dy      = {mouse[5], mouse[23:16]};
// OSD 0=1/4 (default) 1=1/8 2=1/2 3=1/1 -> left-shift of the 4-bit fraction
wire         [2:0] gun_lsh    = (status[99:98] == 2'd0) ? 3'd2 :
                                (status[99:98] == 2'd1) ? 3'd1 :
                                (status[99:98] == 2'd2) ? 3'd3 : 3'd4;
wire signed [15:0] dx_f       = $signed({{7{ms_dx[8]}}, ms_dx}) <<< gun_lsh;
wire signed [15:0] dy_f       = $signed({{7{ms_dy[8]}}, ms_dy}) <<< gun_lsh;
wire signed [16:0] nx_f       = $signed({3'b0, px_f}) + dx_f;
wire signed [16:0] ny_f       = $signed({5'b0, py_f}) - dy_f;   // PS/2 +Y is UP, screen Y grows DOWN
always @(posedge clk_1x) begin
   mouse_ev_d <= mouse[24];
   if (mouse_ev_d != mouse[24]) begin              // one update per mouse packet
      px_f <= (nx_f < 0) ? 14'd0 : (nx_f > $signed({3'b0, PXMAX_F})) ? PXMAX_F : nx_f[13:0];
      py_f <= (ny_f < 0) ? 12'd0 : (ny_f > $signed({5'b0, PYMAX_F})) ? PYMAX_F : ny_f[11:0];
   end
end
wire  [9:0] gun_px = px_f[13:4];                   // 0..1023 virtual
wire  [7:0] gun_py = py_f[11:4];                   // 0..255  virtual
wire [19:0] gx_mul = gun_px * 10'd687;
wire [15:0] gy_mul = gun_py * 8'd239;
wire signed [15:0] gun_x = 16'sd216 + $signed({6'b0, gx_mul[19:10]});   // 216..903
wire signed [15:0] gun_y = 16'sd44  + $signed({8'b0, gy_mul[15:8]});    // 44..283
// Trigger: mouse LEFT acts as BUTTON1, which is exactly what MAME's ptblank2 PORT_MODIFY leaves
// live on PLAYER1 (0x10). Button1 on a pad already works, so this only adds the mouse.
wire gun_trigger = mouse[0];

// ===== P2 light gun pointer (2026-07-26) =====
// Point Blank 2 / Gunbarl are 2-PLAYER games: MAME defines GUN2X/GUN2Y with exactly the same
// spans as GUN1 (X 0xd8..0x387, Y 0x2c..0x11b, centres 0x22f/0xa8) and keeps PLAYER2 bit 0x10
// live as P2's trigger. Until now zn_gun2_x/y were tied to the P1 pointer, so both guns aimed at
// the same spot and co-op was impossible.
// WHY THE STICK AND NOT A SECOND MOUSE: hps_io exposes exactly ONE PS/2 stream (`ps2_mouse`) --
// the HPS merges every physical mouse into it -- so a second mouse is not reachable from the
// core. The P2 pad's left analog stick is the only independent pointing device available.
// WHY VELOCITY AND NOT ABSOLUTE: a self-centring stick mapped straight to an absolute position
// would snap the crosshair back to screen centre the moment you let go, which is useless for
// aiming. Integrating deflection as a VELOCITY makes it behave like a trackball -- hold to glide,
// release to hold position.
// POLARITY: MiSTer analog axes follow the SDL/evdev convention, so stick UP is NEGATIVE Y. Screen
// Y also grows downward, so P2 needs NO Y inversion (unlike the PS/2 mouse above, whose +Y is up).
// Pointer lives in the SAME virtual 1024x256 space as P1, so it inherits the resolution-
// independent crosshair mapping for free.
wire signed [7:0] p2_sx_raw = joystick_analog_l1[7:0];
wire signed [7:0] p2_sy_raw = joystick_analog_l1[15:8];
// Deadzone: sticks rest a few counts off centre, and without this the crosshair would creep
// across the screen forever while untouched.
wire signed [7:0] p2_ax = (p2_sx_raw > 8'sd12 || p2_sx_raw < -8'sd12) ? p2_sx_raw : 8'sd0;
wire signed [7:0] p2_ay = (p2_sy_raw > 8'sd12 || p2_sy_raw < -8'sd12) ? p2_sy_raw : 8'sd0;
// DIGITAL D-PAD FALLBACK: on an arcade core P2 is very likely on a digital stick with no analog
// axes at all, and without this they could not aim AT ALL. Synthesise a 3/4-deflection when a
// direction is held and the analog stick is idle (analog always wins if it is deflected), which
// is the same pattern used for the Pocket Racer steering ramp. joy2[3]=UP [2]=DOWN [1]=LEFT
// [0]=RIGHT; screen Y grows down, so UP must be NEGATIVE.
wire signed [7:0] p2_dpx = joy2[0] ? 8'sd96 : joy2[1] ? -8'sd96 : 8'sd0;
wire signed [7:0] p2_dpy = joy2[2] ? 8'sd96 : joy2[3] ? -8'sd96 : 8'sd0;
wire signed [7:0] p2_sx  = (p2_ax != 8'sd0) ? p2_ax : p2_dpx;
wire signed [7:0] p2_sy  = (p2_ay != 8'sd0) ? p2_ay : p2_dpy;
// Same OSD sensitivity control as the mouse, as a velocity divider. Default (1/4) crosses the
// screen in ~1.0 s at full deflection; 1/1 in ~0.26 s.
wire        [2:0] p2_rsh = (status[99:98] == 2'd0) ? 3'd3 :
                           (status[99:98] == 2'd1) ? 3'd4 :
                           (status[99:98] == 2'd2) ? 3'd2 : 3'd1;
wire signed [15:0] p2_dx = $signed({{8{p2_sx[7]}}, p2_sx}) >>> p2_rsh;
wire signed [15:0] p2_dy = $signed({{8{p2_sy[7]}}, p2_sy}) >>> p2_rsh;
reg         [14:0] p2_tick_cnt  = 15'd0;         // 33.87 MHz / 32768 => ~1.03 kHz update
reg         [13:0] p2x_f = 14'd512 << 4;         // 10.4 fixed point, centre
reg         [11:0] p2y_f = 12'd128 << 4;         //  8.4 fixed point, centre
reg                p2_gun_active = 1'b0;         // gates the P2 crosshair until P2 shows up
wire signed [16:0] p2nx_f = $signed({3'b0, p2x_f}) + p2_dx;
wire signed [16:0] p2ny_f = $signed({5'b0, p2y_f}) + p2_dy;
always @(posedge clk_1x) begin
   p2_tick_cnt <= p2_tick_cnt + 15'd1;
   if (p2_tick_cnt == 15'd0) begin
      p2x_f <= (p2nx_f < 0) ? 14'd0 : (p2nx_f > $signed({3'b0, PXMAX_F})) ? PXMAX_F : p2nx_f[13:0];
      p2y_f <= (p2ny_f < 0) ? 12'd0 : (p2ny_f > $signed({5'b0, PYMAX_F})) ? PYMAX_F : p2ny_f[11:0];
   end
   // Latch "a second player is here" on first stick deflection or trigger pull, so a solo player
   // never sees a stray second crosshair parked in the middle of the screen.
   if ((p2_sx != 8'sd0) || (p2_sy != 8'sd0) || joy2[4]) p2_gun_active <= 1'b1;
end
// Titles that use MAME's BASE namcos11 port set, where ADC0/1/2 belong to PLAYER 3 (see the
// in_adc1/in_adc2 comment at the c76_sound instance). Everything else PORT_MODIFYs those channels.
wire zn_generic_adc = (zn_keycus_id == 8'h03)    // Dunk Mania
                    | (zn_keycus_id == 8'h05)    // Xevious 3D-G
                    | (zn_keycus_id == 8'h06)    // Dancing Eyes
                    | (zn_keycus_id == 8'h08);   // Star Sweep

wire  [9:0] gun2_px = p2x_f[13:4];                  // 0..1023 virtual
wire  [7:0] gun2_py = p2y_f[11:4];                  // 0..255  virtual
wire [19:0] g2x_mul = gun2_px * 10'd687;
wire [15:0] g2y_mul = gun2_py * 8'd239;
wire signed [15:0] gun2_x = 16'sd216 + $signed({6'b0, g2x_mul[19:10]});   // 216..903
wire signed [15:0] gun2_y = 16'sd44  + $signed({8'b0, g2y_mul[15:8]});    // 44..283

// Pocket Racer steering source: left-stick X, or the paddle when paddleMode is on
// (joy0_xmuxed already handles that mux). Signed -128..127; half-scaled and reversed
// into the wheel's 0x41-0xC0 span (inside MAME's legal 0x38-0xC8).
//
// DIGITAL STEERING FALLBACK (2026-07-26): joy0_xmuxed carries ONLY the left analog stick
// (or an armed NeGcon paddle), so on a d-pad or keyboard it stayed 0 and in_adc0 sat
// permanently at 0x80 = centred — the car could not be steered at all. Ramp a virtual
// wheel while Left/Right are held and spring it back to centre on release. The analog
// stick still wins whenever it is deflected past a small deadzone, so wheel/stick users
// are unaffected. ~258 Hz tick at clk_1x ~33.87 MHz => ~0.5 s from centre to full lock.
// No clamping needed: prc_stick -127..127 maps to 0x41..0xC0, inside MAME's 0x38..0xC8.
reg [16:0]       prc_steer_cnt = 17'd0;
reg signed [7:0] prc_dig       = 8'sd0;
always @(posedge clk_1x) begin
   prc_steer_cnt <= prc_steer_cnt + 17'd1;
   if (prc_steer_cnt == 17'd0) begin
      if (joy[1] & ~joy[0]) begin                          // Left
         if (prc_dig > -8'sd127) prc_dig <= prc_dig - 8'sd1;
      end else if (joy[0] & ~joy[1]) begin                 // Right
         if (prc_dig <  8'sd127) prc_dig <= prc_dig + 8'sd1;
      end else begin                                       // auto-centre on release
         if      (prc_dig > 8'sd0) prc_dig <= prc_dig - 8'sd1;
         else if (prc_dig < 8'sd0) prc_dig <= prc_dig + 8'sd1;
      end
   end
end
wire signed [7:0] prc_analog     = joy0_xmuxed;
wire              prc_analog_live = (prc_analog > 8'sd16) || (prc_analog < -8'sd16);
wire signed [7:0] prc_stick      = prc_analog_live ? prc_analog : prc_dig;

c76_sound c76snd
(
   .clk(clk_1x), .ce(c76_ce), .reset(reset), .sample_ce(snd_sample_ce),
   .bios_wr(c76bios_wr), .bios_addr(c76bios_addr), .bios_din(c76bios_word[7:0]),
   .mips_addr(mb_mips_addr), .mips_din(mb_mips_wdata), .mips_dout(mb_mips_rdata), .mips_wr(mb_mips_we),
   // 2026-07-06 INPUT FIX: System 11 inputs are read by the C76 (MAME c76_map 0x1000-0x1007)
   // and relayed to the MIPS via shared RAM — they were tied off (nothing could ever be
   // pressed, no coins). Active-low. in_player1 IS the game's IN1[15:8] byte:
   //   b7=START b6=IN1.0x4000 b5=IN1.0x2000 b4=IN1.0x1000 b3=UP b2=DOWN b1=LEFT b0=RIGHT
   //   SWITCH:  b7=SERVICE1 b6=TEST b5=COIN1 b4=COIN2 b1:b0=DIPs (off=1)
   //   PLAYER4: b4=P2 BTN3(LK) b5=P2 BTN4(RK) (Tekken P1 kicks travel on ADC ch2/ch1)
   // 2026-07-18 SOUL EDGE KICK FIX: b6 (game IN1 0x4000) was hardcoded 1'b0 because it is
   //   IPT_UNUSED in the tekken port layout. But souledge (and the generic namcos11 games
   //   dunkmnia/danceyes/xevi3dg/starswep) map BUTTON3 there — for Soul Edge that is the KICK,
   //   which was therefore permanently unpressed. Drive it with Button3 (joy[6]/joy2[6]).
   //   Harmless to Tekken (0x4000 is UNUSED there; joy[6] already also feeds ADC ch2), so no
   //   per-game gating is needed.
   // My Angel 3 (keycus_id 0x09) PORT_MODIFY("PLAYER1"): 0x08=BTN1 0x04=BTN2 0x02=BTN3 0x01=BTN4
   // (the base joystick-direction bits become the 4 quiz buttons). Remap the low nibble to
   // Button1-4 (joy[4..7]) for 0x09; keep U/D/L/R (joy[3..0]) for every other game.
   // NOTE: keycus 0x09 covers My Angel 3 AND the light-gun titles ptblank2/gunbarl. For the gun
   // games MAME's PORT_MODIFY leaves only 0x10 (BUTTON1 = TRIGGER) and 0x80 (START1) live, so the
   // low-nibble remap below is a My Angel 3 mapping that is harmless on the gun games. Bit 4 is
   // the trigger: OR in the mouse left button so a mouse can fire as well as a pad Button1.
   .in_player1(~{joy[10],  joy[6],  joy[5],  (joy[4] | (zn_gun_game & gun_trigger)),
                 (zn_keycus_id == 8'h09) ? {joy[4],  joy[5],  joy[6],  joy[7]}  : {joy[3],  joy[2],  joy[1],  joy[0]}}),
   .in_player2(~{joy2[10], joy2[6], joy2[5], joy2[4],
                 (zn_keycus_id == 8'h09) ? {joy2[4], joy2[5], joy2[6], joy2[7]} : {joy2[3], joy2[2], joy2[1], joy2[0]}}),
   // PLAYER4: bit4 (0x10) = Tekken P2 kick (joy2[6]) / Soul Edge P2 Guard (C409 0x02 -> joy2[7]);
   //          bit3 (0x08) = Pocket Racer (C432 0x07) BUTTON2 = view toggle (joy[5]) per MAME
   //          PORT_MODIFY("PLAYER4") 0x08; else unused.
   // PLAYER4 is a normal digital port, unlike player 3. On the BASE namcos11 layout it is the
   // full player-4 station (b7=START4 b6..b4=BTN3..1 b3=UP b2=DOWN b1=LEFT b0=RIGHT); every other
   // layout repurposes just a couple of its bits, so only the base titles get the full mapping.
   .in_player4(~(zn_generic_adc
                 ? {joy4[10], joy4[6], joy4[5], joy4[4], joy4[3], joy4[2], joy4[1], joy4[0]}
                 : {2'b00, joy2[7], (zn_keycus_id == 8'h02) ? joy2[7] : joy2[6],
                    (zn_keycus_id == 8'h07) ? joy[5] : 1'b0, 3'b000})),
   // SWITCH: b7=SERVICE1 b6=TEST b5=COIN1 b4=COIN2 b3=COIN3 b2=COIN4 b1:b0=DIPs.
   // COIN3/COIN4 were hardcoded unpressed, so players 3 and 4 could not credit up even once their
   // controls existed -- on a 4-player cabinet like Dunk Mania that alone makes them unusable.
   // Driven only on the base layout: the tekken/myangel3 port sets mark these bits IPT_UNUSED.
   // SERVICE1 (b7) is the cabinet service button, mapped as a normal game input
   // (J1 "Service", joy[13], either player). The TEST toggle (b6) sits unpressed —
   // the P2 "DIP1 (Test)" switch below is the service-menu entry, as on hardware.
   .in_switch (~{(joy[13] | joy2[13]), 1'b0, joy[11], joy2[11],
                 zn_generic_adc ? joy3[11] : 1'b0, zn_generic_adc ? joy4[11] : 1'b0,
                 status[96], status[97]}),
   // Pocket Racer (KEYCUS C432): AN0 = steering (PADDLE centre 0x80, legal 0x38-0xC8,
   // reversed per MAME) from the left analog stick X, AN1 = throttle pedal (0x00
   // released, BTN1 = full). AN0 left at the 0xFF idle value reads as a wheel pegged
   // past its legal max -> the C76 flags a fault at shram 0xBD32 and the game never
   // boots. All other games keep the Tekken kick mapping on AN1/AN2 and 0xFF on AN0.
   .in_adc0   ((zn_keycus_id == 8'h07) ? (8'h80 - {prc_stick[7], prc_stick[7:1]})
               : zn_generic_adc ? (joy3[6] ? 8'h00 : 8'hFF)            // P3 BUTTON3
                                : 8'hFF),
   // PLAYER 3 (base namcos11 layout) arrives ENTIRELY through the A-D converter -- there is no
   // digital port for it. AN0/1/2 = BUTTON3/2/1, AN3=RIGHT AN4=LEFT AN5=DOWN AN6=UP, AN7=START3.
   // Note this SUPERSEDES the earlier "gate ADC1/ADC2 to 0xFF" step for these titles: the problem
   // was never that the channels were driven, it was that they were driven from PLAYER 1. They now
   // get their rightful owner. Non-base titles keep 0xFF (they override these UNUSED in MAME).
   .in_adc3   (zn_generic_adc ? (joy3[0] ? 8'h00 : 8'hFF) : 8'hFF),    // P3 RIGHT
   .in_adc4   (zn_generic_adc ? (joy3[1] ? 8'h00 : 8'hFF) : 8'hFF),    // P3 LEFT
   .in_adc5   (zn_generic_adc ? (joy3[2] ? 8'h00 : 8'hFF) : 8'hFF),    // P3 DOWN
   .in_adc6   (zn_generic_adc ? (joy3[3] ? 8'h00 : 8'hFF) : 8'hFF),    // P3 UP
   .in_adc7   (zn_generic_adc ? (joy3[10] ? 8'h00 : 8'hFF) : 8'hFF),   // START3
   // ADC1/ADC2 PHANTOM-PLAYER-3 FIX (2026-07-26). MAME's BASE namcos11 port set maps
   // ADC0/ADC1/ADC2 to PLAYER 3's BUTTON3/BUTTON2/BUTTON1 -- not to P1's. Only the titles that
   // PORT_MODIFY those channels (the tekken layout, souledge, ptblank2, pocketrc) put P1 inputs
   // there. We were driving ADC1=joy[7] and ADC2=joy[6] for EVERY non-Pocket-Racer title, so on
   // the four base-layout games a P1 Button3 press -- a real, used button there (PLAYER1 0x40) --
   // ALSO read as "Player 3 pressed Button1". Gate those titles off.
   // Player 3 can never be a real input anyway: c76.vhd decodes only ADC ch0/1/2 (SFR 0x20/0x22/
   // 0x24); ch3-7 (P3 joystick + START3) have no decode at all.
   // keycus 0x09 is deliberately NOT gated: it is shared by My Angel 3 (MAME: all ADCs UNUSED) and
   // Point Blank 2/Gunbarl (MAME: ADC1/ADC2 = P1 BUTTON4/BUTTON3, genuinely needed). ptblank2 wins;
   // separating them would need a new MRA discriminator byte.
   // Pocket Racer AN1 = throttle PEDAL. MAME's ADC1 is IPT_PEDAL + PORT_REVERSE (MINMAX 0x00-0x7F),
   // so a RELEASED pedal reads 0x7F, full = 0x00. We had it inverted (released=0x00) -> the C76 saw
   // the pedal pinned "fully pressed" at boot (stuck-pedal) and never published the input-ready bit
   // at shram 0xBD32 -> MIPS hung at 0x80018C9C. Released = 0x7F, Button1 (accel) = 0x00.
   .in_adc1   ((zn_keycus_id == 8'h07) ? (joy[4] ? 8'h00 : 8'h7F)
               : zn_generic_adc ? (joy3[5] ? 8'h00 : 8'hFF)           // P3 BUTTON2 (never P1)
               : (zn_keycus_id == 8'h02) ? 8'hFF                      // Soul Edge: MAME UNUSED
                                       : (joy[7] ? 8'h00 : 8'hFF)),   // else: Tekken P1 BTN4 (right kick)
   // ADC2: Tekken = P1 BTN3 left kick (joy[6]); Soul Edge (C409, id 0x02) maps P1 BUTTON4
   // (Guard) to ADC2 per MAME PORT_MODIFY("ADC2") -> use joy[7] (Button4). Pocket Racer = idle.
   .in_adc2   ((zn_keycus_id == 8'h07) ? 8'hFF
               : zn_generic_adc ? (joy3[4] ? 8'h00 : 8'hFF)            // P3 BUTTON1 (NOT P1's)
               : (zn_keycus_id == 8'h02) ? (joy[7] ? 8'h00 : 8'hFF)    // Soul Edge: ADC2 = P1 Guard
                                         : (joy[6] ? 8'h00 : 8'hFF)),  // Tekken: ADC2 = P1 BTN3 (left kick)
   .sprog_addr(c76_sprog_addr), .sprog_data(c76_sprog_data), .sprog_rd(c76_sprog_rd), .sprog_ready(c76_sprog_ready),
   .wave_addr(c76_wave_addr), .wave_data(c76_wave_data), .wave_rd(c76_wave_rd), .wave_ready(c76_wave_ready),
   .dbg_c352_wrcnt(c352_wrcnt), .dbg_keyon_cnt(c352_keyoncnt),
   .dbg_commit_cnt(c352_commitcnt), .dbg_busy_cnt(c352_busycnt),
   .dbg_vwr(c352_vwr),
   .audio_l(c352_aud_l), .audio_r(c352_aud_r),
   .dbg_halted(c76_halted), .dbg_c352_seen(c76_c352_seen), .dbg_pc_out(c76_pc),
   .dbg_ad_state(c76_ad_state),   // DIAG pocketrc A-D: [15]ADCON-start [14:8]ad_tick_cnt [7:0]AN0
   .dbg_first_pc(c76_first_pc), .dbg_pc_ever_bios(c76_ever_bios), .dbg_pc_ever_c098(c76_ever_c098),
   .dbg_c76_resp(c76_resp), .dbg_ram80(c76_ram80), .dbg_ram83(c76_ram83),
   .dbg_opcode_out(c76_opcode), .dbg_brk_site_out(c76_brk_site), .dbg_mb_hs(c76_mb_hs),
   .dbg_rb_en(c76_rb_en), .dbg_rb_addr(jtag_addr[13:0]), .dbg_rb_q(c76_rb_q),
   .dbg_coin(c76_coin), .dbg_ring_idx(jtag_addr[4:0]), .dbg_ring_q(c76_ring), .dbg_c76resp(c76_resp_lat)
);
wire [15:0] c76_coin;   // DIAG coin->C352 keyon: [15:8]=coin edges [7:0]=max keyons in ~0.5s after a coin
wire [31:0] c76_ring;   // DIAG MIPS-command coin ring @ idx jtag_addr[4:0]: [31]valid [25:16]byte-off from 0xBD00 [15:0]data
wire [31:0] c76_resp_lat; // DIAG C76 coin-response latches (mode 4): [31]bda4_seen [30]bd01_clr [29]bd00_seen [23:16]bda4_val [15:8]#C76-BDxx-writes [7:0]bd00_val
wire        c76_rb_en = 1'b0;   // mode E dpram window disconnected for release   // mode E: steal MIPS port B to read dpram[jtag_addr[13:0]]
wire [15:0] c76_rb_q;                                // dpram word read back
wire [7:0]  c76_opcode;       // C76 last-fetched opcode (= the halting opcode when halted)
wire [15:0] c76_ad_state;     // DIAG pocketrc A-D: [15]ADCON-start [14:8]ad_tick_cnt [7:0]AN0
wire [23:0] c76_brk_site;
wire [31:0] c76_mb_hs;      // C76 mailbox handshake forensics (see c76_sound.vhd)     // PC that took the last BRK before the derail
wire        c76_halted;       // C76 hit an unimplemented opcode (crashed)
wire        c76_c352_seen;    // C76 wrote the C352 during BIOS init (= alive)
wire [23:0] c76_pc;           // live C76 program counter
wire [23:0] c76_first_pc;     // FIRST retired PC after reset (=0xC030 if reset vector OK)
wire        c76_ever_bios;    // REPURPOSED: C76 ever executed STA $83 @0xC279 (TB0 ISR toggle store)
wire        c76_ever_c098;    // REPURPOSED: C76 ever took BBS-not-taken @0xC26F (RAM[0x80] bit6 clear)
wire        c76_resp;         // C76 ever wrote the handshake response word 0xBD30-0xBD33
wire [7:0]  c76_ram80;        // C76 internal RAM[0x80] (TB0 toggle gate flags; bit6 gates 0xC275)
wire [7:0]  c76_ram83;        // C76 internal RAM[0x83] (TB0 toggle byte the 0xC151 wait loop polls)
// DIAG: C76 TB0-toggle investigation. [31:24]=RAM[0x83] (toggle target; 0x00/0xFF if working),
// [23:16]=RAM[0x80] (gate; bit6=0x40 must be set for the toggle path), [15]halted,
// [14]ran-TB1-service-ISR(0xC31F), [13]took-0xC279(STA $83 ran), [12]resp(wrote mailbox 0xBD30), [11:0]=PC[11:0].
// HALT DIAGNOSIS: [31:24]=last-fetched opcode (the unimplemented opcode when halted),
// [23:0]=full live/halt C76 PC. (TB1 fix confirmed: service ISR runs, RAM[0x83] toggles,
// but the C76 now halts on an unimplemented m37702 opcode deeper in the service code.)
wire        dbg_reached_game; // MIPS reached game code (from psx_mister) -> overlay auto-hide
// HANDSHAKE STATUS (post-IPL-fix): the C76 now runs live (no derail). Check whether it completes
// the MIPS<->C76 mailbox handshake. [31]halted [30]resp(C76 wrote mailbox 0xBD30-0xBD33)
// [29]MIPS-reached-game [28]ever_sprog [27]c352_seen [26]sprog_done [25:24]=0 [23:0]=live C76 PC.
// BOOT-vs-SERVICE DIAG: [31]halted [30]resp(wrote mailbox) [29]ever_c098(ran TB1 service ISR 0xC31F
// = reached mailbox service) [28]ever_bios(ran STA$83 @0xC279) [27]c352_seen [26]sprog_done
// [25:24]=0 [23:0]=c76_pc (= latched derail SOURCE PC once a derail fires, else live PC). If
// ever_c098=1 the C76 reached mailbox service before derailing (service/stack bug); if 0 it derailed
// during boot (corrupt SPROG/code).
wire [31:0] c76_state = {c76_opcode, c76_pc};  // {halting opcode[31:24], halt PC[23:0]}
// C76-LIVENESS PROBE (2026-07-02): confirm/deny the mailbox gate. [31]halted [30]resp(C76 wrote mailbox
// handshake 0xBD30) [29]ever_c098(reached TB1 mailbox-service ISR) [28]ever_bios(ran C76 BIOS store)
// [27]c352_seen [26]derailed(brk_site!=0) [25:24]=0 [23:0]=c76_pc (live if alive, latched derail-PC if dead).
wire [31:0] c76_status = {c76_halted, c76_resp, c76_ever_c098, c76_ever_bios, c76_c352_seen, (c76_brk_site!=24'd0), 2'b00, c76_pc[23:0]};
// C76 MAILBOX/TIMER DIAG (2026-07-03): find where the handshake breaks.
// mb_wr_cnt = # of MIPS mailbox writes (0 => MIPS not sending commands). RAM[0x83] toggling => TB0 alive
// (0xC151 idle loop is normal); FROZEN => TB0 dead (C76 stuck). RAM[0x80] => INT0 setup ran.
reg [15:0] mb_wr_cnt   = 16'd0;
reg [13:0] mb_last_addr= 14'd0;
reg [15:0] mb_last_wd  = 16'd0;
reg        mb_we_d     = 1'b0;
reg [7:0]  ram83_seen  = 8'd0;   // OR of all RAM[0x83] values seen (detects toggling: !=0 and != first)
reg [7:0]  ram83_first = 8'hAA;
reg        ram83_toggled = 1'b0;
always @(posedge clk_1x) begin
   mb_we_d <= mb_mips_we;
   if (mb_mips_we & ~mb_we_d) begin mb_wr_cnt <= mb_wr_cnt + 1'b1; mb_last_addr <= mb_mips_addr; mb_last_wd <= mb_mips_wdata; end
   if (ram83_first == 8'hAA) ram83_first <= c76_ram83;
   else if (c76_ram83 != ram83_first) ram83_toggled <= 1'b1;
end
wire [31:0] c76_mbstat = {c76_ram80, c76_ram83, mb_wr_cnt};                                    // [31:24]RAM80 [23:16]RAM83 [15:0]MIPS-write-count
wire [31:0] c76_mblast = {c76_resp, c76_ever_c098, ram83_toggled, c76_halted, mb_last_addr[13:0], mb_last_wd[13:0]}; // [31]resp [30]c098 [29]RAM83-toggled [28]halted [27:14]lastMBwordAddr [13:0]lastMBdata
// COMBINED: [31]c76_halted [30]c76_resp [29]ran-TB1-svc [28]c76 ever derailed (brk_site!=0)
// (dbg_combo probe word excluded — GITHUB output template, 2026-09-01)

// 2026-07-06 SILENCE TRIAGE probe (mode 5): {aud_nz[11:0], c352_wr[7:0], wave_rq[5:0], wave_dn[5:0]}
//   aud_nz  = samples where C352 L/R output != 0 (rolling)   -> audio produced?
//   c352_wr = C352 register write count (rolling)            -> voices being programmed?
//   wave_rq/dn = wave reader requests/completions (rolling)  -> sample fetches happening?
reg [4:0]  dbg_aud_nz  = 5'd0;
reg [3:0]  dbg_sce_cnt = 4'd0;       // sample_ce liveness (rolls at ~88kHz if alive)
reg [5:0]  dbg_wave_rq = 6'd0;
reg        dbg_waverd_seen = 1'b0;   // C352 EVER asserted its wave read strobe
wire [7:0] c352_wrcnt;
wire [7:0] c352_keyoncnt;
wire [5:0] c352_commitcnt;
wire [31:0] c352_vwr;   // 2026-07-07 freq=0 fork probe: {cnt8, lastaddr12, lastdata8, freqNZcnt4}
wire [5:0] c352_busycnt;
always @(posedge clk_1x) begin
   if (snd_sample_ce)                       dbg_sce_cnt <= dbg_sce_cnt + 1'b1;
   if (snd_sample_ce && (c352_aud_l != 16'd0 || c352_aud_r != 16'd0)) dbg_aud_nz <= dbg_aud_nz + 1'b1;
   if (c76_wave_rd)                         dbg_waverd_seen <= 1'b1;
   if (c76_wave_req)                        dbg_wave_rq <= dbg_wave_rq + 1'b1;
end
// {aud_nz[4:0], sce[3:0], keyon[7:0], waverd_seen, commit[5:0], busy[5:0], wr[1:0]}
wire [31:0] snd_triage = {dbg_aud_nz, dbg_sce_cnt, c352_keyoncnt, dbg_waverd_seen, c352_commitcnt, c352_busycnt, c352_wrcnt[1:0]};

assign AUDIO_L = psx_aud_l + $signed(c352_aud_l);     // mix C352 into PSX audio
assign AUDIO_R = psx_aud_r + $signed(c352_aud_r);

// C76 SPROG reader FSM: on a C76 SPROG read, fetch the 32-bit word from SDRAM ch3,
// extract the requested byte, and hand it back via the sprog_ready handshake. ch3
// read data arrives on cheats_din; completion on sdramCh3_done.
always @(posedge clk_1x) begin
   c76_sprog_req <= 1'b0;
   case (sprog_st)
   // ★ 2026-07-05 CH3-COLLISION FIX: the ch3 mux prioritizes clr_active/sentinel_active over the
   // SPROG fetch, but this FSM advanced to WAIT even when its request was masked by the mux — the
   // NEXT sdramCh3_done (e.g. the CLR runtime monitor's ~2ms periodic 0x2B1CE0 re-read!) was then
   // latched as the C76's OPCODE byte → the C76 executed RAM content → BRK → halt @0xC1E9 → the
   // game's boot-asset uploads stop at c2v=37585 and boot never reaches the movie/attract.
   // Only issue (and only advance) when the ch3 bus is actually ours.
   2'd0: if (c76_sprog_rd && zn_platform_r[4] && ~clr_active && ~sentinel_active && wave_st == 2'd0 &&
             ~(bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download)) begin
            c76_sprog_sdaddr <= SPROG_START + {7'b0, c76_sprog_addr[19:2], 2'b00};
            c76_sprog_req    <= 1'b1;                  // one-cycle ch3 request pulse
            sprog_bsel       <= c76_sprog_addr[1:0];
            sprog_st         <= 2'd1;
            c76_ever_sprog   <= 1'b1;                  // diag: C76 ever issued a SPROG read
         end
   2'd1: if (sdramCh3_done) begin
            c76_sprog_done_ever <= 1'b1;               // diag: a ch3 SPROG read ever completed
            case (sprog_bsel)
              2'd0: c76_sprog_data <= cheats_din[7:0];
              2'd1: c76_sprog_data <= cheats_din[15:8];
              2'd2: c76_sprog_data <= cheats_din[23:16];
              2'd3: c76_sprog_data <= cheats_din[31:24];
            endcase
            // DIAG: capture the SPROG HEADER word (byte 0x100 = word index 0x40). The C76 checks
            // LDA $200100 == 0x5500; if this word's low 16 != 0x5500, the SPROG read/load is broken
            // -> C76 skips the SPROG init -> empty 0xBEFA jump table -> JSR derail to 0x10.
            if (c76_sprog_addr[19:2] == 18'h00040) dbg_sprog_hdr <= cheats_din;
            sprog_fetched   <= c76_sprog_addr[19:0];   // this byte is valid for this address
            sprog_st        <= 2'd2;
         end
   2'd2: if (~c76_sprog_rd || c76_sprog_addr[19:0] != sprog_fetched) begin
            // access done (rd low) OR the M37702 advanced to the next byte (ea+1) while holding
            // rd -> re-fetch the new address (the high byte of a 16-bit read).
            sprog_st        <= 2'd0;
         end
   endcase
end

// C352 wave-ROM reader FSM (2026-07-06): lower priority than SPROG — issues only while the
// SPROG FSM is idle AND the C76 is not requesting an instruction byte this cycle; the SPROG
// FSM in turn waits for wave_st==0, so exactly one ch3 request is ever in flight and each
// sdramCh3_done pulse belongs unambiguously to its issuer.
always @(posedge clk_1x) begin
   c76_wave_req <= 1'b0;
   case (wave_st)
   2'd0: if (c76_wave_rd && zn_platform_r[4] && ~clr_active && ~sentinel_active &&
             sprog_st == 2'd0 && ~c76_sprog_rd &&
             ~(bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download)) begin
            c76_wave_sdaddr <= WAVE_START + {5'b0, c76_wave_addr[21:2], 2'b00};
            c76_wave_req    <= 1'b1;
            wave_st         <= 2'd1;
         end
   2'd1: if (sdramCh3_done) begin
            c76_wave_data <= cheats_din;       // whole 32-bit word to the c352 line cache
            wave_fetched  <= c76_wave_addr;
            wave_st       <= 2'd2;
         end
   2'd2: if (~c76_wave_rd || c76_wave_addr != wave_fetched) begin
            wave_st      <= 2'd0;
         end
   endcase
end

// GITHUB output template (2026-09-01): the JTAG/ISSP debug probe is excluded
// from this edition, so its address source is a constant; every diagnostic
// cone it selected (VRAM readback, C76 ring/dpram windows) folds away.
wire [31:0] jtag_addr = 32'd0;

psx_mister
psx
(
   .clk1x(clk_1x),
   .clk2x(clk_2x),
   .clk3x(clk_3x),
   .clkvid(clk_vid),
   .reset(reset),
   .isPaused(isPaused),
   // commands
   .pause(paused),
   .hps_busy(hps_busy),
   .loadExe(loadExe),
   .exe_initial_pc(exe_initial_pc),
   .exe_initial_gp(exe_initial_gp),
   .exe_load_address(exe_load_address),
   .exe_file_size(exe_file_size),
   .exe_stackpointer(exe_stackpointer),
   .fastboot(status[16] && hasCD),
   .ram8mb(1'b1),
   .TURBO_MEM(TURBO_MEM),
   .TURBO_COMP(TURBO_COMP),
   .TURBO_CACHE(TURBO_CACHE),
   .TURBO_CACHE50(TURBO_CACHE50),
   .REPRODUCIBLEGPUTIMING(0),
   .INSTANTSEEK(status[21]),
   .FORCECDSPEED(status[77:75]),
   .LIMITREADSPEED(status[78]),
   .IGNORECDDMATIMING(status[88]),
   .ditherOff(status[22]),
   .interlaced480pHack(status[89]),
   .showGunCrosshairs(status[9]),
   .enableNeGconRumble(status[91]),
   .fpscountOn(1'b0),  // GITHUB template: FPS-counter debug overlay excluded
   .cdslowOn(status[59]),
   .testSeek(status[70]),
   .pauseOnCDSlow(~status[72]),
   .errorOn(status[74]),
   .LBAOn(status[69]),
   .PATCHSERIAL(0), //.PATCHSERIAL(status[54]),
   .noTexture(status[27]),
   .textureFilter(status[82:81]),
   .textureFilterStrength(status[87:86]),
   .textureFilter2DOff(status[83]),
   .dither24(status[73]),
   .render24(status[84] && ~hack_480p),
   .drawSlow(status[90]),
   .syncVideoOut(syncVideoOut),
   .syncInterlace(status[60]),
   .rotate180(status[24]),
   .fixedVBlank(status[55] && ~hack_480p),
   .vCrop(hack_480p ? 2'b00 : status[4:3]),
   .hCrop(status[67]),
   .SPUon(~status[30]),
   .SPUIRQTrigger(status[2]),
   .SPUSDRAM(status[44] & SDRAM2_EN),
   .REVERBOFF(0),
   .REPRODUCIBLESPUDMA(status[43]),
   .WIDESCREEN(status[54:53]),
   .oldGPU(status[92]),   
   // RAM/BIOS interface
   .biosregion(biosregion),
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead32(sdr_sdram_dout32),
   .ram_Adr(sdram_addr),
   .ram_cntDMA(sdram_cntDMA),
   .ram_be(sdram_be),
   .ram_rnw(sdram_rnw),
   .ram_ena(sdram_req),
   .ram_dma(sdram_dma),
   .ram_cache(sdram_cache),
   .ram_done(sdram_ack),
   .ram_dmafifo_adr  (sdram_dmafifo_adr),
   .ram_dmafifo_data (sdram_dmafifo_data),
   .ram_dmafifo_empty(sdram_dmafifo_empty),
   .ram_dmafifo_read (sdram_dmafifo_read),
   .cache_wr(cache_wr),
   .cache_data(cache_data),
   .cache_addr(cache_addr),
   .dma_wr(dma_wr),
   .dma_reqprocessed(dma_reqprocessed),
   .dma_data(dma_data),
   // vram/ddr3
   .DDRAM_BUSY      (DDRAM_BUSY      ),
   .DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
   .DDRAM_ADDR      (DDRAM_ADDR      ),
   .DDRAM_DOUT      (DDRAM_DOUT      ),
   .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
   .DDRAM_RD        (DDRAM_RD        ),
   .DDRAM_DIN       (DDRAM_DIN       ),
   .DDRAM_BE        (DDRAM_BE        ),
   .DDRAM_WE        (DDRAM_WE        ),
   // cd (unused in ZN)
   .region          (2'b01),    // JP
   .region_out      (region_out),
   .hasCD           (1'b0),
   .LIDopen         (1'b0),
   .fastCD          (1'b0),
   .trackinfo_data  (32'h0),
   .trackinfo_addr  (9'h0),
   .trackinfo_write (1'b0),
   .resetFromCD     (resetFromCD),
   .cd_hps_req      (),
   .cd_hps_lba      (),
   .cd_hps_ack      (1'b0),
   .cd_hps_write    (1'b0),
   .cd_hps_data     (16'h0),
   // spuram
   .spuram_dataWrite(spuram_dataWrite),
   .spuram_Adr      (spuram_Adr      ),
   .spuram_be       (spuram_be       ),
   .spuram_rnw      (spuram_rnw      ),
   .spuram_ena      (spuram_ena      ),
   .spuram_dataRead (spuram_dataRead ),
   .spuram_done     (spuram_done     ),
   // memcard (unused in ZN)
   .memcard_changed (),
   .saving_memcard  (),
   .memcard1_load   (1'b0),
   .memcard2_load   (1'b0),
   .memcard_save    (1'b0),
   .memcard1_mounted   (1'b0),
   .memcard1_available (1'b0),
   .memcard1_rd     (),
   .memcard1_wr     (),
   .memcard1_lba    (),
   .memcard1_ack    (1'b0),
   .memcard1_write  (1'b0),
   .memcard1_addr   (9'h0),
   .memcard1_dataIn (16'h0),
   .memcard1_dataOut(),
   .memcard2_mounted   (1'b0),
   .memcard2_available (1'b0),
   .memcard2_rd     (),
   .memcard2_wr     (),
   .memcard2_lba    (),
   .memcard2_ack    (1'b0),
   .memcard2_write  (1'b0),
   .memcard2_addr   (9'h0),
   .memcard2_dataIn (16'h0),
   .memcard2_dataOut(),
   // video
   .videoout_on     (~status[14]),
   .isPal           (isPal),
   .pal60           (status[15]),
   .hsync           (hs),
   .vsync           (vs),
   .hblank          (hbl),
   .vblank          (vbl),
   .DisplayWidth    (DisplayWidth),
   .DisplayHeight   (DisplayHeight),
   .DisplayOffsetX  (DisplayOffsetX),
   .DisplayOffsetY  (DisplayOffsetY),
   .video_ce        (ce_pix),
   .video_interlace (video_interlace),
   .video_r         (r),
   .video_g         (g),
   .video_b         (b),
   .video_isPal     (video_isPal),
   .video_fbmode    (video_fbmode),
   .video_fb24      (video_fb24),
   .video_hResMode  (video_hResMode),
   .video_frameindex(frameindex),
   //Keys
   .DSAltSwitchMode(status[31]),
   .PadPortEnable1 (PadPortEnable1),
   .PadPortDigital1(PadPortDigital1),
   .PadPortAnalog1 (PadPortAnalog1),
   .PadPortMouse1  (PadPortMouse1 ),
   .PadPortGunCon1 (PadPortGunCon1),
   .PadPortNeGcon1 (PadPortNeGcon1),
   .PadPortWheel1  (PadPortWheel1),
   .PadPortDS1     (PadPortDS1),
   .PadPortJustif1 (PadPortJustif1),
   .PadPortStick1  (PadPortStick1),
   .PadPortPopn1   (PadPortPopn1),
   .PadPortEnable2 (PadPortEnable2),
   .PadPortDigital2(PadPortDigital2),
   .PadPortAnalog2 (PadPortAnalog2),
   .PadPortMouse2  (PadPortMouse2 ),
   .PadPortGunCon2 (PadPortGunCon2),
   .PadPortNeGcon2 (PadPortNeGcon2),
   .PadPortWheel2  (PadPortWheel2),
   .PadPortDS2     (PadPortDS2),
   .PadPortJustif2 (PadPortJustif2),
   .PadPortStick2  (PadPortStick2),
   .PadPortPopn2   (PadPortPopn2),
   .KeyTriangle({joy4[4], joy3[4], joy2[4], joy[4] }),
   .KeyCircle  ({joy4[5] ,joy3[5] ,joy2[5] ,joy[5] }),
   .KeyCross   ({joy4[6] ,joy3[6] ,joy2[6] ,joy[6] }),
   .KeySquare  ({joy4[7] ,joy3[7] ,joy2[7] ,joy[7] }),
   .KeySelect  ({joy4[8] ,joy3[8] ,joy2[8] ,joy[8] }),
   .KeyStart   ({joy4[9] ,joy3[9] ,joy2[9] ,joy[9] }),
   .KeyRight   ({joy4[0] ,joy3[0] ,joy2[0] ,joy[0] }),
   .KeyLeft    ({joy4[1] ,joy3[1] ,joy2[1] ,joy[1] }),
   .KeyUp      ({joy4[3] ,joy3[3] ,joy2[3] ,joy[3] }),
   .KeyDown    ({joy4[2] ,joy3[2] ,joy2[2] ,joy[2] }),
   .KeyR1      ({joy4[11],joy3[11],joy2[11],joy[11]}),
   .KeyR2      ({joy4[13],joy3[13],joy2[13],joy[13]}),
   .KeyR3      ({joy4[15],joy3[15],joy2[15],joy[15]}),
   .KeyL1      ({joy4[10],joy3[10],joy2[10],joy[10]}),
   .KeyL2      ({joy4[12],joy3[12],joy2[12],joy[12]}),
   .KeyL3      ({joy4[14],joy3[14],joy2[14],joy[14]}),
   .ToggleDS   (ToggleDS),
   .Analog1XP1(joy0_xmuxed),
   .Analog1YP1(joystick_analog_l0[15:8]),
   .Analog2XP1(joystick_analog_r0[7:0]),
   .Analog2YP1(joystick_analog_r0[15:8]),
   .Analog1XP2(joystick_analog_l1[7:0]),
   .Analog1YP2(joystick_analog_l1[15:8]),
   .Analog2XP2(joystick_analog_r1[7:0]),
   .Analog2YP2(joystick_analog_r1[15:8]),
   .Analog1XP3(joystick_analog_l2[7:0]),
   .Analog1YP3(joystick_analog_l2[15:8]),
   .Analog2XP3(joystick_analog_r2[7:0]),
   .Analog2YP3(joystick_analog_r2[15:8]),
   .Analog1XP4(joystick_analog_l3[7:0]),
   .Analog1YP4(joystick_analog_l3[15:8]),
   .Analog2XP4(joystick_analog_r3[7:0]),
   .Analog2YP4(joystick_analog_r3[15:8]),
   .RumbleDataP1(joystick1_rumble),
   .RumbleDataP2(joystick2_rumble),
   .RumbleDataP3(joystick3_rumble),
   .RumbleDataP4(joystick4_rumble),
   .padMode(padMode),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
   .multitap(multitap),
   .multitapDigital(multitapDigital),
   .multitapAnalog(multitapAnalog),
   //snac
   .snacPort1(snacPort1),
   .snacPort2(snacPort2),
   .selectedPort1Snac(selectedPort1Snac),
   .selectedPort2Snac(selectedPort2Snac),
   .irq10Snac(irq10Snac),
   .transmitValueSnac(transmitValueSnac),
   .clk9Snac(clk9Snac),
   .receiveBufferSnac(receiveBufferSnac),
   .beginTransferSnac(beginTransferSnac),
   .actionNextSnac(actionNextSnac),
   .receiveValidSnac(receiveValidSnac),
   .ackSnac(~ack),//using real ack not the 1 cycle ack
   .snacMC(status[66]),

   //sound
	.sound_out_left(psx_aud_l),
	.sound_out_right(psx_aud_r),
   //savestates
   .increaseSSHeaderCount (!status[36]),
   .save_state            (ss_save),
   .load_state            (ss_load),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   .validSStates          (validSStates),
   .rewind_on             (0), //(status[27]),
   .rewind_active         (0), //(status[27] & joy[15]),
   //cheats
   .cheat_clear(gg_reset),
   .cheats_enabled(~status[6] && ~TURBO_MEM && ~ioctl_download && ~zn_platform_r[4]),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

   .Cheats_BusAddr(cheats_addr),
   .Cheats_BusRnW(cheats_rnw),
   .Cheats_BusByteEnable(cheats_be),
   .Cheats_BusWriteData(cheats_dout),
   .Cheats_Bus_ena(cheats_ena),
   .Cheats_BusReadData(cheats_din),
   .Cheats_BusDone(sdramCh3_done),

   // ZN-1 Arcade I/O
   .zn_p1_right   (joy[0]),
   .zn_p1_left    (joy[1]),
   .zn_p1_down    (joy[2]),
   .zn_p1_up      (joy[3]),
   .zn_p1_btn     (joy[9:4]),    // btn1-6 = joy[4..9]
   .zn_p1_start   (joy[10]),
   .zn_p1_coin    (joy[11]),
   .zn_p2_right   (joy2[0]),
   .zn_p2_left    (joy2[1]),
   .zn_p2_down    (joy2[2]),
   .zn_p2_up      (joy2[3]),
   .zn_p2_btn     (joy2[9:4]),
   .zn_p2_start   (joy2[10]),
   .zn_p2_coin    (joy2[11]),
   .zn_service    (1'b0),  // GITHUB template: OSD Service toggle excluded
   .zn_test_mode  (1'b0),  // GITHUB template: OSD Test toggle excluded
   .zn_dsw        (8'hFF),       // all DIP switches ON (normal/defaults)
   // CAT702 keys loaded dynamically via MRA rom index 4 (key_a=KN01/motherboard) and 5 (key_b=KN02/game)
   // CAT702 select is ACTIVE LOW: key_a used for 0x88 path (KN01), key_b used for 0x84 path (KN02)
   .zn_cat702_key  (zn_cat702_key_a),
   .zn_cat702_key_b(zn_cat702_key_b_r),
   .zn_platform    (zn_platform_r[3:0]),
   .zn_system11    (zn_platform_r[4]),   // MRA platform byte bit4 = Namco System 11 mode
   .zn_gputype1_force(zn_platform_r[5]), // MRA platform byte bit5 = coh100 board (GPU type 1: old Tekken 2 revisions)
   .keycus_id      (zn_keycus_id),       // MRA index-1 byte[1]: 0=none, 1=C406 (Tekken 2)
   .zn_gun1_x      (gun_x),              // System 11 GUN I/F (Point Blank 2 / Gunbarl, C443)
   .zn_gun1_y      (gun_y),
   .zn_gun2_x      (gun2_x),             // P2 gun = P2 pad left analog stick (no 2nd mouse exists)
   .zn_gun2_y      (gun2_y),
   .ee_dl_wr       (ee_dl_wr),           // MRA index 9: EEPROM/nvram load
   .ee_dl_addr     (ee_dl_addr),
   .ee_dl_data     (ee_dl_data),
   .ee_up_rd       (ee_up_rd),           // nvram save: read-back
   .ee_up_addr     (ee_up_addr),
   .ee_up_q        (ee_up_q),
   .ee_wr_pulse    (ee_wr_pulse),
   .mb_mips_addr   (mb_mips_addr),
   .mb_mips_wdata  (mb_mips_wdata),
   .mb_mips_we     (mb_mips_we),
   .mb_mips_rdata  (mb_mips_rdata),
   .dbg_c76_in     ({c76_resp, c76_ever_c098}),  // C76 triage -> bars: GREEN=ever_c098, BLUE=c76_resp
   .dbg_c76_pc     (c76_first_pc),               // C76 FIRST PC after reset -> value display
   .dbg_reached_game(dbg_reached_game),          // MIPS reached game code -> overlay auto-hide
   .zn_debug_out   (zn_debug_out),
   .zn_debug_val   (zn_debug_val),
   .zn_dbg_a0      (zn_dbg_a0),
   .zn_dbg_a1      (zn_dbg_a1),
   .zn_dbg_eeprom_o(zn_dbg_eeprom_o),
   .zn_dbg_gpu     (zn_dbg_gpu),
   .zn_dbg_disp    (zn_dbg_disp),
   .zn_dbg_dma     (zn_dbg_dma),
   .zn_dbg_madr    (zn_dbg_madr),
   .zn_dbg_nextaddr(zn_dbg_nextaddr),
   .zn_dbg_gpustat (zn_dbg_gpustat),
   .zn_dbg_procst  (zn_dbg_procst),
   .zn_dbg_pv0     (zn_dbg_pv0),
   .zn_dbg_mipspc  (zn_dbg_mipspc),
   .zn_dbg_pause   (zn_dbg_pause),
   .zn_dbg_pv2     (zn_dbg_pv2),
   .dbg_vram_coord (jtag_addr),    // JTAG VRAM readback: write 0xF<Y><X> to read VRAM[x,y] via mode D

   .trace_flat     (trace_flat),
   .trace_meta     (trace_meta),
   .zn_debug_addr  (zn_debug_addr),
   .zn_debug_words (zn_debug_words)
);

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire  [31:0] sdr_sdram_dout32;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [26:0] sdram_addr;
wire   [1:0] sdram_cntDMA;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_dma;
wire         sdram_cache;
wire [ 3:0]  cache_wr;
wire [31:0]  cache_data;
wire [ 7:0]  cache_addr;
wire         dma_wr;
wire         dma_reqprocessed;
wire [31:0]  dma_data;

wire  [22:0] sdram_dmafifo_adr;
wire  [31:0] sdram_dmafifo_data;
wire         sdram_dmafifo_empty;
wire         sdram_dmafifo_read;


wire [20:0] cheats_addr;
wire cheats_rnw;
wire [3:0] cheats_be;
wire [31:0] cheats_dout;
wire cheats_ena;
wire [31:0] cheats_din;
wire sdramCh3_done;

// GITHUB output template (2026-09-01): the sentinel-readback instrument (a
// post-download SDRAM marker write/read forensic) is a debug feature and is
// excluded from this edition. The constant tie-offs below keep the shared ch3
// mux expressions valid; synthesis folds every sentinel term away.
wire [26:0] sent_addr  = 27'd0;
wire [31:0] sent_din   = 32'd0;
wire        sent_req   = 1'b0;
wire        sent_rnw   = 1'b1;
wire [3:0]  sent_be    = 4'b1111;
wire        sentinel_active = 1'b0;
// ============================================================================
// MAIN-RAM ZERO-FILL (2026-06-26): MAME's namcos11 RAM is a zero-initialized
// ram_device, so the game reads never-written regions (e.g. the EEPROM-default
// source buffer @0x802B1CE0 in the upper 2MB) expecting 0x00. The FPGA's SDRAM is
// power-on garbage (uninitialized DRAM reads INCONSISTENTLY), corrupting that data
// -> the EEPROM verify @0x8003E6xx never converges (writes garbage, never matches).
// Clear all 4MB of main RAM (SDRAM 0x000000-0x3FFFFC) once after the ROM download,
// holding CPU/C76 reset (~ram_cleared, OR'd into reset_or) until done. ~0.15s.
// ============================================================================
reg        ram_cleared = 1'b0;
reg [19:0] clr_addr    = 20'd0;
reg [2:0]  clr_state   = 3'd0;
reg        clr_req     = 1'b0;
reg        clr_rnw     = 1'b0;
reg [15:0] clr_settle  = 16'd0;
reg        dl_seen     = 1'b0;   // a ROM download has occurred (=> SDRAM is initialized & ROMs loaded)
localparam CLR_IDLE=3'd0, CLR_SETTLE=3'd1, CLR_ISSUE=3'd2, CLR_WAIT=3'd3, CLR_DONE=3'd6;
wire       clr_active  = (clr_state == CLR_ISSUE) || (clr_state == CLR_WAIT);
wire [31:0] zn_dbg_a0, zn_dbg_a1;
wire [31:0] zn_dbg_eeprom_o;
wire [31:0] zn_dbg_gpu;
wire [31:0] zn_dbg_disp;
wire [31:0] zn_dbg_dma;
wire [31:0] zn_dbg_madr;
wire [31:0] zn_dbg_nextaddr;
wire [31:0] zn_dbg_gpustat;
wire [31:0] zn_dbg_procst;
wire [31:0] zn_dbg_pv0, zn_dbg_pv2;
wire [31:0] zn_dbg_mipspc;  // live MIPS PC (mode 2)
wire [31:0] zn_dbg_pause;   // pause/ce forensics (mode 4)
wire [8:0]  dbg_sdram_fsm;   // {lastbank_valid, command[2:0], state[4:0]}
wire [7:0]  dbg_sdram_drd1;  // ch1 data-ready delay window
// GITHUB output template (2026-09-01): the ch1 edge counters, SDRAM monitor
// address, and remaining probe-mux scaffolding were debug instrumentation and
// are excluded from this edition.
// DDR3-acceptance forensics (2026-07-05): avalon-level write beats. A write transfers when
// WE=1 && BUSY=0. Counting both sides splits "GPU emitted writes" (psx_top vram_WE, mode 7)
// from "framework accepted writes" (here) — the lost-write stage is between them.
reg [15:0] ddram_we_acc  = 16'd0;   // accepted write beats (WE & ~BUSY)
reg [15:0] ddram_we_stall= 16'd0;   // stalled write cycles (WE & BUSY)
reg [7:0]  ddram_we_lastbe   = 8'd0;   // BE of the last accepted write
reg [23:0] ddram_we_lastaddr = 24'd0;  // DDRAM_ADDR low 24 of the last accepted write
always @(posedge clk_2x) begin
   if (DDRAM_WE & ~DDRAM_BUSY) begin
      ddram_we_acc      <= ddram_we_acc + 1'b1;
      ddram_we_lastbe   <= DDRAM_BE;
      ddram_we_lastaddr <= DDRAM_ADDR[23:0];
   end
   if (DDRAM_WE &  DDRAM_BUSY) ddram_we_stall <= ddram_we_stall + 1'b1;
end
// RELEASE BUILD: debug/forensic probes retired to reclaim ALMs. The design was
// fitting at 98% ALM / 96% DSP, which makes the fitter's job exponentially harder
// (long fits, intermittent nofit) and leaves no headroom for the remaining
// System 11 work. Disconnecting a probe from this mux lets synthesis prune its
// entire upstream counter/latch cone as dead logic.
//
// KEPT (the release QA gate depends on these — do not retire):
//   mode 5 = snd_triage   (c76stat.tcl)
//   mode B = gpustat      (gpustat_watch.tcl / gpures.tcl — boot liveness)
//   mode D = c76_status   (c76stat.tcl / c76health.tcl — C76-health boot gate)
//
// RETIRED here (restore from the parent commit when resuming that work):
//   mode 1 VRAM[X,Y] readback, mode 2 live MIPS PC, mode 3 SDRAM ch1/FSM counters,
//   mode 4 pause/ce forensics, mode 6 C352 voice-reg write, mode E PIO/cpu2vram
//   counters, and the VRAM-readback default (dbg_clr_rd).
//   mode 7 zn_dbg_procst (bit3 = errfifo_sticky, the GPU fifoIn-overflow detector)
//   is the Tekken 2 texture instrument — restore it on the T2 branch:
//     git checkout release/20260712~1 -- SYSTEM11.sv
// 2026-07-14 BLANK FORENSICS (modes 1 + 3). The blank is: game running (MIPS PC advancing,
// C76 healthy, GPUSTAT churning) but the screen is black for ~46 min, then it SELF-RECOVERS.
// Two mutually-exclusive causes, and these two probes separate them decisively:
//   (a) VRAM went black  -> nothing is being drawn / the framebuffer got wiped
//   (b) VRAM is fine but the SCANOUT points at the wrong place -> DisplayOffsetY / vramRange
// mode 1: VRAM[x,y] readback. Latch the coord by writing 0xF|Y<<10|X, then read mode 1.
//         Nonzero pixels during a blank => VRAM has content => cause (b), a scanout bug.
//         All-zero across a grid => cause (a), the framebuffer really is black.
// mode 3: [31:23]=DisplayOffsetY(9) [22:13]=DisplayOffsetX(10) [12:9]=frameindex(4)
//         [8]=GPUSTAT[23] display-disable [7:0]=0.  These are the exact bits that form
//         FB_BASE (see the assign above), i.e. where the scaler is told to scan out from.
//         A wrong DisplayOffsetY (e.g. stuck in the far half of VRAM) *is* cause (b) proven.
// GITHUB output template (2026-09-01): the altsource_probe ISSP instance and
// its probe mux (including the three dev-QA modes 5/B/D) are excluded from
// this edition — no JTAG debug instrumentation ships in the .rbf. To restore
// for development, take this region from the PATREON-side branch.
wire [26:0] clr_ch3_addr = {5'b0, clr_addr, 2'b00};
always @(posedge clk_1x) begin
   clr_req <= 1'b0;
   if (ioctl_download) dl_seen <= 1'b1;
   case (clr_state)
      // Only start AFTER a download has happened (SDRAM ready, ROMs loaded) and ioctl_download
      // is low; then settle (handles ioctl_download toggling between MRA indices).
      CLR_IDLE:   if (dl_seen && ~ioctl_download) begin clr_settle <= 16'd0; clr_state <= CLR_SETTLE; end
      CLR_SETTLE: if (ioctl_download) clr_state <= CLR_IDLE;          // a new download began -> rearm
                  else if (&clr_settle) begin clr_addr <= 20'd0; clr_rnw <= 1'b0; clr_state <= CLR_ISSUE; end
                  else clr_settle <= clr_settle + 1'b1;
      CLR_ISSUE:  begin clr_req <= 1'b1; clr_state <= CLR_WAIT; end   // issue 0-write
      CLR_WAIT:   if (sdramCh3_done) begin
                     if (clr_addr == 20'hFFFFF) begin ram_cleared <= 1'b1; clr_state <= CLR_DONE; end  // 4MB zero-fill complete
                     else begin clr_addr <= clr_addr + 1'b1; clr_state <= CLR_ISSUE; end
                  end
      // GITHUB output template (2026-09-01): the post-clear readback and the
      // periodic runtime re-read monitor were ch3 debug diagnostics and are
      // excluded from this edition. The zero-fill itself is functional (MAME's
      // main RAM is zero-initialized; games read never-written regions) and
      // completes here, releasing reset via ram_cleared.
      CLR_DONE:   ; // terminal — ch3 stays with its runtime owners
   endcase
end


// (The sentinel-readback state machine that lived here is excluded from the
// GITHUB output template — see the tie-offs above.)

// (2026-07-06 probe cleanup: CH1-predecessor monitor / ch1_cap / live-PC spin capture
// removed — their questions are answered; see project memory. Freed for routing.)
assign sdram_ack = sdram_readack | sdram_writeack;

sdram sdram
(
   .SDRAM_DQ   (SDRAM_DQ),
   .SDRAM_A    (SDRAM_A),
   .SDRAM_DQML (SDRAM_DQML),
   .SDRAM_DQMH (SDRAM_DQMH),
   .SDRAM_BA   (SDRAM_BA),
   .SDRAM_nCS  (SDRAM_nCS),
   .SDRAM_nWE  (SDRAM_nWE),
   .SDRAM_nRAS (SDRAM_nRAS),
   .SDRAM_nCAS (SDRAM_nCAS),
   .SDRAM_CKE  (SDRAM_CKE),
   .SDRAM_CLK  (SDRAM_CLK),

   .SDRAM_EN(1),
	.init(~pll_locked),
	.clk(clk_3x),       // STOCK ZN1 config: SDRAM on clk_3x=101.6MHz (proven-working in the ZN1 sibling core)
	.clk_sdramclk(clk_3x),     // SDRAM_CLK unshifted (stock write timing, matches sdram2/ZN1 baseline)
	.clk_dqcap(clk_3x),        // stock 0° capture (+90° A/B 2026-07-11: NO effect on T2 corruption, 620 vs 652 — not a DQ-margin fault)
	                           // corruption — root cause was the gpu.vhd fifoIn PIO/DMA write collision
	                           // (word drop), not DQ margin. Reverted to the proven ZN1 baseline.
	.clk_base(clk_1x),

	.refreshForce(sdr_refresh),
	.pagemode_en(1'b0),   // page-mode disabled: every read does ACTIVE (conservative stock behavior)

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(sdr_sdram_dout32),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(sdram_dma),
	.ch1_cntDMA(sdram_cntDMA),
	.ch1_cache(sdram_cache),
	.ch1_ready(sdram_readack),
	.cache_wr(cache_wr),
	.cache_data(cache_data),
	.cache_addr(cache_addr),
	.dma_wr(dma_wr),
	.dma_reqprocessed(dma_reqprocessed),
	.dma_data(dma_data),

	.ch2_addr (sdram_addr),
	.ch2_din  (sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  (sdram_req & ~sdram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr ((bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) ? ramdownload_wraddr : (clr_active ? clr_ch3_addr : (sentinel_active ? sent_addr : (zn_platform_r[4] ? (wave_ch3_own ? c76_wave_sdaddr : c76_sprog_sdaddr) : {6'b0, cheats_addr})))),  // ★ wave_ch3_own (NOT the 1-cycle req pulse): hold the wave address until the arbiter grants — see 2026-07-11 CH3 ADDRESS-HOLD FIX
	.ch3_din  ((bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) ? ramdownload_wrdata : (clr_active ? 32'b0 : (sentinel_active ? sent_din  : (zn_platform_r[4] ? 32'b0 : cheats_dout)))),
	.ch3_dout (cheats_din),
	.ch3_req  ((bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) ? ramdownload_wr     : (clr_active ? clr_req : (sentinel_active ? sent_req  : (zn_platform_r[4] ? (c76_sprog_req | c76_wave_req) : cheats_ena)))),
	.ch3_rnw  ((bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) ? 1'b0 : (clr_active ? clr_rnw : (sentinel_active ? sent_rnw : (zn_platform_r[4] ? 1'b1 : cheats_rnw)))),
	.ch3_be   ((bios_download | fixedrom_download | bankedrom_download | sprog_download | wave_download) ? 4'b1111            : (clr_active ? 4'b1111 : (sentinel_active ? sent_be : (zn_platform_r[4] ? 4'b1111 : cheats_be)))),
	.ch3_ready(sdramCh3_done),

	.dmafifo_adr  (sdram_dmafifo_adr),
	.dmafifo_data (sdram_dmafifo_data),
	.dmafifo_empty(sdram_dmafifo_empty),
	.dmafifo_read (sdram_dmafifo_read),
	.dbg_pm_hit   (),
	.dbg_pm_open  (),
	.dbg_pm_pre   (),
	.dbg_sdram    (dbg_sdram_fsm),
	.dbg_drd1     (dbg_sdram_drd1)
);
// SDRAM JTAG diagnostics removed with the revert-to-ZN1-stock; tie the probe wires off (read 0).
wire [31:0]  sdram_dbg_raw = 32'b0;

wire [31:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [31:0] spuram_dataRead;
wire        spuram_done;

assign spuram_done     = sdram_readack2 | sdram_writeack2;

`ifdef MISTER_DUAL_SDRAM

sdram sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
   .SDRAM_A    (SDRAM2_A),
   .SDRAM_DQML (),
   .SDRAM_DQMH (),
   .SDRAM_BA   (SDRAM2_BA),
   .SDRAM_nCS  (SDRAM2_nCS),
   .SDRAM_nWE  (SDRAM2_nWE),
   .SDRAM_nRAS (SDRAM2_nRAS),
   .SDRAM_nCAS (SDRAM2_nCAS),
   .SDRAM_CKE  (),
   .SDRAM_CLK  (SDRAM2_CLK),
   .SDRAM_EN   (SDRAM2_EN),

	.init(~pll_locked),
	.clk(clk_3x),       // STOCK ZN1 config: SDRAM on clk_3x=101.6MHz
	.clk_sdramclk(clk_3x),  // sdram2 (SPU): SDRAM_CLK on clk_3x (unchanged)
	.clk_dqcap(clk_3x),     // sdram2 read-DQ capture clock (stock)
	.clk_base(clk_1x),

	.refreshForce(1'b0),
	.pagemode_en(1'b0),
	.ram_idle(),

	.ch1_addr(spuram_Adr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(spuram_dataRead),
	.ch1_req(spuram_ena & spuram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(1'b0),
   .ch1_cntDMA(2'b00),
	.ch1_cache(1'b0),
	.ch1_ready(sdram_readack2),

	.ch2_addr (spuram_Adr),
	.ch2_din  (spuram_dataWrite),
	.ch2_dout (),
	.ch2_req  (spuram_ena & ~spuram_rnw),
	.ch2_rnw  (1'b0),
   .ch2_be   (spuram_be),
	.ch2_ready(sdram_writeack2),

	.ch3_addr(0),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready(),

	.dmafifo_adr  (0),
	.dmafifo_data (0),
	.dmafifo_empty(1'b1),
	.dmafifo_read ()
);

`else

wire SDRAM2_EN = 0;

assign spuram_dataRead = '0;
assign sdram_readack2 = '0;
assign sdram_writeack2 = '0;

`endif


assign DDRAM_CLK = clk_2x;

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_vid;

wire hs, vs, hbl, vbl, video_interlace, video_isPal, video_fbmode, video_fb24;

wire [2:0] video_hResMode;

wire ce_pix;
wire [7:0] r,g,b;
// GITHUB output template (2026-09-01): the wires below only sink psx_top's
// diagnostic output ports so the instantiation stays complete; nothing reads
// them in this edition, so their upstream cones prune at synthesis. The
// load-word capture, overlay indexing, and JTAG readout that consumed them
// are excluded.
wire [6:0] zn_debug_out;
wire [31:0] zn_debug_val;
wire [2047:0] trace_flat;
wire [31:0]   trace_meta;
wire [31:0] zn_debug_addr;
wire [255:0] zn_debug_words;

wire hack_480p = status[89];

typedef struct {
	logic [7:0] red;
	logic [7:0] green;
	logic [7:0] blue;
	logic       hs;
	logic       vs;
	logic       hb;
	logic       vb;
	logic       interlace;
} vid_info;

vid_info video_aspect;
vid_info video_gamma;

// ===== Light-gun CROSSHAIR overlay (Point Blank 2 / Gunbarl) =====
// The arcade cabinet draws NO crosshair — you aim a physical gun at the screen, and MAME's
// crosshair is its own UI overlay (PORT_CROSSHAIR -> emu/crsshair.cpp), not game output. With a
// mouse you cannot aim at what you cannot see, so the core has to draw one itself.
// Derive pixel coordinates from the blanking edges rather than touching the GPU pipeline.
// The gun counters map almost 1:1 onto the active area (X 216..903 = 688 wide, Y 44..283 = 240
// tall), so subtracting the minimum gives a screen position directly.
// OFF by default: keycus 0x09 is shared with My Angel 3 (not a gun game), and anyone using a real
// Sinden/GunCon aims physically and does not want a synthetic crosshair.
// MEASURE the real active area from the blanking edges — do not assume a resolution. h_act/v_act
// are latched each line/frame and also read back on JTAG mode 6 to confirm the mapping on hardware.
reg  [11:0] xh_hcnt = 12'd0;   // live pixel-in-line (also the running width)
reg  [11:0] xh_vcnt = 12'd0;   // live line-in-frame (also the running height)
reg  [11:0] h_act   = 12'd320;
reg  [11:0] v_act   = 12'd240;
reg         xh_hb_d = 1'b0;
reg         xh_vb_d = 1'b0;
reg  [11:0] xh_cx   = 12'd160;  // crosshair centre in ACTIVE-AREA pixels, refreshed per frame
reg  [11:0] xh_cy   = 12'd120;
reg  [11:0] xh2_cx  = 12'd160;  // P2 crosshair (drawn GREEN so the two players can tell them apart)
reg  [11:0] xh2_cy  = 12'd120;
wire [21:0] cx_mul  = gun_px * h_act;   // virtual 1024 wide  -> >>10
wire [19:0] cy_mul  = gun_py * v_act;   // virtual  256 tall  -> >>8
wire [21:0] c2x_mul = gun2_px * h_act;  // P2 shares the same virtual space, so the same mapping
wire [19:0] c2y_mul = gun2_py * v_act;
always @(posedge CLK_VIDEO) begin
   if (ce_pix) begin
      xh_hb_d <= video_gamma.hb;
      xh_vb_d <= video_gamma.vb;
      if (video_gamma.hb) begin
         if (~xh_hb_d) begin                          // entering hblank: a line just ended
            h_act   <= xh_hcnt;                       // latch measured active width
            xh_hcnt <= 12'd0;
            if (~video_gamma.vb) xh_vcnt <= xh_vcnt + 12'd1;
         end
      end else begin
         xh_hcnt <= xh_hcnt + 12'd1;
      end
      if (video_gamma.vb & ~xh_vb_d) begin            // entering vblank: frame ended
         v_act   <= xh_vcnt;                          // latch measured active height
         xh_vcnt <= 12'd0;
         xh_cx   <= cx_mul[21:10];                    // refresh crosshair once per frame (no tearing)
         xh_cy   <= cy_mul[19:8];
         xh2_cx  <= c2x_mul[21:10];
         xh2_cy  <= c2y_mul[19:8];
      end
   end
end
wire [11:0] xh_dx = (xh_hcnt >= xh_cx) ? (xh_hcnt - xh_cx) : (xh_cx - xh_hcnt);
wire [11:0] xh_dy = (xh_vcnt >= xh_cy) ? (xh_vcnt - xh_cy) : (xh_cy - xh_vcnt);
wire        xhair = status[100] & zn_gun_game
                    & ~video_gamma.hb & ~video_gamma.vb
                    & (((xh_dy == 12'd0) & (xh_dx <= 12'd6))     // horizontal arm
                     | ((xh_dx == 12'd0) & (xh_dy <= 12'd6)));   // vertical arm
// P2 crosshair: same geometry, but gated on p2_gun_active so a solo player never sees a stray
// second reticle parked at screen centre. Drawn GREEN to distinguish it from P1's white.
wire [11:0] xh2_dx = (xh_hcnt >= xh2_cx) ? (xh_hcnt - xh2_cx) : (xh2_cx - xh_hcnt);
wire [11:0] xh2_dy = (xh_vcnt >= xh2_cy) ? (xh_vcnt - xh2_cy) : (xh2_cy - xh_vcnt);
wire        xhair2 = status[100] & zn_gun_game & p2_gun_active
                    & ~video_gamma.hb & ~video_gamma.vb
                    & (((xh2_dy == 12'd0) & (xh2_dx <= 12'd6))
                     | ((xh2_dx == 12'd0) & (xh2_dy <= 12'd6)));

assign CE_PIXEL = ce_pix;
assign VGA_R    = xhair ? 8'hFF : xhair2 ? 8'h00 : video_gamma.red;
assign VGA_G    = (xhair | xhair2) ? 8'hFF : video_gamma.green;
assign VGA_B    = xhair ? 8'hFF : xhair2 ? 8'h00 : video_gamma.blue;
assign VGA_VS   = video_gamma.vs;
assign VGA_HS   = video_gamma.hs;
assign VGA_DE   = ~(video_gamma.vb | video_gamma.hb);
assign VGA_F1   =  status[14] ? 1'b0 : video_aspect.interlace;
assign VGA_SL = 0;
logic [11:0] aspect_x, aspect_y;

wire [1:0] ar = status[33:32];
// ARX/ARY live readback: [25:24]=ar(0=use LUT) [23:12]=ARX(aspect_x) [11:0]=ARY(aspect_y). Ratio ARX/ARY should be ~4:3.
wire [31:0] arx_ary_dbg = {6'b0, ar, aspect_x[11:0], aspect_y[11:0]};
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? ((status[54:53] == 1) ? 3 : (status[54:53] == 2) ? 5 : (status[54:53] == 3) ? 16 : status[11] ? 12'd2 : aspect_x) : (ar - 1'd1)),
	.ARY((!ar) ? ((status[54:53] == 1) ? 2 : (status[54:53] == 2) ? 3 : (status[54:53] == 3) ?  9 : status[11] ? 12'd1 : aspect_y) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);

// Res  Div Padding
// 256  10  +25
// 320  8   +32
// 368  7   +37
// 512  5   +51
// 640  4   +64

localparam reg [23:0] aspect_ratio_lut_ntsc[128] = '{
    24'h37015B, 24'h2B4113, 24'h1A10A7, 24'hEB45EF, 24'hA00411, 24'hF8365B, 24'hA31435, 24'h6A42C3,
    24'h85D381, 24'hF8F691, 24'h581257, 24'h1860A7, 24'hFD56D4, 24'h6EF303, 24'h497202, 24'hDA1601,
    24'hF8D6E6, 24'h8513B7, 24'hB014F3, 24'h3C51B5, 24'h3971A3, 24'hC02583, 24'hD09606, 24'h4E1245,
    24'hFEF776, 24'hC555D0, 24'hBD559D, 24'hE686E1, 24'hF7C771, 24'hC4F5F4, 24'h655315, 24'hB5158B,
    24'h2C015B, 24'h1750B9, 24'hC74637, 24'hF857CB, 24'h89B459, 24'h800411, 24'hC87668, 24'hA21536,
    24'hFB3820, 24'h443238, 24'hE17761, 24'hFD3856, 24'h207113, 24'h204113, 24'h3941EB, 24'hE6F7C8,
    24'h28015B, 24'hD55745, 24'hD21733, 24'hE9F810, 24'hC0A6AD, 24'h99955A, 24'hA0359D, 24'h7FF482,
    24'hD5B792, 24'hE5C82F, 24'hF558C9, 24'h35D1F0, 24'h6EF404, 24'h93155A, 24'h5BF35D, 24'h9F75DD,
    24'h6E0411, 24'h2DF1B5, 24'h44D292, 24'h1160A7, 24'hB4F6D4, 24'hD49810, 24'hD057F1, 24'h91B595,
    24'hB006C7, 24'hF959A6, 24'hE338D6, 24'hC1378D, 24'hC557C0, 24'hF579B0, 24'h7E1500, 24'hABD6D9,
    24'hFE3A2E, 24'hD3D886, 24'h54736A, 24'hFF3A5E, 24'hE19935, 24'hF42A03, 24'h356233, 24'hFEBA8B,
    24'h957637, 24'hEFAA03, 24'h43F2DA, 24'hA6F70A, 24'h20015B, 24'h24D191, 24'h72E4E9, 24'hC1E853,
    24'hDC097D, 24'hD09909, 24'hFE8B13, 24'hD5E959, 24'hFEFB31, 24'h2B81EB, 24'h8A5620, 24'h2B91F0,
    24'h2AF1EB, 24'hD3F982, 24'hED9AB4, 24'h163101, 24'h724531, 24'hDCBA12, 24'hC50907, 24'hFB7B92,
    24'h580411, 24'hFDDBC7, 24'hAA77F1, 24'hD259D7, 24'h2ED233, 24'h2431B5, 24'hC1992B, 24'h20F191,
    24'h7665A7, 24'h42D334, 24'hD09A0A, 24'hF17BAB, 24'hFFFC6B, 24'h6B653B, 24'h5153FA, 24'hFD9C73
};

localparam reg [23:0] aspect_ratio_lut_pal[160] = '{
    24'hE8F4D9, 24'h41015D, 24'h40815D, 24'h8EB30A, 24'hF8D557, 24'h1C009B, 24'h1CB0A0, 24'h473190,
    24'h711280, 24'hCEF49C, 24'hD734D4, 24'hCAC495, 24'h4791A1, 24'hF695A7, 24'hC7549A, 24'hC31489,
    24'hAEB417, 24'hB8C45B, 24'hA2C3DD, 24'hBCF484, 24'hD2E513, 24'hC2A4B7, 24'hEFF5DA, 24'h85D349,
    24'h18809B, 24'h0C9050, 24'hF59626, 24'hE595C9, 24'h35C15D, 24'hF81655, 24'h0EC061, 24'hEA160D,
    24'h68D2BA, 24'hD735A2, 24'h4731E0, 24'hE9A631, 24'hDC35DF, 24'h6D12ED, 24'h96D412, 24'hB87502,
    24'hCFF5AE, 24'h73732C, 24'hF1D6AF, 24'h7CA377, 24'h30C15D, 24'hA7A4B7, 24'h5C629D, 24'h3941A1,
    24'h4A221F, 24'hF5B712, 24'hD5F631, 24'h8ED428, 24'h8BC417, 24'hE236A8, 24'hA854FB, 24'hEAE6FD,
    24'hD73670, 24'hD5666B, 24'hFD97AB, 24'hA8751F, 24'hCDA649, 24'hCE1655, 24'h5C92DC, 24'h3BC1DB,
    24'hAEB574, 24'hB5A5B3, 24'hFE8807, 24'h2B015D, 24'h13009B, 24'hB6F5DC, 24'hA5E557, 24'hC7D677,
    24'hD1A6D1, 24'h099050, 24'hEF37DB, 24'hB8C619, 24'h25B140, 24'h4FD2A9, 24'hE1978E, 24'hD7373E,
    24'h28515D, 24'hE437C1, 24'hD35737, 24'hF4D866, 24'hF97899, 24'h42724D, 24'h5572F9, 24'h27015D,
    24'hCF0745, 24'h6D83DD, 24'hFFB910, 24'hE35818, 24'hEB2869, 24'hB1565F, 24'hF3F8CE, 24'hE05822,
    24'h10A09B, 24'hEFF8C7, 24'h9E35D0, 24'h87B502, 24'hBAF6EE, 24'hD7D809, 24'hD7380C, 24'hF59939,
    24'h2E31BE, 24'hE0B883, 24'h6B8417, 24'h93F5A7, 24'h09E061, 24'hE3B8C6, 24'hBCE74F, 24'h2FC1DB,
    24'h22F15D, 24'h818513, 24'h5ED3BB, 24'hFF3A15, 24'h5AB399, 24'hB52737, 24'hF0199A, 24'hEE5992,
    24'hBDB7A6, 24'hC74811, 24'h3FD298, 24'h77F4E5, 24'h4552D7, 24'h1390CE, 24'hE4D973, 24'h25B190,
    24'h91960F, 24'hBBD7D9, 24'h20815D, 24'h788513, 24'h20415D, 24'h9BF69E, 24'h8EB614, 24'h8435A7,
    24'hF8DAAE, 24'h9B26AF, 24'h0E009B, 24'h8EA631, 24'h1CB140, 24'h1B112F, 24'hD05925, 24'hD1F940,
    24'h89060F, 24'hD7098B, 24'h88060F, 24'h4172ED, 24'hD739A8, 24'hDBE9E7, 24'h656495, 24'hFF8B97,
    24'hD1A98B, 24'hA6D79F, 24'hB4E84B, 24'hEC7AE1, 24'hFF1BC7, 24'h5C944A, 24'hC31912, 24'hEE8B21
};

logic [11:0] h_pos, v_pos, vb_pos, v_total;
logic [11:0] hb_start_lut[8];
logic [11:0] hb_end_lut[8];
logic [11:0] hb_start, hb_end;

// FIXME: this should be adjusted if hsync changes size to maintain center
assign hb_start_lut = '{12'd63,  12'd50,  12'd36,  12'd31,  12'd24,  12'd0, 12'd0, 12'd0};
assign hb_end_lut =   '{12'd767, 12'd613, 12'd441, 12'd383, 12'd305, 12'd0, 12'd0, 12'd0};

always_comb begin
	hb_start = hb_start_lut[video_hResMode];
	hb_end = hb_end_lut[video_hResMode];
end

always_ff @(posedge CLK_VIDEO) if (CE_PIXEL) begin
	logic old_vb;
	old_vb <= vbl;
	video_aspect.hs <= hs;
	video_aspect.vs <= vs;
	video_aspect.vb <= vbl;
	video_aspect.interlace <= video_interlace;
	video_aspect.red <= (vbl || hbl) ? 8'd0 : r;
	video_aspect.green <= (vbl || hbl) ? 8'd0 : g;
	video_aspect.blue <= (vbl || hbl) ? 8'd0 : b;
	{aspect_x, aspect_y} <= video_isPal ? aspect_ratio_lut_pal[v_total] : aspect_ratio_lut_ntsc[v_total];

	VGA_DISABLE <= fast_forward;

	h_pos <= h_pos + 1'd1;
	if (~old_vb && vbl)
		vb_pos <= 0;

	if (video_aspect.hs && ~hs) begin
		h_pos <= 0;
		if (~vbl)
			v_pos <= v_pos + 1'd1;
		else
			vb_pos <= vb_pos + 1'd1;
	end

	if (~video_aspect.vs && vs) begin
		v_pos <= 0;

		if (v_pos < 128)
			v_total <= 6'd0;
		else if (video_isPal && v_pos > 287)
			v_total <= 8'd159;
		else if (~video_isPal && v_pos > 255)
			v_total <= 7'd127;
		else
			v_total <= v_pos - 8'd128;
	end

	if (vb_pos > (video_isPal ? 161 : 135))
		video_aspect.vb <= 0;

	if (h_pos == hb_start)
		video_aspect.hb <= 0;
	if (h_pos == hb_end)
		video_aspect.hb <= 1;
	if (status[62] || hack_480p || (status[54:53] > 0))
		video_aspect.hb <= hbl;

	// GITHUB output template (2026-09-01): the boot-debug bar overlay (the
	// status[93] bit-bar renderer and its visible-area pixel counters) is
	// excluded from this edition.

end

// GITHUB output template (2026-09-01): the pause screen (credits overlay) is
// excluded from this edition. Pausing (button or OSD) still freezes the core;
// every pause source now simply displays the last game frame.

assign gamma_bus[21] = 1;
gamma_corr gamma(
	.clk_sys(gamma_bus[20]),
	.clk_vid(CLK_VIDEO),
	.ce_pix(CE_PIXEL),

	.gamma_en(gamma_bus[19]),
	.gamma_wr(gamma_bus[18]),
	.gamma_wr_addr(gamma_bus[17:8]),
	.gamma_value(gamma_bus[7:0]),

	.HSync(video_aspect.hs),
	.VSync(video_aspect.vs),
	.HBlank(video_aspect.hb),
	.VBlank(video_aspect.vb),
	.RGB_in({video_aspect.red, video_aspect.green, video_aspect.blue}),

	.HSync_out(video_gamma.hs),
	.VSync_out(video_gamma.vs),
	.HBlank_out(video_gamma.hb),
	.VBlank_out(video_gamma.vb),
	.RGB_out({video_gamma.red,video_gamma.green,video_gamma.blue})
);



////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
reg [127:0] gg_code;
reg gg_valid;
reg gg_reset;
reg code_download_1;
wire gg_active;
always_ff @(posedge clk_1x) begin

   gg_reset <= 0;
   code_download_1 <= code_download;
	if (code_download && ~code_download_1) begin
      gg_reset <= 1;
   end

   gg_valid <= 0;
	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_valid          <= 1;          // Clock it in
			end
		endcase
	end
end

wire clk8Snac;
wire clk9Snac;
wire oldClk8;
wire oldClk9;
wire selectedPort1Snac;
wire selectedPort2Snac;
wire oldselectedPort1;
wire oldselectedPort2;
wire [7:0]transmitValueSnac;
wire [7:0]receiveBufferSnac;
wire receiveValidSnac;
wire beginTransferSnac;
wire actionNextSnac;
wire actionNextPadSnac;
reg [7:0]Send;
reg [7:0]Receive;
wire Cmd;
wire Dat;
wire ack;
wire oldAck;
//wire ackSnac;
wire [15:0]ackTimer;
wire ackNone;
wire oneTime;
wire [3:0]bitCnt;
wire [8:0]byteCnt;
wire [8:0]bytesLeft;
wire [7:0]pad1ID;
wire [7:0]pad2ID;
wire [7:0]targetID;
wire irq10Snac;
wire csync;
wire MCtransfer;
wire PStransfer;
wire [7:0]PSdatalength;

reg USER_IN3_1;
reg USER_IN4_1;
reg USER_IN6_1;

reg USER_IN3_2;
reg USER_IN4_2;
reg USER_IN6_2;

reg USER_IN3_3;
reg USER_IN3_4;
reg ackglitch;

assign clk8Snac = bitCnt < 8 ? clk9Snac : 1'b1;

always @(posedge clk_1x)
begin

   USER_IN3_1 <= USER_IN[3];
   USER_IN4_1 <= USER_IN[4];
   USER_IN6_1 <= USER_IN[6];

   USER_IN3_2 <= USER_IN3_1;
   USER_IN4_2 <= USER_IN4_1;
   USER_IN6_2 <= USER_IN6_1;

   USER_IN3_3 <= USER_IN3_2;//glitch filter for ack
   USER_IN3_4 <= USER_IN3_3;
   ackglitch  <= ~USER_IN3_1 && ~USER_IN3_2 && ~USER_IN3_3 && ~USER_IN3_4 ? 1'b0 : 1'b1;

	if (snacPort1 || snacPort2) begin
		USER_OUT[0] <= ~selectedPort2Snac;
		USER_OUT[1] <= ~selectedPort1Snac;
		USER_OUT[2] <= Cmd;
		USER_OUT[3] <= 1'b1; //ACK
		USER_OUT[4] <= 1'b1; //DAT
		USER_OUT[5] <= oldClk8;
		ack         <= ~ackglitch ? USER_IN3_2 : 1'b1;
		Dat         <= USER_IN4_2;

		if ((pad1ID == 8'h63 || pad2ID == 8'h63) && (pad1ID != 8'h31 || pad2ID != 8'h31)) begin //quirk for guncon, irq is N/C in guncon. so using irq line and outputting csync on snac for g-con. only if justifier isn't connected
			USER_OUT[6] <= ~csync;
			irq10Snac   <= 1'b0;
			csync       <= VGA_HS ^ VGA_VS;//real csync shifts HSync during VSync, should be close enough to work	with guncon
		end
		else begin
			USER_OUT[6] <= 1'b1;
			irq10Snac   <= ~USER_IN6_2;
		end
	end
	else begin
		USER_OUT  <= '1;
		irq10Snac <= 1'b0;
		ack       <= 1'b1;
		Dat       <= 1'b1;
	end

	oldselectedPort1 <= selectedPort1Snac;
	oldselectedPort2 <= selectedPort2Snac;

	if ((~oldselectedPort1 && selectedPort1Snac) || (~oldselectedPort2 && selectedPort2Snac)) begin
		byteCnt   <= 9'd0;
		bytesLeft <= 9'd0;
	end

	if (beginTransferSnac) begin
		bitCnt  <= 4'd0;
		byteCnt <= byteCnt + 9'd1 ;
	end

	oldClk8 <= clk8Snac;
	oldClk9 <= clk9Snac;

	if (oldClk9 && ~clk9Snac) begin	//send on falling edge
		if (bitCnt < 8) begin
			if (bitCnt==0) begin
				Cmd  <= transmitValueSnac[0];
				Send <= {1'b1, transmitValueSnac[7:1]};
			end
			else begin
				Cmd  <= Send[0];
				Send <= {1'b1, Send[7:1]};
			end
		end
		else begin
			Cmd  <= 1'b1;
			Send <= Send;
		end
	end

	if(~oldClk8 && clk8Snac) begin //receive on rising edge
		Receive <= { Dat, Receive[7:1]};
		bitCnt <= bitCnt + 1'b1;
		if(bitCnt == 4'd7) begin//check for ack
			oneTime <= 1'b1;
			if (MCtransfer) ackTimer <= 16'd60000;//very late ack after 7th byte. around 56000 cycles (1.7ms) with a sony MC. 3rd party MCs don't seem to do this
			else begin
				if (byteCnt == bytesLeft + 3) ackTimer <= 16'd400;//only wait around 150 on last byte
				else ackTimer <= 16'd1800;//1st byte of multitap(1375) cycles to ack,digital(460),analog(350-400),ds2(250-400),mouse(120),guncon(270)
			end
		end
	end

	if (ackTimer > 0) begin
		ackTimer <= ackTimer - 16'd1;
	end

	oldAck <= ack;
	if(oldAck && ~ack) begin //ack received
		actionNextPadSnac <= 1'b1;
		ackTimer <= 16'd173;//16'd255;//a delay between ack and next action. too small might cause a hang. was using acktimer 1-255
	end
	else if(ackTimer == 1) begin //wait over
		actionNextPadSnac <= 1'b1;
		oneTime <= 1'b0;
	end
	else if (ackTimer == 16'd258) begin //no ack
		ackNone <= 1'b1;
		actionNextPadSnac <= 1'b1;
	end
	else if (ackTimer == 16'd256) begin //reset if no ack
		oneTime <= 1'b0;
		ackTimer <= 16'd0;
	end
	else begin
		actionNextPadSnac <= 1'b0;
		ackNone <= 1'b0;
	end

	if (actionNextPadSnac && ((snacPort1 && selectedPort1Snac) || (snacPort2 && selectedPort2Snac))) begin //logic for joypad.vhd
		if (oneTime) begin
			if (ackNone) begin
				if (byteCnt < (bytesLeft + 4)) begin // no ack on last byte of transfer
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					actionNextSnac <= 1'b1;
				end
				else
					actionNextSnac <= 1'b1;
				end
			else begin
				if (byteCnt < (bytesLeft + 4)) begin
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					//ackSnac <= 1'b1;
				end
				actionNextSnac <= 1'b1;
			end
		end
		else begin
			actionNextSnac <= 1'b1;
		end
	end
	else begin
		receiveBufferSnac <= 8'd0;
		receiveValidSnac <= 1'b0;
		actionNextSnac <= 1'b0;
		//ackSnac <= 1'b0;
	end

	if (receiveValidSnac) begin
		if (byteCnt == 1) begin
			targetID <= transmitValueSnac;
		end
		if (byteCnt == 2) begin
			if (targetID == 8'h81 || targetID == 8'h82 || targetID == 8'h83 || targetID == 8'h84) begin 	//memcard quirks
				MCtransfer <= 1'b1;
				if (transmitValueSnac == 8'h52) bytesLeft <= 9'd137;//read
				if (transmitValueSnac == 8'h57) bytesLeft <= 9'd135;//write
				if (transmitValueSnac == 8'h53) bytesLeft <= 9'd7;//ID Cmd
				//pocketstation
				if (transmitValueSnac == 8'h50) bytesLeft <= 9'd0;//Change a FUNC 03h related value
				if (transmitValueSnac == 8'h58) bytesLeft <= 9'd2;//Get an ID or Version value
				if (transmitValueSnac == 8'h59) bytesLeft <= 9'd6;//Prepare File Execution with Dir_index, and Parameter
				if (transmitValueSnac == 8'h5A) bytesLeft <= 9'd18;//Get Dir_index, ComFlags, F_SN, Date, and Time
				if (transmitValueSnac == 8'h5D) bytesLeft <= 9'd3;//Execute Custom Download Notification
				if (transmitValueSnac == 8'h5E) bytesLeft <= 9'd3;//Get-and-Send ComFlags.bit1,3,2
				if (transmitValueSnac == 8'h5F) bytesLeft <= 9'd1;//Get-and-Send ComFlags.bit0
				if (transmitValueSnac == 8'h5B) begin//Execute Function and transfer data from Pocketstation to PSX--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
				if (transmitValueSnac == 8'h5C) begin//Execute Function and transfer data from PSX to Pocketstation--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
			end
			else begin //joypad quirks
				MCtransfer <= 1'b0;
				if (selectedPort1Snac) pad1ID <= Receive;
				if (selectedPort2Snac) pad2ID <= Receive;

				if (Receive == 8'h80) bytesLeft <= 9'd32; //for multitap
				else bytesLeft <= {5'd0, (Receive[3:0] + Receive[3:0])};
			end
		end
		if (byteCnt == 4 && PStransfer == 1) begin //for pocketstation
			bytesLeft <= bytesLeft + Receive;
			PSdatalength <=  Receive;
		end
		if ((byteCnt == PSdatalength + 5) && PStransfer == 1) begin
			bytesLeft <= bytesLeft + Receive;
			PStransfer <= 1'b0;
		end
	end
end

endmodule
