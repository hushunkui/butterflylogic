//--------------------------------------------------------------------------------
// Logic_Sniffer.vhd
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
// Logic Analyzer top level module. It connects the core with the hardware
// dependend IO modules and defines all inputs and outputs that represent
// phyisical pins of the fpga.
//
// It defines two constants FREQ and RATE. The first is the clock frequency 
// used for receiver and transmitter for generating the proper baud rate.
// The second defines the speed at which to operate the serial port.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//

`timescale 1ns/100ps

module Terasic_DE1 #(
  // logic analyzer parameters
  parameter int SDW = 32,
  // memory interface parameters
  parameter int MDW = 32,
  // Sets the speed for UART communications
  parameter FREQ = 50_000_000,  // 50MHz
  parameter BAUD = 921_600      // 
)(
  // system signals
  input  wire        clk,
  input  wire        rst,
  // logic analyzer signals
  input  wire        extClockIn,
  output wire        extClockOut,
  input  wire        extTriggerIn,
  output wire        extTriggerOut,
  //
  inout  wire [31:0] extData,
  // 
  output wire        dataReady,
  output wire        armLEDnn,
  output wire        triggerLEDnn,
  // host interface
  input  wire        uart_rx,
  output wire        uart_tx
);

wire extClock_mode;
wire extTestMode;

wire [39:0] cmd;
wire [31:0] sram_wrdata;
wire [31:0] sram_rddata; 
wire  [3:0] sram_rdvalid;
wire [31:0] stableInput;

wire  [7:0] ctl_code;
wire [31:0] ctl_data; 

assign {ctl_data,ctl_code} = cmd;

//--------------------------------------------------------------------------------
// clocking
//--------------------------------------------------------------------------------

// system signals
logic sys_clk;
logic sys_rst;
logic soft_reset;

assign sys_clk = clk;

always @ (posedge clk, posedge rst)
if (rst) sys_rst <= 1'b1;
else     sys_rst <= 1'b0;

//--------------------------------------------------------------------------------
// IO
//--------------------------------------------------------------------------------

wire        sti_clk;
wire [31:0] sti_data;

assign sti_clk  = extClockIn;
assign sti_data = extData;

assign extClockOut = clk;

//--------------------------------------------------------------------------------
// rtl instances
//--------------------------------------------------------------------------------

wire           mwr_tvalid;
wire           mwr_tready;
wire           mwr_tlast ;
wire [MDW-1:0] mwr_tdata ;

wire           mrd_tvalid;
wire           mrd_tready;
wire [MDW-1:0] mrd_tdata ; 
wire     [3:0] mrd_tkeep ;

wire [SDW-1:0] stableInput;

wire     [7:0] cmd_code;
wire    [31:0] cmd_data; 
wire           cmd_valid;

wire           cmd_valid_flags;

// RXD data stream
logic          str_rxd_tvalid;
logic [ 8-1:0] str_rxd_tdata ;
logic          str_rxd_tready;
// TXD data stream
logic          str_txd_tvalid;
logic [ 8-1:0] str_txd_tdata ;
logic          str_txd_tready;

uart #(
  .DW (8),
  .PT ("NONE"),
  .SW (1),
  .BN (FREQ/BAUD)
) uart (
  // system signals
  .clk             (sys_clk),
  .rst             (sys_rst),
  // TXD stream
  .str_txd_tvalid  (str_txd_tvalid),
  .str_txd_tdata   (str_txd_tdata ),
  .str_txd_tready  (str_txd_tready),
  // RXD stream
  .str_rxd_tvalid  (str_rxd_tvalid),
  .str_rxd_tdata   (str_rxd_tdata ),
  .str_rxd_tready  (str_rxd_tready),
  // error status
  .error_fifo      (error_fifo  ),
  .error_parity    (error_parity),
  // UART 
  .uart_txd        (uart_rxd),
  .uart_rxd        (uart_txd)
);

ctrl #(
  .MDW (MDW),
  .HDW (8)
) ctrl (
  // system signals
  .clk             (sys_clk),
  .rst             (sys_rst),
  // software reset
  .soft_reset      (soft_reset),
  // input stream
  .mem_tvalid      (mrd_tvalid), 
  .mem_tdata       (mrd_tdata ), 
  .mem_tkeep       (mrd_tkeep ),
  .mem_tready      (mrd_tready),
  // control stream
  .cmd_code        (cmd_code ),
  .cmd_data        (cmd_data ),
  .cmd_valid       (cmd_valid),
  // RXD data stream
  .str_rxd_tvalid  (str_rxd_tvalid),
  .str_rxd_tdata   (str_rxd_tdata ),
  .str_rxd_tready  (str_rxd_tready),
  // TXD data stream
  .str_txd_tvalid  (str_txd_tvalid),
  .str_txd_tdata   (str_txd_tdata ),
  .str_txd_tready  (str_txd_tready)
);

core #(
  .SDW (SDW),
  .MDW (MDW)
) core (
  // system signsls
  .sys_clk         (sys_clk),
  .sys_rst         (sys_rst | soft_reset),
  // input stream
  .sti_clk         (sti_clk),
  .sti_data_p      (sti_data),
  .sti_data_n      (sti_data),
  // command interface
  .cmd_code        (cmd_code),
  .cmd_data        (cmd_data),
  .cmd_valid       (cmd_valid),
  .cmd_valid_flags (cmd_valid_flags),
  // outputs...
  .extTriggerIn    (extTriggerIn),
  .sampleReady50   (),
  .stableInput     (stableInput),
  .extTriggerOut   (extTriggerOut),
  .extClock_mode   (extClock_mode),
  .extTestMode     (extTestMode),
  // indcators
  .indicator_arm   (armLEDnn),
  .indicator_trg   (triggerLEDnn),
  // memory read interface
  .outputBusy      (mrd_tready),
  .outputSend      (mrd_tvalid),
  .memoryRead      (read),
  // memory write interface
  .mwr_tvalid      (mwr_tvalid),
  .mwr_tlast       (mwr_tlast ),
  .mwr_tdata       (mwr_tdata )
);

// Instantiate the memory interface...
sram_interface sram_interface (
  // system signals
  .clk          (sys_clk),
  .rst          (sys_rst),
  // configuration/control signals
  .cmd_flags    (cmd_valid_flags), 
  .cmd_data     (cmd_data[5:2]),
  // write interface
  .mwr_tready   (),
  .mwr_tvalid   (mwr_tvalid),
  .mwr_tlast    (mwr_tlast ),
  .mwr_tdata    (mwr_tdata ),
  // read interface
  .mrd_tready   (read),
  .mrd_tvalid   (),
  .mrd_tkeep    (mrd_tkeep ),
  .mrd_tdata    (mrd_tdata )
);

endmodule
