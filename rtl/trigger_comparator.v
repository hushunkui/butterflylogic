//////////////////////////////////////////////////////////////////////////////
//
// trigger - comparator
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

module trigger_comparator #(
  // sample data parameters
  parameter integer SDW = 32  // sample data width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire           cfg_mod, // mode (0 - OR, 1 - AND)
  input  wire [SDW-1:0] cfg_0_0, //
  input  wire [SDW-1:0] cfg_0_1, //
  input  wire [SDW-1:0] cfg_1_0, //
  input  wire [SDW-1:0] cfg_1_1, //
  // status
  output reg            sts_evt,

  // input stream
  input  wire           sti_transfer,
  input  wire [SDW-1:0] sti_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

reg  [SDW-1:0] dly_tdata;
wire [SDW-1:0] cmp_tdata;

//////////////////////////////////////////////////////////////////////////////
// comparator
//////////////////////////////////////////////////////////////////////////////

// delay input data
always @ (posedge clk)
if (sti_transfer) dly_tdata <= sti_tdata;

// match data against configuration
assign cmp_tdata = ((~dly_tdata & ~sti_tdata) & cfg_0_0) |
                   ((~dly_tdata &  sti_tdata) & cfg_0_1) |
                   (( dly_tdata & ~sti_tdata) & cfg_1_0) |
                   (( dly_tdata &  sti_tdata) & cfg_1_1) ;

// combine (OR/AND) bitwise signals into a single hit
always @ (posedge clk, posedge rst)
if (rst)                sts_evt <= 1'b0;
else if (sti_transfer)  sts_evt <= cfg_mod ? &cmp_tdata : |cmp_tdata;

endmodule
