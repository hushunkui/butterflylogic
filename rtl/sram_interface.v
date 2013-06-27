//--------------------------------------------------------------------------------
//
// sram_interface.v
// Copyright (C) 2011 Ian Davis
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
// Details: 
//   http://www.dangerousprototypes.com/ols
//   http://www.gadgetfactory.net/gf/project/butterflylogic
//   http://www.mygizmos.org/ols
//
// Writes data to SRAM incrementally, fully filling a 32bit word before
// moving onto the next one.   On reads, pulls data back out in reverse
// order (to maintain SUMP client compatability).  But really, backwards?!!?
//
//--------------------------------------------------------------------------------
//

`timescale 1ns/100ps

module sram_interface #(
  // memory parameters
  parameter MSZ = 6*1024,       // size (6K x 36bit)
//parameter MAW = $clog2(MSZ),  // address width (13bit => 8K)
  parameter MAW = 13,           // address width (13bit => 8K)
  parameter MDW = 32            // data width
  parameter MKW = 32            // keep width
)(
  // system signals
  input  wire           clk,
  input  wire           rst,
  // configuration/control signals
  input  wire           cmd_flags,
  input  wire     [3:0] cmd_data,
  // write interface
  input  wire           mwr_tready,
  input  wire           mwr_tvalid,
  input  wire           mwr_tlast ,
  input  wire [MKW-1:0] mwr_tkeep ,
  input  wire [MDW-1:0] mwr_tdata ,
  // read interface
  input  wire           mrd_tready,
  output reg            mrd_tvalid,
  output wire           mrd_tlast ,
  output reg  [MKW-1:0] mrd_tkeep ,
  output wire [MDW-1:0] mrd_tdata
);

assign mwr_tready = 1'b1;

//
// Registers...
//
reg       init;
reg [1:0] mode, next_mode;
reg [MAW-1:0] address, next_address;
reg [3:0] next_mrd_tkeep;

//
// Control logic...
//
initial 
begin
  init = 1'b0;
  address = 0;
  mrd_tkeep = 4'b0000;
  mrd_tvalid = 1'b0;
end
always @ (posedge clk)
begin
  init      <= cmd_flags;
  address   <= next_address;
  mrd_tkeep   <= next_mrd_tkeep;
  mrd_tvalid  <=|next_mrd_tkeep;
end


always @*
begin
  //
  // Handle writes & reads.  Fill a given line of RAM completely before
  // moving onward.   
  //
  // This differs from the original SUMP storage which wrapped around 
  // before changing clock enables.  Client sees no difference. However, 
  // it'll eventally allow easier streaming of data to the client...
  //
  if (init) begin
    // Reset clock enables & ram address...
    next_address = 0;
  end else begin
    casex ({mwr_tvalid && !mwr_tlast, mrd_tready})
      2'b1x : next_address = (address == MSZ-1) ? 0 : address+1'b1;
      2'bx1 : next_address = (address == 0) ? MSZ-1 : address-1'b1;
    endcase
  end
end

//
// Instantiate RAM's (each BRAM6kx9bit in turn instantiates three 2kx9's block RAM's)...
//

wire mwr_transfer;
assign mwr_transfer = mwr_tvalid & mwr_tready;

`ifdef XC3S250E

genvar i;
generate
for (i=0; i<MKW; i=i+1) begin : mem
  reg [8-1:0] mem1 [0:2048-1];
  reg [8-1:0] mem0 [0:4096-1];
  reg [8-1:0] mrd_tdata1;
  reg [8-1:0] mrd_tdata0;
  reg         adr_reg;
  // write access
  always @ (posedge clk)  if (mwr_tvalid & mwr_tkeep[i] &  address[12]) mem1 [address[10:0]] <= mwr_tdata[i*8+:8];
  always @ (posedge clk)  if (mwr_tvalid & mwr_tkeep[i] & ~address[12]) mem0 [address[10:0]] <= mwr_tdata[i*8+:8];
  // read access
  always @ (posedge clk)  mrd_tdata1 <= mem1 [address[10:0]];
  always @ (posedge clk)  mrd_tdata0 <= mem0 [address[11:0]];
  // multiplexer
  always @ (posedge clk) adr_reg <= address[12];
  assign mrd_tdata [i*8+:8] = adr_reg ? mrd_tdata1 : mrd_tdata0;
end
endgenerate

`else


genvar i;
generate
for (i=0; i<MKW; i=i+1) begin : mem
  // byte wide memory array
  reg [8-1:0] mem [0:MSZ-1];
  // write access
  always @ (posedge clk)
  if (mwr_transfer & mwr_tkeep[i]) mem [address] <= mwr_tdata[i*8+:8];
  // read access
  always @ (posedge clk)
  mrd_tdata[i*8+:8] <= mem [address];
end
endgenerate

`endif

endmodule
