//////////////////////////////////////////////////////////////////////////////
//
// testbench: logger
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

module tb_logger #(
  // sample data parameters
  parameter integer SEW = 2,   // sample event width
  parameter integer SDW = 32,  // sample data  width
  // absolute time parameters
  parameter integer ATW = 48,  // absolute timer width
  // event log parameters
  parameter integer LEN = 32,  // event log number of entries

  // event log memory parameters
  parameter integer LDW = ATW+SEW // log data width
);

logic clk = 1'b1;
logic rst = 1'b1;

always #5 clk = ~clk;

// log stream
wire            stl_tready;
wire            stl_tvalid;
wire  [LDW-1:0] stl_tdata ;

// logging memory full error
wire            err_full;

// input stream
wire            sti_tready;
wire            sti_tvalid;
wire  [SEW-1:0] sti_tevent;
wire  [SDW-1:0] sti_tdata ;
// output stream
wire            sto_tready;
wire            sto_tvalid;
wire  [SEW-1:0] sto_tevent;
wire  [SDW-1:0] sto_tdata ;

// debuging signals
logic [SDW-1:0] dat;
logic [LDW-1:0] evt;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial begin
  repeat (4) @ (posedge clk);
  rst = 1'b0;
  repeat (4) @ (posedge clk);

  // send test sequence
  fork
    begin: seq_src
      src.trn ({2'h0, 32'h00000000}); // dummy data, to clear the matcher pipeline
      src.trn ({2'h0, 24'h000000,"S"});
      src.trn ({2'h0, 24'h000000,"O"});
      src.trn ({2'h1, 24'h000000,"S"});
    end: seq_src
    begin: seq_drn
      drn.trn (dat);
      drn.trn (dat);
      drn.trn (dat);
      drn.trn (dat);
    end: seq_drn

    begin: seq_log
      log.trn (evt);
    end: seq_log
  join

  repeat (4) @ (posedge clk);
  $finish();
end

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_drn #(.DW (LDW)) log (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (stl_tready),
  .tvalid  (stl_tvalid),
  .tdata   (stl_tdata )
);

// stream source instance
str_src #(.DW (SEW+SDW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sti_tready),
  .tvalid  (sti_tvalid),
  .tdata  ({sti_tevent,
            sti_tdata })
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
logger #(
  // sample data parameters
  .SEW (SEW),
  .SDW (SDW),
  // absolute time parameters
  .ATW (ATW),
  // event log parameters
  .LEN (LEN)
) logger (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // system bus (write access only)
  .stl_tready  (stl_tready),
  .stl_tvalid  (stl_tvalid),
  .stl_tdata   (stl_tdata ),
  // logging memory full error
  .err_full    (err_full),
  // input stream
  .sti_tready  (sti_tready),
  .sti_tvalid  (sti_tvalid),
  .sti_tevent  (sti_tevent),
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

endmodule: tb_logger
