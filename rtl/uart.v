//--------------------------------------------------------------------------------
// eia232.vhd
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
// EIA232 aka RS232 interface.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module uart #(
  parameter integer FREQ = 50_000_000,
  parameter integer BAUD = 921_600
)(
  // system signals
  input  wire        clk,
  input  wire        rst,
  // data stream
  input  wire        send,	// Send data output serial tx
  input  wire [31:0] wrdata,	// Data to be sent
  //
  output wire [39:0] cmd,
  output wire        execute,	// Cmd is valid
  output wire        busy,	// Indicates transmitter busy
  // UART signals
  input  wire        uart_rx,  // Serial RX
  output wire        uart_tx   // Serial TX
);

reg id; 
reg xon; 
reg xoff; 
reg wrFlags;
reg dly_execute; 
reg [3:0] disabledGroupsReg;

wire [7:0] opcode;
wire [31:0] opdata;
assign cmd = {opdata,opcode};

//
// Process special uart commands that do not belong in core decoder...
//
always @(posedge clk, posedge rst) 
if (rst) begin
  id      <= 1'b0;
  xon     <= 1'b0;
  xoff    <= 1'b0;
  wrFlags <= 1'b0;
  disabledGroupsReg <= 4'b0000;
end else begin
  if (~dly_execute & execute)
  case(opcode)
    8'h02 : id      <= 1'b1;
    8'h11 : xon     <= 1'b1;
    8'h13 : xoff    <= 1'b1;
    8'h82 : wrFlags <= 1'b1;
  endcase
  if (wrFlags) disabledGroupsReg <= opdata[5:2];
end

always @(posedge clk, posedge rst) 
if (rst)  dly_execute <= 1'b0;
else      dly_execute <= execute;

//
// Instantiate serial-to-parallel receiver.  
// Asserts "execute" whenever valid 8-bit value received.
//
uart_rx #(
  .FREQ (FREQ),
  .BAUD (BAUD)
) rx (
  // system signals
  .clk      (clk),
  .rst      (rst),
  //
  .op       (opcode),
  .data     (opdata),
  .execute  (execute),
  // UART signals
  .uart_rx  (uart_rx)
);

//
// Instantiate parallel-to-serial transmitter.
// Genereate serial data whenever "send" or "id" asserted.
// Obeys xon/xoff commands.
//
uart_tx #(
  .FREQ (FREQ),
  .BAUD (BAUD)
) tx (
  // system signals
  .clk            (clk),
  .rst            (rst),
  //
  .disabledGroups (disabledGroupsReg),
  .write          (send),
  .wrdata         (wrdata),
  .id             (id),
  .xon            (xon),
  .xoff           (xoff),
  .busy           (busy),
  // UART signals
  .uart_tx        (uart_tx)
);

endmodule
