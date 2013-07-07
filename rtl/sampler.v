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
//
// In addition to input events one internal event is generated. This is the
// subsampling counter/divider reaching zero. This event is not prapagated to
// the output.
//
// There is an event mask available, defining which events can request a
// sample to be transferred from the input to the output. The MSB in this
// mask is alligned with the divider zero event. Other mask bits allign with
// input events.
//
//////////////////////////////////////////////////////////////////////////////

module sampler #(
  parameter integer SDW = 32,  // sample data    width
  parameter integer SCW = 32,  // sample counter width
  parameter integer SEW = 1    // sample event   width   
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // configuration
  input  wire [SCW-1:0] cfg_div,      // sample data ratio
  input  wire [SEW-0:0] cfg_evt_smp,  // event sample mask

  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SEW-1:0] sti_tevent,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output reg            sto_tvalid,
  output reg  [SEW-1:0] sto_tevent,
  output reg  [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// stream transfer signal
wire sti_transfer;
wire sto_transfer;

// subsampling related signals
reg  [SCW-1:0] cnt_val;  // counter for sample divider
wire           cnt_nul;  // counter for sample divider reached zero
wire           smp;  // sampling event

//////////////////////////////////////////////////////////////////////////////
// sample divider
//////////////////////////////////////////////////////////////////////////////

// input stream transfer signal
assign sti_transfer = sti_tvalid & sti_tready;

// sample divider counter is decremented on each input transfer
always @ (posedge clk, posedge rst)
if (rst)                cnt_val <= 'd0;
else if (sti_transfer)  cnt_val <= cnt_nul ? cfg_div : cnt_val - 'b1;

assign cnt_nul = ~|cnt_val;

assign smp = |(cfg_evt_smp & {cnt_nul, sti_tevent});

//////////////////////////////////////////////////////////////////////////////
// stream outputs
//////////////////////////////////////////////////////////////////////////////

// input is ready to receive if strobe is not active
assign sti_tready = sto_tready | ~sto_tvalid;

// there is data on the output if strobe is active
always @ (posedge clk, posedge rst)
if (rst) sto_tvalid <= 1'b0;
else     sto_tvalid <= sti_tvalid & smp;

// event stream
always @ (posedge clk)
if (sti_transfer) begin
  if (smp)  sto_tevent <= sti_tevent;
  else      sto_tevent <= sti_tevent | sto_tevent;
end

// data stream
always @ (posedge clk)
if (sti_transfer) begin
  if (smp)  sto_tdata <= sti_tdata;
end

endmodule
