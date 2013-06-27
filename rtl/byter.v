//////////////////////////////////////////////////////////////////////////////
//
// organize data into bytes
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

// from the mask you know how far each bit should be moved, and from this distance
// you pick the bit describing the distance of the current shift, so construct a
// table of shifts and pick the appropriate bits, this should be done for every
// stage, since the mask changes from stage to stage

// mask0  01101100  01010000  10001000
// shft0  xx11x00x  xx10xxxx  0xxxx1xx
//        01110001  10100101  00101101 toggle if maskbit is 0
// mask1  00111100  00110000  10000100
// shft1  xxxx1111  xxxx00xx  xx1xxxx1
//        00111111  11000011  00110011 toggle pair of bits if msb of mask pair is 0
// mask2  00001111  00110000  00100001
// shft2  xxxx0000  xxxxxx11  xxxxxx10

`timescale 1ns/1ps

module byter #(
  parameter integer SDW = 32,
  parameter integer SKW = SDW/8
)(
  // system signals
  input  wire           clk,
  input  wire           rst,
  // control signals
  input  wire           ctl_clr,
  input  wire           ctl_ena,
  // configuration signals
  input  wire [SDW-1:0] cfg_mask,
  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output wire           sto_tvalid,
  output wire           sto_tlast ,
  output wire [SKW-1:0] sto_tkeep
  output wire [SDW-1:0] sto_tdata
);

// combinatorial bypass
assign sto_tvalid = sti_tvalid;
assign sto_tvalid = sti_tlast ;
assign sto_tdata  = sti_tdata ;

assign sti_tready = !ctl_ena ? sto_tready : pipe_tready[0] | ~pipe_tvalid[0];

endmodule
