//////////////////////////////////////////////////////////////////////////////
//
// trigger
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

module trigger #(
  // sample data parameters
  parameter integer SDW = 32,  // sample data    width
  // trigger event source parameters
  parameter integer TCN = 4, // trigger comparator number
  parameter integer TAN = 4, // trigger adder      number
  // state machine table parameters
  parameter integer TEW = TCN+TAN, // table event width
  parameter integer TDW = 4,       // table data width (number of events)
  parameter integer TAW = TDW+TEW  // table address width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // ststem bus

  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output reg            sto_tvalid,
  output reg  [SEW-1:0] sto_tevent,
  output reg  [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// comparator
//////////////////////////////////////////////////////////////////////////////

  // configuration
  input  wire [SDW-1:0] cfg_0_0, //
  input  wire [SDW-1:0] cfg_0_1, //
  input  wire [SDW-1:0] cfg_1_0, //
  input  wire [SDW-1:0] cfg_1_1, //

reg  [SDW-1:0] cmp_tdata;
reg  [SDW-1:0] cmp_tmatch;
wire [         cmp_tdata;

// delay input data
always @ (posedge clk)
if (sti_transfer) dly_tdata <= sti_tdata;

assign sts_tmatch <= ((~dly_tdata & ~sti_tdata) & cfg_0_0) |
                     ((~dly_tdata &  sti_tdata) & cfg_0_1) |
                     (( dly_tdata & ~sti_tdata) & cfg_1_0) |
                     (( dly_tdata &  sti_tdata) & cfg_1_1) ;

// match data against configuration
always @ (posedge clk, posedge rst)
if (rst) begin
  sts_and <= 1'b0;
  sts_or  <= 1'b0;
else if (sti_transfer) begin
  sts_and <= &sts_tmatch;
  sts_or  <= |sts_tmatch;
end

//////////////////////////////////////////////////////////////////////////////
// adder
//////////////////////////////////////////////////////////////////////////////

  // configuration
  input  wire [SDW-1:0] cfg_val, //

reg [SDW-1:0] sub_val;

// match data against configuration
always @ (posedge clk, posedge rst)
if (rst)  sub_val <= 'd0;
else if (sti_transfer)  sub_val <= $signed({1'b0,sti_tdata}) - $signed({1'b0,sub_val});


//////////////////////////////////////////////////////////////////////////////
// state machine table
//////////////////////////////////////////////////////////////////////////////

// state machine table
reg  [TDW-1:0] tbl_mem [2**TAW-1:0];  // state machine table
reg  [TDW-1:0] tbl_stt;  // state
reg  [TEW-1:0] tbl_evt;  // events
reg  [TAW-1:0] tbl_adr;  // address

// next state (rable read)
always @ (posedge clk);
if (sti_transfer) tbl_stt <= tbl_mem [{tbl_evt, tbl_stt}];

// table write
always @ (posedge clk);
if () tbl_mem [tbl_adr] <= bus_wdata;

endmodule
