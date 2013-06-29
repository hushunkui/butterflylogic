//////////////////////////////////////////////////////////////////////////////
//
// filter removing all single period glitches
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

module filter #(
  parameter SDW = 32  // sample data width
)(
  // system signals
  input  wire           clk,  // clock
  input  wire           rst,  // reset
  // configuration and control signals
  input  wire           ena,
  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output reg            sto_tvalid,
  output reg  [SDW-1:0] sto_tdata
);

// data transfer on the input stream
wire sti_transfer;
assign sti_transfer = sti_tvalid & sti_tready;

// register for storing the previous data
reg [SDW-1:0] dly_tdata;

// storing the previous input value for comparison
always @(posedge clk)
if (sti_transfer) begin
  if (ena)  dly_tdata <= sti_tdata;
end

// forward input value to the output if the input is stable
genvar i;
generate
for (i=0; i<SDW; i=i+1) begin: bit
  always @(posedge clk)
  if (sti_transfer) begin
    if (~ena | (sti_tdata[i] ~^ dly_tdata[i]))  sto_tdata[i] <= sti_tdata[i];
  end
end
endgenerate

// forward valid signal
always @(posedge clk, posedge rst)
if (rst)  sto_tvalid <= 1'b0;
else if (sti_tready) sto_tvalid <= sti_tvalid;

// backpressure
assign sti_tready = sto_tready | ~sto_tvalid;

endmodule
