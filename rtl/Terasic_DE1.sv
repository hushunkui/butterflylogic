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
  // Sets the speed for UART communications
  // SYSTEM_JITTER = "1000 ps"
  parameter FREQ = 100000000,       // limited to 100M by onboard SRAM
  parameter TRXSCALE = 28,          // 100M / 28 / 115200 = 31 (5bit)  --If serial communications are not working then try adjusting this number.
  parameter BAUDRATE = 115200,           // maximum & base rate
  parameter  [1:0] SPEED=2'b00
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

wire  [7:0] opcode;
wire [31:0] config_data; 

assign {config_data,opcode} = cmd;

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

//
// Instantiate serial interface....
//
uart #(
  .FREQ     (FREQ),
  .SCALE    (TRXSCALE),
  .BAUDRATE (BAUDRATE)
) uart (
  // system signals
  .clock    (sys_clk),
  .reset    (sys_rst),
  // input stream
  .wrdata   (sram_rddata),
  .send     (send),
  // output configuration
  .speed    (SPEED),
  .cmd      (cmd),
  .execute  (execute),
  .busy     (busy),
  // UART signals
  .uart_rx  (uart_rx),
  .uart_tx  (uart_tx)
);


//
// Instantiate core...
//

core #(
  .SDW (32),
  .MDW (32)
) core (
  // system signsls
  .sys_clk         (sys_clk),
  .sys_rst         (sys_rst),
  // input stream
  .sti_clk         (sti_clk),
  .sti_data_p      (sti_data),
  .sti_data_n      (sti_data),
  //
  .extTriggerIn    (extTriggerIn),
  .opcode          (opcode),
  .config_data     (config_data),
  .execute         (execute),
  .outputBusy      (busy),
  // outputs...
  .sampleReady50   (),
  .stableInput     (stableInput),
  .outputSend      (send),
  .extTriggerOut   (extTriggerOut),
  .wrFlags         (wrFlags),
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

//
// Instantiate the memory interface...
//
sram_interface sram_interface (
  // system signals
  .clk          (sys_clk),
  .rst          (sys_rst),
  // configuration/control signals
  .wrFlags      (wrFlags), 
  .config_data  (config_data[5:2]),
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
