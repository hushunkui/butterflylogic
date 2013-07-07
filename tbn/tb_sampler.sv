//////////////////////////////////////////////////////////////////////////////
//
// testbench: sampler
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

`timescale 1ns/1ps

module tb_sampler #(
  parameter int SDW = 32,  // sample data    width
  parameter int SCW = 32,  // sample counter width
  parameter int SEW = 1    // sample event   width
);

// system signals
logic clk = 1;
logic rst = 1;

always #5ns clk = ~clk;

// configuration
logic [SCW-1:0] cfg_div = 0;
logic [SEW-0:0] cfg_evt_smp = 'b10;  // event sample mask

// input stream
logic           sti_tready;
logic           sti_tvalid;
logic [SEW-1:0] sti_tevent;
logic [SDW-1:0] sti_tdata ;
// output stream
logic           sto_tready;
logic           sto_tvalid;
logic [SEW-1:0] sto_tevent;
logic [SDW-1:0] sto_tdata ;

// test signals
logic [SDW-1:0] data;
int unsigned   error = 0;
int unsigned   src_i;
int unsigned   drn_i;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial
begin
fork

  // streaming sequences
  begin
    // reset sequence
    repeat (2) @ (posedge clk);
    rst = 1'b0;

    // list stream tests
    test_rate (0, 8);
    test_rate (1, 8);

    repeat (2) @ (posedge clk);
    // report test status
    if (error)  $display ("FAILURE: there were %d errors during simulation.", error);
    else        $display ("SUCESS: there were no errors during simulation.");
    $finish();
  end

  // timeout
  begin
    repeat (128) @ (posedge clk);
    $display ("FAILURE: simulation ended due to timeout.");
    $finish();
  end

join
end


task test_rate (
  input int div,
  input int len
);
begin
  cfg_div = div;
  repeat (1) @ (posedge clk);
  fork
    // source sequence
    begin
      for (src_i=0; src_i<len; src_i++) begin
        src.trn (src_i);
      end
    end
    // drain sequence
    begin
      for (drn_i=0; drn_i<len; drn_i+=1+div) begin
        drn.trn (data); if (data != drn_i)  error++;
      end
    end
  join
end
endtask: test_rate

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.VW (SEW+SDW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sti_tready ),
  .tvalid  (sti_tvalid ),
  .tdata  ({sti_tevent ,
            sti_tdata  })
);

// stream drain instance
str_drn #(.VW (SEW+SDW)) drn (
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
sampler #(
  .SDW  (SDW),
  .SCW  (SCW),
  .SEW  (SEW)
) sampler (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // configuration signals
  .cfg_div     (cfg_div),
  .cfg_evt_smp (cfg_evt_smp),
  // input stream
  .sti_tdata   (sti_tdata ),
  .sti_tvalid  (sti_tvalid),
  .sti_tevent  (sti_tevent),
  .sti_tready  (sti_tready),
  // output stream
  .sto_tdata   (sto_tdata ),
  .sto_tvalid  (sto_tvalid),
  .sto_tevent  (sto_tevent),
  .sto_tready  (sto_tready)
);

////////////////////////////////////////////////////////////////////////////////
// waveform related code
////////////////////////////////////////////////////////////////////////////////

initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial begin
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule: tb_sampler
