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
  // system bus parameters
  parameter integer BAW = 6,   // bus address width
  parameter integer BDW = 32,  // bus data    width
  // sample data parameters
  parameter integer SDW = 32,  // sample data  width
  parameter integer SEW = 2,   // sample event width
  // trigger event source parameters
  parameter integer TMN = 4,   // trigger matcher number
  parameter integer TAN = 2,   // trigger adder   number
  parameter integer TCN = 4,   // trigger counter number
  parameter integer TCW = 32,  // counter width
  // state machine table parameters
  parameter integer TSW = 4    // table state width (number of events)
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // system bus (write access only)
  output wire           bus_wready,
  input  wire           bus_wvalid,
  input  wire [BAW-1:0] bus_waddr ,
  input  wire [BDW-1:0] bus_wdata ,
  input  wire [  4-1:0] bus_wselct,

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

localparam integer TEW = TMN+TCN+TAN;    // table event width
localparam integer TAW = TSW+TEW;        // table address width
localparam integer TDW = TSW+SEW+2*TCN;  // table data width

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// input stream signals
wire               sti_transfer;

// local stream signals
wire               stl_transfer;
wire               stl_tready;
reg                stl_tvalid;
reg    [2*TCN-1:0] stl_tevent;
reg      [SDW-1:0] stl_tdata ;

// system bus transfer
wire bus_transfer;

// configuration - comparator
reg  [TMN*SDW-1:0] cfg_cmp_or ;
reg  [TMN*SDW-1:0] cfg_cmp_and;
reg  [TMN*SDW-1:0] cfg_cmp_0_0;
reg  [TMN*SDW-1:0] cfg_cmp_0_1;
reg  [TMN*SDW-1:0] cfg_cmp_1_0;
reg  [TMN*SDW-1:0] cfg_cmp_1_1;
// configuration - adder
reg  [TAN    -1:0] cfg_add_mod;
reg  [TAN*SDW-1:0] cfg_add_msk;
reg  [TAN*SDW-1:0] cfg_add_val;
// configuration - counter
reg  [TCN*TCW-1:0] cfg_cnt_val;

// state machine table
reg      [TDW-1:0] tbl_mem [2**TAW-1:0];  // state machine table
reg      [TSW-1:0] tbl_stt;  // state
wire     [TEW-1:0] tbl_evt;  // events
reg      [TAW-1:0] tbl_adr;  // address

// events
wire     [TMN-1:0] evt_cmp;
wire     [TAN-1:0] evt_add;
wire     [TCN-1:0] evt_cnt;

//////////////////////////////////////////////////////////////////////////////
// system bus access to configuration
//////////////////////////////////////////////////////////////////////////////

genvar i;

// there is no need for pushback
assign bus_wready = 1'b1;

// system bus transfer
assign bus_transfer = bus_wvalid & bus_wready;

// comparator configuration write
generate
for (i=0; i<TMN; i=i+1) begin: cmp
  always @ (posedge clk, posedge rst)
  if (rst) begin
    cfg_cmp_or  [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_cmp_and [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_cmp_0_0 [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_cmp_0_1 [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_cmp_1_0 [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_cmp_1_1 [SDW*i+:SDW] <= {SDW{1'b0}};
  end else if (bus_transfer & bus_wselct[0]) begin
    if (bus_waddr[4:3] == i) begin
      case (bus_waddr[2:0])
        3'b000: cfg_cmp_or  [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b001: cfg_cmp_and [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b100: cfg_cmp_0_0 [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b101: cfg_cmp_0_1 [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b110: cfg_cmp_1_0 [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b111: cfg_cmp_1_1 [SDW*i+:SDW] <= bus_wdata [0+:SDW];
      endcase
    end
  end
end
endgenerate

// adder configuration write
generate
for (i=0; i<TAN; i=i+1) begin: add
  always @ (posedge clk, posedge rst)
  if (rst) begin
    cfg_add_mod [  1*i+:  1] <= {  1{1'b0}};
    cfg_add_msk [SDW*i+:SDW] <= {SDW{1'b0}};
    cfg_add_val [SDW*i+:SDW] <= {SDW{1'b0}};
  end else if (bus_transfer & bus_wselct[1]) begin
    if (bus_waddr[4:3] == i) begin
      case (bus_waddr[1:0])
        3'b00: cfg_add_mod [  1*i+:  1] <= bus_wdata [0+:  1];
        3'b10: cfg_add_msk [SDW*i+:SDW] <= bus_wdata [0+:SDW];
        3'b11: cfg_add_val [SDW*i+:SDW] <= bus_wdata [0+:SDW];
      endcase
    end
  end
end
endgenerate

// counter configuration write
generate
for (i=0; i<TCN; i=i+1) begin: cnt
  always @ (posedge clk, posedge rst)
  if (rst) begin
    cfg_cnt_val [TCW*i+:TCW] <= {TCW{1'b0}};
  end else if (bus_transfer & bus_wselct[2]) begin
    if (bus_waddr[1:0] == i) begin
      cfg_cnt_val [TCW*i+:TCW] <= bus_wdata [0+:TCW];
    end
  end
end
endgenerate

// state machine LUT write
always @ (posedge clk)
if (bus_transfer & bus_wselct[3]) begin
  tbl_mem [bus_waddr] <= bus_wdata;
end

//////////////////////////////////////////////////////////////////////////////
// sample data path
//////////////////////////////////////////////////////////////////////////////

// input stage transfer
assign sti_transfer = sti_tvalid & sti_tready;
// input stage ready
assign sti_tready = stl_tready | ~stl_tvalid;

// local stage transfer
assign stl_transfer = stl_tvalid & stl_tready;
// local stage ready
assign stl_tready = sto_tready | ~sto_tvalid;
// local stage valid
always @ (posedge clk, posedge rst)
if (rst)              stl_tvalid <= 1'b0;
else if (sti_tready)  stl_tvalid <= sti_tvalid;
// local stage data
always @ (posedge clk, posedge rst)
if (sti_transfer)  stl_tdata <= sti_tdata;

// output stage transfer
assign sto_transfer = sto_tvalid & sto_tready;
// output stage valid
always @ (posedge clk, posedge rst)
if (rst)              sto_tvalid <= 1'b0;
else if (stl_tready)  sto_tvalid <= stl_tvalid;
// output stage data
always @ (posedge clk, posedge rst)
if (stl_transfer)  sto_tdata <= stl_tdata;

//////////////////////////////////////////////////////////////////////////////
// comparators
//////////////////////////////////////////////////////////////////////////////

trigger_comparator #(
  // sample data parameters
  .SDW (SDW)
) comparator [TCN-1:0] (
  // system signas
  .clk      (clk),
  .rst      (rst),
  // configuration
  .cfg_or   (cfg_cmp_or ),
  .cfg_and  (cfg_cmp_and),
  .cfg_0_0  (cfg_cmp_0_0),
  .cfg_0_1  (cfg_cmp_0_1),
  .cfg_1_0  (cfg_cmp_1_0),
  .cfg_1_1  (cfg_cmp_1_1),
  // status
  .sts_evt  (evt_cmp),
  // input stream
  .sti_transfer (sti_transfer),
  .sti_tdata    (sti_tdata   )
);

//////////////////////////////////////////////////////////////////////////////
// adders
//////////////////////////////////////////////////////////////////////////////

trigger_adder #(
  // sample data parameters
  .SDW (SDW)
) adder [TAN-1:0] (
  // system signas
  .clk      (clk),
  .rst      (rst),
  // configuration
  .cfg_mod  (cfg_add_mod),
  .cfg_msk  (cfg_add_msk),
  .cfg_val  (cfg_add_val),
  // status
  .sts_evt  (evt_add),
  // input stream
  .sti_transfer (sti_transfer),
  .sti_tdata    (sti_tdata   )
);

//////////////////////////////////////////////////////////////////////////////
// counters
//////////////////////////////////////////////////////////////////////////////

trigger_counter #(
  // sample data parameters
  .SDW (SDW),
  // counter parameters
  .TCW (TCW)
) counter [TCN-1:0] (
  // system signas
  .clk      (clk),
  .rst      (rst),
  // configuration
  .cfg_val     (cfg_cnt_val),
  // status
  .sts_evt     (evt_cnt),
  // input stream
  .sti_transfer (stl_transfer),
  .sti_tevent   (stl_tevent  )
);

//////////////////////////////////////////////////////////////////////////////
// state machine table (produces next state and output event)
//////////////////////////////////////////////////////////////////////////////

assign tbl_evt = {evt_cmp, evt_add, evt_cnt};

// next state (rable read)
always @ (posedge clk)
if (sti_transfer) {sto_tevent, stl_tevent, tbl_stt} <= tbl_mem [{tbl_evt, tbl_stt}];

// start 
// trigger
// abort
// end

endmodule
