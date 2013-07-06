//////////////////////////////////////////////////////////////////////////////
//
// sampler
//
// Copyright (C) 2013 Iztok Jeras <iztok.jeras@gmail.com>
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
// Copyright (C) 2006 Michael Poppitz
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
//
// Produces samples from input applying a programmable divider to the clock.
// Sampling rate can be calculated by:
//
//     r = f / (d + 1)
//
// Where r is the sampling rate, f is the clock frequency and d is the value
// programmed into the cfg_div register.
//
//////////////////////////////////////////////////////////////////////////////

module sampler #(
  parameter integer SDW = 32,  // sample data    width
  parameter integer SCW = 32,  // sample counter width
  parameter integer SNW = 32   // sample number  width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire [SCW-1:0] cfg_div,      // sample data ratio
  input  wire [SNW-1:0] cfg_num,      // sample data number
  // control signals
  input  wire           ctl_st1,      // start data stream
  input  wire           ctl_st0,      // stop  data stream
  // status signals
  output reg            sts_run,      // stream run status  

  // input stream
  output wire           sti_tready ,
  input  wire           sti_tvalid ,
  input  wire           sti_trigger,
  input  wire [SDW-1:0] sti_tdata  ,
  // output stream
  input  wire           sto_tready ,
  output wire           sto_tvalid ,
  output wire           sto_tlast  ,
  output reg            sto_trigger,
  output wire [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// stream transfer signal
wire sti_transfer;
wire sto_transfer;

// subsampling related signals
reg  [SCW-1:0] cnt_div;  // counter for sample divider
reg  [SNW-1:0] cnt_num;  // counter for sample number
wire           nul_div;  // counter for sample divider reached zero
wire           nul_num;  // counter for sample number  reached zero
reg            stb    ;  // strobe

// delayed trigger
reg dly_trigger;

//////////////////////////////////////////////////////////////////////////////
// sample divider
//////////////////////////////////////////////////////////////////////////////

// input stream transfer signal
assign sti_transfer = sti_tvalid & sti_tready;

// sample divider counter is decremented on each input transfer
always @ (posedge clk, posedge rst)
if (rst)                cnt_div <= 'd0;
else if (sti_transfer)  cnt_div <= nul_div ? cfg_div : cnt_div - 'b1;

assign nul_div = ~|cnt_div;

// input stream transfer signal
assign sto_transfer = sto_tvalid & sto_tready;

// strobe sample when the cnt reaches zero, and stream is enabled
always @ (posedge clk, posedge rst)
if (rst)                stb <= 'd0;
else if (sti_transfer)  stb <= nul_div & sts_run;

//////////////////////////////////////////////////////////////////////////////
// sample number and run status
//////////////////////////////////////////////////////////////////////////////

// sample number counter is decremented on each output transfer
always @ (posedge clk, posedge rst)
if (rst)                cnt_num <= 'd0;
else if (sto_transfer)  cnt_num <= nul_num ? cfg_num : cnt_num - 'b1;

assign nul_num = ~|cnt_num;

// run status
always @ (posedge clk, posedge rst)
if (rst)                 sts_run <= 0;
else begin
  if (ctl_st1)           sts_run <= 1;
  else if (ctl_st0)      sts_run <= 0;
  else if (sto_transfer) sts_run <= ~nul_num;
end

//////////////////////////////////////////////////////////////////////////////
// trigger
//////////////////////////////////////////////////////////////////////////////

always @ (posedge clk, posedge rst)
if (rst)                  sto_trigger <= 1'b0;
else begin
  if      (sti_transfer)  sto_trigger <= sti_trigger;
  else if (sto_transfer)  sto_trigger <= 1'b0;
end

//////////////////////////////////////////////////////////////////////////////
// stream outputs
//////////////////////////////////////////////////////////////////////////////

// input is ready to receive if strobe is not active
assign sti_tready  = sto_tready  | ~stb;

// there is data on the output if strobe is active
assign sto_tvalid  = sti_tvalid  |  stb;
assign sto_tlast   = ~sts_run;
assign sto_tdata   = sti_tdata;

endmodule
