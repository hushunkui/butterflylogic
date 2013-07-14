`timescale 1ns/1ps

module bus_master #(
  parameter int BAW = 32, // address width
  parameter int BDW = 32  // data    width
)(
  // system signals
  input  logic           clk, 
  input  logic           rst, 
  // bus signals
  output logic           wvalid = 1'b0,
  input  logic           wready,
  output logic [BAW-1:0] waddr ,
  output logic [BDW-1:0] wdata
);

// transfer
task trn (
  input [BDW-1:0] adr,
  input [BDW-1:0] dat
);
begin
  // put data on the bus
  wvalid = 1'b1;
  waddr  = adr;
  wdata  = dat;
  // perform transfer cycle
  do @ (posedge clk);
  while (~wready);
  waddr  = 'x;
  wdata  = 'x;
  wvalid = 1'b0;
end
endtask: trn

endmodule: bus_master


module bus_slave #(
  parameter int BAW = 32, // address width
  parameter int BDW = 32  // data    width
)(
  // system signals
  input  logic           clk, 
  input  logic           rst, 
  // bus signals
  input  logic           wvalid,
  output logic           wready = 1'b0,
  input  logic [BAW-1:0] waddr ,
  input  logic [BDW-1:0] wdata
);

// transfer
task trn (
  output [BAW-1:0] adr,
  output [BDW-1:0] dat
);
begin
  // perform transfer cycle
  wready = 1'b1;
  do @ (posedge clk);
  while (~wvalid);
  wready = 1'b0;
  // pick data from the bus
  adr = waddr;
  dat = wdata;
end
endtask: trn

endmodule: bus_slave
