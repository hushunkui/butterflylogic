//////////////////////////////////////////////////////////////////////////////
//
// testbench: trigger
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

`timescale 1ns/100ps

module tb_trigger #(
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
);

logic clk = 1'b1;
logic rst = 1'b1;

always #5 clk = ~clk;

// system bus (write access only)
wire           bus_wready;
wire           bus_wvalid;
wire [BAW-1:0] bus_waddr ;
wire [BDW-1:0] bus_wdata ;

// input stream
wire           sti_tready;
wire           sti_tvalid;
wire [SDW-1:0] sti_tdata ;
// output stream
wire           sto_tready;
wire           sto_tvalid;
wire     [1:0] sto_tevent;
wire [SDW-1:0] sto_tdata ;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial begin
  $finish();
end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.VW (SDW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sti_tready ),
  .tvalid  (sti_tvalid ),
  .tdata   (sti_tdata  )
);

// stream drain instance
str_drn #(.VW (2+SDW)) drn (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sto_tready),
  .tvalid  (sto_tvalid),
  .tdata  ({sto_tevent,
            sto_tdata })
);

// DUT instance
trigger #(
  // system bus parameters
  .BDW (BDW),
  .BAW (BAW),
  // sample data parameters
  .SDW (SDW),
  // trigger event source parameters
  .TMN (TMN),
  .TAN (TAN),
  .TCN (TCN),
  .TCW (TCW),
  // state machine table parameters
  .TDW (TDW)
) trigger (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // system bus (write access only)
  .bus_wready  (bus_wready),
  .bus_wvalid  (bus_wvalid),
  .bus_waddr   (bus_waddr ),
  .bus_wdata   (bus_wdata ),
  // input stream
  .sti_tready  (sti_tready),
  .sti_tvalid  (sti_tvalid),
  .sti_tdata   (sti_tdata ),
  // output stream
  .sto_tready  (sto_tready),
  .sto_tvalid  (sto_tvalid),
  .sto_tevent  (sto_tevent),
  .sto_tdata   (sto_tdata )
);

////////////////////////////////////////////////////////////////////////////////
// waveform related code
////////////////////////////////////////////////////////////////////////////////

// Initialized wavedump...
initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule: tb_trigger
