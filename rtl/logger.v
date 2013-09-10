//////////////////////////////////////////////////////////////////////////////
//
// logger (event log)
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

module logger #(
  // sample data parameters
  parameter integer SEW = 2,   // sample event width
  parameter integer SDW = 32,  // sample data  width
  // absolute time parameters
  parameter integer ATW = 48,  // absolute timer width
  // event log parameters
  parameter integer LEN = 32,  // event log number of entries

  // event log memory parameters
  parameter integer LDW = ATW+SEW // log data width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // log stream
  input  wire           stl_tready,
  output reg            stl_tvalid,
  output wire [LDW-1:0] stl_tdata ,
  // logging memory full error
  output reg            err_full,

  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SEW-1:0] sti_tevent,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output wire           sto_tvalid,
  output wire [SEW-1:0] sto_tevent,
  output wire [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// event log memory parameters
localparam integer EAW = $clog2(LEN);  // address width

// stream transfer
wire           sti_ttrnsf;  // input stream transfer
wire           stl_ttrnsf;  // log   stream transfer

// absolute time counter
reg  [ATW-1:0] atc_cnt;

// event log write access
wire           log_wen;  // write enable
reg  [EAW-0:0] log_wad;  // write address
wire [LDW-1:0] log_wdt;  // write data
// event log read access
wire           log_ren;  // read enable
reg  [EAW-0:0] log_rad;  // read address
reg  [LDW-1:0] log_rdt;  // read data

// event log FIFO status
wire [EAW-0:0] log_cmp;
wire           log_ful;
wire           log_emp;

reg  [LDW-1:0] log_mem [0:LEN-1]; // memory array

//////////////////////////////////////////////////////////////////////////////
// input stream
//////////////////////////////////////////////////////////////////////////////

// input stream transfer
assign sti_ttrnsf = (sti_tready & sti_tvalid);

//////////////////////////////////////////////////////////////////////////////
// absolute time counter
//////////////////////////////////////////////////////////////////////////////

always @ (posedge clk, posedge rst)
if (rst)             atc_cnt <= 0;
else if (sti_ttrnsf) atc_cnt <= atc_cnt + 'd1;

//////////////////////////////////////////////////////////////////////////////
// FIFO write
//////////////////////////////////////////////////////////////////////////////

// write data
assign log_wdt = {sti_tevent, atc_cnt};

// write enable
assign log_wen = sti_ttrnsf & |sti_tevent & ~log_ful;

// write address
always @ (posedge clk, posedge rst)
if (rst)          log_wad <= 'd0;
else if (log_wen) log_wad <= log_wad + 'd1;

// event log memory write
always @ (posedge clk)
if (log_wen)  log_mem [log_wad] <= log_wdt;

//////////////////////////////////////////////////////////////////////////////
// FIFO read
//////////////////////////////////////////////////////////////////////////////

// event log memory read
always @ (posedge clk)
if (log_ren)  log_rdt <= log_mem [log_rad];

// read address
always @ (posedge clk, posedge rst)
if (rst)          log_rad <= 'd0;
else if (log_ren) log_rad <= log_rad + 'd1;

// read enable
assign log_ren = ~log_emp & ~stl_tvalid | stl_ttrnsf;

//////////////////////////////////////////////////////////////////////////////
// FIFO status
//////////////////////////////////////////////////////////////////////////////

assign log_cmp = log_wad ^ log_rad;

assign log_ful =  log_cmp[EAW] & ~|log_cmp[EAW-1:0];
assign log_emp = ~log_cmp[EAW] & ~|log_cmp[EAW-1:0];

//////////////////////////////////////////////////////////////////////////////
// event log stream
//////////////////////////////////////////////////////////////////////////////

// log stream transfer
assign stl_ttrnsf = (stl_tready & stl_tvalid);

// read data
assign stl_tdata  = log_rdt;

// log stream valid
always @ (posedge clk, posedge rst)
if (rst) stl_tvalid <= 1'b0;
else     stl_tvalid <= log_ren | (stl_tvalid & ~stl_ttrnsf);

// log full error
always @ (posedge clk, posedge rst)
if (rst) err_full <= 1'b0;
else     err_full <= log_ful & sti_ttrnsf & |sti_tevent;

//////////////////////////////////////////////////////////////////////////////
// input stream -> output stream
//////////////////////////////////////////////////////////////////////////////

assign sti_tready = sto_tready;

assign sto_tvalid = sti_tvalid;
assign sto_tevent = sti_tevent;
assign sto_tdata  = sti_tdata ;

endmodule
