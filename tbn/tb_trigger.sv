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
wire            bus_wready;
wire            bus_wvalid;
wire  [BAW-1:0] bus_waddr ;
wire  [BDW-1:0] bus_wdata ;
logic   [4-1:0] bus_wselct;

// input stream
wire            sti_tready;
wire            sti_tvalid;
wire  [SDW-1:0] sti_tdata ;
// output stream
wire            sto_tready;
wire            sto_tvalid;
wire  [SEW-1:0] sto_tevent;
wire  [SDW-1:0] sto_tdata ;

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
  configure_sos;

  // send test sequence
  fork
    begin: seq_src
      src.trn ({32'h00000000}); // dummy data, to clear the comparator pipeline
      src.trn ({24'h000000,"S"});
      src.trn ({24'h000000,"O"});
      src.trn ({24'h000000,"S"});
    end: seq_src
    begin: seq_drn
      drn.trn (dat);
      drn.trn (dat);
      drn.trn (dat);
      drn.trn (dat);
    end: seq_drn
  join

  repeat (4) @ (posedge clk);
  $finish();
end

////////////////////////////////////////////////////////////////////////////////
// comparator calculator
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  bit [SDW-1:0] cmp_or ;
  bit [SDW-1:0] cmp_and;
  bit [SDW-1:0] cmp_0_0;
  bit [SDW-1:0] cmp_0_1;
  bit [SDW-1:0] cmp_1_0;
  bit [SDW-1:0] cmp_1_1;
} t_cfg_cmp;

function t_cfg_cmp comparator_match (
  logic [SDW-1:0] val
);
  bit [SDW-1:0] val0;
  bit [SDW-1:0] val1;
  bit [SDW-1:0] mask;
begin
  val0 = ~val;
  val1 =  val;
  mask = val0 ^ val1;
  $display ("val = %08x, val0 =  %08x, val1 =  %08x, mask = %08x", val, val0, val1, mask);
  comparator_match.cmp_or  = 0;
  comparator_match.cmp_and = mask;
  comparator_match.cmp_0_0 = ~val;
  comparator_match.cmp_0_1 =  val;
  comparator_match.cmp_1_0 = ~val;
  comparator_match.cmp_1_1 =  val;
end
endfunction: comparator_match

////////////////////////////////////////////////////////////////////////////////
// table calculator
////////////////////////////////////////////////////////////////////////////////

localparam integer TEW = TMN+TCN+TAN;    // table event width
localparam integer TAW = TSW+TEW;        // table address width
localparam integer TDW = TSW+SEW+2*TCN;  // table data width

function [TDW-1:0] table_sos (
  input bit [TAW-1:0] adr
);
  // events
  bit [TMN-1:0] evt_cmp;
  bit [TAN-1:0] evt_add;
  bit [TCN-1:0] evt_cnt;
  // status
  bit [TSW-1:0] tbl_stt;
  // return values
  bit [TSW-1:0] stt;
  bit [  2-1:0] evt;
begin
  // deconstruct address
  {{evt_cmp, evt_add, evt_cnt}, tbl_stt} = adr;
  // state machine description
  case (tbl_stt)
    0: begin
      if (evt_cmp[0]) begin stt = 1; evt = 0; end
      else            begin stt = 0; evt = 0; end
    end
    1: begin
      if (evt_cmp[1]) begin stt = 2; evt = 0; end
      else            begin stt = 0; evt = 0; end
    end
    2: begin
      if (evt_cmp[0]) begin stt = 3; evt = 1; end
      else            begin stt = 0; evt = 0; end
    end
    default:          begin stt = 0; evt = 0; end
  endcase
  // contruct a data line in the table
  table_sos = {evt, stt};
end
endfunction: table_sos

task configure_sos;
  int adr;
  t_cfg_cmp cfg_cmp;
begin
  // select comparator registers
  bus_wselct = 4'b0001;
  // program CMP 0 with 'S'
  cfg_cmp = comparator_match ({24'hxxxxxx,"S"});
  master.trn ({5'h0,3'h0}, cfg_cmp.cmp_or );
  master.trn ({5'h0,3'h1}, cfg_cmp.cmp_and);
  master.trn ({5'h0,3'h4}, cfg_cmp.cmp_0_0);
  master.trn ({5'h0,3'h5}, cfg_cmp.cmp_0_1);
  master.trn ({5'h0,3'h6}, cfg_cmp.cmp_1_0);
  master.trn ({5'h0,3'h7}, cfg_cmp.cmp_1_1);
  // program CMP 0 with 'O'
  cfg_cmp = comparator_match ({24'hxxxxxx,"O"});
  master.trn ({5'h1,3'h0}, cfg_cmp.cmp_or );
  master.trn ({5'h1,3'h1}, cfg_cmp.cmp_and);
  master.trn ({5'h1,3'h4}, cfg_cmp.cmp_0_0);
  master.trn ({5'h1,3'h5}, cfg_cmp.cmp_0_1);
  master.trn ({5'h1,3'h6}, cfg_cmp.cmp_1_0);
  master.trn ({5'h1,3'h7}, cfg_cmp.cmp_1_1);
  // program table
  bus_wselct = 4'b0010;
  for (adr = 0; adr < 2**TAW; adr++) begin
    master.trn (adr, table_sos (adr [TAW-1:0]));
  end
end
endtask: configure_sos

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
  .bus_wselct  (bus_wselct),
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
