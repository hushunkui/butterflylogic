`timescale 1ns/1ps

module str_src #(
  parameter int DW = 32  // data width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  output logic          tvalid = 1'b0,
  input  logic          tready,
  output logic [DW-1:0] tdata
);

// transfer
task trn (input [DW-1:0] data);
begin
  // put data on the bus
  tvalid = 1'b1;
  tdata = data;
  // perform transfer cycle
                  @ (posedge clk);
  while (~tready) @ (posedge clk);
  tvalid = 1'b0;
end
endtask: trn

endmodule: str_src


module str_drn #(
  parameter int DW = 32  // data width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  input  logic          tvalid,
  output logic          tready = 1'b0,
  input  logic [DW-1:0] tdata
);

// transfer
task trn (output [DW-1:0] data);
begin
  // perform transfer cycle
  tready = 1'b1;
                  @ (posedge clk);
  while (~tvalid) @ (posedge clk);
  tready = 1'b0;
  // pick data from the bus
  data = tdata;
end
endtask: trn

endmodule: str_drn
