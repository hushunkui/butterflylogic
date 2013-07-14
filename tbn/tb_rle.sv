`timescale 1ns/100ps

module tb_rle #(
  parameter int DW = 32,   // data width
  parameter int KW = DW/8  // keep width (number of data bytes)
);

// system signals
logic clk = 1;
logic rst = 1;

always #5 clk = ~clk;

//
// Instantaite RLE...
//
logic          enable;
logic          arm;
logic    [1:0] rle_mode;
logic [KW-1:0] disabledGroups;

// input stream
logic [KW-1:0][7:0] sti_data;
logic               sti_valid;
logic               sti_ready;
// output stream
logic [DW-1:0]      sto_data;
logic               sto_valid;
logic               sto_ready;

// test signals
logic [DW-1:0] value;
int unsigned   error = 0;
int unsigned   sti_cnt;
int unsigned   sto_cnt;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

//
// Generate test sequence...
//
initial
begin
  enable = 0;
  arm    = 1;
  repeat (10) @(posedge clk);
  rst = 0;

  rle_mode = 0;
  disabledGroups = 4'b1110; // 8'bit mode

  repeat (10) @(posedge clk);
  test_bypass(4);

  repeat (10) @(posedge clk);
  enable = 1; // turn on RLE...

  repeat (10) @(posedge clk);

  // report test status
  if (error)  $display ("FAILURE: there were %d errors during simulation.", error);
  else        $display ("SUCESS: there were no errors during simulation.");
  $finish;
end

event sto_event;

task test_bypass (input int unsigned len);
begin
  fork
    // source sequence
    begin
      for (sti_cnt=0; sti_cnt<len; sti_cnt++) begin
        sti.trn ({4{sti_cnt[7:0]}});
      end
    end
    // drain sequence
    begin
      for (sto_cnt=0; sto_cnt<len; sto_cnt++) begin
        #1;
        sto.trn (value); if (value != {4{sto_cnt[7:0]}})  error++;
      end
    end
  join
end
endtask: test_bypass

//task test_disabled;
//begin
//  issue_block(1      , {KW{8'h41}}, 1'b1);
//  issue_block(1      , {KW{8'h42}}, 1'b0);
//  issue_block(1      , {KW{8'h43}}, 1'b1);
//  issue_block(1      , {KW{8'h43}}, 1'b0);
//  issue_block(1      , {KW{8'h43}}, 1'b0);
//  issue_block(1      , {KW{8'h43}}, 1'b1);
//
//  issue_block(2    +1, {KW{8'h44}}, 1'b1);
//  issue_block(3    +1, {KW{8'h45}}, 1'b1);
//  issue_block(4    +1, {KW{8'h46}}, 1'b1);
//  issue_block(8    +1, {KW{8'h47}}, 1'b1);
//  issue_block(16   +1, {KW{8'h48}}, 1'b1);
//  issue_block(32   +1, {KW{8'h49}}, 1'b1);
//  issue_block(64   +1, {KW{8'h4A}}, 1'b1);
//  issue_block(128  +1, {KW{8'h4B}}, 1'b1);
//  issue_block(129  +1, {KW{8'h4C}}, 1'b1);
//  issue_block(130  +1, {KW{8'h4D}}, 1'b1);
//  issue_block(131  +1, {KW{8'h4E}}, 1'b1);
//  issue_block(256  +1, {KW{8'h4F}}, 1'b1);
//  issue_block(512  +1, {KW{8'h50}}, 1'b1);
//  issue_block(1024 +1, {KW{8'h51}}, 1'b1);
//  issue_block(2048 +1, {KW{8'h52}}, 1'b1);
//  issue_block(4096 +1, {KW{8'h53}}, 1'b1);
//  issue_block(8192 +1, {KW{8'h54}}, 1'b1);
//  issue_block(16384+1, {KW{8'h55}}, 1'b1);
//  issue_block(32768+1, {KW{8'h56}}, 1'b1);
//  issue_block(65536+1, {KW{8'h57}}, 1'b1);
//
//  issue_block(10     , {KW{8'hFF}}, 1'b0);
//end
//endtask: issue_pattern

////////////////////////////////////////////////////////////////////////////////
// bench module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.DW (DW)) sti (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (sti_valid),
  .tready  (sti_ready),
  .tvalue  (sti_data )
);

// stream drain instance
str_drn #(.DW (DW)) sto (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (sto_valid),
  .tready  (sto_ready),
  .tvalue  (sto_data )
);

////////////////////////////////////////////////////////////////////////////////
// DUT instance
////////////////////////////////////////////////////////////////////////////////

rle_enc rle (
  // system signals
  .clk            (clk),
  .rst            (rst),
  // configuration/control signals
  .enable         (enable        ),
  .arm            (arm           ),
  .rle_mode       (rle_mode      ),
  .disabledGroups (disabledGroups),
  // input stream
  .sti_data       (sti_data ),
  .sti_valid      (sti_valid),
  // output stream
  .sto_data       (sto_data ),
  .sto_valid      (sto_valid)
);

assign sti_ready = 1'b1;

////////////////////////////////////////////////////////////////////////////////
// waveform related code
////////////////////////////////////////////////////////////////////////////////

initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule
