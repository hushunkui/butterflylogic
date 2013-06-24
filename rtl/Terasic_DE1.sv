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

assign dataReady = busy;

uart #(
  .DW (DW),
  .PT (PT),
  .SW (SW),
  .BN (FREQ/BAUD)
) dut (
  // system signals
  .clk             (clk),
  .rst             (rst),
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

module ctrl #(
  .MDW (MDW),
  .HDW (8)
)(
  // system signals
  .clk,
  .rst,
  // memory data stream
  .mem_tvalid  (),
  .mem_tdata   (),
  .mem_tready  (),
  // control stream
  .ctl_code   (),
  .ctl_data   (),
  .ctl_valid  (),
  // RXD data stream
  .str_rxd_tvalid  (),
  .str_rxd_tdata   (),
  .str_rxd_tready  (),
  // TXD data stream
  .str_txd_tvalid  (),
  .str_txd_tdata   (),
  .str_txd_tready  ()
);

core #(
  .SDW (SDW),
  .MDW (MDW)
) core (
  // system signsls
  .sys_clk         (sys_clk),
  .sys_rst         (sys_rst),
  // input stream
  .sti_clk         (sti_clk),
  .sti_data_p      (sti_data),
  .sti_data_n      (sti_data),
  //
  .ctl_code        (ctl_code),
  .ctl_data        (ctl_data),
  .ctl_exe         (ctl_exe),
  .wrFlags         (wrFlags),
  // outputs...
  .extTriggerIn    (extTriggerIn),
  .sampleReady50   (),
  .stableInput     (stableInput),
  .outputSend      (send),
  .extTriggerOut   (extTriggerOut),
  .outputBusy      (busy),
  .extClock_mode   (extClock_mode),
  .extTestMode     (extTestMode),
  .indicator_arm   (armLEDnn),
  .indicator_trg   (triggerLEDnn),
  // memory interface
  .memoryWrData    (sram_wrdata),
  .memoryRead      (read),
  .memoryWrite     (write),
  .memoryLastWrite (lastwrite)
);

// Instantiate the memory interface...
sram_interface sram_interface (
  // system signals
  .clk          (sys_clk),
  .rst          (sys_rst),
  // configuration/control signals
  .wrFlags      (wrFlags), 
  .ctl_data     (ctl_data[5:2]),
  // write interface
  .write        (write),
  .lastwrite    (lastwrite),
  .wrdata       (sram_wrdata),
  // read interface
  .rd_ready     (read),
  .rd_valid     (),
  .rd_keep      (sram_rdvalid),
  .rd_data      (sram_rddata)
);

endmodule
