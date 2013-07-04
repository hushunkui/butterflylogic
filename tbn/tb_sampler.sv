`timescale 1ns/1ps

module tb_sampler #(
  parameter int SDW = 32,  // sample data    width
  parameter int SCW = 32,  // sample counter width
  parameter int SNW = 32   // sample number  width
);

// system signals
logic clk = 1;
logic rst = 1;

always #5ns clk = ~clk;

// configuration
logic [SCW-1:0] cfg_div = 0;
logic [SNW-1:0] cfg_num = 0;
// control
logic           ctl_st1 = 1'b0;
logic           ctl_st0 = 1'b0;
// status
logic           sts_run;

// input stream
logic           sti_tready ;
logic           sti_tvalid ;
logic           sti_trigger;
logic [SDW-1:0] sti_tdata  ;
// output stream
logic           sto_tready ;
logic           sto_tvalid ;
logic           sto_trigger;
logic           sto_tlast  ;
logic [SDW-1:0] sto_tdata  ;

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
    // bypass test
    test_bypass;
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


task test_bypass;
begin
  cfg_div = 0;
  repeat (2) @ (posedge clk);
  fork
    // source sequence
    begin
      for (src_i=0; src_i<16; src_i++) begin
        src.trn (src_i);
      end
    end
    // drain sequence
    begin
      for (drn_i=0; drn_i<16; drn_i++) begin
        drn.trn (data); if (data != drn_i)  error++;
      end
    end
  join
end
endtask: test_bypass

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.VW (1+SDW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sti_tready ),
  .tvalid  (sti_tvalid ),
  .tdata  ({sti_trigger,
            sti_tdata  })
);

// stream drain instance
str_drn #(.VW (1+1+SDW)) drn (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tready  (sto_tready ),
  .tvalid  (sto_tvalid ),
  .tdata  ({sto_trigger,
            sto_tlast  ,  
            sto_tdata  })
);

// DUT instance
sampler #(
  .SDW  (SDW),
  .SCW  (SCW),
  .SNW  (SNW)
) sampler (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // control signals
  .ctl_st0     (ctl_st0),
  .ctl_st1     (ctl_st1),
  // configuration signals
  .cfg_div     (cfg_div),
  .cfg_num     (cfg_num),
  // status
  .sts_run     (sts_run),
  // input stream
  .sti_tdata   (sti_tdata  ),
  .sti_tvalid  (sti_tvalid ),
  .sti_trigger (sti_trigger),
  .sti_tready  (sti_tready ),
  // output stream
  .sto_tdata   (sto_tdata  ),
  .sto_tvalid  (sto_tvalid ),
  .sto_trigger (sto_trigger),
  .sto_tlast   (sto_tlast  ),
  .sto_tready  (sto_tready )
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
