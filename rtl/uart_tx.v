//--------------------------------------------------------------------------------
// transmitter.vhd
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
// Takes 32bit (one sample) and sends it out on the serial port.
// End of transmission is signalled by taking back the busy flag.
// Supports xon/xoff flow control.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module uart_tx #( 
  parameter integer FREQ = 50_000_000,
  parameter integer BAUD = 921_600,
  parameter integer BITLENGTH = FREQ / BAUD, // 54
  parameter integer CW = $clog2(BITLENGTH) // counter width
)(
  // system signals
  input  wire        clk,
  input  wire        rst,
  //
  input  wire  [3:0] disabledGroups,
  input  wire        write,		// Data write request
  input  wire [31:0] wrdata,		// Write data
  input  wire        id,		// ID output request
  input  wire        xon,		// Flow control request
  input  wire        xoff,		// Resume output request
  output reg         busy,		// Busy flag
  // UART signals
  output wire        uart_tx		// Serial tx data
);

//
// Registers...
//
reg [31:0] sampled_wrdata;
reg [3:0] sampled_disabledGroups;
reg [3:0] bits;
reg [2:0] bytesel;
reg paused;
reg byteDone;

reg [9:0] txBuffer;
assign uart_tx = txBuffer[0];

reg [9:0] counter;  // Big enough for FREQ/BAUDRATE (100Mhz/115200 ~= 868)
wire counter_zero = ~|counter;

wire writeByte; 

//
// Byte select mux...
//
wire [7:0] dbyte;
wire       disabled;

assign dbyte = sampled_wrdata[8*bytesel[1:0]+:8];
assign disabled = sampled_disabledGroups[bytesel[1:0]];

// baud rate counter
always @ (posedge clk, posedge rst)
if (rst) begin
  counter  <= 0;
end else begin
  if (writeByte) 
    counter  <= BITLENGTH;
  else if (counter_zero)
    counter <= BITLENGTH;
  else
    counter <= counter - 1'b1;
end

//
// Send one byte...
//
always @ (posedge clk, posedge rst)
if (rst) begin
  bits     <= 0;
  byteDone <= 1'b0;
end else begin
  if (writeByte) 
  begin
    bits     <= 0;
    byteDone <= 1'b0;
  end
  else if (counter_zero)
  begin
    if (bits == 4'hA)
      byteDone <= 1'b1;
    else bits <= bits + 1'b1;
  end 
end

always @ (posedge clk, posedge rst)
if (rst) begin
  txBuffer <= 1;
end else begin
  if (writeByte)
    txBuffer <= {1'b1,dbyte,1'b0}; // 8 bits, no parity, 1 stop bit (8N1)
  else if (counter_zero)
    txBuffer <= {1'b1,txBuffer[9:1]};
end

//
// Control FSM for sending 32 bit words...
//
localparam [1:0] IDLE = 0, SEND = 1, POLL = 2;
reg [1:0] state;

always @ (posedge clk, posedge rst) 
if (rst) begin
  busy                   <= 1'b0;
  paused                 <= 1'b0;
  state                  <= IDLE;
  sampled_wrdata         <= 32'h0;
  sampled_disabledGroups <= 4'h0;
  bytesel                <= 3'h0;
end else begin
  busy                   <= (state != IDLE) || write || paused;
  paused                 <= xoff | (paused & !xon);;
  case(state) // when write is '1', data will be available with next cycle
    IDLE : 
      begin
        sampled_wrdata <= wrdata;
        sampled_disabledGroups <= disabledGroups;
        bytesel <= 2'h0;
        if (write) 
          state <= SEND;
        else if (id)  // send our signature/ID code (in response to the query command)
	  begin
            sampled_wrdata <= 32'h534c4131; // "SLA1"
            sampled_disabledGroups <= 4'b0000;
            state <= SEND;
          end
      end
    SEND : 
      begin
	bytesel <= bytesel+1'b1;
        state <= POLL;
      end
    POLL :
      begin
	if (byteDone && !paused)
          state <= (bytesel[2]) ? IDLE : SEND;
      end
  endcase
end

assign writeByte = (state == SEND);

endmodule
