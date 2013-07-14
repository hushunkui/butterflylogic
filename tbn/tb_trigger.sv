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

initial begin
  $finish();
end


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
