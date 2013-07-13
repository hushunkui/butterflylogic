//////////////////////////////////////////////////////////////////////////////
//
// trigger - adder
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

module trigger_adder #(
  // sample data parameters
  parameter integer SDW = 32  // sample data    width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire           cfg_mod, // mode (0 - gteater then, 1 - less or equal)
  input  wire [SDW-1:0] cfg_msk, // mask
  input  wire [SDW-1:0] cfg_val, // value used for subtraction
  // status
  output wire           sts_evt,

  // input stream
  input  wire           sti_transfer,
  input  wire [SDW-1:0] sti_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// result of subtraction
reg signed [SDW-0:0] sub_val;

//////////////////////////////////////////////////////////////////////////////
// adder
//////////////////////////////////////////////////////////////////////////////

// subtract reference value from stream data
always @ (posedge clk, posedge rst)
if (rst)                sub_val <= 'd0;
else if (sti_transfer)  sub_val <= $signed({1'b0, sti_tdata & cfg_msk})
                                 - $signed({1'b0, cfg_val});

assign sts_evt = sub_val [SDW] ^ cfg_mod;

endmodule
