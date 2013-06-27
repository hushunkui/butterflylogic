//--------------------------------------------------------------------------------
// core.vhd
//
// Copyright (C) 2006 Michael Poppitz
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
//
//--------------------------------------------------------------------------------
//
// Details: http://www.sump.org/projects/analyzer/
//
// The core contains all "platform independent" modules and provides a
// simple interface to those components. The core makes the analyzer
// memory type and computer interface independent.
//
// This module also provides a better target for test benches as commands can
// be sent to the core easily.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module core #(
  parameter integer SDW = 32,    // sample data width
  parameter integer MDW = 32,    // memory data width
  parameter integer MKW = MDW/8  // memory keep width
)(
  // system signals
  input  wire           clk,     // clock
  input  wire           rst,     // reset
  // configuration/control inputs
  input  wire     [7:0] cmd_code,       // Configuration command from serial/SPI interface
  input  wire    [31:0] cmd_data,
  input  wire           cmd_valid,      // cmd_code & cmd_data valid
  output wire           cmd_valid_flags,
  // configuration/control outputs
  input  wire           extTriggerIn,
  output wire           extTriggerOut,
  output wire           extClock_mode,
  output wire           extTestMode,
  output reg            indicator_arm,
  output reg            indicator_trg,
  // input stream
  input  wire           sti_clk,
  input  wire [SDW-1:0] sti_data_p,
  input  wire [SDW-1:0] sti_data_n,
  // memory write interface
  input  wire           sto_tready,
  output wire           sto_tvalid,
  output wire           sto_tlast ,
  output wire [MKW-1:0] sto_tkeep ,
  output wire [MDW-1:0] sto_tdata
);

// data stream (sync -> cdc)
wire           sync_tready;
wire           sync_tvalid;
wire [SDW-1:0] sync_tdata ;
// data stream (cdc -> sample)
wire           cdc_tready;
wire           cdc_tvalid;
wire [SDW-1:0] cdc_tdata ;
// data stream (sample -> trigger, delay)
wire           sample_tready;
wire           sample_tvalid;
wire [SDW-1:0] sample_tdata ; 
// data stream (align -> rle)
wire           align_tready;
wire           align_tvalid;
wire [SDW-1:0] align_tdata ;
// data stream (rle -> controller)
wire           rle_tready; 
wire           rle_tvalid; 
wire [SDW-1:0] rle_tdata ;


wire  [3:0] wrtrigmask; 
wire  [3:0] wrtrigval; 
wire  [3:0] wrtrigcfg;
wire        wrDivider; 
wire        wrsize; 

wire arm_basic, arm_adv;
wire arm = arm_basic | arm_adv;

//
// Reset...
//
wire sti_rst;
reset_sync reset_sync_sample (sti_clk, rst, sti_rst);


//
// Decode flags register...
//
wire [31:0] flags_reg;
wire        demux_mode     = flags_reg[0];                    // DDR sample the input data
wire        filter_mode    = flags_reg[1];                    // Apply half-clock glitch noise filter to input data
wire  [3:0] disabledGroups = flags_reg[5:2];                  // Which channel groups should -not- be captured.
assign      extClock_mode  = flags_reg[6];                    // Use external clock for sampling.
wire        falling_edge   = flags_reg[7];                    // Capture on falling edge of sample clock.
wire        rleEnable      = flags_reg[8];                    // RLE compress samples
wire        numberScheme   = flags_reg[9];                    // Swap upper/lower 16 bits
assign      extTestMode    = flags_reg[10] && !numberScheme;  // Generate external test pattern on upper 16 bits of sti_data
wire        intTestMode    = flags_reg[11];                   // Sample internal test pattern instead of sti_data[31:0]
wire  [1:0] rle_mode       = flags_reg[15:14];                // Change how RLE logic issues <value> & <counts>


//
// Sample external trigger signals...
//
wire run_basic, run_adv, run; 
dly_signal extTriggerIn_reg  (clk, extTriggerIn, sampled_extTriggerIn);
dly_signal extTriggerOut_reg (clk, run, extTriggerOut);

assign run = run_basic | run_adv | sampled_extTriggerIn;



//
// indicators can be connected to LED
//
always @ (posedge clk, posedge rst)
if (rst)        indicator_arm <= 1'b0;
else begin
  if      (arm) indicator_arm <= 1'b1;
  else if (run) indicator_arm <= 1'b0;
end

always @(posedge clk, posedge rst)
if (rst)        indicator_trg <= 1'b0;
else begin
  if      (run) indicator_trg <= 1'b1;
  else if (arm) indicator_trg <= 1'b0;
end

//
// Decode commands & config registers...
//
decoder decoder (
  // system signals
  .clk          (clk),
  .rst          (rst),
  // command
  .cmd_valid    (cmd_valid),
  .cmd_code     (cmd_code),
  // outputs...
  .wrtrigmask   (wrtrigmask),
  .wrtrigval    (wrtrigval),
  .wrtrigcfg    (wrtrigcfg),
  .wrspeed      (wrDivider),
  .wrsize       (wrsize),
  .wrFlags      (cmd_valid_flags),
  .wrTrigSelect (wrTrigSelect),
  .wrTrigChain  (wrTrigChain),
  .finish_now   (finish_now),
  .arm_basic    (arm_basic),
  .arm_adv      (arm_adv)
);

//
// Configuration flags register...
//
flags flags (
  .clk         (clk),
  .rst         (rst),
  //
  .cmd_valid   (cmd_valid_flags),
  .cmd_data    (cmd_data),
  //
  .finish_now  (finish_now),
  // outputs...
  .flags_reg   (flags_reg)
);

// Capture input relative to sti_clk...
sync #(
  .DW (SDW)
) sync (
  // configuration/control
  .intTestMode  (intTestMode),
  .numberScheme (numberScheme),
  .filter_mode  (filter_mode),
  .demux_mode   (demux_mode),
  .falling_edge (falling_edge),
  // input stream
  .sti_clk      (sti_clk),
  .sti_rst      (sti_rst),
  .sti_data_p   (sti_data_p),
  .sti_data_n   (sti_data_n),
  // outputs stream
  .sto_tready   (sync_tready)
  .sto_tvalid   (sync_tvalid)
  .sto_tdata    (sync_tdata),
);

// Transfer from input clock (whatever it may be) to the core clock 
// (used for everything else, including RLE counts)...
cdc #(
  .DW  (SDW),
  .FF  (8)
) cdc (
  // input interface
  .ffi_clk  (sti_clk),
  .ffi_rst  (sti_rst),
  .ffi_dat  (sync_tdata ),
  .ffi_vld  (sync_tvalid),
  .ffi_rdy  (sync_tready),
  // output interface
  .ffo_clk  (clk),
  .ffo_rst  (rst),
  .ffo_dat  (cdc_tdata ),
  .ffo_vld  (cdc_tvalid),
  .ffo_rdy  (cdc_tready)
);

// subsampling input stream
sampler #(
  .DW (SDW)
) sampler (
  // system signals
  .clk           (clk),
  .rst           (rst),
  // sonfiguraation/control signals
  .cmd_valid     (wrDivider),
  .cmd_data      (cmd_data),
  // input stream
  .sti_tready    (cdc_tready),
  .sti_tvalid    (cdc_tvalid),
  .sti_tdata     (cdc_tdata ),
  // output stream
  .sto_tready    (sample_tready),
  .sto_tvalid    (sample_tvalid),
  .sto_tdata     (sample_tdata )
);

// Evaluate standard triggers...
trigger #(
  .DW (SDW)
) trigger (
  // system signals
  .clk          (clk),
  .rst          (rst),
  // configuraation/control signals
  .wrMask       (wrtrigmask),
  .wrValue      (wrtrigval),
  .wrConfig     (wrtrigcfg),
  .config_data  (cmd_data),
  //
  .arm          (arm_basic),
  .demux_mode   (demux_mode),
  // input stream
  .sti_tready   (sample_tready),
  .sti_tvalid   (sample_tvalid),
  .sti_tdata    (sample_tdata ),
  // outputs...
  .run          (run_basic),
  .capture      (capture_basic)
);

// Evaluate advanced triggers...
trigger_adv #(
  .DW (SDW)
) trigger_adv (
  // system signals
  .clk           (clk),
  .rst           (rst),
  // configuraation/control signals
  .wrSelect      (wrTrigSelect),
  .wrChain       (wrTrigChain),
  .config_data   (cmd_data),
  //
  .arm           (arm_adv),
  .finish_now    (finish_now),
  // input stream
  .sti_tready    (sample_tready),
  .sti_tvalid    (sample_tvalid),
  .sti_tdata     (sample_tdata ),
  // outputs...
  .run           (run_adv),
  .capture       (capture_adv)
);

wire capture = capture_basic || capture_adv;

/*
// Detect duplicate data & insert RLE counts (if enabled)... 
// Requires client software support to decode.
rle_enc rle_enc (
  // system signals
  .clk             (clk),
  .rst             (rst),
  // configuration/control signals
  .enable          (rleEnable),
  .arm             (arm),
  .rle_mode        (rle_mode),
  .disabledGroups  (disabledGroups),
  // input stream
  .sti_tready      (align_tready),
  .sti_tvalid      (align_tvalid),
  .sti_tdata       (align_tdata),
  // output stream
  .sto_tready      (rle_tready),
  .sto_tvalid      (rle_tvalid),
  .sto_tdata       (rle_tdata)
);
*/

shifter #(
  .DW (SDW)
) shifter (
  // system signals
  .clk            (clk),
  .rst            (rst),
  // control signals
  .ctl_clr        (1'b1),
  .ctl_ena        (1'b0),
  // configuration signals
  .cfg_mask       ({SDW{1'b1}}),
  // input stream
  .sti_tvalid     (sample_tvalid),
  .sti_tvalid     (sample_tvalid),
  .sti_tdata      (sample_tdata),
  // output stream
  .sto_tvalid     (align_tvalid),
  .sto_tvalid     (align_tvalid),
  .sto_tdata      (align_tdata)
);

endmodule
