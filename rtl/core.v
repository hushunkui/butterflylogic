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
  // status
  output reg            ind_arm,
  output reg            ind_trg,

  // input stream
  input  wire           sti_clk,
  input  wire           sti_rst,
  output wire           sti_tready ,
  input  wire           sti_tvalid ,
  input  wire           sti_trigger,
  input  wire [SDW-1:0] sti_tdata  ,
  // memory write interface
  input  wire           sto_tready ,
  output wire           sto_tvalid ,
  output wire           sto_tlast  ,
  output wire [MKW-1:0] sto_tkeep  ,
  output wire [MDW-1:0] sto_tdata
);

// data stream (cdc -> filter)
wire           cdc_tready ;
wire           cdc_tvalid ;
wire           cdc_trigger;
wire [SDW-1:0] cdc_tdata  ;
// data stream (filter -> sample)
wire           filter_tready ;
wire           filter_tvalid ;
wire           filter_trigger;
wire [SDW-1:0] filter_tdata  ;
// data stream (sample -> trigger)
wire           sample_tready ;
wire           sample_tvalid ;
wire           sample_trigger;
wire           sample_tlast  ;
wire [SDW-1:0] sample_tdata  ;
// data stream (rle -> shifter)
wire           rle_tready ;
wire           rle_tvalid ;
wire           rle_trigger;
wire           rle_tlast  ;
wire [SDW-1:0] rle_tdata  ;
// data stream (shifter -> byter)
wire           shifter_tready ;
wire           shifter_tvalid ;
wire           shifter_trigger;
wire           shifter_tlast  ;
wire [SDW-1:0] shifter_tdata  ;

// indicators can be connected to LED
always @ (posedge clk, posedge rst)
if (rst)        ind_arm <= 1'b0;
else begin
  if      (arm) ind_arm <= 1'b1;
  else if (run) ind_arm <= 1'b0;
end

always @(posedge clk, posedge rst)
if (rst)        ind_trg <= 1'b0;
else begin
  if      (run) ind_trg <= 1'b1;
  else if (arm) ind_trg <= 1'b0;
end

// register set
regset regset (
  // system signals
  .clk          (clk),
  .rst          (rst),
  // register access write bus
  .cmd_valid    (cmd_valid),
  .cmd_data     (cmd_data ),
  // configuration signals
  .wrtrigmask   (wrtrigmask),
  .wrtrigval    (wrtrigval),
  .wrtrigcfg    (wrtrigcfg),
  .wrspeed      (wrDivider),
  .wrsize       (wrsize),
  .wrFlags      (cmd_valid_flags),
  .wrTrigSelect (wrTrigSelect),
  .wrTrigChain  (wrTrigChain),
  .finish_now   (finish_now),
  // control signals
  .arm_basic    (arm_basic),
  .arm_adv      (arm_adv)
);

// clock domain crossing between sample and processing clock
cdc #(
  .DW  (1+SDW),
  .FF  (8)
) cdc (
  // input interface
  .ffi_clk  (sti_clk),
  .ffi_rst  (sti_rst),
  .ffi_rdy  (sti_tready ),
  .ffi_vld  (sti_tvalid ),
  .ffi_dat ({sti_trigger,
             sti_tdata  }),
  // output interface
  .ffo_clk  (clk),
  .ffo_rst  (rst),
  .ffo_rdy  (cdc_tready ),
  .ffo_vld  (cdc_tvalid ),
  .ffo_dat ({cdc_trigger,
             cdc_tdata  })
);

// subsampling input stream
filter #(
  .SDW (1+SDW)
) filter (
  // system signals
  .clk           (clk),
  .rst           (rst),
  // configuraation
  .cfg_div       (cfg_div)
  // control
  .ctl_run       (ctl_run),
  // input stream
  .sti_tready    (cdc_tready ),
  .sti_tvalid    (cdc_tvalid ),
  .sti_tdata    ({cdc_trigger,
                  cdc_tdata  }),
  // output stream
  .sto_tready    (filter_tready ),
  .sto_tvalid    (filter_tvalid ),
  .sto_tdata    ({filter_trigger,
                  filter_tdata  })
);

// subsampling input stream
sampler #(
  .SDW (SDW),
  .SCW (32),
  .SNW (32)
) sampler (
  // system signals
  .clk           (clk),
  .rst           (rst),
  // configuraation
  .cfg_div       (cfg_div)
  // control
  .ctl_run       (ctl_run),
  // input stream
  .sti_tready    (filter_tready ),
  .sti_tvalid    (filter_tvalid ),
  .sti_trigger   (filter_trigger),
  .sti_tdata     (filter_tdata  ),
  // output stream
  .sto_tready    (sample_tready ),
  .sto_tvalid    (sample_tvalid ),
  .sto_tlast     (sample_tlast  ),
  .sto_trigger   (sample_trigger),
  .sto_tdata     (sample_tdata  )
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
  .sti_tlast    (sample_tlast ),
  .sti_tdata    (sample_tdata ),
  // outputs...
  .run          (run),
  .capture      (capture)
);

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
