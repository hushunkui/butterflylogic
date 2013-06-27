//--------------------------------------------------------------------------------
// sampler.vhd
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
// Produces samples from input applying a programmable divider to the clock.
// Sampling rate can be calculated by:
//
//     r = f / (d + 1)
//
// Where r is the sampling rate, f is the clock frequency and d is the value
// programmed into the divider register.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
// 

`timescale 1ns/100ps

module sampler #(
  parameter integer DW = 32,  // data width
  parameter integer CW = 24   // counter width
)(
  // system signas
  input  wire          clk,             // clock
  input  wire          rst,             // reset
  // configuration/control signals
  input  wire          wrDivider,       // write divider register
  input  wire [32-1:0] cmd_data,        // configuration data
  // input stream
  output wire          sti_tready,
  input  wire          sti_tvalid,
  input  wire [DW-1:0] sti_tdata ,
  // output stream
  input  wire          sto_tready,
  output wire          sto_tvalid,
  output wire [DW-1:0] sto_tdata ,
);

wire sti_transfer;

reg  [CW-1:0] divider; 
reg  [CW-1:0] counter;
wire          sample;

// divider register write access
always @ (posedge clk, posedge rst)
if (rst)            divider <= 0;
else if (wrDivider) divider <= cmd_data[CW-1:0];

assign sti_transfer = sti_tvalid & sti_tready;

// count input transfers
always @ (posedge clk)
if (rst)                counter <= 0;
else if (sti_transfer)  counter <= sample ? divider : counter-1'b1;

// sample when the counter reaches zero
assign sample = ~|counter;

// input is ready to receive if sample is not active
assign sti_tready = sto_tready | ~sample;

// there is data on the output if sample is active
assign sto_tvalid = sti_tvalid |  sample;
assign sto_tdata  = sti_tdata;

endmodule
