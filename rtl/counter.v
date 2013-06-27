//////////////////////////////////////////////////////////////////////////////
//
// sample counter
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

`timescale 1ns/1ps

module counter #(
  parameter integer SDW = 32,  // sample data width
  parameter integer SCW = 32,  // sample counter width
  parameter integer OFF = 4    // input stream offset against the enable signal
)(
  // system signals
  input  wire           clk,
  input  wire           rst,
  // control signals
  input  wire           ctl_clr,
  input  wire           ctl_ena,
  // configuration signals
  input  wire           cfg_cnt,
  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output wire           sto_tvalid,
  output wire           sto_tlast ,
  output wire [SDW-1:0] sto_tdata
);

// counter status
reg  [SCW-1:0] cnt;

always @ (posedge clk, posedge rst)
if (rst) cnt <= 0;
else     cnt <= ctl_clr ? cfg_cnt : cnt - ctl_ena;

assign sto_tvalid = sti_tvalid;
assign sto_tlast  = cnt == OFF;
assign sto_tdata  = sti_tdata ;

assign sti_tready = sto_tready;

endmodule
