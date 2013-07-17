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
  parameter integer BAW = 8,   // bus address width
  parameter integer BDW = 32,  // bus data    width
  // sample data parameters
  parameter integer SDW = 32,  // sample data    width
  parameter integer SEW = 2,   // sample data    width
  // trigger event source parameters
  parameter integer TMN = 4,   // trigger matcher number
  parameter integer TAN = 2,   // trigger adder   number
  parameter integer TCN = 4,   // trigger counter number
  parameter integer TCW = 32,  // counter width
  // state machine table parameters
  parameter integer TSW = 4    // table state width
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
wire [SEW-1:0] sto_tevent;
wire [SDW-1:0] sto_tdata ;

// debuging signals
logic [SDW-1:0] dat;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial begin
  repeat (4) @ (posedge clk);
  rst = 1'b0;
  repeat (4) @ (posedge clk);

  // program registers
  master.trn (8'h00, 32'h00000001);
  master.trn (8'h04, 32'h76543210);
  master.trn (8'h05, 32'h01234567);
  master.trn (8'h06, 32'hfedcba98);
  master.trn (8'h07, 32'h89abcdef);

  // send test sequence
  fork
    src.trn (32'h76543210);
    drn.trn (dat);
  join

  repeat (4) @ (posedge clk);
  $finish();
end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
bus_master #(.BAW (BAW), .BDW (BDW)) master (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .wready  (bus_wready),
  .wvalid  (bus_wvalid),
  .waddr   (bus_waddr ),
  .wdata   (bus_wdata )
);

// stream source instance
str_src #(.DW (SDW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sti_tready),
  .tvalid  (sti_tvalid),
  .tdata   (sti_tdata )
);

// stream drain instance
str_drn #(.DW (SEW+SDW)) drn (
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
  .BAW (BAW),
  .BDW (BDW),
  // sample data parameters
  .SDW (SDW),
  .SEW (SEW),
  // trigger event source parameters
  .TMN (TMN),
  .TAN (TAN),
  .TCN (TCN),
  .TCW (TCW),
  // state machine table parameters
  .TSW (TSW)
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
