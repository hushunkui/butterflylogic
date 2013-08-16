//////////////////////////////////////////////////////////////////////////////
//
// trigger - matcher
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

module trigger_matcher #(
  // sample data parameters
  parameter integer SDW = 32  // sample data width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire [SDW-1:0] cfg_or , //
  input  wire [SDW-1:0] cfg_and, //
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
wire [SDW-1:0] cmp_tdata_0_0;
wire [SDW-1:0] cmp_tdata_0_1;
wire [SDW-1:0] cmp_tdata_1_0;
wire [SDW-1:0] cmp_tdata_1_1;
wire [SDW-1:0] cmp_tdata;

//////////////////////////////////////////////////////////////////////////////
// matcher
//////////////////////////////////////////////////////////////////////////////

// TODO, this is actually here just to avoid simulation issues
initial dly_tdata = 0;

// delay input data
always @ (posedge clk)
if (sti_transfer) dly_tdata <= sti_tdata;

// match data against configuration
assign cmp_tdata_0_0 = (~dly_tdata & ~sti_tdata) & cfg_0_0;
assign cmp_tdata_0_1 = (~dly_tdata &  sti_tdata) & cfg_0_1;
assign cmp_tdata_1_0 = ( dly_tdata & ~sti_tdata) & cfg_1_0;
assign cmp_tdata_1_1 = ( dly_tdata &  sti_tdata) & cfg_1_1;
assign cmp_tdata = cmp_tdata_0_0 | cmp_tdata_0_1 | cmp_tdata_1_0 | cmp_tdata_1_1;

// combine (OR/AND) bitwise signals into a single hit
always @ (posedge clk, posedge rst)
if (rst)                sts_evt <= 1'b0;
else if (sti_transfer)  sts_evt <= (&(cmp_tdata | ~cfg_and) & |cfg_and) | (|(cmp_tdata & cfg_or));

endmodule
