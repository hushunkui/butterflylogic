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
  // sample data parameters
  parameter integer SEW = 2,   // sample event width
  parameter integer SDW = 32,  // sample data  width
  // trigger event source parameters
  parameter integer TMN = 4,   // trigger matcher number
  parameter integer TAN = 2,   // trigger adder   number
  parameter integer TCN = 4,   // trigger counter number
  parameter integer TCW = 32,  // counter width
  // state machine table parameters
  parameter integer TSW = 4,   // table state width
  // local table parameters, also used elsewhere
  parameter integer TEW = TMN+TAN+TCN,    // table event width
  parameter integer TAW = TSW+TEW,        // table address width
  parameter integer TDW = TSW+SEW+2*TCN,  // table data width
  // system bus parameters
  parameter integer BAW = TAW, // bus address width
  parameter integer BDW = 32   // bus data    width
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
      src.trn ({32'h00000000}); // dummy data, to clear the matcher pipeline
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
// matcher calculator
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  bit [SDW-1:0] mch_or ;
  bit [SDW-1:0] mch_and;
  bit [SDW-1:0] mch_0_0;
  bit [SDW-1:0] mch_0_1;
  bit [SDW-1:0] mch_1_0;
  bit [SDW-1:0] mch_1_1;
} t_cfg_mch;

function t_cfg_mch matcher_match (
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
  matcher_match.mch_or  = 0;
  matcher_match.mch_and = mask;
  matcher_match.mch_0_0 = ~val;
  matcher_match.mch_0_1 =  val;
  matcher_match.mch_1_0 = ~val;
  matcher_match.mch_1_1 =  val;
end
endfunction: matcher_match

////////////////////////////////////////////////////////////////////////////////
// table calculator
////////////////////////////////////////////////////////////////////////////////

function [TDW-1:0] table_sos (
  input bit [TAW-1:0] adr
);
  // events
  bit   [TMN-1:0] evt_mch;  // matcher
  bit   [TAN-1:0] evt_add;  // adder
  bit   [TCN-1:0] evt_cnt;  // counter
  // state
  bit   [TSW-1:0] tbl_stt;  // state
  // return values
  bit   [TSW-1:0] out_stt;
  bit [2*TCN-1:0] out_cnt;
  bit     [2-1:0] out_evt;
begin
  // deconstruct address
  {{evt_mch, evt_add, evt_cnt}, tbl_stt} = adr;
  // state machine description
  case (tbl_stt)
    0: begin
      if (evt_mch[0]) begin out_stt = 1; out_evt = 0; end
      else            begin out_stt = 0; out_evt = 0; end
    end
    1: begin
      if (evt_mch[1]) begin out_stt = 2; out_evt = 0; end
      else            begin out_stt = 0; out_evt = 0; end
    end
    2: begin
      if (evt_mch[0]) begin out_stt = 3; out_evt = 1; end
      else            begin out_stt = 0; out_evt = 0; end
    end
    default:          begin out_stt = 0; out_evt = 0; end
  endcase
  // counters are not used here, therefore they should idle
  out_cnt = {TCN{2'b00}}; 
  // contruct a data line in the table
  table_sos = {out_evt, out_cnt, out_stt};
end
endfunction: table_sos

task configure_sos;
  int adr;
  t_cfg_mch cfg_mch;
begin
  // select matcher registers
  bus_wselct = 4'b0001;
  // program CMP 0 with 'S'
  cfg_mch = matcher_match ({24'hxxxxxx,"S"});
  master.trn ({5'h0,3'h0}, cfg_mch.mch_or );
  master.trn ({5'h0,3'h1}, cfg_mch.mch_and);
  master.trn ({5'h0,3'h4}, cfg_mch.mch_0_0);
  master.trn ({5'h0,3'h5}, cfg_mch.mch_0_1);
  master.trn ({5'h0,3'h6}, cfg_mch.mch_1_0);
  master.trn ({5'h0,3'h7}, cfg_mch.mch_1_1);
  // program CMP 0 with 'O'
  cfg_mch = matcher_match ({24'hxxxxxx,"O"});
  master.trn ({5'h1,3'h0}, cfg_mch.mch_or );
  master.trn ({5'h1,3'h1}, cfg_mch.mch_and);
  master.trn ({5'h1,3'h4}, cfg_mch.mch_0_0);
  master.trn ({5'h1,3'h5}, cfg_mch.mch_0_1);
  master.trn ({5'h1,3'h6}, cfg_mch.mch_1_0);
  master.trn ({5'h1,3'h7}, cfg_mch.mch_1_1);
  // program table
  bus_wselct = 4'b1000;
  for (adr = 0; adr < 2**TAW; adr++) begin
    master.trn (adr, { {BDW-TDW{1'bx}}, table_sos (adr [TAW-1:0]) });
  end
end
endtask: configure_sos

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// bus master instance
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
