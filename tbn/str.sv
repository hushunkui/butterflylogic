`timescale 1ns/1ps

module str_src #(
  parameter int VW = 32  // value width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  output logic          tvalid = 1'b0,
  input  logic          tready,
  output logic [VW-1:0] tdata
);

// transfer
task trn (input [VW-1:0] value);
begin
  // put value on the bus
  tvalid = 1'b1;
  tdata = value;
  // perform transfer cycle
                  @ (posedge clk);
  while (~tready) @ (posedge clk);
  tvalid = 1'b0;
end
endtask: trn

endmodule: str_src


module str_drn #(
  parameter int VW = 32  // value width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  input  logic          tvalid,
  output logic          tready = 1'b0,
  input  logic [VW-1:0] tdata
);

// transfer
task trn (output [VW-1:0] value);
begin
  // perform transfer cycle
  tready = 1'b1;
                  @ (posedge clk);
  while (~tvalid) @ (posedge clk);
  tready = 1'b0;
  // pick value from the bus
  value = tdata;
end
endtask: trn

endmodule: str_drn
