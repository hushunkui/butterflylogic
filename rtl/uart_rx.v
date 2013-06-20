//--------------------------------------------------------------------------------
// receiver.vhd
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
// Receives commands from the serial port. The first byte is the commands
// opcode, the following (optional) four byte are the command data.
// Commands that do not have the highest bit in their opcode set are
// considered short commands without data (1 byte long). All other commands are
// long commands which are 5 bytes long.
//
// After a full command has been received it will be kept available for 10 cycles
// on the op and data outputs. A valid command can be detected by checking if the
// execute output is set. After 10 cycles the registers will be cleared
// automatically and the receiver waits for new data from the serial port.
//
//--------------------------------------------------------------------------------

`timescale 1ns/100ps

module uart_rx #(
  parameter integer FREQ = 50_000_000,
  parameter integer BAUD = 921_600,
  parameter integer BITLENGTH = FREQ / BAUD, // 54
  parameter integer CW = $clog2(BITLENGTH) // counter width
)(
  // system signals
  input  wire        clk,
  input  wire        rst,
  //
  output wire  [7:0] op,
  output wire [31:0] data,
  output reg         execute,
  // UART signals
  input  wire        uart_rx
);

localparam [2:0]
  INIT      = 3'h0,
  WAITSTOP  = 3'h1,
  WAITSTART = 3'h2,
  WAITBEGIN = 3'h3,
  READBYTE  = 3'h4,
  ANALYZE   = 3'h5,
  READY     = 3'h6;

reg  [9:0] counter;  // clock prescaling counter
reg  [3:0] bitcount;  // count rxed bits of current byte
reg  [2:0] bytecount;  // count rxed bytes of current command
reg  [2:0] state;  // receiver state
reg  [7:0] opcode;  // opcode byte
reg [31:0] databuf;  // data dword

assign op = opcode;
assign data = databuf;

always @(posedge clk, posedge rst) 
if (rst) begin
  state     <= INIT;
  counter   <= 0;
  bitcount  <= 0;
  bytecount <= 0;
  databuf   <= 0;
  opcode    <= 0;
  execute   <= 0;
end else begin
  case(state)
    INIT : 
      begin
        counter   <= 0;
        bitcount  <= 0;
	bytecount <= 0;
	opcode    <= 0;
        databuf   <= 0;
	state     <= WAITSTOP; 
      end

    WAITSTOP : // reset uart
      begin
	if (uart_rx) state <= WAITSTART; 
      end

    WAITSTART : // wait for start bit
      begin
	if (!uart_rx) state <= WAITBEGIN; 
      end

    WAITBEGIN : // wait for first half of start bit
      begin
	if (counter == (BITLENGTH / 2)) 
	  begin
	    counter <= 0;
	    state <= READBYTE;
	  end
	else 
	  counter <= counter + 1;
      end

    READBYTE : // receive byte
      begin
	if (counter == BITLENGTH) 
	  begin
	    counter <= 0;
	    bitcount <= bitcount + 1;
	    if (bitcount == 4'h8) 
	      begin
		bytecount <= bytecount + 1;
		state <= ANALYZE;
	      end
	    else if (bytecount == 0) 
	      begin
		opcode <= {uart_rx,opcode[7:1]};
		databuf <= databuf;
	      end
	    else 
	      begin
		opcode <= opcode;
		databuf <= {uart_rx,databuf[31:1]};
	      end
	  end
	else
	  counter <= counter + 1;
      end

    ANALYZE : // check if long or short command has been fully received
      begin
	counter <= 0;
	bitcount <= 0;
        if (bytecount == 3'h5) // long command when 5 bytes have been received
	  state <= READY;
        else if (!opcode[7]) // short command when set flag not set
          state <= READY;
        else state <= WAITSTOP; // otherwise continue receiving
    end

    READY : // done, give 10 cycles for processing
      begin
	counter <= counter + 1;
	if (counter == 4'd10)
	  state <= INIT;
	else state <= state;
      end
    endcase

  execute <= (state == READY);
end

endmodule
