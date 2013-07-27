//////////////////////////////////////////////////////////////////////////////
//
// trigger - counter
//
// Copyright (C) 2013 Iztok Jeras <iztok.jeras@gmail.com>
//
//////////////////////////////////////////////////////////////////////////////
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
//////////////////////////////////////////////////////////////////////////////

module trigger_counter #(
  // sample data parameters
  parameter integer SDW = 32,  // sample data    width
  // counter parameters
  parameter integer TCW = 32   // trigger counter width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire [TCW-1:0] cfg_val,      // counter value to match
  // status
  output wire           sts_evt,

  // input stream
  input  wire           sti_transfer,
  input  wire   [2-1:0] sti_tevent
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// counter register
reg  [TCW-1:0] cnt_val;
wire           cnt_clr;
wire           cnt_inc;
wire           cnt_dec;

//////////////////////////////////////////////////////////////////////////////
// counter
//////////////////////////////////////////////////////////////////////////////

assign cnt_clr = sti_tevent == 2'b01;
assign cnt_inc = sti_tevent == 2'b10;
assign cnt_dec = sti_tevent == 2'b11;

// subtract reference value from stream data
always @ (posedge clk, posedge rst)
if (rst)                cnt_val <= 'd0;
else if (sti_transfer)  cnt_val <= cnt_clr ? 'd0 : cnt_val + cnt_inc - cnt_dec;

assign sts_evt = cnt_val == cfg_val;

endmodule
