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
  parameter integer BDW = 32,  // bus data    width
  parameter integer BAW = 6,   // bus address width
  // sample data parameters
  parameter integer SDW = 32,  // sample data    width
  // trigger event source parameters
  parameter integer TMN = 4,  // trigger matcher number
  parameter integer TAN = 2,  // trigger adder   number
  parameter integer TCN = 4,  // trigger counter number
  parameter integer TCW = 32, // counter width
  // state machine table parameters
  parameter integer TEW = TCN+TAN, // table event width
  parameter integer TDW = 4,       // table data width (number of events)
  parameter integer TAW = TDW+TEW  // table address width
)(
  // system signas
  input  wire           clk,          // clock
  input  wire           rst,          // reset

  // system bus (write access only)
  output wire           bus_wready,
  input  wire           bus_wvalid,
  input  wire [BAW-1:0] bus_waddr ,
  input  wire [BDW-1:0] bus_wdata ,

  // input stream
  output wire           sti_tready,
  input  wire           sti_tvalid,
  input  wire [SDW-1:0] sti_tdata ,
  // output stream
  input  wire           sto_tready,
  output reg            sto_tvalid,
  output reg      [1:0] sto_tevent,
  output reg  [SDW-1:0] sto_tdata
);

//////////////////////////////////////////////////////////////////////////////
// local signals
//////////////////////////////////////////////////////////////////////////////

// input stream transfer


// system bus transfer
wire bus_transfer;

// configuration
reg  [TCN    -1:0] cfg_mod;
reg  [TCN*SDW-1:0] cfg_0_0;
reg  [TCN*SDW-1:0] cfg_0_1;
reg  [TCN*SDW-1:0] cfg_1_0;
reg  [TCN*SDW-1:0] cfg_1_1;

// state machine table
reg  [TDW-1:0] tbl_mem [2**TAW-1:0];  // state machine table
reg  [TDW-1:0] tbl_stt;  // state
reg  [TEW-1:0] tbl_evt;  // events
reg  [TAW-1:0] tbl_adr;  // address

//////////////////////////////////////////////////////////////////////////////
// system bus access to configuration
//////////////////////////////////////////////////////////////////////////////

// system bus transfer
assign bus_transfer = bus_wvalid & bus_wready;

// table write
always @ (posedge clk)
if (bus_transfer) begin
  case (bus_taddr[BAW-1:BAW-2])
    2'b00: begin
      for (i=0; i<TCN; i=i+1) begin
        if (bus_address[4:3] == i) begin
          case (bus_taddr[2:0])
            3'b000: cfg_mod [  1*i:  1] <= bus_wdata;
            3'b100: cfg_0_0 [SDW*i:SDW] <= bus_wdata;
            3'b101: cfg_0_1 [SDW*i:SDW] <= bus_wdata;
            3'b110: cfg_1_0 [SDW*i:SDW] <= bus_wdata;
            3'b111: cfg_1_1 [SDW*i:SDW] <= bus_wdata;
          endcase
        end
      end
    end
    2'b11: begin
      tbl_mem [bus_waddr] <= bus_wdata;
    end
  endcase
end

//////////////////////////////////////////////////////////////////////////////
// sample data path
//////////////////////////////////////////////////////////////////////////////

// sample data transfer
assign sti_transfer = sti_tvalid & sti_tready;

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
  .cfg_mod  (cfg_mod),
  .cfg_0_0  (cfg_0_0),
  .cfg_0_1  (cfg_0_1),
  .cfg_1_0  (cfg_1_0),
  .cfg_1_1  (cfg_1_1),
  // status
  .sts_evt  (sts_evt_cmp),
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
  .cfg_mod  (cfg_mod),
  .cfg_msk  (cfg_msk),
  .cfg_val  (cfg_val),
  // status
  .sts_evt  (sts_evt_adr),
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
  .TCW (TCW),
  // state machine table parameters
  .TAW (TAW)
) counter [TCN-1:0] (
  // system signas
  .clk      (clk),
  .rst      (rst),
  // configuration
  .cfg_clr_val (cfg_clr_val),
  .cfg_clr_msk (cfg_clr_msk),
  .cfg_inc_val (cfg_inc_val),
  .cfg_inc_msk (cfg_inc_msk),
  .cfg_dec_val (cfg_dec_val),
  .cfg_dec_msk (cfg_dec_msk),
  .cfg_val     (cfg_val    ),
  // status
  .sts_evt     (sts_evt_cnt),
  // input stream
  .sti_transfer (sti_transfer),
  .sti_tevent   (sti_tevent  )
);

//////////////////////////////////////////////////////////////////////////////
// state machine table
//////////////////////////////////////////////////////////////////////////////

// next state (rable read)
always @ (posedge clk)
if (sti_transfer) tbl_stt <= tbl_mem [{tbl_evt, tbl_stt}];

//////////////////////////////////////////////////////////////////////////////
// output stream events
//////////////////////////////////////////////////////////////////////////////

// start 
// trigger
// abort
// end

endmodule
