`timescale 1ns/100ps

module tb #(
  parameter FILENAME_TX = "uart_txd.fifo",
  parameter FILENAME_RX = "uart_rxd.fifo"
);

// system clock/reset
logic clk = 1'b1;
logic rst = 1'b1;

always #10ns clk = ~clk;

initial begin
  repeat (4) @ (posedge clk); rst <= 1'b0;
end

// UART file pointers
int fp_tx;
int fp_rx;
int status;

// UART signals
wire uart_tx;
wire uart_rx;

//
// Instantiate the Logic Sniffer...
//
logic        extClockIn   = 1'b0;
logic        extTriggerIn = 1'b0;
wire  [31:0] extData;
logic [31:0] extData_reg;

assign extData = extData_reg;

`ifdef MODELSIM
glbl glbl ();
`endif

Terasic_DE1 la (
  // system signals
  .clk           (clk),
  .rst           (rst),
  // logic analyzer signals
  .extClockIn    (extClockIn),
  .extClockOut   (extClockOut),
  .extTriggerIn  (extTriggerIn),
  .extTriggerOut (extTriggerOut),
  .extData       (extData),
  .dataReady     (dataReady),
  .armLEDnn      (armLEDnn),
  .triggerLEDnn  (triggerLEDnn),
  .uart_tx       (uart_tx),
  .uart_rx       (uart_rx)
);

uart_model #(
) uart (
  .TxD  (uart_rx),
  .RxD  (uart_tx)
);

// Generate UART test commands...
task write_cmd (input logic [7:0] dat);
  int cnt;
begin
  uart.transmit (dat);
//  cnt = uart.cnt_tx;
//  status = $ungetc (dat, fp_tx);
  $display ("%t: UART TxD: (0x%02x) '%c'",$realtime, dat, dat);
//  wait (uart.cnt_tx == cnt+1);
end
endtask: write_cmd

initial begin
  fp_tx = $fopen (FILENAME_TX, "w");
  fp_rx = $fopen (FILENAME_RX, "r");

  uart.start (FILENAME_TX, FILENAME_RX);
end

task write_longcmd (
  input  [7:0] opcode,
  input [31:0] value
);
begin
  write_cmd (opcode);
  write_cmd (value[ 7: 0]);
  write_cmd (value[15: 8]);
  write_cmd (value[23:16]);
  write_cmd (value[31:24]);
end
endtask: write_longcmd


// Simulate behavior of PIC responding the dataReady asserting...
task wait4fpga;
begin
  while (!dataReady) @(posedge dataReady);
  while ( dataReady) write_cmd(8'h7F);
end
endtask: wait4fpga


// 100Mhz sampling...
task setup_channel;
input [3:0] channel_disable;
begin
  $display ("%t: Reset for channel test 4'b%b...", $realtime, channel_disable);
  write_cmd (8'h00); 

  $display ("%t: Flags... (internal_testmode.  channel_disable=%b)", $realtime,channel_disable);
  write_longcmd (8'h82, 32'h00000800 | {channel_disable,2'b00}); // set internal testmode

  $display ("%t: Divider... (100Mhz sampling)", $realtime);
  write_longcmd (8'h80, 32'h00000000);

  $display ("%t: Read & Delay Count...", $realtime);
  write_longcmd (8'h81, 32'h00040004);

  $display ("%t: Starting channel test...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  wait4fpga();
end
endtask: setup_channel


//
// Generate test sequence...
//
initial
begin
  extData_reg = 0;
  wait (~rst);
  repeat (2) @ (posedge clk);

  $display ("%t: Reset...", $realtime);
  repeat (5)
  write_cmd (8'h00);

  $display ("%t: Query ID...", $realtime);
  write_cmd (8'h02); wait4fpga();

`ifdef TEST_META
  $display ("%t: Query Meta data...", $realtime);
  write_cmd (8'h04); 
  wait4fpga();
  repeat (5) @(posedge clk); 
  $finish;
`endif

  //
  // Setup default test on disabled groups...
  //
  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_longcmd (8'hC0, 32'h000000FF); // mask
  write_longcmd (8'hC1, 32'h00000040); // value
  write_longcmd (8'hC2, 32'h08000000); // config

  // 8 bit tests...
  setup_channel(4'hE); // channel 0
  setup_channel(4'hD); // channel 1
  setup_channel(4'hB); // channel 2
  setup_channel(4'h7); // channel 3

  // 16 bit tests...
  setup_channel(4'hC); // channels 0 & 1
  setup_channel(4'hA); // channels 0 & 2
  setup_channel(4'h6); // channels 0 & 3
  setup_channel(4'h9); // channels 1 & 2
  setup_channel(4'h5); // channels 1 & 3
  setup_channel(4'h3); // channels 2 & 3

  // 24 bit tests...
  setup_channel(4'h8); // channels 0,1,2
  setup_channel(4'h4); // channels 0,1,3
  setup_channel(4'h2); // channels 0,2,3
  setup_channel(4'h1); // channels 1,2,3

  $finish;
end

//
// Initialized wavedump...
//
initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

// periodic time printouts
always #10000 $display ("%t",$realtime);

endmodule
