//--------------------------------------------------------------------------------
//
// Copyright (C) 2013 Iztok Jeras
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

module shifter #(
  parameter integer DW = 32
)(
  // system signals
  input  wire          clk,
  input  wire          rst,
  // control signals
  input  wire          ctl_clr,
  input  wire          ctl_ena,
  // configuration signals
  input  wire [DW-1:0] cfg_mask,
  // input stream
  input  wire          sti_valid,
  output wire          sti_ready,
  input  wire [DW-1:0] sti_data,
  // output stream
  output wire          sto_valid,
  input  wire          sto_ready,
  output wire [DW-1:0] sto_data
);

// number of data procesing layers
localparam DL = $clog2(DW);

// input data path signals
wire sti_transfer;

assign sti_transfer = sti_valid & sti_ready;

// delay data path signals
reg  [DL-1:0] [DW-1:0] pipe_data;
reg  [DL-1:0]          pipe_valid = {DL{1'b0}};
wire [DL-1:0]          pipe_ready;

// shifter dynamic control signal
reg  [DW-1:0] [DL-1:0] shift;

// conversion from mask to shifts
function [DW-1:0] [DL-1:0] mask2shift (input [DW-1:0] mask);
  integer l,b;
begin
  for (l=0; l<DL; l=l+1) begin
    for (b=0; b<DW; b=b+1) begin
      
    end
  end
end
endfunction

// rotate right
//function [DW-1:0] rtr (
//  input [DW-1:0] data,
//  input integer len
//);
//  rtr = {data [DW-len-1:0], data [DW-1:DW-len]};
//endfunction

// control path
always @ (posedge clk, posedge rst)
if (rst) begin
  pipe_valid <= {DL{1'b0}};
end else if (ctl_ena) begin
  pipe_valid <= {pipe_valid [DL-2:0], sti_valid};
end

// data path
genvar l, b;
generate
  for (l=0; l<DL; l=l+1) begin: layer
    for (b=0; b<DW; b=b+1) begin: dbit
      always @ (posedge clk)
      if (ctl_ena)  pipe_data[l][b] <= shift[b][l] ? pipe_data[l-1][(b+l)%DW] : pipe_data[l-1][b];
    end
  end
endgenerate

// combinatorial bypass
assign sto_valid = !ctl_ena ? sti_valid : pipe_valid[DL-1];
assign sto_data  = !ctl_ena ? sti_data  : pipe_data [DL-1];

assign sti_ready = !ctl_ena ? sto_ready : pipe_ready[0] | ~pipe_valid[0];

endmodule
