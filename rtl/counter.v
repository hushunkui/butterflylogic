//////////////////////////////////////////////////////////////////////////////
//
// sample counter and stream window
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
//
// Input events and control inputs can manipulate the next counter
// functionality: start/stop/clear
//
// The counter ads a new event to the output.
//
// Input and internal events can also enable or disable the output data stream.
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
  input  wire [SCW-1:0] cfg_num,      // stream window size counter
  input  wire [SEW-1:0] cfg_evt_c_s,  // event mask counter start
  input  wire [SEW-1:0] cfg_evt_c_p,  // event mask counter pause
  input  wire [SEW-1:0] cfg_evt_c_c,  // event mask counter clear
  input  wire [SEW-0:0] cfg_evt_e_s,  // event mask stream enable set
  input  wire [SEW-0:0] cfg_evt_e_c,  // event mask stream enable clear
  // control signals
  input  wire           ctl_e_s,      // stream enable set
  input  wire           ctl_e_c,      // stream enable clear
  // status signals
  output reg            sts_ena,      // stream enable status  

  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SEW-1:0] sti_tevent,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output reg            sto_tvalid,
  output reg  [SEW-0:0] sto_tevent,  // the internal counter event is added
  output reg  [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// stream transfer signal
wire sti_transfer;
wire sto_transfer;

// counter status
reg  [SCW-1:0] cnt_val;  // counter value
reg            cnt_ena;  // counter enable
wire           cnt_nul;  // counter reached zero
// counter control signals
wire           cnt_set;  // counter start
wire           cnt_clr;  // counter pause
wire           cnt_pau;  // counter clear

// stream enable status
reg            ena_val;  // counter for sample number
// stream enable control signals
wire           ena_set;  // stream enable set
wire           ena_clr;  // stream enable clear

//////////////////////////////////////////////////////////////////////////////
// sample number counter
//////////////////////////////////////////////////////////////////////////////

// counter control signals
assign cnt_set = |(cfg_evt_c_s & sti_tevent);
assign cnt_clr = |(cfg_evt_c_c & sti_tevent);
assign cnt_pau = |(cfg_evt_c_p & sti_tevent);

// 
always @ (posedge clk, posedge rst)
if (rst)                cnt_ena <= 0;
else if (sti_transfer) begin
  if      (cnt_pau)     cnt_ena <= 0;
  else if (cnt_set)     cnt_ena <= 1;
end

// sample number counter is decremented on each output transfer
always @ (posedge clk, posedge rst)
if (rst)                cnt_val <= 'd0;
else if (sto_transfer)  cnt_val <= cnt_nul | cnt_clr ? cfg_num : cnt_val - cnt_ena;

assign cnt_nul = ~|cnt_val;

//////////////////////////////////////////////////////////////////////////////
// run status
//////////////////////////////////////////////////////////////////////////////

// stream enable control signals
assign ena_set = ctl_e_s & {cnt_nul, sti_tevent};
assign ena_clr = ctl_e_c & {cnt_nul, sti_tevent};

// 
always @ (posedge clk, posedge rst)
if (rst)                 ena_val <= 0;
else if (sti_transfer) begin
  if      (ena_clr)      ena_val <= 0;
  else if (ena_set)      ena_val <= 1;
end

//////////////////////////////////////////////////////////////////////////////
// stream outputs
//////////////////////////////////////////////////////////////////////////////

// input is ready to receive if strobe is not active
assign sti_tready  = sto_tready  | ~sto_tvalid;

// there is data on the output if strobe is active
always @ (posedge clk, posedge rst)
if (rst) sto_tvalid <= 1'b0;
else     sto_tvalid <= sti_tvalid & ena_val;

// event and data stream
always @ (posedge clk)
if (sti_transfer) begin
  sto_tevent <= {cnt_nul, sti_tevent};
  sto_tdata  <= sti_tdata;
end

endmodule
